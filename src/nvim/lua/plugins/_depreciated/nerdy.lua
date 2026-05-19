return {
  '2KAbhishek/nerdy.nvim',
  lazy = true,
  cmd = { 'Nerdy' },
  keys = {
    {
      mode = 'i',
      '<c-.>',
      '<cmd>Nerdy<cr>',
      silent = true,
      desc = '󰛓 Browse Nerd Font Icons',
    },
    {
      mode = 'n',
      ';n',
      '<cmd>Nerdy<cr>',
      silent = true,
      desc = '󰛓 Browse Nerd Font Icons',
    },
  },
  opts = {
    max_recents = 20,
    add_default_keybindings = false,
    copy_to_clipboard = false,
  },
}
