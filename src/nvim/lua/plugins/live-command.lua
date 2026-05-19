return {
  'smjonas/live-command.nvim',
  keys = ':',
  config = function()
    require('live-command').setup({
      commands = {
        Norm = { cmd = 'norm' },
      },
    })
  end,
}
