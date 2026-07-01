-- Headless assertions for custom.utils.gh_pr_unresolved_comments.
-- Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/gh_pr_unresolved_comments_spec.lua
-- The script resolves its own module path, so it needs no plugin runtime.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
package.path = lua_root .. '?.lua;' .. lua_root .. '?/init.lua;' .. package.path

-- Load the module under test by explicit path. Neovim keeps the user config dir
-- (~/.config/nvim, a symlink to the source repo) on its runtimepath even under
-- `-u NONE`, so a plain `require` would resolve a *different* copy of this module
-- than the one beside this spec (e.g. when running inside a git worktree). dofile
-- pins the test to the local file; its internal `custom.*` requires are identical
-- across copies and resolve normally.
local gh_pr_unresolved_comments = dofile(lua_root .. 'custom/utils/gh_pr_unresolved_comments.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

check('zero count is hidden', gh_pr_unresolved_comments.format_count(0), '')
check('negative count is hidden', gh_pr_unresolved_comments.format_count(-3), '')
check('non-number is hidden', gh_pr_unresolved_comments.format_count(nil), '')
check('one comment renders with a leading space', gh_pr_unresolved_comments.format_count(1), ' 1')
check('many comments render the number', gh_pr_unresolved_comments.format_count(12), ' 12')
check('get_count starts empty before any fetch', gh_pr_unresolved_comments.get_count(), '')

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall gh_pr_unresolved_comments assertions passed\n')
os.exit(0)
