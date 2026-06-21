local file_utils = require('custom.utils.files')
local util = require('custom.actions.github.util')

local parse_team_config = util.parse_team_config
local get_team_members_for_slugs = util.get_team_members_for_slugs

local M = {}

local function show_notifications_picker(notifications)
  local items = {}
  for _, notif in ipairs(notifications) do
    local type_icon = ({ PullRequest = '', Issue = '', Discussion = '󰍩' })[notif.subject_type] or ''
    table.insert(items, {
      text = string.format('%s [%s] %s (%s)', type_icon, notif.repository, notif.subject_title, notif.reason),
      notif = notif,
    })
  end

  local snacks_ok, snacks = pcall(require, 'snacks')
  if not snacks_ok then return end

  -- Cache for fetched notification details (keyed by subject_url)
  local detail_cache = {}

  snacks.picker({
    title = 'GitHub Notifications (' .. #items .. ')',
    items = items,
    format = function(item) return { { item.text, 'Normal' } } end,
    preview = function(ctx)
      local item = ctx.item
      if not item or not item.notif then return end
      local notif = item.notif

      local function render_preview(lines)
        ctx.preview:set_lines(lines)

        -- Highlight header lines
        for i, line in ipairs(lines) do
          if line:match('^[A-Z].*:') and not line:match('^  ') then
            ctx.preview:highlight({ col = 0, line = i, end_col = line:find(':'), hl = 'Title' })
          elseif line:match('^─') then
            ctx.preview:highlight({ col = 0, line = i, end_col = #line, hl = 'Comment' })
          end
        end
      end

      -- Build static header
      local reason_labels = {
        assign = 'Assigned to you',
        author = 'You created this',
        comment = 'New comment',
        ci_activity = 'CI activity',
        invitation = 'Invitation',
        manual = 'Subscribed manually',
        mention = 'You were mentioned',
        review_requested = 'Review requested',
        security_alert = 'Security alert',
        state_change = 'State changed',
        subscribed = 'Subscribed',
        team_mention = 'Team mentioned',
      }

      local header = {
        'Title:      ' .. (notif.subject_title or ''),
        'Repository: ' .. (notif.repository or ''),
        'Type:       ' .. (notif.subject_type or ''),
        'Reason:     ' .. (reason_labels[notif.reason] or notif.reason or ''),
        'Updated:    ' .. (notif.updated_at or ''),
        'Unread:     ' .. (notif.unread and 'Yes' or 'No'),
        '────────────────────────────────────────',
      }

      -- Show header immediately, then fetch details async
      local api_url = notif.subject_url
      if not api_url or api_url == '' then
        render_preview(header)
        return
      end

      if detail_cache[api_url] then
        local lines = vim.list_extend({}, header)
        vim.list_extend(lines, detail_cache[api_url])
        render_preview(lines)
        return
      end

      -- Show header with loading indicator
      local loading = vim.list_extend({}, header)
      table.insert(loading, 'Loading details...')
      render_preview(loading)

      -- Fetch body/details from the API
      local jq_expr = notif.subject_type == 'PullRequest'
          and '{state: .state, user: .user.login, body: .body, additions: .additions, deletions: .deletions, changed_files: .changed_files, merged: .merged, draft: .draft, labels: [.labels[].name]}'
        or '{state: .state, user: .user.login, body: .body, labels: [.labels[].name]}'

      vim.system(
        { 'gh', 'api', api_url, '--jq', jq_expr },
        { text = true },
        vim.schedule_wrap(function(detail_result)
          if detail_result.code ~= 0 or not detail_result.stdout or detail_result.stdout == '' then
            detail_cache[api_url] = { '(Could not load details)' }
          else
            local ok, detail = pcall(vim.json.decode, detail_result.stdout)
            if not ok or not detail then
              detail_cache[api_url] = { '(Failed to parse details)' }
            else
              local detail_lines = {}
              if detail.user then table.insert(detail_lines, 'Author:     ' .. detail.user) end
              if detail.state then
                local state = detail.state
                if detail.merged then
                  state = 'merged'
                elseif detail.draft then
                  state = 'draft'
                end
                table.insert(detail_lines, 'State:      ' .. state)
              end
              if detail.additions then
                table.insert(detail_lines, 'Changes:    +' .. detail.additions .. ' -' .. detail.deletions .. ' (' .. detail.changed_files .. ' files)')
              end
              if detail.labels and #detail.labels > 0 then table.insert(detail_lines, 'Labels:     ' .. table.concat(detail.labels, ', ')) end
              if detail.body and detail.body ~= '' then
                table.insert(
                  detail_lines,
                  '────────────────────────────────────────'
                )
                for body_line in detail.body:gmatch('[^\r\n]*') do
                  table.insert(detail_lines, body_line)
                end
              end
              detail_cache[api_url] = detail_lines
            end
          end

          -- Re-render if this item is still selected
          local lines = vim.list_extend({}, header)
          vim.list_extend(lines, detail_cache[api_url])
          render_preview(lines)
        end)
      )
    end,
    confirm = function(picker, item)
      picker:close()
      local api_url = item.notif.subject_url
      if not api_url or api_url == '' then return end

      vim.system(
        { 'gh', 'api', api_url, '--jq', '.html_url' },
        { text = true },
        vim.schedule_wrap(function(url_result)
          if url_result.code == 0 and url_result.stdout and url_result.stdout ~= '' then
            local html_url = vim.trim(url_result.stdout)
            file_utils.open(html_url)
          else
            vim.notify('Could not resolve URL for notification', vim.log.levels.WARN)
          end
        end)
      )
    end,
    actions = {
      mark_read = function(p)
        local item = p:current()
        if not item or not item.notif then return end
        vim.system(
          { 'gh', 'api', '--method', 'PATCH', '/notifications/threads/' .. item.notif.id },
          { text = true },
          vim.schedule_wrap(function(mark_result)
            if mark_result.code == 0 then vim.notify('Marked as read: ' .. item.notif.subject_title, vim.log.levels.INFO) end
          end)
        )
      end,
    },
    win = {
      input = {
        keys = {
          ['<C-d>'] = { 'mark_read', desc = 'Mark as read', mode = { 'n', 'i' } },
        },
      },
    },
  })
end

local function fetch_notifications(callback)
  vim.notify('Fetching GitHub notifications...', vim.log.levels.INFO)
  vim.system(
    {
      'gh',
      'api',
      'notifications',
      '--jq',
      '.[] | {id: .id, subject_title: .subject.title, subject_type: .subject.type, subject_url: .subject.url, repository: .repository.full_name, reason: .reason, updated_at: .updated_at, unread: .unread}',
    },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        vim.notify('Failed to fetch notifications: ' .. (result.stderr or ''), vim.log.levels.ERROR)
        return
      end

      if not result.stdout or result.stdout == '' then
        vim.notify('No notifications', vim.log.levels.INFO)
        return
      end

      local notifications = {}
      for line in result.stdout:gmatch('[^\n]+') do
        local ok, notif = pcall(vim.json.decode, line)
        if ok and notif then table.insert(notifications, notif) end
      end

      if #notifications == 0 then
        vim.notify('No notifications', vim.log.levels.INFO)
        return
      end

      callback(notifications)
    end)
  )
end

local COMMENT_REASONS = { comment = true, mention = true, team_mention = true }

--- Keep only notifications whose reason is a comment or mention.
---@param notifications table[]
---@return table[]
local function filter_comment_notifications(notifications)
  local filtered = {}
  for _, notif in ipairs(notifications) do
    if COMMENT_REASONS[notif.reason] then table.insert(filtered, notif) end
  end
  return filtered
end

function M.show_notifications()
  fetch_notifications(function(notifications)
    local filtered = filter_comment_notifications(notifications)
    if #filtered == 0 then
      vim.notify('No comment or mention notifications', vim.log.levels.INFO)
      return
    end
    show_notifications_picker(filtered)
  end)
end

---@param org_name string
---@param slugs string[]
---@param comment_only boolean|nil when true, keep only comment/mention notifications
local function fetch_notifications_for_team(org_name, slugs, comment_only)
  get_team_members_for_slugs(org_name, slugs, function(usernames)
    if #usernames == 0 then
      vim.notify('No members found for selected team', vim.log.levels.WARN)
      return
    end

    local members_set = {}
    for _, login in ipairs(usernames) do
      members_set[login:lower()] = true
    end

    fetch_notifications(function(notifications)
      if comment_only then notifications = filter_comment_notifications(notifications) end
      vim.notify('Resolving notification authors...', vim.log.levels.INFO)
      local pending = #notifications
      local author_map = {}

      if pending == 0 then
        vim.notify('No notifications', vim.log.levels.INFO)
        return
      end

      for _, notif in ipairs(notifications) do
        local api_url = notif.subject_url
        if not api_url or api_url == '' then
          pending = pending - 1
          if pending == 0 then
            vim.schedule(function()
              local filtered = {}
              for _, n in ipairs(notifications) do
                local author = author_map[n.subject_url]
                if author and members_set[author:lower()] then table.insert(filtered, n) end
              end
              if #filtered == 0 then
                vim.notify('No notifications from team members', vim.log.levels.INFO)
                return
              end
              show_notifications_picker(filtered)
            end)
          end
        else
          vim.system(
            { 'gh', 'api', api_url, '--jq', '.user.login' },
            { text = true },
            vim.schedule_wrap(function(author_result)
              if author_result.code == 0 and author_result.stdout and author_result.stdout ~= '' then author_map[api_url] = vim.trim(author_result.stdout) end
              pending = pending - 1
              if pending == 0 then
                local filtered = {}
                for _, n in ipairs(notifications) do
                  local author = author_map[n.subject_url]
                  if author and members_set[author:lower()] then table.insert(filtered, n) end
                end
                if #filtered == 0 then
                  vim.notify('No notifications from team members', vim.log.levels.INFO)
                  return
                end
                show_notifications_picker(filtered)
              end
            end)
          )
        end
      end
    end)
  end)
end

function M.show_notifications_by_team()
  local team_slugs, org_name = parse_team_config()
  if not team_slugs or not org_name then return end

  local choices = {}
  for _, slug in ipairs(team_slugs) do
    table.insert(choices, { text = slug, slugs = { slug } })
  end
  table.insert(choices, { text = 'All teams', slugs = team_slugs })

  vim.ui.select(choices, {
    prompt = 'Select team:',
    format_item = function(item) return item.text end,
  }, function(choice)
    if not choice then return end
    fetch_notifications_for_team(org_name, choice.slugs)
  end)
end

function M.show_notifications_by_default_team()
  local team_slugs, org_name = parse_team_config()
  if not team_slugs or not org_name then return end

  fetch_notifications_for_team(org_name, { team_slugs[1] }, true)
end

function M.redeploy_pr()
  vim.system(
    { 'gh', 'pr', 'view', '--json', 'number,comments', '--jq', '.number' },
    { text = true },
    vim.schedule_wrap(function(pr_result)
      if pr_result.code ~= 0 or not pr_result.stdout or pr_result.stdout == '' then
        vim.notify('No PR found for current branch', vim.log.levels.ERROR)
        return
      end

      local pr_number = vim.trim(pr_result.stdout)

      vim.system(
        {
          'gh',
          'api',
          string.format('repos/{owner}/{repo}/issues/%s/comments', pr_number),
          '--jq',
          '[.[] | select((.body | test("#deploy")) or .user.login == "github-actions[bot]") | {id: .id, author: .user.login}]',
        },
        { text = true },
        vim.schedule_wrap(function(comments_result)
          if comments_result.code ~= 0 then
            vim.notify('Failed to fetch PR comments', vim.log.levels.ERROR)
            return
          end

          local ok, comments = pcall(vim.json.decode, comments_result.stdout)
          if not ok then comments = {} end

          local pending = #comments

          local function add_deploy_comment()
            vim.system(
              { 'gh', 'pr', 'comment', pr_number, '--body', '#deploy' },
              { text = true },
              vim.schedule_wrap(function(result)
                if result.code == 0 then
                  vim.notify(string.format('Added #deploy to PR #%s', pr_number), vim.log.levels.INFO)
                else
                  vim.notify('Failed to add #deploy comment', vim.log.levels.ERROR)
                end
              end)
            )
          end

          if pending == 0 then
            add_deploy_comment()
            return
          end

          for _, comment in ipairs(comments) do
            vim.system(
              { 'gh', 'api', '--method', 'DELETE', string.format('repos/{owner}/{repo}/issues/comments/%d', comment.id) },
              { text = true },
              vim.schedule_wrap(function()
                pending = pending - 1
                if pending == 0 then add_deploy_comment() end
              end)
            )
          end
        end)
      )
    end)
  )
end

return M
