-- Headless assertions for the pure helpers in custom.actions.worktree.
-- Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/worktree_spec.lua
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
-- pins the test to the local file; its internal `custom.utils.*` requires are
-- identical across copies and resolve normally.
local worktree = dofile(lua_root .. 'custom/actions/worktree.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- slugify: lowercase, non-alphanumerics -> '-', collapsed, trimmed.
check('slugify lowercases and hyphenates', worktree.slugify('Hello World'), 'hello-world')
check('slugify collapses punctuation runs', worktree.slugify('Add OAuth!! support'), 'add-oauth-support')
check('slugify trims leading/trailing separators', worktree.slugify('  Spaces  '), 'spaces')

-- compute_branch_name: Jira key honored with slugified summary; else sanitized name.
check('jira key + summary -> key-slug', worktree.compute_branch_name('ABC-123', 'Fix the thing'), 'ABC-123-fix-the-thing')
check('jira key + empty summary -> key', worktree.compute_branch_name('ABC-123', ''), 'ABC-123')
check('jira key + nil summary -> key', worktree.compute_branch_name('ABC-123', nil), 'ABC-123')
check('plain text preserves case, spaces -> dash', worktree.compute_branch_name('My Cool Feature', nil), 'My-Cool-Feature')
check('plain text slashes -> dash', worktree.compute_branch_name('feature/foo bar', nil), 'feature-foo-bar')
check('lowercase key is not jira (case-sensitive)', worktree.compute_branch_name('abc-123', nil), 'abc-123')
check('whitespace-only input -> empty', worktree.compute_branch_name('   ', nil), '')

-- build_commit_message: Jira keys get a subject + Jira trailer; plain text does not.
check(
  'jira commit message has subject + trailer',
  worktree.build_commit_message('feat', 'ABC-123', 'Fix the thing', 'storebrand'),
  'feat: ABC-123 Fix the thing\n\nJira: https://storebrand.atlassian.net/browse/ABC-123'
)
check(
  'jira commit message without summary',
  worktree.build_commit_message('fix', 'ABC-123', '', 'storebrand'),
  'fix: ABC-123\n\nJira: https://storebrand.atlassian.net/browse/ABC-123'
)
check('plain commit message has no trailer', worktree.build_commit_message('chore', 'my thing', nil, 'storebrand'), 'chore: my thing')

-- folder_from_branch: strip a single leading segment, flatten remaining slashes.
check('folder strips leading segment', worktree.folder_from_branch('feature/foo'), 'foo')
check('folder passes through plain branch', worktree.folder_from_branch('foo'), 'foo')
check('folder flattens nested slashes', worktree.folder_from_branch('a/b/c'), 'b-c')

-- is_wcreated_path: only direct descendants of WCREATED_DIR classify as created.
check('child of wcreated is created', worktree.is_wcreated_path('/home/u/Programming/wcreated/foo', '/home/u/Programming/wcreated'), true)
check('wcheckout path is not created', worktree.is_wcreated_path('/home/u/Programming/wcheckout/foo', '/home/u/Programming/wcreated'), false)
check('the wcreated dir itself is not a worktree', worktree.is_wcreated_path('/home/u/Programming/wcreated', '/home/u/Programming/wcreated'), false)
check('trailing slash on dir still matches child', worktree.is_wcreated_path('/x/wcreated/foo', '/x/wcreated/'), true)

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall worktree assertions passed\n')
os.exit(0)
