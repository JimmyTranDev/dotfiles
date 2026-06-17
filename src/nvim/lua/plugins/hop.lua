return {
  'smoka7/hop.nvim',
  version = '*',
  opts = {},
  keys = {
    { 'f', desc = '󰯲 Hop forward' },
    { 'F', desc = '󰯲 Hop backward' },
    { 't', desc = '󰯲 Hop to before forward' },
    { 'T', desc = '󰯲 Hop to before backward' },
  },
  config = function()
    local hop = require('hop')
    hop.setup({
      case_insensitive = false,
    })
    local directions = require('hop.hint').HintDirection
    vim.keymap.set('', 'f', function() hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true }) end, { remap = true })
    vim.keymap.set('', 'F', function() hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true }) end, { remap = true })
    vim.keymap.set(
      '',
      't',
      function() hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true, hint_offset = -1 }) end,
      { remap = true }
    )
    vim.keymap.set(
      '',
      'T',
      function() hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true, hint_offset = 1 }) end,
      { remap = true }
    )
  end,
}
