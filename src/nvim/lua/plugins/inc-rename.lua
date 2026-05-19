return {
  'smjonas/inc-rename.nvim',
  keys = {
    {
      mode = { 'n', 'v' },
      'gn',
      function() return ':IncRename ' .. vim.fn.expand('<cword>') end,
      desc = '󰈮 Lsp Rename Empty',
      expr = true,
    },
    {
      mode = { 'n', 'v' },
      'gN',
      ':IncRename ',
      desc = '󰈮 Lsp Rename',
    },
  },
  config = function() require('inc_rename').setup({}) end,
}
