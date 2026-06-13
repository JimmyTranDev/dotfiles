return {
  'pwntester/octo.nvim',
  cmd = 'Octo',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
  },
  opts = {
    suppress_missing_scope = {
      projects_v2 = true,
    },
    picker = 'snacks',
  },
  keys = {
    { '<leader>hl', '<cmd>Octo pr list<CR>', desc = '󰊤 PR list', silent = true },
    { '<leader>hs', '<cmd>Octo pr search<CR>', desc = '󰊤 PR search', silent = true },
    { '<leader>hd', '<cmd>Octo pr diff<CR>', desc = '󰊤 PR diff', silent = true },
    { '<leader>hr', '<cmd>Octo review start<CR>', desc = '󰊤 Review start', silent = true },
    { '<leader>hR', '<cmd>Octo review submit<CR>', desc = '󰊤 Review submit', silent = true },
    { '<leader>ha', '<cmd>Octo review comments<CR>', desc = '󰊤 Review comments', silent = true },
    { '<leader>hi', '<cmd>Octo issue list<CR>', desc = '󰊤 Issue list', silent = true },
    { '<leader>hI', '<cmd>Octo issue search<CR>', desc = '󰊤 Issue search', silent = true },
    { '<leader>hm', '<cmd>Octo pr merge squash<CR>', desc = '󰊤 PR merge (squash)', silent = true },
    { '<leader>hp', '<cmd>Octo pr checkout<CR>', desc = '󰊤 PR checkout', silent = true },
    { '<leader>hb', '<cmd>Octo pr browser<CR>', desc = '󰊤 PR open in browser', silent = true },
  },
}
