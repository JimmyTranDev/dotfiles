-- Headless assertions for core.statusline resilience.
-- Run with the full user config so lualine/catppuccin are available:
--   nvim --headless -u ~/.config/nvim/init.lua -l tests/statusline_spec.lua
--
-- Regression guard: an error in the optional ASTS price module must NOT take
-- down the whole statusline. A broken price bubble once made the entire status
-- screen vanish (build_config threw before lualine.setup ran), so here we poison
-- custom.utils.asts_price and assert the statusline still sets up.

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- Force every future `require('custom.utils.asts_price')` to raise, simulating a
-- broken/unloadable price module on a real machine. preload wins over rtp lookup
-- and only fires when the module is not already cached.
package.loaded['custom.utils.asts_price'] = nil
package.preload['custom.utils.asts_price'] = function() error('simulated asts_price failure') end

-- Reload the statusline module fresh so build_config re-requires the poisoned one.
package.loaded['core.statusline'] = nil
local statusline = require('core.statusline')

local setup_ok = pcall(statusline.setup)
check('statusline.setup survives a broken asts_price module', setup_ok, true)

-- With the module gone the price bubble must be absent, but the rest of the
-- statusline must still render (left bubbles present, no error).
local rendered_ok, rendered = pcall(function() return require('lualine').statusline(true) end)
check('statusline still renders after the failure', rendered_ok, true)
check('rendered statusline is a string', type(rendered), 'string')
check('a core bubble (mode) still shows', (rendered or ''):find('NORMAL', 1, true) ~= nil, true)

-- The refresh path (ColorScheme reload) must be equally resilient.
local refresh_ok = pcall(statusline.refresh_statusline)
check('refresh_statusline survives a broken asts_price module', refresh_ok, true)

package.preload['custom.utils.asts_price'] = nil

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall statusline assertions passed\n')
os.exit(0)
