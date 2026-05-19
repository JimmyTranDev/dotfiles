return {
  'AndrewRadev/linediff.vim',
  keys = {
    { mode = 'v', '<leader>vv', ':Linediff<CR>', desc = 'Linediff' },
    { mode = 'v', '<leader>vV', ':Linediff!<CR>', desc = 'Linediff!' },
    { mode = 'n', '<leader>vv', ':LinediffReset<CR>', desc = 'LinediffReset' },
  },
}
