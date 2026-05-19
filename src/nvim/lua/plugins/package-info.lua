return {
  'vuki656/package-info.nvim',
  dependencies = 'MunifTanjim/nui.nvim',
  ft = { 'json' },
  keys = {
    -- {
    --   mode = 'n',
    --   '<leader><leader>ps',
    --   function() require('package-info').show() end,
    --   silent = true,
    --   desc = '󰎡 NPM Show',
    -- },
    -- {
    --   mode = 'n',
    --   '<leader><leader>pd',
    --   function() require('package-info').delete() end,
    --   silent = true,
    --   desc = '󰎡 Npm Delete',
    -- },
    -- {
    --   mode = 'n',
    --   '<leader><leader>pc',
    --   function() require('package-info').change_version() end,
    --   silent = true,
    --   desc = '󰎡 Npm Change',
    -- },
    -- {
    --   mode = 'n',
    --   '<leader><leader>pi',
    --   function() require('package-info').install() end,
    --   silent = true,
    --   desc = '󰎡 Npm Install',
    -- },
  },
  config = function()
    local language_utils = require('custom.utils.language')
    local ok, catppuccin = pcall(require, 'catppuccin.palettes')
    local palette = ok and catppuccin.get_palette('mocha') or {}

    require('package-info').setup({
      colors = {
        up_to_date = palette.surface1 or '#45475a',
        outdated = palette.peach or '#fab387',
      },
      icons = {
        enable = true,
        style = {
          up_to_date = '|  ',
          outdated = '|  ',
        },
      },
      autostart = true,
      hide_up_to_date = true,
      hide_unstable_versions = true,
      package_manager = language_utils.get_javascript_package_manager() or 'npm',
    })
  end,
}
