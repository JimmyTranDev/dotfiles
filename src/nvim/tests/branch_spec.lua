-- Headless assertions for the pure helpers in custom.actions.branch.
-- Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/branch_spec.lua
-- The script resolves its own module path, so it needs no plugin runtime.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
package.path = lua_root .. '?.lua;' .. lua_root .. '?/init.lua;' .. package.path

-- Load the module under test by explicit path (see worktree_spec.lua for the
-- rationale: dofile pins the test to the local copy rather than the one on
-- Neovim's runtimepath). Its internal custom.utils.* requires resolve normally.
local branch = dofile(lua_root .. 'custom/actions/branch.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- parse_remote_branches: strip origin/, drop HEAD pointer, dedupe, sort.
check('parse: strips origin/ and sorts', table.concat(branch.parse_remote_branches('  origin/main\n  origin/feature/foo'), ','), 'feature/foo,main')
check('parse: drops HEAD pointer line', #branch.parse_remote_branches('  origin/HEAD -> origin/main\n  origin/main'), 1)
check('parse: dedupes repeats', table.concat(branch.parse_remote_branches('origin/main\norigin/main'), ','), 'main')
check('parse: empty input -> none', #branch.parse_remote_branches(''), 0)
check('parse: honors custom remote', table.concat(branch.parse_remote_branches('  upstream/foo\n  origin/bar', 'upstream'), ','), 'foo')

-- deletable_remote_branches: drop the protected set (default main/master/develop)
-- and the current branch; order is preserved.
check(
  'deletable: excludes default protected',
  table.concat(branch.deletable_remote_branches({ 'main', 'master', 'develop', 'feature/x' }, 'somebranch'), ','),
  'feature/x'
)
check(
  'deletable: excludes current branch',
  table.concat(branch.deletable_remote_branches({ 'feature/x', 'feature/y' }, 'feature/x'), ','),
  'feature/y'
)
check(
  'deletable: nil current keeps all non-protected',
  table.concat(branch.deletable_remote_branches({ 'feature/x', 'feature/y' }, nil), ','),
  'feature/x,feature/y'
)
check(
  'deletable: custom protected overrides default',
  table.concat(branch.deletable_remote_branches({ 'main', 'keep' }, nil, { 'keep' }), ','),
  'main'
)
check('deletable: empty input -> none', #branch.deletable_remote_branches({}, 'main'), 0)

-- parse_ref_authors: map `git for-each-ref` "<short>|<email>" lines to
-- { [branch] = email }, stripping the origin/ prefix and the <> around emails.
local authors = branch.parse_ref_authors('origin/feature/x|<me@example.com>\norigin/feature/y|<other@example.com>\norigin/HEAD|<me@example.com>')
check('ref_authors: strips origin/ prefix', authors['feature/x'], 'me@example.com')
check('ref_authors: keeps distinct authors', authors['feature/y'], 'other@example.com')
check('ref_authors: drops HEAD pointer', authors['HEAD'], nil)
check('ref_authors: honors custom remote', branch.parse_ref_authors('upstream/foo|<a@b.c>', 'upstream')['foo'], 'a@b.c')
check('ref_authors: bare email without angle brackets', branch.parse_ref_authors('origin/z|plain@e.com')['z'], 'plain@e.com')
check('ref_authors: empty input -> empty map', next(branch.parse_ref_authors('')), nil)

-- mine_remote_branches: keep only branches whose tip author email == me
-- (case-insensitive); order preserved. Unknown `me` fails open (keep all).
local by = { ['feature/x'] = 'me@example.com', ['feature/y'] = 'other@example.com', ['feature/z'] = 'ME@Example.com' }
check(
  'mine: keeps only my branches',
  table.concat(branch.mine_remote_branches({ 'feature/x', 'feature/y' }, by, 'me@example.com'), ','),
  'feature/x'
)
check(
  'mine: matches email case-insensitively',
  table.concat(branch.mine_remote_branches({ 'feature/z' }, by, 'me@example.com'), ','),
  'feature/z'
)
check(
  'mine: preserves input order',
  table.concat(branch.mine_remote_branches({ 'feature/y', 'feature/x', 'feature/z' }, by, 'me@example.com'), ','),
  'feature/x,feature/z'
)
check('mine: drops branch with unknown author when me is known', #branch.mine_remote_branches({ 'ghost' }, by, 'me@example.com'), 0)
check(
  'mine: empty me fails open (keep all)',
  table.concat(branch.mine_remote_branches({ 'feature/x', 'feature/y' }, by, ''), ','),
  'feature/x,feature/y'
)
check('mine: nil me fails open (keep all)', #branch.mine_remote_branches({ 'feature/x', 'feature/y' }, by, nil), 2)
check('mine: empty input -> none', #branch.mine_remote_branches({}, by, 'me@example.com'), 0)

-- build_delete_remote_cmd: argv for deleting a branch on the remote.
check('cmd: default remote origin', table.concat(branch.build_delete_remote_cmd('feature/x'), ' '), 'git push origin --delete feature/x')
check('cmd: custom remote', table.concat(branch.build_delete_remote_cmd('feature/x', 'upstream'), ' '), 'git push upstream --delete feature/x')

-- build_set_upstream_cmd: argv retargeting the current branch's upstream.
check('upstream: default remote origin', table.concat(branch.build_set_upstream_cmd('feature/x'), ' '), 'git branch --set-upstream-to=origin/feature/x')
check('upstream: explicit current branch', table.concat(branch.build_set_upstream_cmd('feature/x', 'origin', 'local-b'), ' '), 'git branch --set-upstream-to=origin/feature/x local-b')
check('upstream: custom remote', table.concat(branch.build_set_upstream_cmd('foo', 'upstream'), ' '), 'git branch --set-upstream-to=upstream/foo')
check('upstream: empty current omitted', table.concat(branch.build_set_upstream_cmd('x', 'origin', ''), ' '), 'git branch --set-upstream-to=origin/x')

-- build_ref_authors_cmd: argv listing each remote branch tip's author email.
local ra = branch.build_ref_authors_cmd()
check('ref_authors_cmd: for-each-ref', table.concat(ra, ' '), 'git for-each-ref --format=%(refname:short)|%(authoremail) refs/remotes/origin')
check('ref_authors_cmd: custom remote target', branch.build_ref_authors_cmd('upstream')[#ra], 'refs/remotes/upstream')

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall branch assertions passed\n')
os.exit(0)
