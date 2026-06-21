return {
  'artemave/workspace-diagnostics.nvim',
  keys = {
    {
      mode = 'n',
      '<leader>flx',
      function()
        for _, client in ipairs(vim.lsp.get_clients()) do
          require('workspace-diagnostics').populate_workspace_diagnostics(client, 0)
        end
      end,
      desc = '󰒡 Workspace Diagnostics',
    },
  },
  config = function() require('workspace-diagnostics').setup() end,
}
