return {
  'williamboman/mason-lspconfig.nvim',
  dependencies = {
    'saghen/blink.cmp',
    'neovim/nvim-lspconfig',
    'williamboman/mason.nvim',
  },
  lazy = false,
  config = function()
    require('mason').setup()

    local servers = require('lsp.servers').servers
    local server_names = vim.tbl_keys(servers)

    require('mason-lspconfig').setup({
      automatic_installation = true,
      ensure_installed = server_names,
    })

    local default_flags = {
      debounce_text_changes = 300,
      allow_incremental_sync = true,
      exit_timeout = 2000,
    }

    for server, server_config in pairs(servers) do
      local config = vim.tbl_deep_extend('force', {}, server_config, {
        flags = default_flags,
        capabilities = require('blink.cmp').get_lsp_capabilities(server_config.capabilities),
      })

      vim.lsp.config(server, config)
      vim.lsp.enable(server)
    end
  end,
}
