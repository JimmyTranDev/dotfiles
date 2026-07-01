-- PR-ownership guard for remote branch deletion. Before any
-- `git push origin --delete <branch>`, callers consult GitHub: if the branch has
-- an OPEN pull request authored by someone other than me, the remote delete is
-- skipped. On any uncertainty (no gh, no PR, merged/closed, unknown author or me)
-- the delete is allowed -- the guard only ever *adds* safety (fail-open). Mirrors
-- the shell guard in etc/scripts/src/worktrees/commands/delete.sh.

local async = require('custom.utils.async')

local M = {}

--- Pure verdict: should the remote branch delete be blocked? True iff the PR is
--- OPEN and authored by someone other than me (both logins known). Every other
--- case returns false (allow). No I/O -- unit-tested in tests/pr_ownership_spec.lua.
---@param state string|nil  PR state: OPEN / MERGED / CLOSED (nil/'' = no PR)
---@param author string|nil PR author login ('' / nil = unknown)
---@param me string|nil     my GitHub login ('' / nil = unknown)
---@return boolean
function M.blocks_remote_delete(state, author, me)
  return state == 'OPEN'
    and author ~= nil and author ~= ''
    and me ~= nil and me ~= ''
    and author ~= me
end

-- My GitHub login, resolved once per session via `gh api user`. nil = not yet
-- resolved; '' = gh missing/unauthenticated/failed (treated as "unknown me").
local me_cache = nil

-- Callbacks awaiting an in-flight async `gh api user`; non-nil only while one is
-- running, so concurrent callers share a single request instead of each firing
-- their own (the multi-branch remote-delete path resolves many branches at once).
local me_waiters = nil

-- The gh args that print a branch's PR as "STATE|author" ('' author when none);
-- a non-zero gh exit means no PR for the branch.
local function pr_query_cmd(branch)
  return { 'gh', 'pr', 'view', branch, '--json', 'state,author', '--jq', '.state + "|" + (.author.login // "")' }
end

-- Split "STATE|author" into state, author (author may be empty). nil on no match.
local function parse_pr_info(stdout)
  local info = (stdout or ''):gsub('%s+$', '')
  if info == '' then return nil end
  return info:match('^(.-)|(.*)$')
end

--- Async: resolve my login (cached), then callback(me). Concurrent callers made
--- before the first resolve completes queue on the same in-flight request.
---@param cb fun(me: string)
local function resolve_me(cb)
  if me_cache ~= nil then return cb(me_cache) end
  if vim.fn.executable('gh') == 0 then
    me_cache = ''
    return cb(me_cache)
  end
  if me_waiters then
    me_waiters[#me_waiters + 1] = cb
    return
  end
  me_waiters = { cb }
  async.run_cmd({ 'gh', 'api', 'user', '--jq', '.login' }, function(res)
    me_cache = res.code == 0 and (res.stdout or ''):gsub('%s+$', '') or ''
    local waiters = me_waiters
    me_waiters = nil
    for _, w in ipairs(waiters) do
      w(me_cache)
    end
  end)
end

--- Sync: resolve my login (cached) via a blocking `gh api user`.
---@return string
local function resolve_me_sync()
  if me_cache ~= nil then return me_cache end
  if vim.fn.executable('gh') == 0 then
    me_cache = ''
    return me_cache
  end
  local res = vim.system({ 'gh', 'api', 'user', '--jq', '.login' }, { text = true }):wait()
  if res.code == 0 then
    me_cache = (res.stdout or ''):gsub('%s+$', '')
  else
    me_cache = ''
  end
  return me_cache
end

--- Async guard. Calls cb(blocked, reason): blocked=true only when `branch` has an
--- OPEN PR owned by someone else. Fail-open (cb(false)) on missing gh / no PR /
--- any error. `main_repo` is the cwd used to resolve the PR (repo that owns branch).
---@param main_repo string|nil
---@param branch string|nil
---@param cb fun(blocked: boolean, reason?: string)
function M.check(main_repo, branch, cb)
  if not branch or branch == '' or vim.fn.executable('gh') == 0 then return cb(false) end
  resolve_me(function(me)
    if me == '' then return cb(false) end
    async.run_cmd(pr_query_cmd(branch), function(res)
      if res.code ~= 0 then return cb(false) end
      local state, author = parse_pr_info(res.stdout)
      if M.blocks_remote_delete(state, author, me) then
        return cb(true, string.format('open PR owned by %s (not you)', author))
      end
      cb(false)
    end, { cwd = main_repo })
  end)
end

--- Synchronous guard (blocks). Returns blocked, reason -- blocked=true only when
--- `branch` has an OPEN PR owned by someone else. Fail-open (false) on missing gh /
--- no PR / any error. For callers that already resolve facts synchronously.
---@param main_repo string|nil
---@param branch string|nil
---@return boolean blocked, string? reason
function M.check_sync(main_repo, branch)
  if not branch or branch == '' or vim.fn.executable('gh') == 0 then return false end
  local me = resolve_me_sync()
  if me == '' then return false end
  local res = vim.system(pr_query_cmd(branch), { text = true, cwd = main_repo }):wait()
  if res.code ~= 0 then return false end
  local state, author = parse_pr_info(res.stdout)
  if M.blocks_remote_delete(state, author, me) then
    return true, string.format('open PR owned by %s (not you)', author)
  end
  return false
end

return M
