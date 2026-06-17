return {
  'echasnovski/mini.jump',
  version = '*',
  keys = {
    { 'f', mode = { 'n', 'x', 'o' }, desc = '󰯲 Jump forward' },
    { 'F', mode = { 'n', 'x', 'o' }, desc = '󰯲 Jump backward' },
    { 't', mode = { 'n', 'x', 'o' }, desc = '󰯲 Jump to before forward' },
    { 'T', mode = { 'n', 'x', 'o' }, desc = '󰯲 Jump to before backward' },
  },
  config = function()
    require('mini.jump').setup({
      mappings = {
        forward = 'f',
        backward = 'F',
        forward_till = 't',
        backward_till = 'T',
      },
    })
  end,
}
