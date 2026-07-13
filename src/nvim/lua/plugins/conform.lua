return {
  'stevearc/conform.nvim',
  event = 'BufWritePre',
  opts = {},
  config = function()
    require('conform').setup({
      format_after_save = {
        lsp_format = 'fallback',
        async = true,
        timeout_ms = 10000,
      },
      formatters_by_ft = {
        python = { 'black', 'isort' },
        go = { 'goimports', 'gofmt' },
        dart = { 'dart_format' },
        java = {},
        lua = { 'stylua' },

        javascript = { 'oxfmt', 'eslint' },
        javascriptreact = { 'oxfmt', 'eslint' },
        typescript = { 'oxfmt', 'eslint' },
        typescriptreact = { 'oxfmt', 'eslint' },

        json = { 'oxfmt' },
        jsonc = { 'oxfmt' },
        html = { 'oxfmt' },
        css = { 'oxfmt' },
        markdown = { 'oxfmt' },
        xhtml = { 'oxfmt' },
        xml = { 'prettier' },
        yaml = { 'oxfmt' },

        bash = { 'shfmt' },
        sh = { 'shfmt' },
        zsh = { 'shfmt' },
      },
      formatters = {
        oxfmt = {
          command = 'oxfmt',
          args = { '--stdin-filepath', '$FILENAME' },
          stdin = true,
        },
      },
    })
  end,
}
