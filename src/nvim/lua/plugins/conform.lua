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
        dart = { 'dartfmt' },
        java = {},
        lua = { 'stylua' },

        javascript = { 'prettier', 'eslint' },
        javascriptreact = { 'prettier', 'eslint' },
        typescript = { 'prettier', 'eslint' },
        typescriptreact = { 'prettier', 'eslint' },

        json = { 'prettier' },
        jsonc = { 'prettier' },
        html = { 'prettier' },
        css = { 'prettier' },
        markdown = { 'prettier' },
        xhtml = { 'prettier' },
        xml = { 'prettier' },
        yaml = { 'prettier' },

        bash = { 'shfmt' },
        sh = { 'shfmt' },
        zsh = { 'shfmt' },
      },
    })
  end,
}
