return {
  'mechatroner/rainbow_csv',
  ft = { 'csv', 'tsv', 'csv_semicolon', 'csv_whitespace', 'csv_pipe', 'rfc_csv', 'rfc_semicolon' },
  init = function()
    vim.g.rcsv_delimiters = { '\t', ',', ';', '|' }
    vim.filetype.add({
      pattern = {
        ['.*%.psv'] = 'csv_pipe',
      },
    })
    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
      pattern = '*',
      callback = function()
        local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ''
        if first_line:find('|') and not vim.bo.filetype:find('csv') then
          local pipe_count = select(2, first_line:gsub('|', ''))
          if pipe_count >= 2 then vim.bo.filetype = 'csv_pipe' end
        end
      end,
    })
  end,
}
