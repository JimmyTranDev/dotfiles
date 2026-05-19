return {
  ft = { 'java' },
  'nvim-java/nvim-java',
  config = function()
    require('java').setup()

    local formatter_path = vim.fn.stdpath('config') .. '/etc/intellij-java-style.xml'

    vim.lsp.config('jdtls', {
      settings = {
        java = {
          format = {
            enabled = true,
            settings = {
              url = formatter_path,
              profile = 'IntelliJStyle',
            },
          },
          compile = {
            nullAnalysis = {
              mode = 'automatic',
            },
          },
          cleanup = {
            actionsOnSave = {
              'addOverride',
              'addDeprecated',
              'qualifyMembers',
              'qualifyStaticMembers',
              'organizeImports',
            },
          },
          diagnostics = {
            unusedImports = 'warning',
            unusedVariables = 'warning',
            unusedParameters = 'warning',
          },
          saveActions = {
            organizeImports = true,
          },
        },
      },
    })

    vim.lsp.enable('jdtls')
  end,
}
