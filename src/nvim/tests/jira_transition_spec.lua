-- Headless assertions for the pure transition-chain slicer in
-- custom.actions.jira.util. Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/jira_transition_spec.lua
-- The script pins the module by explicit path (see worktree_spec.lua for why),
-- so it tests the copy beside this spec rather than the one on runtimepath.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
local util = dofile(lua_root .. 'custom/actions/jira/util.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- Compare list contents+order as a single delimited string ('|' never appears in
-- a status name), so a mismatch in length, order, or value all surface here.
local function joined(list) return table.concat(list, '|') end

-- slice_transition_chain: returns the chain from the start up to and INCLUDING
-- the selected target; empty when the target is absent (fail closed).
check('target in middle -> start up to and including it', joined(util.slice_transition_chain({ 'A', 'B', 'C' }, 'B')), 'A|B')
check('target is first -> just the first status', joined(util.slice_transition_chain({ 'A', 'B', 'C' }, 'A')), 'A')
check('target is last -> the whole chain', joined(util.slice_transition_chain({ 'A', 'B', 'C' }, 'C')), 'A|B|C')
check('target absent -> empty (fail closed)', joined(util.slice_transition_chain({ 'A', 'B', 'C' }, 'Z')), '')
check('empty chain -> empty', joined(util.slice_transition_chain({}, 'A')), '')
check('nil target -> empty (fail closed)', joined(util.slice_transition_chain({ 'A', 'B' }, nil)), '')

-- Real chain: selecting "Done Concept" reproduces the old "Done Concept only"
-- bundle, and selecting the last status reproduces the old "Prioritise" bundle.
local CHAIN = { 'In Progress Concept', 'Done Concept', 'Prioritised Issues Development' }
check('real chain: Done Concept stops at the sentinel', joined(util.slice_transition_chain(CHAIN, 'Done Concept')), 'In Progress Concept|Done Concept')
check('real chain: In Progress Concept is a newly-exposed early stop', joined(util.slice_transition_chain(CHAIN, 'In Progress Concept')), 'In Progress Concept')
check(
  'real chain: final status runs the whole chain',
  joined(util.slice_transition_chain(CHAIN, 'Prioritised Issues Development')),
  'In Progress Concept|Done Concept|Prioritised Issues Development'
)

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall jira transition assertions passed\n')
