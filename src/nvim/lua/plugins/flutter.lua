--- Register buffer-local Flutter/Dart keymaps, grouped by concern under <leader>F.
--- Buffer-local so the bindings only exist inside Dart buffers.
---@param bufnr integer
local function set_flutter_keymaps(bufnr)
  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = bufnr, silent = true, desc = desc }) end

  -- Run / Hot reload -------------------------------------------------
  map('<leader>Frr', '<cmd>FlutterRun<cr>', '󰜎 Run')
  map('<leader>Frl', '<cmd>FlutterReload<cr>', '󰑓 Hot Reload')
  map('<leader>FrR', '<cmd>FlutterRestart<cr>', '󰜉 Hot Restart')
  map('<leader>Frq', '<cmd>FlutterQuit<cr>', '󰓛 Quit Runner')
  map('<leader>Frv', '<cmd>FlutterVisualDebug<cr>', '󰃤 Toggle Visual Debug')

  -- Devices / Emulators ----------------------------------------------
  map('<leader>Fdd', '<cmd>FlutterDevices<cr>', '󰄜 Select Device')
  map('<leader>Fde', '<cmd>FlutterEmulators<cr>', '󰦧 Launch Emulator')

  -- Tooling -----------------------------------------------------------
  map('<leader>Fto', '<cmd>FlutterOutlineToggle<cr>', '󰙅 Toggle Outline')
  map('<leader>Ftd', '<cmd>FlutterDevTools<cr>', '󰙨 Open DevTools')
  map('<leader>Ftl', '<cmd>FlutterLspRestart<cr>', '󰜉 Restart Dart LSP')

  -- Pub ---------------------------------------------------------------
  map('<leader>Fpg', '<cmd>FlutterPubGet<cr>', '󰏔 Pub Get')
  map('<leader>Fpu', '<cmd>FlutterPubUpgrade<cr>', '󰚰 Pub Upgrade')
end

return {
  ft = { 'dart' },
  'nvim-flutter/flutter-tools.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'saghen/blink.cmp',
  },
  config = function()
    local capabilities = require('blink.cmp').get_lsp_capabilities()

    require('flutter-tools').setup({
      ui = { border = 'rounded' },
      lsp = {
        capabilities = capabilities,
        color = { enabled = true },
        settings = {
          showTodos = true,
          completeFunctionCalls = true,
          renameFilesWithClasses = 'prompt',
          updateImportsOnRename = true,
          enableSnippets = true,
          lineLength = 100,
        },
      },
      dev_log = { enabled = true, open_cmd = 'tabedit' },
      widget_guides = { enabled = true },
    })

    local group = vim.api.nvim_create_augroup('flutter_keymaps', { clear = true })
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = 'dart',
      callback = function(args) set_flutter_keymaps(args.buf) end,
    })

    -- The FileType event for the buffer that lazy-loaded this plugin has
    -- already fired, so apply the keymaps to it directly.
    if vim.bo.filetype == 'dart' then set_flutter_keymaps(vim.api.nvim_get_current_buf()) end
  end,
}
