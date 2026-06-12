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
    { '<leader>ghl', '<cmd>Octo pr list<CR>', desc = '󰊤 PR list', silent = true },
    { '<leader>ghs', '<cmd>Octo pr search<CR>', desc = '󰊤 PR search', silent = true },
    { '<leader>ghd', '<cmd>Octo pr diff<CR>', desc = '󰊤 PR diff', silent = true },
    { '<leader>ghr', '<cmd>Octo review start<CR>', desc = '󰊤 Review start', silent = true },
    { '<leader>ghR', '<cmd>Octo review submit<CR>', desc = '󰊤 Review submit', silent = true },
    { '<leader>gha', '<cmd>Octo review comments<CR>', desc = '󰊤 Review comments', silent = true },
    { '<leader>ghi', '<cmd>Octo issue list<CR>', desc = '󰊤 Issue list', silent = true },
    { '<leader>ghI', '<cmd>Octo issue search<CR>', desc = '󰊤 Issue search', silent = true },
    { '<leader>ghm', '<cmd>Octo pr merge squash<CR>', desc = '󰊤 PR merge (squash)', silent = true },
    { '<leader>ghp', '<cmd>Octo pr checkout<CR>', desc = '󰊤 PR checkout', silent = true },
    { '<leader>ghb', '<cmd>Octo pr browser<CR>', desc = '󰊤 PR open in browser', silent = true },
  },
}
