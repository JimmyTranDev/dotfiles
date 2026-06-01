return {
  'nvim-treesitter/nvim-treesitter-textobjects',
  branch = 'main',
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  lazy = false,
  config = function()
    local select = require('nvim-treesitter.textobjects.select')
    local move = require('nvim-treesitter.textobjects.move')

    require('nvim-treesitter-textobjects').setup({
      select = {
        lookahead = true,
        selection_modes = {
          ['@function.outer'] = 'V',
          ['@parameter.outer'] = 'v',
        },
        include_surrounding_whitespace = true,
      },
      move = {
        set_jumps = true,
      },
    })

    -- Select keymaps
    for _, mode in ipairs({ 'x', 'o' }) do
      vim.keymap.set(mode, 'af', function()
        select.select_textobject('@function.outer', 'textobjects')
      end)
      vim.keymap.set(mode, 'if', function()
        select.select_textobject('@function.inner', 'textobjects')
      end)
      vim.keymap.set(mode, 'ap', function()
        select.select_textobject('@parameter.outer', 'textobjects')
      end)
      vim.keymap.set(mode, 'ip', function()
        select.select_textobject('@parameter.inner', 'textobjects')
      end)
      vim.keymap.set(mode, 'ao', function()
        select.select_textobject('@block.outer', 'textobjects')
      end)
      vim.keymap.set(mode, 'io', function()
        select.select_textobject('@block.inner', 'textobjects')
      end)
    end

    -- Move keymaps
    vim.keymap.set({ 'n', 'x', 'o' }, ']f', function()
      move.goto_next_start('@function.outer', 'textobjects')
    end)
    vim.keymap.set({ 'n', 'x', 'o' }, ']p', function()
      move.goto_next_start('@parameter.outer', 'textobjects')
    end)
    vim.keymap.set({ 'n', 'x', 'o' }, ']F', function()
      move.goto_next_end('@function.outer', 'textobjects')
    end)
    vim.keymap.set({ 'n', 'x', 'o' }, ']P', function()
      move.goto_next_end('@parameter.outer', 'textobjects')
    end)
    vim.keymap.set({ 'n', 'x', 'o' }, '[f', function()
      move.goto_previous_start('@function.outer', 'textobjects')
    end)
    vim.keymap.set({ 'n', 'x', 'o' }, '[p', function()
      move.goto_previous_start('@parameter.outer', 'textobjects')
    end)
    vim.keymap.set({ 'n', 'x', 'o' }, '[F', function()
      move.goto_previous_end('@function.outer', 'textobjects')
    end)
    vim.keymap.set({ 'n', 'x', 'o' }, '[P', function()
      move.goto_previous_end('@parameter.outer', 'textobjects')
    end)
  end,
}
