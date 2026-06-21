return {
  'catppuccin/nvim',
  name = 'catppuccin',
  lazy = false, -- Load immediately for colorscheme
  priority = 1000,
  config = function()
    require('catppuccin').setup({
      flavour = 'mocha', -- Default to mocha flavor
      transparent_background = false, -- disables setting the background color.
      show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
      term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
      dim_inactive = {
        enabled = false, -- dims the background color of inactive window
        shade = 'dark',
        percentage = 0.15, -- percentage of the shade to apply to the inactive window
      },
      no_italic = false, -- Force no italic
      no_bold = false, -- Force no bold
      no_underline = false, -- Force no underline
      styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
        comments = { 'italic' }, -- Change the style of comments
        conditionals = { 'italic' },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
        -- miscs = {}, -- Uncomment to turn off hard-coded styles
      },
      color_overrides = {},
      -- Pin Snacks accent groups to the Mocha palette so the picker, dashboard,
      -- notifier and input UIs match the rest of the Catppuccin Mocha theme.
      -- The `snacks` integration below already links the base groups; these
      -- overrides only sharpen the accents and are harmless if a group is unused.
      custom_highlights = function(colors)
        return {
          -- Picker
          SnacksPickerTitle = { fg = colors.teal, style = { 'bold' } },
          SnacksPickerBorder = { fg = colors.surface1, bg = colors.mantle },
          SnacksPickerInputBorder = { fg = colors.surface1, bg = colors.mantle },
          SnacksPickerPreviewTitle = { fg = colors.blue, style = { 'bold' } },
          SnacksPickerMatch = { fg = colors.peach, style = { 'bold' } },
          -- Dashboard
          SnacksDashboardHeader = { fg = colors.teal },
          SnacksDashboardTitle = { fg = colors.blue, style = { 'bold' } },
          SnacksDashboardIcon = { fg = colors.peach },
          SnacksDashboardKey = { fg = colors.yellow },
          SnacksDashboardFooter = { fg = colors.overlay1 },
          -- Notifier
          SnacksNotifierInfo = { fg = colors.green },
          SnacksNotifierWarn = { fg = colors.yellow },
          SnacksNotifierError = { fg = colors.red },
          SnacksNotifierDebug = { fg = colors.overlay1 },
          SnacksNotifierTitleInfo = { fg = colors.green, style = { 'bold' } },
          SnacksNotifierTitleWarn = { fg = colors.yellow, style = { 'bold' } },
          SnacksNotifierTitleError = { fg = colors.red, style = { 'bold' } },
          -- Input
          SnacksInputTitle = { fg = colors.teal, style = { 'bold' } },
          SnacksInputBorder = { fg = colors.surface1, bg = colors.mantle },
        }
      end,
      default_integrations = true,
      integrations = {
        cmp = true,
        gitsigns = true,
        treesitter = true,
        notify = true,
        which_key = true,
        hop = true,
        snacks = true,
      },
    })

    -- Apply the theme
    vim.cmd('colorscheme catppuccin-mocha')
  end,
}
