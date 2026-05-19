return {
  'sQVe/sort.nvim',
  cmd = { 'Sort' },
  config = function()
    require('sort').setup({
      default_mappings = false,
    })
  end,
  keys = {
    { '<leader><leader>ss', ':Sort<CR>', mode = { 'n', 'v' }, desc = '󰒺 Sort lines' },
    { '<leader><leader>si', ':Sort i<CR>', mode = { 'n', 'v' }, desc = '󰒺 Sort lines (ignore case)' },
    { '<leader><leader>su', ':Sort u<CR>', mode = { 'n', 'v' }, desc = '󰒺 Sort lines (unique)' },
    { '<leader><leader>sr', ':Sort!<CR>', mode = { 'n', 'v' }, desc = '󰒺 Sort lines (reverse)' },
    { '<leader><leader>sn', ':Sort n<CR>', mode = { 'n', 'v' }, desc = '󰒺 Sort lines (numeric)' },
    { '<leader><leader>sl', ':Sort l<CR>', mode = { 'n', 'v' }, desc = '󰒺 Sort lines (by length)' },
  },
}
