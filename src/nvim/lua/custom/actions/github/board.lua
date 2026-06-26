-- Team PR board: a full-window buffer that lists the configured team's (and the
-- current user's) open GitHub PRs with their review + CI status, polls/refreshes
-- on a timer while open, and opens the PR under the cursor in the browser on
-- <CR>. Unlike the transient `ugt`/`ugT` pickers, this is a persistent,
-- self-refreshing buffer. Bound to <Leader>ugb.
local file_utils = require('custom.utils.files')
local github_utils = require('custom.utils.github')
local util = require('custom.actions.github.util')

local M = {}

local POLL_INTERVAL_MS = 60000
local BUFFER_NAME = 'Team PRs'

local panel_ns = vim.api.nvim_create_namespace('custom_team_pr_board')

-- Only one team PR board is meaningful at a time; its state lives here.
local state = {
  buf = nil,
  timer = nil,
  org_name = nil,
  usernames = nil,
  line2pr = {},
  loading = false,
}

--- Stop and dispose the polling timer and clear the loading guard. Safe to call
--- repeatedly (it nils the handle), so BufWipeout and VimLeavePre can both fire.
function M._stop()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  state.loading = false
end

--- Aggregate a PR's `statusCheckRollup` array into a single CI emoji. Failure
--- outranks pending, which outranks success; an empty/absent rollup is neutral.
---@param rollup table[]|nil array of { conclusion?: string, state?: string }
---@return string emoji
function M.ci_status(rollup)
  if type(rollup) ~= 'table' or #rollup == 0 then return '➖' end

  local fail, pending, pass = 0, 0, 0
  for _, check in ipairs(rollup) do
    local conclusion = (check.conclusion or ''):upper()
    local check_state = (check.state or ''):upper()
    if conclusion == 'FAILURE' or conclusion == 'CANCELLED' or conclusion == 'TIMED_OUT' or conclusion == 'ERROR' then
      fail = fail + 1
    elseif check_state == 'PENDING' or check_state == 'IN_PROGRESS' or check_state == 'QUEUED' then
      pending = pending + 1
    elseif conclusion == 'SUCCESS' then
      pass = pass + 1
    end
  end

  if fail > 0 then return '❌' end
  if pending > 0 then return '🟡' end
  if pass > 0 then return '✅' end
  return '➖'
end

--- Build the display line for one PR row: draft, review, ci, author, number,
--- title, repo. Expects `pr.ci` to already be a CI emoji (see M.ci_status).
---@param pr table { draft?, review_decision?, ci?, author?, number?, title?, repo? }
---@return string line
function M.format_pr_line(pr)
  local draft = github_utils.format_draft_state(pr.draft)
  local review = github_utils.format_review_decision(pr.review_decision)
  local ci = pr.ci or '➖'
  return string.format('%s %s %s  [%s] #%d %s  %s', draft, review, ci, pr.author or '?', pr.number or 0, pr.title or '', pr.repo or '')
end

