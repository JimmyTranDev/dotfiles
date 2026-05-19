return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  config = function() require('core.statusline').setup() end,
}
