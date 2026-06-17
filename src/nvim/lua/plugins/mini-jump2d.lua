return {
  'echasnovski/mini.jump2d',
  version = '*',
  keys = {
    { 's', mode = { 'n', 'x', 'o' }, desc = '󰸳 Jump 2D' },
  },
  config = function()
    require('mini.jump2d').setup({
      mappings = {
        start_jumping = 's',
      },
    })
  end,
}