--- Collect open PRs for the given team usernames plus the current user's own
--- open PRs across configured owners. Mirrors team.lua's fan-out but returns the
--- deduped, sorted list via callback instead of opening a picker.
---@param org_name string
---@param usernames string[]
---@param callback fun(prs: table[])
local function collect_team_prs(org_name, usernames, callback)
  local all_prs = {}
  local seen_urls = {}

  local function add_pr(pr)
    if pr.url and seen_urls[pr.url] then return end
    if pr.url then seen_urls[pr.url] = true end
    table.insert(all_prs, pr)
  end

  local function finish()
    table.sort(all_prs, function(a, b)
      local a_created = a.created_at or ''
      local b_created = b.created_at or ''
      if a_created ~= b_created then return a_created > b_created end
      if (a.author or '') ~= (b.author or '') then return (a.author or '') < (b.author or '') end
      return (a.repo or '') < (b.repo or '')
    end)
    callback(all_prs)
  end

  -- After team PRs are collected, merge in the current user's own open PRs.
  local function merge_my_prs()
    github_utils.get_current_login(function(my_login)
      github_utils.fetch_my_prs_across_owners(github_utils.get_github_owners(), {}, function(my_prs)
        for _, pr in ipairs(my_prs) do
          add_pr({
            number = pr.number,
            title = pr.title,
            url = pr.url,
            repo = pr.repo,
            author = my_login or 'me',
            draft = pr.draft,
            created_at = pr.created_at,
          })
        end
        finish()
      end)
    end)
  end

  if #usernames == 0 then
    merge_my_prs()
    return
  end

  local pending = #usernames
  for _, username in ipairs(usernames) do
    vim.system(
      {
        'gh',
        'search',
        'prs',
        '--owner',
        org_name,
        '--state',
        'open',
        '--author',
        username,
        '--json',
        'number,title,repository,url,isDraft,createdAt',
        '--limit',
        '100',
      },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code == 0 and result.stdout and result.stdout ~= '' then
          local ok, prs = pcall(vim.json.decode, result.stdout)
          if ok and type(prs) == 'table' then
            for _, pr in ipairs(prs) do
              local repo_name = pr.repository and pr.repository.nameWithOwner or ''
              add_pr({
                number = pr.number,
                title = pr.title,
                url = pr.url,
                repo = repo_name,
                author = username,
                draft = pr.isDraft,
                created_at = pr.createdAt,
              })
            end
          end
        end

        pending = pending - 1
        if pending == 0 then merge_my_prs() end
      end)
    )
  end
end

--- Enrich each PR with its review decision and CI status via a single
--- `gh pr view` per PR. Sets `pr.review_decision` and `pr.ci`, then calls back.
---@param prs table[]
---@param callback fun(prs: table[])
local function append_statuses(prs, callback)
  if #prs == 0 then
    callback(prs)
    return
  end

  local pending = #prs
  local function done()
    pending = pending - 1
    if pending == 0 then callback(prs) end
  end

  for _, pr in ipairs(prs) do
    if not pr.repo or pr.repo == '' or not pr.number then
      pr.review_decision = nil
      pr.ci = M.ci_status(nil)
      done()
    else
      vim.system(
        { 'gh', 'pr', 'view', tostring(pr.number), '--repo', pr.repo, '--json', 'reviewDecision,statusCheckRollup' },
        { text = true },
        vim.schedule_wrap(function(result)
          local decision, rollup = nil, nil
          if result.code == 0 and result.stdout and result.stdout ~= '' then
            local ok, data = pcall(vim.json.decode, result.stdout)
            if ok and type(data) == 'table' then
              decision = data.reviewDecision
              rollup = data.statusCheckRollup
            end
          end
          pr.review_decision = decision
          pr.ci = M.ci_status(rollup)
          done()
        end)
      )
    end
  end
end

---@return boolean
local function is_active() return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf) end

--- Replace the board buffer's contents, applying header highlights and
--- preserving the cursor position when the board is the current buffer.
---@param lines string[]
---@param highlights ({ [1]: integer, [2]: string })[]|nil
local function render_lines(lines, highlights)
  if not is_active() then return end
  local buf = state.buf

  local win = vim.api.nvim_get_current_win()
  local same_win = vim.api.nvim_win_get_buf(win) == buf
  local cursor = same_win and vim.api.nvim_win_get_cursor(win) or nil

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, panel_ns, 0, -1)
  for _, hl in ipairs(highlights or {}) do
    pcall(vim.api.nvim_buf_set_extmark, buf, panel_ns, hl[1], 0, {
      end_col = #(lines[hl[1] + 1] or ''),
      hl_group = hl[2],
    })
  end

  if cursor then
    local row = math.min(cursor[1], vim.api.nvim_buf_line_count(buf))
    pcall(vim.api.nvim_win_set_cursor, win, { row, cursor[2] })
  end
end

---@param count integer
---@return string title
---@return string legend
local function header(count)
  local title = string.format('󰓢 Team PRs (%d) · updated %s — <CR> open · r refresh · q close', count, vim.fn.strftime('%H:%M:%S'))
  local legend = 'draft 📝/🟢 · review ✅/❌/⏳ · ci ✅/❌/🟡/➖'
  return title, legend
end

