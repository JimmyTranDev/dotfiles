-- Headless assertions for the multi-script picker opts builder in
-- custom.actions.language. Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/language_picker_spec.lua
-- The script resolves its own module path, so it needs no plugin runtime.

local function script_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return source:match('(.*/)') or './'
end

local lua_root = script_dir() .. '../lua/'
package.path = lua_root .. '?.lua;' .. lua_root .. '?/init.lua;' .. package.path

-- dofile pins the test to the local copy of the module beside this spec.
local language = dofile(lua_root .. 'custom/actions/language.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- Mimic snacks.picker.config.multi(): it iterates opts.multi with ipairs whenever
-- it is truthy, so a boolean (or any non-table) blows up with
-- "bad argument #1 to 'ipairs' (table expected, got boolean)". This is the exact
-- crash this spec guards against.
local function snacks_would_crash_on_multi(opts)
  if not opts.multi then return false end
  return type(opts.multi) ~= 'table'
end

local scripts = { 'dev', 'build', 'test', 'lint' }
local opts = language.build_multi_script_picker_opts(scripts, 'pnpm')

-- Regression: the picker opts must never pass a boolean `multi` to snacks.
check('multi is not a boolean (no snacks ipairs crash)', snacks_would_crash_on_multi(opts), false)
check('items mirror the scripts', #opts.items, #scripts)
check('first item carries its script', opts.items[1].script, 'dev')
check('first item text is the script name', opts.items[1].text, 'dev')

-- confirm() must read the multi-selection from the picker (Tab-selected items),
-- cap it to max_splits, and start one terminal per selected script.
local started = {}
local closed = false
local selection = {
  { script = 'dev' },
  { script = 'build' },
  { script = 'test' },
}
local fake_picker = {
  close = function() closed = true end,
  selected = function() return selection end,
}

local opts2 = language.build_multi_script_picker_opts(scripts, 'pnpm', {
  max_splits = 2,
  run = function(name, spec) table.insert(started, { name = name, cmd = spec.cmd }) end,
  notify = function() end,
})
opts2.confirm(fake_picker)

check('confirm closes the picker', closed, true)
check('confirm caps to max_splits', #started, 2)
check('confirm builds the run command', started[1].cmd, 'pnpm run dev')
check('confirm names the terminal', started[1].name, 'npm-run-dev')

-- Empty selection should start nothing.
local started_empty = {}
local empty_picker = {
  close = function() end,
  selected = function() return {} end,
}
local opts3 = language.build_multi_script_picker_opts(scripts, 'pnpm', {
  run = function(name, spec) table.insert(started_empty, name) end,
  notify = function() end,
})
opts3.confirm(empty_picker)
check('confirm starts nothing on empty selection', #started_empty, 0)

-- sort_items reorders the built items (used to float recently-run scripts up).
local opts4 = language.build_multi_script_picker_opts(scripts, 'pnpm', {
  sort_items = function(items)
    table.sort(items, function(a, b) return a.script > b.script end)
    return items
  end,
})
check('sort_items controls item order', opts4.items[1].script, 'test')
check('sort_items keeps every item', #opts4.items, #scripts)

-- record() fires once per launched script (capped to max_splits), so usage can
-- be persisted for recency sorting.
local recorded = {}
local opts5 = language.build_multi_script_picker_opts(scripts, 'pnpm', {
  max_splits = 2,
  run = function() end,
  notify = function() end,
  record = function(script) table.insert(recorded, script) end,
})
opts5.confirm(fake_picker)
check('record fires per launched script', #recorded, 2)
check('record receives the script name', recorded[1], 'dev')

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall language picker assertions passed\n')
os.exit(0)
