return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    'marilari88/neotest-vitest',
    'rcasia/neotest-java',
    'nvim-neotest/neotest-python',
  },
  keys = {
    { '<leader><leader>cr', function() require('neotest').run.run() end, desc = '󰙨 Run Nearest' },
    { '<leader><leader>cf', function() require('neotest').run.run(vim.fn.expand('%')) end, desc = '󰙨 Run File' },
    { '<leader><leader>cs', function() require('neotest').summary.toggle() end, desc = '󰙨 Toggle Summary' },
    { '<leader><leader>co', function() require('neotest').output_panel.toggle() end, desc = '󰙨 Toggle Output Panel' },
    { '<leader><leader>cd', function() require('neotest').run.run({ strategy = 'dap' }) end, desc = '󰙨 Debug Nearest' },
    { '<leader><leader>cx', function() require('neotest').run.stop() end, desc = '󰙨 Stop' },
    { '<leader><leader>ca', function() require('neotest').run.run(vim.uv.cwd()) end, desc = '󰙨 Run All' },
  },
  config = function()
    require('neotest').setup({
      adapters = {
        require('neotest-vitest'),
        require('neotest-java'),
        require('neotest-python'),
      },
    })
  end,
}
