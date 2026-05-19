local M = {}

M.servers = {
  lua_ls = {
    filetypes = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
    settings = {
      Lua = {
        diagnostics = {
          globals = { 'vim' },
        },
        workspace = {
          checkThirdParty = false,
          library = vim.api.nvim_get_runtime_file('', true),
        },
      },
    },
  },
  gopls = {
    settings = {
      completions = {
        completeFunctionCalls = true,
      },
    },
  },
  ts_ls = {
    init_options = {
      preferences = {
        importModuleSpecifierPreference = 'relative',
        importModuleSpecifierEnding = 'minimal',
      },
    },
  },
  cssls = {},
  eslint = {},
  html = {},
  jsonls = {},
  marksman = {},
  pyright = {},
  rust_analyzer = {},
  kotlin_language_server = {},
  sqls = {},
  harper_ls = {
    filetypes = { 'markdown', 'text', 'gitcommit' },
    settings = {
      ['harper-ls'] = {
        dialect = 'American',
      },
    },
  },
}

return M
