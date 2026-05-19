return {
  'kawre/leetcode.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  cmd = 'Leet',
  build = ':TSUpdate html',
  keys = {
    { '<leader><leader>ll', '<cmd>Leet<CR>', desc = '󰞷 Open LeetCode', mode = 'n' },
    { '<leader><leader>lm', '<cmd>Leet menu<CR>', desc = '󰍉 LeetCode menu', mode = 'n' },
    { '<leader><leader>lc', '<cmd>Leet console<CR>', desc = '󰆍 Open console', mode = 'n' },
    { '<leader><leader>li', '<cmd>Leet info<CR>', desc = '󰋽 Problem info', mode = 'n' },

    { '<leader><leader>lL', '<cmd>Leet list<CR>', desc = '󰉋 List problems', mode = 'n' },
    { '<leader><leader>ld', '<cmd>Leet daily<CR>', desc = '󰦉 Daily challenge', mode = 'n' },
    { '<leader><leader>lR', '<cmd>Leet random<CR>', desc = '󰛄 Random problem', mode = 'n' },

    { '<leader><leader>lr', '<cmd>Leet run<CR>', desc = '󰃒 Run code', mode = 'n' },
    { '<leader><leader>lS', '<cmd>Leet submit<CR>', desc = '󰜐 Submit solution', mode = 'n' },
    { '<leader><leader>lT', '<cmd>Leet test<CR>', desc = '󰙨 Run tests', mode = 'n' },

    { '<leader><leader>ls', '<cmd>Leet session<CR>', desc = '󰌐 Manage session', mode = 'n' },
    { '<leader><leader>ly', '<cmd>Leet yank<CR>', desc = '󰈙 Yank solution', mode = 'n' },

    { '<leader><leader>lg', '<cmd>Leet lang<CR>', desc = '󰌐 Change language', mode = 'n' },
    { '<leader><leader>lD', '<cmd>Leet desc<CR>', desc = '󰈙 Toggle description', mode = 'n' },
    { '<leader><leader>lC', '<cmd>Leet cache<CR>', desc = '󰨮 Cache operations', mode = 'n' },
  },
  opts = {
    arg = 'leetcode.nvim',
    lang = 'javascript',

    cn = {
      enabled = false,
      translator = true,
      translate_problems = true,
    },

    storage = {
      home = vim.fn.stdpath('data') .. '/leetcode',
      cache = vim.fn.stdpath('cache') .. '/leetcode',
    },

    logging = true,

    cache = {
      update_interval = 60 * 60 * 24 * 7,
    },

    console = {
      open_on_runcode = true,
      dir = 'row',
      size = {
        width = '90%',
        height = '75%',
      },
      result = {
        size = '60%',
      },
      testcase = {
        virt_text = true,
        size = '40%',
      },
    },

    description = {
      position = 'left',
      width = '40%',
      show_stats = true,
    },

    image_support = false,
  },
  config = function(_, opts)
    require('leetcode').setup(opts)

    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'leetcode.nvim',
      callback = function()
        local keymap = vim.keymap
        local function map(mode, lhs, rhs, desc) keymap.set(mode, lhs, rhs, { desc = desc, silent = true, noremap = true }) end

        map('n', '<CR>', '<cmd>Leet run<CR>', '󰃒 Run code')
        map('n', 's', '<cmd>Leet submit<CR>', '󰜐 Submit solution')
        map('n', 't', '<cmd>Leet test<CR>', '󰙨 Run tests')
      end,
    })
  end,
}
