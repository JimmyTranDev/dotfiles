-- Headless assertions for custom.utils.asts_price.
-- Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/asts_price_spec.lua
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
local asts_price = dofile(lua_root .. 'custom/utils/asts_price.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

check('positive change renders signed to 2dp', asts_price.format_price(42.15, 1.8), 'ASTS 42.15 +1.80%')
check('negative change renders a minus sign', asts_price.format_price(42.15, -2.3), 'ASTS 42.15 -2.30%')
check('zero change renders +0.00%', asts_price.format_price(42.15, 0), 'ASTS 42.15 +0.00%')
check('price is rounded to 2dp', asts_price.format_price(9.5, 1), 'ASTS 9.50 +1.00%')
check('missing change is treated as zero', asts_price.format_price(42.15, nil), 'ASTS 42.15 +0.00%')
check('nil price is hidden', asts_price.format_price(nil, 1.8), '')
check('non-number price is hidden', asts_price.format_price('x', 1.8), '')
check('zero price is hidden', asts_price.format_price(0, 1.8), '')
check('get_price starts empty before any fetch', asts_price.get_price(), '')

-- Shared file cache (dedupes Finnhub calls across nvim instances). Point the
-- module at a throwaway cache file so the test never touches the real cache.
local tmp_cache = vim.fn.tempname() .. '_asts_cache.json'
asts_price._set_cache_file(tmp_cache)

-- Freshness is time-based against the TTL (300s), computed relative to a given now.
check('a just-written entry is fresh', asts_price.is_fresh({ timestamp = 1000, text = 'ASTS 1.00 +0.00%' }, 1000), true)
check('an entry within TTL is fresh', asts_price.is_fresh({ timestamp = 1000, text = 'x' }, 1000 + 299), true)
check('an entry at/after TTL is stale', asts_price.is_fresh({ timestamp = 1000, text = 'x' }, 1000 + 300), false)
check('a nil entry is not fresh', asts_price.is_fresh(nil, 1000), false)
check('an entry without a timestamp is not fresh', asts_price.is_fresh({ text = 'x' }, 1000), false)

-- Round-trip: writing a quote then reading it back yields the same text.
check('read_cache is nil when the file is absent', asts_price.read_cache(), nil)
asts_price.write_cache('ASTS 42.15 +1.80%')
local entry = asts_price.read_cache()
check('read_cache returns the written text', entry and entry.text, 'ASTS 42.15 +1.80%')
check('read_cache returns a numeric timestamp', entry and type(entry.timestamp), 'number')

vim.fn.delete(tmp_cache)

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall asts_price assertions passed\n')
os.exit(0)
