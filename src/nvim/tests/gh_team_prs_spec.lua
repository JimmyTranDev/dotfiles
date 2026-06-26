-- Headless assertions for custom.utils.gh_team_prs.
-- Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/gh_team_prs_spec.lua
-- The script resolves its own module path, so it needs no plugin runtime.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
package.path = lua_root .. '?.lua;' .. lua_root .. '?/init.lua;' .. package.path

local gh_team_prs = require('custom.utils.gh_team_prs')

local DRAFT = gh_team_prs.DRAFT_ICON

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

check('both zero is hidden', gh_team_prs.format_counts(0, 0), '')
check('both negative is hidden', gh_team_prs.format_counts(-3, -1), '')
check('non-numbers are hidden', gh_team_prs.format_counts(nil, nil), '')
check('ready only renders the count with a leading space', gh_team_prs.format_counts(3, 0), ' 3')
check('draft only renders the draft icon and count', gh_team_prs.format_counts(0, 2), ' ' .. DRAFT .. ' 2')
check('ready and draft render both segments', gh_team_prs.format_counts(3, 2), ' 3 ' .. DRAFT .. ' 2')
check('many of each render the numbers', gh_team_prs.format_counts(12, 7), ' 12 ' .. DRAFT .. ' 7')
check('a zero ready with drafts hides the ready segment', gh_team_prs.format_counts(0, 1), ' ' .. DRAFT .. ' 1')
check('get_counts starts empty before any fetch', gh_team_prs.get_counts(), '')

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall gh_team_prs assertions passed\n')
os.exit(0)
