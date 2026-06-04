-- Restore the most recent file from oldfiles that belongs to the current working directory.
return {
  'restore-file',
  virtual = true,
  lazy = false,
  config = function()
    vim.api.nvim_create_autocmd('UIEnter', {
      callback = function()
        if vim.fn.argc() > 0 then
          return
        end
        local cwd = vim.fn.getcwd()
        for _, file in ipairs(vim.v.oldfiles or {}) do
          local abs_file = vim.fn.fnamemodify(file, ':p')
          if vim.fn.filereadable(abs_file) == 1 and vim.startswith(vim.fn.fnamemodify(abs_file, ':h'), cwd) then
            vim.defer_fn(function()
              -- Use noautocmd to avoid a Neovim 0.12.2 treesitter bug where
              -- markview's BufEnter handler triggers injection parsing before
              -- the language tree is ready (nil node in :range()).
              -- After the buffer is stable, re-trigger BufEnter so plugins
              -- can attach normally.
              vim.cmd('noautocmd edit ' .. vim.fn.fnameescape(abs_file))
              vim.schedule(function()
                vim.cmd('doautocmd BufReadPost')
                vim.cmd('doautocmd BufEnter')
                vim.cmd('doautocmd BufWinEnter')
              end)
            end, 50)
            break
          end
        end
      end,
      desc = 'Auto-open most recent file from current folder on startup',
    })
  end,
}
