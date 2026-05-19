return {
  'NickvanDyke/opencode.nvim',
  dependencies = {
    { 'folke/snacks.nvim', opts = { input = {}, picker = {}, terminal = {} } },
  },
  lazy = false,
  keys = {
    { '<C-a>', function() require('opencode').ask('@this: ', { submit = true }) end, mode = { 'n', 'x' }, desc = '󰚴 Ask opencode' },
    { '<C-.>', function() require('opencode').toggle() end, mode = { 'n', 't' }, desc = '󰚴 Toggle opencode' },
  },
  config = function()
    vim.g.opencode_opts = {} -- Required by opencode.nvim plugin
  end,
}
