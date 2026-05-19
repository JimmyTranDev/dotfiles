return {
  'pmizio/typescript-tools.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
  ft = { 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' },
  types = { 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' },
  opts = {},
  keys = {
    {
      mode = 'n',
      '<leader>vq',
      function()
        vim.cmd('TSToolsFixAll')
        vim.defer_fn(function()
          vim.cmd('TSToolsRemoveUnused')
          vim.defer_fn(function()
            vim.cmd('TSToolsRemoveUnusedImports')
            vim.defer_fn(function()
              vim.cmd('TSToolsAddMissingImports')
              vim.defer_fn(function()
                vim.cmd('TSToolsOrganizeImports')
                vim.notify('Complete TypeScript cleanup finished', vim.log.levels.INFO)
              end, 100)
            end, 100)
          end, 100)
        end, 200)
      end,
      desc = '󰘧 Complete TS Cleanup (fix all, clean imports, organize)',
      silent = true,
    },
  },
}
