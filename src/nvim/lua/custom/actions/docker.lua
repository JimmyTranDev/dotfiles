local M = {}

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO) end

-- Run a docker/git command from an argv list (no shell), synchronously.
-- Returns the exit code and stdout. Passing values (container, password, image,
-- port) as discrete argv elements means they are never parsed by a shell, which
-- prevents command injection from branch names or env vars.
local function run(args)
  local res = vim.system(args, { text = true }):wait()
  return res.code, res.stdout or ''
end

-- Like run(), but returns stdout split into non-empty lines (only on success).
local function run_lines(args)
  local code, out = run(args)
  local lines = {}
  if code == 0 then
    for line in out:gmatch('[^\r\n]+') do
      table.insert(lines, line)
    end
  end
  return code, lines
end

local function docker_available()
  if vim.fn.executable('docker') ~= 1 then
    notify('Docker is not installed', vim.log.levels.ERROR)
    return false
  end
  return true
end

local function get_worktree_name()
  local code, lines = run_lines({ 'git', 'branch', '--show-current' })
  if code == 0 and lines[1] and lines[1] ~= '' then return lines[1] end

  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
  return cwd
end

local function sanitize_name(name) return name:gsub('[^%w%-]', '-'):gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '') end

local function get_container_name(worktree) return 'pg-' .. sanitize_name(worktree) end

local function get_volume_name(worktree) return 'pgdata-' .. sanitize_name(worktree) end

local function get_port(worktree)
  local base = tonumber(vim.env.DOCKER_POSTGRES_BASE_PORT) or 5432
  local hash = 0
  for i = 1, #worktree do
    hash = (hash * 31 + string.byte(worktree, i)) % 100
  end
  return base + hash
end

local function get_image() return vim.env.DOCKER_POSTGRES_IMAGE or 'postgres:16' end

local function get_password() return vim.env.DOCKER_POSTGRES_PASSWORD or 'postgres' end

local function is_container_running(container_name)
  local code, result = run_lines({ 'docker', 'ps', '--filter', 'name=^/' .. container_name .. '$', '--format', '{{.Names}}' })
  return code == 0 and #result > 0 and result[1] == container_name
end

function M.start_db()
  if not docker_available() then return end

  local worktree = get_worktree_name()
  local container = get_container_name(worktree)
  local volume = get_volume_name(worktree)
  local port = get_port(worktree)
  local image = get_image()
  local password = get_password()

  if is_container_running(container) then
    notify('Postgres already running: ' .. container .. ' on port ' .. port)
    return
  end

  local existing_code, existing = run_lines({ 'docker', 'ps', '-a', '--filter', 'name=^/' .. container .. '$', '--format', '{{.Names}}' })
  if existing_code == 0 and #existing > 0 and existing[1] == container then
    local start_code = run({ 'docker', 'start', container })
    if start_code == 0 then
      notify('Started existing container: ' .. container .. ' on port ' .. port)
    else
      notify('Failed to start container: ' .. container, vim.log.levels.ERROR)
    end
    return
  end

  local run_code = run({
    'docker',
    'run',
    '--name',
    container,
    '-e',
    'POSTGRES_PASSWORD=' .. password,
    '-p',
    port .. ':5432',
    '-v',
    volume .. ':/var/lib/postgresql/data',
    '-d',
    image,
  })
  if run_code == 0 then
    notify('Started Postgres: ' .. container .. ' on port ' .. port)
  else
    notify('Failed to start Postgres container (port ' .. port .. ' may be in use)', vim.log.levels.ERROR)
  end
end

function M.stop_db()
  if not docker_available() then return end

  local worktree = get_worktree_name()
  local container = get_container_name(worktree)

  if not is_container_running(container) then
    notify('No running container: ' .. container, vim.log.levels.WARN)
    return
  end

  local stopped = run({ 'docker', 'stop', container }) == 0
  if stopped then stopped = run({ 'docker', 'rm', container }) == 0 end
  if stopped then
    notify('Stopped and removed: ' .. container)
  else
    notify('Failed to stop container: ' .. container, vim.log.levels.ERROR)
  end
end

function M.status()
  if not docker_available() then return end

  local code, result = run_lines({ 'docker', 'ps', '--filter', 'name=^pg-', '--format', '{{.Names}}\t{{.Ports}}\t{{.Status}}' })
  if code ~= 0 or #result == 0 then
    notify('No worktree Postgres containers running')
    return
  end

  local lines = { 'Worktree Postgres containers:' }
  for _, line in ipairs(result) do
    table.insert(lines, '  ' .. line)
  end
  notify(table.concat(lines, '\n'))
end

function M.cleanup_all()
  if not docker_available() then return end

  local code, containers = run_lines({ 'docker', 'ps', '-a', '--filter', 'name=^pg-', '--format', '{{.Names}}' })
  if code ~= 0 or #containers == 0 then
    notify('No worktree Postgres containers to clean up')
    return
  end

  local count = 0
  for _, container in ipairs(containers) do
    if container ~= '' then
      run({ 'docker', 'stop', container })
      run({ 'docker', 'rm', container })
      count = count + 1
    end
  end

  notify('Cleaned up ' .. count .. ' worktree Postgres container(s)')
end

return M
