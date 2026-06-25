-- Headless assertions for custom.utils.gh_pr_reviews.
-- Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/gh_pr_reviews_spec.lua
-- The script resolves its own module path, so it needs no plugin runtime.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
package.path = lua_root .. '?.lua;' .. lua_root .. '?/init.lua;' .. package.path

local gh_pr_reviews = require('custom.utils.gh_pr_reviews')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

check('zero count is hidden', gh_pr_reviews.format_count(0), '')
check('negative count is hidden', gh_pr_reviews.format_count(-3), '')
check('non-number is hidden', gh_pr_reviews.format_count(nil), '')
check('one review renders with a leading space', gh_pr_reviews.format_count(1), ' 1')
check('many reviews render the number', gh_pr_reviews.format_count(12), ' 12')
check('get_count starts empty before any fetch', gh_pr_reviews.get_count(), '')

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall gh_pr_reviews assertions passed\n')
os.exit(0)
