return {
  'echasnovski/mini.surround',
  version = '*',
  event = 'InsertEnter',
  config = function()
    require('mini.surround').setup({
      mappings = {
        add = 'gsa',
        delete = 'gsd',
        replace = 'gsr',
        find = 'gsf',
        find_left = 'gsF',
        highlight = 'gsh',
        update_n_lines = 'gsn',
      },
    })
  end,
}
