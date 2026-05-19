return {
  'nvzone/floaterm',
  dependencies = 'nvzone/volt',
  keys = {
    { '<leader><leader>F', '<cmd>Floaterm<CR>', desc = '󰙂 Toggle floating terminal' },
    { '<F7>', '<cmd>Floaterm<CR>', desc = '󰙂 Toggle floating terminal', mode = { 'n', 't' } },
    { '<C-\\><C-\\>', '<cmd>Floaterm<CR>', desc = '󰙂 Toggle floating terminal', mode = { 'n', 't' } },
  },
  cmd = 'Floaterm',
  opts = {},
}
