return {
  'gbprod/substitute.nvim',
  -- event = "InsertEnter",
  keys = {
    {
      mode = 'n',
      'gr',
      function() require('substitute').operator() end,
      desc = '󰕈 substitute',
    },
    {
      mode = 'n',
      'grr',
      function() require('substitute').line() end,
      desc = '󰕈 substitute line',
    },
    {
      mode = 'n',
      'gR',
      function() require('substitute').eol() end,
      desc = '󰕈 substitute to end of line',
    },
    {
      mode = 'x',
      'gr',
      function() require('substitute').visual() end,
      desc = '󰕈 substitute visual',
    },
  },
  config = function() require('substitute').setup() end,
}
