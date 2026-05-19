return {
  'folke/todo-comments.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    {
      '<leader>ft',
      function() require('snacks').picker.todo_comments() end,
      desc = 'Todo',
    },
    {
      '<leader>fT',
      function() require('snacks').picker.todo_comments({ keywords = { 'TODO', 'FIX', 'FIXME' } }) end,
      desc = 'Todo/Fix/Fixme',
    },
  },
  config = function() require('todo-comments').setup() end,
}
