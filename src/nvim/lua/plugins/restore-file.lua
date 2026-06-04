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
          if
            vim.fn.filereadable(abs_file) == 1
            and vim.startswith(vim.fn.fnamemodify(abs_file, ':h'), cwd)
            and os.execute('git -C ' .. vim.fn.shellescape(vim.fn.fnamemodify(abs_file, ':h')) .. ' check-ignore -q ' .. vim.fn.shellescape(abs_file) .. ' 2>/dev/null') ~= 0
          then
            vim.defer_fn(function()
              local ok, err = pcall(vim.cmd, 'edit ' .. vim.fn.fnameescape(abs_file))
              if not ok then
                vim.notify('restore-file: ' .. tostring(err), vim.log.levels.WARN)
              end
            end, 50)
            break
          end
        end
      end,
      desc = 'Auto-open most recent file from current folder on startup',
    })
  end,
}
