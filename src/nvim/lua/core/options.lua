vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local function setup_editor_basics()
  vim.opt.spelllang = 'en_us'

  vim.o.mouse = 'a'

  vim.o.undofile = true
  vim.o.hidden = true
  vim.o.autoread = true

  vim.o.completeopt = 'menuone,noselect'

  vim.o.ttimeoutlen = 10
  vim.o.synmaxcol = 240
end

local function setup_display()
  vim.wo.number = true
  vim.wo.relativenumber = true
  vim.wo.signcolumn = 'yes'

  vim.opt.cursorline = true
  vim.o.scrolloff = 99999

  vim.wo.wrap = false
  vim.wo.linebreak = true
  vim.wo.list = false
  vim.o.foldenable = false

  vim.o.laststatus = 3
  vim.o.termguicolors = true
  vim.o.winborder = 'rounded'
end

local function setup_indentation()
  vim.opt.tabstop = 2
  vim.opt.shiftwidth = 2
  vim.opt.softtabstop = 2
  vim.opt.expandtab = true
  vim.o.breakindent = true
end

local function setup_search() vim.o.ignorecase = true end

local function setup_clipboard()
  vim.o.clipboard = 'unnamedplus'

  if vim.fn.has('wsl') == 1 then
    vim.g.clipboard = {
      name = 'win32yank',
      copy = {
        ['+'] = 'win32yank.exe -i --crlf',
        ['*'] = 'win32yank.exe -i --crlf',
      },
      paste = {
        ['+'] = 'win32yank.exe -o --lf',
        ['*'] = 'win32yank.exe -o --lf',
      },
      cache_enabled = 0,
    }
  end
end

local function setup_performance()
  vim.o.updatetime = 250
  vim.o.timeoutlen = 300
  vim.o.redrawtime = 1500
  vim.o.lazyredraw = true
  vim.o.history = 1000
  vim.o.maxmempattern = 20000

  vim.o.swapfile = false
  vim.o.backup = false
  vim.o.writebackup = false

  vim.g.loaded_python3_provider = 0
  vim.g.loaded_ruby_provider = 0
  vim.g.loaded_perl_provider = 0
  vim.g.loaded_node_provider = 0

  vim.opt.diffopt:append('algorithm:patience')
  vim.opt.diffopt:append('indent-heuristic')

  vim.o.foldmethod = 'manual'
  vim.o.foldlevelstart = 99
  vim.o.regexpengine = 0

  vim.cmd('filetype on')
  vim.cmd('filetype plugin on')
  vim.cmd('filetype indent on')
end

local function setup_plugin_globals() vim.g.copilot_no_tab_map = true end

local function setup_diagnostics()
  vim.diagnostic.config({
    float = { border = 'rounded' },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = ' ',
        [vim.diagnostic.severity.WARN] = ' ',
        [vim.diagnostic.severity.INFO] = ' ',
        [vim.diagnostic.severity.HINT] = '󰌵',
      },
    },
  })
end

local function setup_highlights()
  local ok, catppuccin = pcall(require, 'catppuccin.palettes')
  local colors = ok and catppuccin.get_palette('mocha') or {}
  local line_nr_color = colors.overlay0 or '#6c7086'

  vim.api.nvim_set_hl(0, 'LineNrAbove', {
    fg = line_nr_color,
    bold = true,
  })
  vim.api.nvim_set_hl(0, 'LineNrBelow', {
    fg = line_nr_color,
    bold = true,
  })
end

setup_editor_basics()
setup_display()
setup_indentation()
setup_search()
setup_clipboard()
setup_performance()
setup_plugin_globals()
setup_diagnostics()
setup_highlights()
