local M = {}

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO) end

local function docker_available()
  if vim.fn.executable('docker') ~= 1 then
    notify('Docker is not installed', vim.log.levels.ERROR)
    return false
  end
  return true
end

local function get_worktree_name()
  local branch = vim.fn.systemlist('git branch --show-current')[1]
  if vim.v.shell_error == 0 and branch and branch ~= '' then return branch end

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
  local result = vim.fn.systemlist('docker ps --filter name=^/' .. container_name .. '$ --format "{{.Names}}"')
  return vim.v.shell_error == 0 and #result > 0 and result[1] == container_name
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

  local existing = vim.fn.systemlist('docker ps -a --filter name=^/' .. container .. '$ --format "{{.Names}}"')
  if vim.v.shell_error == 0 and #existing > 0 and existing[1] == container then
    vim.fn.system('docker start ' .. container)
    if vim.v.shell_error == 0 then
      notify('Started existing container: ' .. container .. ' on port ' .. port)
    else
      notify('Failed to start container: ' .. container, vim.log.levels.ERROR)
    end
    return
  end

  local cmd = table.concat({
    'docker run',
    '--name ' .. container,
    '-e POSTGRES_PASSWORD=' .. password,
    '-p ' .. port .. ':5432',
    '-v ' .. volume .. ':/var/lib/postgresql/data',
    '-d ' .. image,
  }, ' ')

  vim.fn.system(cmd)
  if vim.v.shell_error == 0 then
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

  vim.fn.system('docker stop ' .. container .. ' && docker rm ' .. container)
  if vim.v.shell_error == 0 then
    notify('Stopped and removed: ' .. container)
  else
    notify('Failed to stop container: ' .. container, vim.log.levels.ERROR)
  end
end

function M.status()
  if not docker_available() then return end

  local result = vim.fn.systemlist('docker ps --filter name=^pg- --format "{{.Names}}\t{{.Ports}}\t{{.Status}}"')
  if vim.v.shell_error ~= 0 or #result == 0 then
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

  local containers = vim.fn.systemlist('docker ps -a --filter name=^pg- --format "{{.Names}}"')
  if vim.v.shell_error ~= 0 or #containers == 0 then
    notify('No worktree Postgres containers to clean up')
    return
  end

  local count = 0
  for _, container in ipairs(containers) do
    if container ~= '' then
      vim.fn.system('docker stop ' .. container .. ' 2>/dev/null; docker rm ' .. container .. ' 2>/dev/null')
      count = count + 1
    end
  end

  notify('Cleaned up ' .. count .. ' worktree Postgres container(s)')
end

return M
