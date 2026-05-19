return {
  'jay-babu/mason-nvim-dap.nvim',
  dependencies = {
    'williamboman/mason.nvim',
    'mfussenegger/nvim-dap',
  },
  lazy = false,
  config = function()
    require('mason-nvim-dap').setup({
      ensure_installed = {
        'stylua',
      },
      automatic_installation = true,
    })
  end,
}