--- Render the PR list and rebuild the line -> PR map used by <CR>.
---@param prs table[]
local function render(prs)
  if not is_active() then return end

  local title, legend = header(#prs)
  local lines = { title, legend }
  local highlights = { { 0, 'Title' }, { 1, 'Comment' } }
  state.line2pr = {}

  if #prs == 0 then
    table.insert(lines, '')
    table.insert(lines, 'No open PRs for your team right now.')
  else
    for _, pr in ipairs(prs) do
      table.insert(lines, M.format_pr_line(pr))
      state.line2pr[#lines] = pr
    end
  end

  render_lines(lines, highlights)
end

local function render_loading() render_lines({ '󰓢 Team PRs · loading…', 'Fetching team PRs and statuses…' }, { { 0, 'Title' }, { 1, 'Comment' } }) end

--- Fetch team + own PRs, enrich with statuses, and re-render. Guards against
--- overlapping polls and against the buffer having been closed mid-flight.
local function fetch_and_render()
  if not is_active() then
    M._stop()
    return
  end
  if state.loading then return end
  state.loading = true

  collect_team_prs(state.org_name, state.usernames or {}, function(prs)
    if not is_active() then
      state.loading = false
      return
    end
    append_statuses(prs, function(enriched)
      state.loading = false
      if not is_active() then return end
      render(enriched)
    end)
  end)
end

--- Open the PR on the current line in the browser.
local function open_under_cursor()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local pr = state.line2pr[line]
  if pr and pr.url then
    file_utils.open(pr.url)
    vim.notify('Opened PR #' .. (pr.number or '?') .. ' in browser', vim.log.levels.INFO)
  else
    vim.notify('No PR on this line', vim.log.levels.WARN)
  end
end

--- Close the board (deleting the buffer triggers BufWipeout -> M._stop).
local function close()
  if is_active() then pcall(vim.api.nvim_buf_delete, state.buf, { force = true }) end
end

---@param buf integer
local function setup_keymaps(buf)
  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set('n', '<CR>', open_under_cursor, opts)
  vim.keymap.set('n', 'r', function()
    vim.notify('Refreshing team PRs…', vim.log.levels.INFO)
    fetch_and_render()
  end, opts)
  vim.keymap.set('n', 'q', close, opts)
  vim.keymap.set('n', '<Esc>', close, opts)
end

---@param buf integer
local function setup_autocmds(buf)
  local group = vim.api.nvim_create_augroup('CustomTeamPrBoard', { clear = true })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = buf,
    callback = function() M._stop() end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function() M._stop() end,
  })
end

---@return integer buf
local function create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'gh-team-prs'
  pcall(vim.api.nvim_buf_set_name, buf, BUFFER_NAME)
  vim.api.nvim_set_current_buf(buf)
  return buf
end

--- Open (or replace) the team PR board: a full-window, auto-polling buffer of
--- the default team's + your open PRs with review/CI status. <CR> opens the PR.
function M.open_team_pr_board()
  if vim.fn.executable('gh') ~= 1 then
    vim.notify('gh CLI not found on PATH', vim.log.levels.ERROR)
    return
  end

  local team_slugs, org_name = util.parse_team_config()
  if not team_slugs or not org_name then
    return -- parse_team_config already notified about the missing env
  end

  -- Replace any existing board: stop its timer, then drop its buffer.
  M._stop()
  local previous = state.buf

  state.buf = create_buffer()
  state.org_name = org_name
  state.usernames = {}
  state.line2pr = {}
  state.loading = false

  if previous and previous ~= state.buf and vim.api.nvim_buf_is_valid(previous) then pcall(vim.api.nvim_buf_delete, previous, { force = true }) end

  setup_keymaps(state.buf)
  setup_autocmds(state.buf)
  render_loading()

  -- Resolve the default team's members once (cached), then poll.
  util.get_team_members_for_slugs(org_name, { team_slugs[1] }, function(usernames)
    if not is_active() then return end
    state.usernames = usernames
    fetch_and_render()
    state.timer = vim.uv.new_timer()
    state.timer:start(POLL_INTERVAL_MS, POLL_INTERVAL_MS, vim.schedule_wrap(fetch_and_render))
  end)
end

return M
