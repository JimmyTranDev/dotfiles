local opencode_cmd = 'opencode --port'

---@type snacks.terminal.Opts
local snacks_terminal_opts = {
  win = {
    position = 'right',
    enter = false,
  },
}

return {
  'NickvanDyke/opencode.nvim',
  version = '*',
  dependencies = {
    { 'folke/snacks.nvim', opts = { input = {}, picker = {}, terminal = {} } },
  },
  lazy = false,
  keys = {
    { '<C-a>', function() require('opencode').ask('@this: ') end, mode = { 'n', 'x' }, desc = '󰚴 Ask opencode' },
    { '<C-.>', function() require('snacks.terminal').toggle(opencode_cmd, snacks_terminal_opts) end, mode = { 'n', 't' }, desc = '󰚴 Toggle opencode' },
  },
  config = function()
    vim.o.autoread = true

    ---@type opencode.Opts
    vim.g.opencode_opts = {
      server = {
        start = function()
          require('snacks.terminal').open(opencode_cmd, snacks_terminal_opts)
        end,
      },
    }
  end,
}
