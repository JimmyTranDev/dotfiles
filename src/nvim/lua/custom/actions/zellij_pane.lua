-- Name the zellij pane an nvim session runs in after the folder it is editing.
--
-- This zellij setup uses `pane_frames = true`, so every pane shows a title in
-- its 1-cell frame. A bare nvim pane otherwise shows the command name "nvim";
-- this module renames nvim's *own* pane (via $ZELLIJ_PANE_ID) to the basename
-- of its working directory, so the pane reads like "dotfiles" rather than
-- "nvim". It mirrors src/opencode/plugins/zellij-pane-status.js, which renames
-- the opencode pane the same way. The pure path logic lives in pane_name_for so
-- it is unit-testable headlessly; rename_pane is the thin zellij side effect.

local M = {}

--- The folder name an nvim pane should display for a working directory: the
--- last path segment, ignoring trailing slashes. Returns nil when there is no
--- meaningful folder name (empty input, the filesystem root, or "."/"..") so the
--- caller can skip the rename and leave the pane title as-is. Pure: no vim, no
--- I/O — this is the unit-tested core.
---@param cwd string|nil
---@return string|nil
function M.pane_name_for(cwd)
  if type(cwd) ~= 'string' then return nil end
  local trimmed = cwd:gsub('/+$', '')
  if trimmed == '' then return nil end -- empty input or all slashes (the root)
  local base = trimmed:match('[^/]+$')
  if not base or base == '.' or base == '..' then return nil end
  return base
end

--- Rename the zellij pane this nvim runs in to its working directory's folder
--- name. No-op outside zellij (no $ZELLIJ / $ZELLIJ_PANE_ID) and when the cwd
--- has no meaningful folder name. Passing --pane-id $ZELLIJ_PANE_ID renames only
--- nvim's own pane, never the focused or any other pane. Best-effort and async:
--- a detached or unreachable zellij just fails silently, like the opencode plugin.
function M.rename_pane()
  if not vim.env.ZELLIJ then return end
  local pane_id = vim.env.ZELLIJ_PANE_ID
  if not pane_id or pane_id == '' then return end

  local name = M.pane_name_for(vim.fn.getcwd())
  if not name then return end

  require('custom.utils.async').run_cmd(
    { 'zellij', 'action', 'rename-pane', '--pane-id', pane_id, name },
    function() end -- best-effort: the pane title is cosmetic, so ignore the result
  )
end

return M
