local M = {}

local REQUIRED_VARS = {
  {
    name = 'ORG_GITHUB_NAME',
    features = 'GitHub: org repos, PRs, issues',
    get = function() return vim.env.ORG_GITHUB_NAME end,
  },
  {
    name = 'PRI_GITHUB_USERNAME',
    features = 'GitHub: personal repo/PR browsing',
    get = function() return vim.env.PRI_GITHUB_USERNAME end,
  },
  {
    name = 'GITHUB_PR_FILTER_TEAMS',
    features = 'GitHub: filter PRs by team members (comma-separated team slugs)',
    get = function() return vim.env.GITHUB_PR_FILTER_TEAMS end,
  },

  {
    name = 'ORG_JIRA_TICKET_LINK',
    features = 'Jira: ticket URL construction',
    get = function() return vim.env.ORG_JIRA_TICKET_LINK end,
  },
  {
    name = 'ORG_JIRA_PARENT_EPICS',
    features = 'Jira: parent epics for child issue discovery',
    get = function() return vim.env.ORG_JIRA_PARENT_EPICS end,
  },
  {
    name = 'ORG_JIRA_EPICS',
    features = 'Jira: direct epics for parent issue selection',
    get = function() return vim.env.ORG_JIRA_EPICS end,
  },
  {
    name = 'ORG_EMAIL',
    features = 'Jira: user identification',
    get = function() return os.getenv('ORG_EMAIL') end,
  },
  {
    name = 'TODOIST_API_TOKEN',
    features = 'Todoist: API authentication',
    get = function() return vim.env.PRI_TODOIST_API_TOKEN or vim.env.TODOIST_API_TOKEN end,
  },

}

local REQUIRED_TOOLS = {
  { name = 'gh', features = 'GitHub: PRs, issues, repos' },
  { name = 'acli', features = 'Jira: task creation and management' },
  { name = 'jq', features = 'JSON: package.json parsing, data extraction' },
  { name = 'td', features = 'Todoist: task management' },
  { name = 'docker', features = 'Docker: worktree database containers' },
  { name = 'diff-cover', features = 'Java: new code test coverage reports' },
}

local function check_tool(name) return vim.fn.executable(name) == 1 end

function M.check_env_vars()
  local missing_vars = {}
  for _, var in ipairs(REQUIRED_VARS) do
    local val = var.get()
    if not val or val == '' then table.insert(missing_vars, var) end
  end

  local missing_tools = {}
  for _, tool in ipairs(REQUIRED_TOOLS) do
    if not check_tool(tool.name) then table.insert(missing_tools, tool) end
  end

  if #missing_vars == 0 and #missing_tools == 0 then return end

  local msg_parts = {}

  if #missing_vars > 0 then
    table.insert(msg_parts, 'Missing env vars (' .. #missing_vars .. '/' .. #REQUIRED_VARS .. '):')
    for _, var in ipairs(missing_vars) do
      table.insert(msg_parts, '  ' .. var.name .. ' → ' .. var.features)
    end
  end

  if #missing_tools > 0 then
    if #msg_parts > 0 then table.insert(msg_parts, '') end
    table.insert(msg_parts, 'Missing CLI tools (' .. #missing_tools .. '/' .. #REQUIRED_TOOLS .. '):')
    for _, tool in ipairs(missing_tools) do
      table.insert(msg_parts, '  ' .. tool.name .. ' → ' .. tool.features)
    end
  end

  vim.notify(table.concat(msg_parts, '\n'), vim.log.levels.WARN)
end

function M.show_env_status()
  local lines = { { '── Env Var Health ──', 'Title' }, { '', nil } }

  for _, var in ipairs(REQUIRED_VARS) do
    local val = var.get()
    local is_set = val and val ~= ''
    local status = is_set and '✓' or '✗'
    local hl = is_set and 'DiagnosticOk' or 'DiagnosticError'
    local text = string.format('  %s  %-30s %s', status, var.name, var.features)
    table.insert(lines, { text, hl })
  end

  table.insert(lines, { '', nil })
  table.insert(lines, { '── CLI Tools ──', 'Title' })
  table.insert(lines, { '', nil })

  for _, tool in ipairs(REQUIRED_TOOLS) do
    local is_available = check_tool(tool.name)
    local status = is_available and '✓' or '✗'
    local hl = is_available and 'DiagnosticOk' or 'DiagnosticError'
    local text = string.format('  %s  %-30s %s', status, tool.name, tool.features)
    table.insert(lines, { text, hl })
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local content = {}
  local highlights = {}

  for i, line in ipairs(lines) do
    table.insert(content, line[1])
    if line[2] then table.insert(highlights, { i - 1, line[2] }) end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'

  local width = 60
  for _, line in ipairs(content) do
    width = math.max(width, vim.fn.strdisplaywidth(line) + 4)
  end
  width = math.min(width, math.floor(vim.o.columns * 0.8))

  local height = math.min(#content, math.floor(vim.o.lines * 0.6))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Environment Health ',
    title_pos = 'center',
  })

  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, -1, hl[2], hl[1], 0, -1)
  end

  local function close_win()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end

  vim.keymap.set('n', 'q', close_win, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close_win, { buffer = buf, nowait = true })
end

return M
