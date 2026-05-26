return {
  'saghen/blink.cmp',
  event = { 'InsertEnter', 'CmdlineEnter' },
  dependencies = {
    'echasnovski/mini.nvim',
  },
  version = '*',
  opts = {
    enabled = function()
      return vim.bo.filetype ~= 'opencode_ask'
    end,
    cmdline = {
      enabled = true,
      completion = {
        menu = { auto_show = true },
      },
    },
    keymap = {
      ['<CR>'] = { 'select_and_accept', 'fallback' },
      ['<Down>'] = { 'select_next', 'fallback' },
      ['<Up>'] = { 'select_prev', 'fallback' },
      ['<S-PageDown>'] = { 'scroll_documentation_down' },
      ['<S-PageUp>'] = { 'scroll_documentation_up' },
      ['<C-n>'] = { 'show', 'show_documentation', 'hide_documentation' },
    },
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer' },
    },
    signature = { enabled = true },
    completion = {
      trigger = {
        keyword_length = 2,
        keyword_regex = '[%w_%-%.#:]*',
        exclude_from_prefix_regex = '[%(%)]',
      },
      accept = { auto_brackets = { enabled = false } },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        update_delay_ms = 100,
      },
      menu = {
        draw = {
          components = {
            kind_icon = {
              ellipsis = false,
              text = function(ctx)
                local icon = require('mini.icons').get('lsp', ctx.kind)
                return icon
              end,
              highlight = function(ctx)
                local _, hl = require('mini.icons').get('lsp', ctx.kind)
                return hl
              end,
            },
          },
        },
      },
    },
  },
  opts_extend = { 'sources.default' },
}
