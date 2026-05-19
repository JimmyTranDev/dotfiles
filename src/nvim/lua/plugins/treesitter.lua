return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').setup({
      install_dir = vim.fn.stdpath('data') .. '/site',
    })

    require('nvim-treesitter').install({
      'lua',
      'vim',
      'vimdoc',
      'query',
      'javascript',
      'typescript',
      'tsx',
      'json',
      'html',
      'css',
      'scss',
      'yaml',
      'toml',
      'markdown',
      'markdown_inline',
      'python',
      'java',
      'kotlin',
      'bash',
      'fish',
      'git_config',
      'git_rebase',
      'gitattributes',
      'gitcommit',
      'gitignore',
      'go',
      'sql',
    })

    vim.treesitter.language.register('markdown', 'mdx')
  end,
}
