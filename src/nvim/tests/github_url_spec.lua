-- Headless assertions for the pure GitHub remote-URL parser in
-- custom.utils.github. Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/github_url_spec.lua
-- The script pins the module by explicit path (see worktree_spec.lua for why),
-- so it tests the copy beside this spec rather than the one on runtimepath.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
local github = dofile(lua_root .. 'custom/utils/github.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- parse_repo_url returns (owner, repo) or (nil, nil). Join both captures into one
-- string so a mismatch in either surfaces; both-nil renders as '' (not a GitHub
-- remote / unparseable).
local function parsed(owner, repo)
  if not owner and not repo then return '' end
  return string.format('%s|%s', owner or '', repo or '')
end

-- Recognized GitHub remotes -> owner|repo, including the SSH host aliases used
-- for multiple keys that the old `github.com[:/]` match rejected.
check('standard SSH scp-style', parsed(github.parse_repo_url('git@github.com:owner/repo.git')), 'owner|repo')
check('host alias .com-work suffix', parsed(github.parse_repo_url('git@github.com-work:owner/repo.git')), 'owner|repo')
check('short host alias github-personal', parsed(github.parse_repo_url('git@github-personal:owner/repo.git')), 'owner|repo')
check('ssh:// url', parsed(github.parse_repo_url('ssh://git@github.com/owner/repo.git')), 'owner|repo')
check('ssh:// url with port', parsed(github.parse_repo_url('ssh://git@github.com:22/owner/repo.git')), 'owner|repo')
check('git+ssh:// url', parsed(github.parse_repo_url('git+ssh://git@github.com/owner/repo.git')), 'owner|repo')
check('https:// with .git', parsed(github.parse_repo_url('https://github.com/owner/repo.git')), 'owner|repo')
check('https:// without .git', parsed(github.parse_repo_url('https://github.com/owner/repo')), 'owner|repo')
check('git:// url', parsed(github.parse_repo_url('git://github.com/owner/repo.git')), 'owner|repo')
check('scp-style without user', parsed(github.parse_repo_url('github.com:owner/repo.git')), 'owner|repo')
check('trailing slash', parsed(github.parse_repo_url('https://github.com/owner/repo/')), 'owner|repo')

-- Names the old `[^/%.]+` capture mishandled (dots) or that use common symbols.
check('dotted repo name kept whole', parsed(github.parse_repo_url('git@github.com:owner/my.repo.git')), 'owner|my.repo')
check('hyphen and underscore names', parsed(github.parse_repo_url('git@github.com:my-org/my_repo.git')), 'my-org|my_repo')

-- Non-GitHub or malformed remotes -> not parsed (must not resolve to github.com).
check('gitlab not mis-resolved', parsed(github.parse_repo_url('git@gitlab.com:me/github-tools.git')), '')
check('bitbucket rejected', parsed(github.parse_repo_url('git@bitbucket.org:me/repo.git')), '')
check('empty string', parsed(github.parse_repo_url('')), '')
check('nil input', parsed(github.parse_repo_url(nil)), '')
check('local path', parsed(github.parse_repo_url('/Users/me/repos/thing')), '')
check('missing repo segment', parsed(github.parse_repo_url('git@github.com:owner')), '')

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall github url assertions passed\n')
os.exit(0)
