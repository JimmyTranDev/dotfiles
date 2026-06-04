return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').setup({
      install_dir = vim.fn.stdpath('data') .. '/site',
      ensure_installed = {
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
      },
    })

    vim.treesitter.language.register('markdown', 'mdx')

    -- Workaround for Neovim 0.12.2 bug: treesitter injection parsing can
    -- pass a nil node to get_range(), causing `node:range()` to error.
    -- Patch get_range to return zeros for nil nodes instead of crashing.
    local original_get_range = vim.treesitter.get_range
    vim.treesitter.get_range = function(node, source, metadata)
      if node == nil then
        return { 0, 0, 0, 0, 0, 0 }
      end
      return original_get_range(node, source, metadata)
    end
  end,
}
