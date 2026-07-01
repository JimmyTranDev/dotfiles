-- Headless assertions for the pure verdict in custom.utils.pr_ownership.
-- Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/pr_ownership_spec.lua
-- Mirrors the shell truth table in etc/scripts/tests/test_worktree_delete.zsh.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
package.path = lua_root .. '?.lua;' .. lua_root .. '?/init.lua;' .. package.path

local pr = dofile(lua_root .. 'custom/utils/pr_ownership.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- blocks_remote_delete: block iff an OPEN PR is authored by someone other than
-- me; every other case is allowed (fail-open).
check('open PR by another user is blocked', pr.blocks_remote_delete('OPEN', 'alice', 'bob'), true)
check('open PR authored by me is allowed', pr.blocks_remote_delete('OPEN', 'bob', 'bob'), false)
check('merged PR by another user is allowed', pr.blocks_remote_delete('MERGED', 'alice', 'bob'), false)
check('closed PR by another user is allowed', pr.blocks_remote_delete('CLOSED', 'alice', 'bob'), false)
check('no PR (nil state) is allowed', pr.blocks_remote_delete(nil, nil, 'bob'), false)
check('no PR (empty state) is allowed', pr.blocks_remote_delete('', '', 'bob'), false)
check('open PR with empty author is allowed', pr.blocks_remote_delete('OPEN', '', 'bob'), false)
check('open PR with nil author is allowed', pr.blocks_remote_delete('OPEN', nil, 'bob'), false)
check('open PR with empty me is allowed', pr.blocks_remote_delete('OPEN', 'alice', ''), false)
check('open PR with nil me is allowed', pr.blocks_remote_delete('OPEN', 'alice', nil), false)

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall pr_ownership assertions passed\n')
os.exit(0)
