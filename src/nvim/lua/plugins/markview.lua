return {
  'OXY2DEV/markview.nvim',
  lazy = false,
  dependencies = {
    'saghen/blink.cmp',
  },
  config = function()
    local set_hl = vim.api.nvim_set_hl

    set_hl(0, 'MarkviewHeading1', { fg = '#94e2d5', bold = true })
    set_hl(0, 'MarkviewHeading1Sign', { fg = '#94e2d5' })
    set_hl(0, 'MarkviewHeading2', { fg = '#89b4fa', bold = true })
    set_hl(0, 'MarkviewHeading2Sign', { fg = '#89b4fa' })
    set_hl(0, 'MarkviewHeading3', { fg = '#94e2d5' })
    set_hl(0, 'MarkviewHeading3Sign', { fg = '#94e2d5' })
    set_hl(0, 'MarkviewHeading4', { fg = '#a6e3a1' })
    set_hl(0, 'MarkviewHeading4Sign', { fg = '#a6e3a1' })
    set_hl(0, 'MarkviewHeading5', { fg = '#f9e2af' })
    set_hl(0, 'MarkviewHeading5Sign', { fg = '#f9e2af' })
    set_hl(0, 'MarkviewHeading6', { fg = '#fab387' })
    set_hl(0, 'MarkviewHeading6Sign', { fg = '#fab387' })

    set_hl(0, 'MarkviewCode', { bg = '#313244' })
    set_hl(0, 'MarkviewCodeFg', { fg = '#45475a' })
    set_hl(0, 'MarkviewCodeInfo', { fg = '#6c7086' })
    set_hl(0, 'MarkviewInlineCode', { bg = '#313244', fg = '#cdd6f4' })

    set_hl(0, 'MarkviewHyperlink', { fg = '#b4befe' })
    set_hl(0, 'MarkviewImage', { fg = '#b4befe' })
    set_hl(0, 'MarkviewEmail', { fg = '#b4befe' })

    set_hl(0, 'MarkviewListItemMinus', { fg = '#a6adc8' })
    set_hl(0, 'MarkviewListItemPlus', { fg = '#a6adc8' })
    set_hl(0, 'MarkviewListItemStar', { fg = '#a6adc8' })

    set_hl(0, 'MarkviewGradient0', { fg = '#313244' })
    set_hl(0, 'MarkviewGradient1', { fg = '#3b3c50' })
    set_hl(0, 'MarkviewGradient2', { fg = '#45475a' })
    set_hl(0, 'MarkviewGradient3', { fg = '#4f5164' })
    set_hl(0, 'MarkviewGradient4', { fg = '#585b6e' })
    set_hl(0, 'MarkviewGradient5', { fg = '#626578' })
    set_hl(0, 'MarkviewGradient6', { fg = '#6c7086' })
    set_hl(0, 'MarkviewGradient7', { fg = '#7f849c' })
    set_hl(0, 'MarkviewGradient8', { fg = '#9399b2' })
    set_hl(0, 'MarkviewGradient9', { fg = '#a6adc8' })

    set_hl(0, 'MarkviewCheckboxChecked', { fg = '#a6e3a1' })
    set_hl(0, 'MarkviewCheckboxUnchecked', { fg = '#6c7086' })
    set_hl(0, 'MarkviewCheckboxPending', { fg = '#f9e2af' })
    set_hl(0, 'MarkviewCheckboxProgress', { fg = '#89b4fa' })
    set_hl(0, 'MarkviewCheckboxCancelled', { fg = '#45475a' })
    set_hl(0, 'MarkviewCheckboxStriked', { fg = '#45475a' })

    require('markview').setup({
      preview = {
        enable = true,
        filetypes = { 'markdown', 'md' },
      },
      markdown = {
        tables = {
          enable = true,
          use_virt_lines = true,
        },
        headings = {
          enable = true,
          shift_width = 1,

          heading_1 = {
            style = 'icon',
            icon = '󰼏  ',
            hl = 'MarkviewHeading1',
            sign = '󰌕 ',
            sign_hl = 'MarkviewHeading1Sign',
          },
          heading_2 = {
            style = 'icon',
            icon = '󰎨  ',
            hl = 'MarkviewHeading2',
            sign = '󰌖 ',
            sign_hl = 'MarkviewHeading2Sign',
          },
          heading_3 = {
            style = 'icon',
            icon = '󰼑  ',
            hl = 'MarkviewHeading3',
          },
          heading_4 = {
            style = 'icon',
            icon = '󰎲  ',
            hl = 'MarkviewHeading4',
          },
          heading_5 = {
            style = 'icon',
            icon = '󰼓  ',
            hl = 'MarkviewHeading5',
          },
          heading_6 = {
            style = 'icon',
            icon = '󰎴  ',
            hl = 'MarkviewHeading6',
          },

          setext_1 = {
            style = 'decorated',
            icon = '  ',
            hl = 'MarkviewHeading1',
            sign = '󰌕 ',
            sign_hl = 'MarkviewHeading1Sign',
            border = '▂',
          },
          setext_2 = {
            style = 'decorated',
            icon = '  ',
            hl = 'MarkviewHeading2',
            sign = '󰌖 ',
            sign_hl = 'MarkviewHeading2Sign',
            border = '▁',
          },
        },

        code_blocks = {
          enable = true,
          style = 'block',
          min_width = 60,
          pad_amount = 2,
          pad_char = ' ',
          sign = true,

          border_hl = 'MarkviewCode',
          info_hl = 'MarkviewCodeInfo',

          default = {
            block_hl = 'MarkviewCode',
            pad_hl = 'MarkviewCode',
          },

          ['diff'] = {
            block_hl = function(_, line)
              if line:match('^%+') then
                return 'MarkviewPalette4'
              elseif line:match('^%-') then
                return 'MarkviewPalette1'
              else
                return 'MarkviewCode'
              end
            end,
            pad_hl = 'MarkviewCode',
          },
        },

        horizontal_rules = {
          enable = true,
          parts = {
            {
              type = 'repeating',
              direction = 'left',
              repeat_amount = function(buffer)
                local utils = require('markview.utils')
                local window = utils.buf_getwin(buffer)
                local width = vim.api.nvim_win_get_width(window)
                local textoff = vim.fn.getwininfo(window)[1].textoff
                return math.floor((width - textoff - 3) / 2)
              end,
              text = '─',
              hl = {
                'MarkviewGradient1',
                'MarkviewGradient1',
                'MarkviewGradient2',
                'MarkviewGradient2',
                'MarkviewGradient3',
                'MarkviewGradient3',
                'MarkviewGradient4',
                'MarkviewGradient4',
                'MarkviewGradient5',
                'MarkviewGradient5',
                'MarkviewGradient6',
                'MarkviewGradient6',
                'MarkviewGradient7',
                'MarkviewGradient7',
                'MarkviewGradient8',
                'MarkviewGradient8',
                'MarkviewGradient9',
                'MarkviewGradient9',
              },
            },
            {
              type = 'text',
              text = '  ',
              hl = 'MarkviewGradient6',
            },
            {
              type = 'repeating',
              direction = 'right',
              repeat_amount = function(buffer)
                local utils = require('markview.utils')
                local window = utils.buf_getwin(buffer)
                local width = vim.api.nvim_win_get_width(window)
                local textoff = vim.fn.getwininfo(window)[1].textoff
                return math.ceil((width - textoff - 3) / 2)
              end,
              text = '─',
              hl = {
                'MarkviewGradient1',
                'MarkviewGradient1',
                'MarkviewGradient2',
                'MarkviewGradient2',
                'MarkviewGradient3',
                'MarkviewGradient3',
                'MarkviewGradient4',
                'MarkviewGradient4',
                'MarkviewGradient5',
                'MarkviewGradient5',
                'MarkviewGradient6',
                'MarkviewGradient6',
                'MarkviewGradient7',
                'MarkviewGradient7',
                'MarkviewGradient8',
                'MarkviewGradient8',
                'MarkviewGradient9',
                'MarkviewGradient9',
              },
            },
          },
        },

        list_items = {
          enable = true,
          wrap = true,
          indent_size = function(buffer)
            if type(buffer) ~= 'number' then return vim.bo.shiftwidth or 4 end
            return vim.bo[buffer].shiftwidth or 4
          end,
          shift_width = 4,

          marker_minus = {
            add_padding = true,
            conceal_on_checkboxes = true,
            text = '●',
            hl = 'MarkviewListItemMinus',
          },
          marker_plus = {
            add_padding = true,
            conceal_on_checkboxes = true,
            text = '◈',
            hl = 'MarkviewListItemPlus',
          },
          marker_star = {
            add_padding = true,
            conceal_on_checkboxes = true,
            text = '◇',
            hl = 'MarkviewListItemStar',
          },
          marker_dot = {
            add_padding = true,
            conceal_on_checkboxes = true,
            text = function(_, item) return string.format('%d.', item.n) end,
            hl = 'MarkviewListItemMinus',
          },
          marker_parenthesis = {
            add_padding = true,
            conceal_on_checkboxes = true,
            text = function(_, item) return string.format('%d)', item.n) end,
            hl = 'MarkviewListItemMinus',
          },
        },
      },

      markdown_inline = {
        hyperlinks = {
          enable = true,
          default = {
            icon = '󰌷 ',
            hl = 'MarkviewHyperlink',
          },
        },
        images = {
          enable = true,
          default = {
            icon = '󰥶 ',
            hl = 'MarkviewImage',
          },
        },
        emails = {
          enable = true,
          default = {
            icon = ' ',
            hl = 'MarkviewEmail',
          },
        },
      },
    })
  end,
}
