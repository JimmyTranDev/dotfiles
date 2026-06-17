return {
  url = 'https://codeberg.org/andyg/leap.nvim',
  dependencies = {
    'tpope/vim-repeat',
  },
  keys = {
    { 's', '<Plug>(leap)', mode = { 'n', 'x', 'o' } },
    { 'S', '<Plug>(leap-from-window)', mode = 'n' },
  },
}
