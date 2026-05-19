return {
  'hat0uma/csvview.nvim',
  ft = { 'csv', 'tsv', 'csv_semicolon', 'csv_whitespace', 'csv_pipe', 'rfc_csv', 'rfc_semicolon' },
  opts = {
    parser = {
      delimiter = {
        default = ',',
        ft = {
          tsv = '\t',
          csv_pipe = '|',
          csv_semicolon = ';',
        },
      },
    },
    view = {
      display_mode = 'border',
    },
  },
  keys = {
    { '<leader>cv', '<cmd>CsvViewToggle<cr>', desc = 'Toggle CSV View', ft = { 'csv', 'tsv', 'csv_semicolon', 'csv_pipe' } },
  },
}
