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

-- build_delete_steps: the central wcreated-only remote-deletion safety rule.
local function contains(list, value)
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

local function has_remote_delete(steps)
  for _, s in ipairs(steps) do
    if contains(s.cmd, 'push') and contains(s.cmd, '--delete') then return true end
  end
  return false
end

local wcreated_full = worktree.build_delete_steps({
  main_repo = '/repo',
  worktree = '/wc/foo',
  branch = 'feature/foo',
  delete_remote = true,
  local_exists = true,
  remote_exists = true,
  remote = 'origin',
})
check('wcreated full: 3 steps', #wcreated_full, 3)
check('wcreated full: deletes remote', has_remote_delete(wcreated_full), true)
check('wcreated full: first step removes worktree', table.concat(wcreated_full[1].cmd, ' '), 'git -C /repo worktree remove --force /wc/foo')

local wcheckout_steps = worktree.build_delete_steps({
  main_repo = '/repo',
  worktree = '/wco/foo',
  branch = 'feature/foo',
  delete_remote = false,
  local_exists = true,
  remote_exists = true,
  remote = 'origin',
})
check('wcheckout: 2 steps', #wcheckout_steps, 2)
check('wcheckout: never deletes remote', has_remote_delete(wcheckout_steps), false)

local no_remote_ref = worktree.build_delete_steps({
  main_repo = '/repo',
  worktree = '/wc/foo',
  branch = 'foo',
  delete_remote = true,
  local_exists = true,
  remote_exists = false,
  remote = 'origin',
})
check('wcreated, missing remote ref: 2 steps', #no_remote_ref, 2)
check('wcreated, missing remote ref: skips remote delete', has_remote_delete(no_remote_ref), false)

local no_local = worktree.build_delete_steps({
  main_repo = '/repo',
  worktree = '/wc/foo',
  branch = 'foo',
  delete_remote = true,
  local_exists = false,
  remote_exists = true,
  remote = 'origin',
})
check('missing local branch: 2 steps (no branch -D)', #no_local, 2)
check('missing local branch: still deletes remote', has_remote_delete(no_local), true)

local no_branch = worktree.build_delete_steps({
  main_repo = '/repo',
  worktree = '/wc/foo',
  branch = nil,
  delete_remote = true,
  local_exists = false,
  remote_exists = false,
  remote = 'origin',
})
check('no branch: only worktree remove', #no_branch, 1)

local corrupt = worktree.build_delete_steps({
  main_repo = nil,
  worktree = '/wc/foo',
  branch = 'foo',
  delete_remote = true,
  local_exists = true,
  remote_exists = true,
  remote = 'origin',
})
check('no main repo: no git steps', #corrupt, 0)

-- detect_package_manager: node lockfile precedence (pnpm > yarn > bun > npm).
local function only(name)
  return function(f) return f == name end
end
check('pm: pnpm-lock wins', worktree.detect_package_manager(only('pnpm-lock.yaml')), 'pnpm')
check('pm: yarn.lock', worktree.detect_package_manager(only('yarn.lock')), 'yarn')
check('pm: bun.lockb', worktree.detect_package_manager(only('bun.lockb')), 'bun')
check('pm: bun.lock', worktree.detect_package_manager(only('bun.lock')), 'bun')
check('pm: package-lock.json -> npm', worktree.detect_package_manager(only('package-lock.json')), 'npm')
check('pm: none -> nil', worktree.detect_package_manager(function() return false end), nil)
check(
  'pm: pnpm beats yarn+npm',
  worktree.detect_package_manager(function(f) return f == 'pnpm-lock.yaml' or f == 'yarn.lock' or f == 'package-lock.json' end),
  'pnpm'
)
check(
  'pm: yarn beats bun+npm',
  worktree.detect_package_manager(function(f) return f == 'yarn.lock' or f == 'bun.lockb' or f == 'package-lock.json' end),
  'yarn'
)

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall worktree assertions passed\n')
os.exit(0)
