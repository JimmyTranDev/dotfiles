-- Headless assertions for custom.actions.zellij_pane.
-- Run from the nvim config root (src/nvim):
--   nvim --headless -l tests/zellij_pane_spec.lua
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
-- pins the test to the local file; pane_name_for is pure and requires nothing.
local zellij_pane = dofile(lua_root .. 'custom/actions/zellij_pane.lua')

local failures = 0
local function check(name, got, want)
  if got ~= want then
    failures = failures + 1
    io.write(string.format('NOT OK: %s\n  expected %q\n  got      %q\n', name, tostring(want), tostring(got)))
  else
    io.write(string.format('ok: %s\n', name))
  end
end

-- pane_name_for: the folder name (last path segment) the nvim pane should show.

-- Typical project / worktree paths -> their folder name.
check('absolute project path -> folder', zellij_pane.pane_name_for('/Users/jimmy/Programming/JimmyTranDev/dotfiles'), 'dotfiles')
check('worktree path -> folder', zellij_pane.pane_name_for('/Users/jimmy/Programming/wcreated/turso-poc-2'), 'turso-poc-2')
check('single-segment absolute path -> that segment', zellij_pane.pane_name_for('/tmp'), 'tmp')
check('relative path -> basename', zellij_pane.pane_name_for('foo/bar'), 'bar')

-- Trailing slashes are stripped before taking the basename.
check('one trailing slash is stripped', zellij_pane.pane_name_for('/a/b/dotfiles/'), 'dotfiles')
check('multiple trailing slashes are stripped', zellij_pane.pane_name_for('/a/b/dotfiles//'), 'dotfiles')

-- Folder names with spaces are preserved verbatim (zellij quotes the arg).
check('spaces in folder name are preserved', zellij_pane.pane_name_for('/a/My Project'), 'My Project')

-- No sensible folder name -> nil (caller skips the rename, leaving the pane as-is).
check('filesystem root -> nil', zellij_pane.pane_name_for('/'), nil)
check('only slashes -> nil', zellij_pane.pane_name_for('//'), nil)
check('empty string -> nil', zellij_pane.pane_name_for(''), nil)
check('current-dir dot -> nil', zellij_pane.pane_name_for('.'), nil)
check('parent-dir dotdot -> nil', zellij_pane.pane_name_for('..'), nil)
check('nil input -> nil', zellij_pane.pane_name_for(nil), nil)
check('non-string input -> nil', zellij_pane.pane_name_for(42), nil)

-- rename_pane: the zellij command it builds, and its environment guards.
-- Stub the async runner rename_pane lazy-requires; seeding package.loaded makes
-- the require return this fake instead of spawning a real `zellij` process.
local captured
package.loaded['custom.utils.async'] = {
  run_cmd = function(cmd) captured = cmd end,
}
local function reset()
  vim.env.ZELLIJ = nil
  vim.env.ZELLIJ_PANE_ID = nil
  captured = nil
end
local function argv_str(t) return t and table.concat(t, ' ') or nil end

-- Inside a real zellij pane: rename only this pane, by id, to the cwd's folder.
reset()
vim.env.ZELLIJ = '1'
vim.env.ZELLIJ_PANE_ID = '%7'
local tmp = vim.fn.tempname() .. '/dotfiles'
vim.fn.mkdir(tmp, 'p')
vim.cmd('cd ' .. vim.fn.fnameescape(tmp))
zellij_pane.rename_pane()
check('rename_pane targets its own pane with the folder name', argv_str(captured), 'zellij action rename-pane --pane-id %7 dotfiles')

-- Outside zellij ($ZELLIJ unset): no command is run.
reset()
zellij_pane.rename_pane()
check('rename_pane is a no-op without $ZELLIJ', captured, nil)

-- Inside zellij but with no pane id: still a no-op (cannot target a pane).
reset()
vim.env.ZELLIJ = '1'
zellij_pane.rename_pane()
check('rename_pane is a no-op without $ZELLIJ_PANE_ID', captured, nil)

if failures > 0 then
  io.write(string.format('\n%d assertion(s) failed\n', failures))
  os.exit(1)
end
io.write('\nall zellij_pane assertions passed\n')
os.exit(0)
