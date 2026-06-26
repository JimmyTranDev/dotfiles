-- Headless assertions for custom.actions.github.board pure helpers.
-- Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/team_pr_board_spec.lua
-- The script resolves its own module path, so it needs no plugin runtime.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
package.path = lua_root .. '?.lua;' .. lua_root .. '?/init.lua;' .. package.path

local board = require('custom.actions.github.board')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- ci_status: aggregate statusCheckRollup into a single emoji.
check('nil rollup is neutral', board.ci_status(nil), '➖')
check('empty rollup is neutral', board.ci_status({}), '➖')
check('non-table rollup is neutral', board.ci_status('nope'), '➖')
check('all success passes', board.ci_status({ { conclusion = 'SUCCESS' }, { conclusion = 'SUCCESS' } }), '✅')
check('any failure fails', board.ci_status({ { conclusion = 'SUCCESS' }, { conclusion = 'FAILURE' } }), '❌')
check('failure outranks pending', board.ci_status({ { state = 'PENDING' }, { conclusion = 'FAILURE' } }), '❌')
check('pending when no failure', board.ci_status({ { conclusion = 'SUCCESS' }, { state = 'IN_PROGRESS' } }), '🟡')
check('cancelled counts as failure', board.ci_status({ { conclusion = 'CANCELLED' } }), '❌')
check('skipped-only is neutral', board.ci_status({ { conclusion = 'SKIPPED' } }), '➖')

-- format_pr_line: build the display row from an enriched PR item.
check(
  'open approved row',
  board.format_pr_line({
    draft = false,
    review_decision = 'APPROVED',
    ci = '✅',
    author = 'alice',
    number = 42,
    title = 'Fix the thing',
    repo = 'org/repo',
  }),
  '🟢 ✅ ✅  [alice] #42 Fix the thing  org/repo'
)

check(
  'draft changes-requested row',
  board.format_pr_line({
    draft = true,
    review_decision = 'CHANGES_REQUESTED',
    ci = '❌',
    author = 'bob',
    number = 7,
    title = 'WIP',
    repo = 'org/api',
  }),
  '📝 ❌ ❌  [bob] #7 WIP  org/api'
)

check('missing fields fall back gracefully', board.format_pr_line({ number = 1 }), '🟢 ⏳ ➖  [?] #1   ')

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall team_pr_board assertions passed\n')
os.exit(0)
