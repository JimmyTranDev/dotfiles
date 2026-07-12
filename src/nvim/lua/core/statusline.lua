local M = {}

local TEXT_TRUNCATE_LENGTH = 40
local TEXT_TRUNCATE_PREVIEW = 37
local MIN_WIDTH_FOR_DETAILS = 80
local DEFAULT_THEME_FLAVOR = 'mocha'

local function get_catppuccin_colors()
  local ok, catppuccin = pcall(require, 'catppuccin.palettes')
  if not ok then
    return {
      green = '#a6e3a1',
      peach = '#fab387',
      sapphire = '#74c7ec',
      red = '#f38ba8',
      yellow = '#f9e2af',
      sky = '#89dceb',
      lavender = '#b4befe',
      mauve = '#cba6f7',
      mantle = '#181825',
      base = '#1e1e2e',
    }
  end

  local colors = catppuccin.get_palette(DEFAULT_THEME_FLAVOR)

  colors.orange = colors.peach or colors.orange
  colors.cyan = colors.sky or colors.cyan

  return colors
end

local colors = get_catppuccin_colors()

local conditions = {
  hide_in_width = function() return vim.fn.winwidth(0) > MIN_WIDTH_FOR_DETAILS end,
}

local function truncate_text(text)
  if type(text) == 'string' and #text > TEXT_TRUNCATE_LENGTH then return text:sub(1, TEXT_TRUNCATE_PREVIEW) .. '...' end
  return tostring(text)
end

local function build_config()
  local config = {
    options = {
      globalstatus = true,
      component_separators = '',
      section_separators = '',
      disabled_filetypes = {
        statusline = {},
        winbar = {},
      },
      theme = {
        normal = { c = { fg = colors.green, bg = colors.mantle } },
        insert = { c = { fg = colors.green, bg = colors.mantle } },
        visual = { c = { fg = colors.green, bg = colors.mantle } },
        replace = { c = { fg = colors.green, bg = colors.mantle } },
        command = { c = { fg = colors.green, bg = colors.mantle } },
        inactive = { c = { fg = colors.green, bg = colors.mantle } },
      },
    },
    sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_y = {},
      lualine_z = {},
      lualine_c = {},
      lualine_x = {},
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_y = {},
      lualine_z = {},
      lualine_c = {},
      lualine_x = {},
    },
  }

  local function create_bubble(section, color_fn, icon, component)
    local cond = component.cond
    component.color = color_fn

    table.insert(section, {
      function() return icon end,
      cond = cond,
      color = color_fn,
      padding = { left = 1, right = 0 },
    })

    if type(component[1]) == 'function' then
      local orig_fn = component[1]
      component[1] = function(...) return truncate_text(orig_fn(...)) end
    end

    if component.fmt then
      local orig_fmt = component.fmt
      component.fmt = function(text, ...) return truncate_text(orig_fmt(text, ...)) end
    else
      component.fmt = truncate_text
    end

    table.insert(section, component)
  end

  local function left_bubble(color_fn, icon, component) create_bubble(config.sections.lualine_c, color_fn, icon, component) end

  local function right_bubble(color_fn, icon, component) create_bubble(config.sections.lualine_x, color_fn, icon, component) end

  local function get_lsp_client()
    local clients = vim.lsp.get_clients({ bufnr = 0 })

    if #clients == 0 then return 'NONE' end

    if #clients == 1 then return clients[1].name end

    return clients[1].name .. ' +' .. (#clients - 1)
  end

  local function get_directory_name()
    local cwd = vim.fn.getcwd()
    return vim.fn.fnamemodify(cwd, ':t')
  end

  local function get_git_branch()
    local head = vim.b.gitsigns_head
    if head and head ~= '' then return head end
    return 'NONE'
  end

  left_bubble(function() return { fg = colors.green, gui = 'bold' } end, '', { 'mode' })

  left_bubble(function() return { fg = colors.peach, gui = 'bold' } end, '󰕥', { get_lsp_client })

  left_bubble(function() return { fg = colors.sapphire, gui = 'bold' } end, '', { get_directory_name })

  left_bubble(function() return { fg = colors.lavender, gui = 'bold' } end, '', { get_git_branch })

  table.insert(config.sections.lualine_c, {
    'diff',
    symbols = { added = ' ', modified = ' ', removed = ' ' },
    diff_color = {
      added = { fg = colors.green },
      modified = { fg = colors.orange or colors.peach },
      removed = { fg = colors.red },
    },
    cond = conditions.hide_in_width,
    always_visible = true,
  })

  local gh_pr_unresolved_comments = require('custom.utils.gh_pr_unresolved_comments')
  right_bubble(function() return { fg = colors.peach, gui = 'bold' } end, '', {
    gh_pr_unresolved_comments.get_count,
    cond = function() return gh_pr_unresolved_comments.get_count() ~= '' end,
  })

  local gh_team_prs = require('custom.utils.gh_team_prs')
  right_bubble(function() return { fg = colors.mauve or colors.lavender, gui = 'bold' } end, '󰊤', {
    gh_team_prs.get_count,
    cond = function() return gh_team_prs.get_count() ~= '' end,
  })

  table.insert(config.sections.lualine_x, {
    'diagnostics',
    sources = { 'nvim_diagnostic', 'nvim_lsp', 'nvim_workspace_diagnostic' },
    symbols = { error = ' ', warn = '󰀨 ', info = ' ', hint = '󰠠 ' },
    diagnostics_color = {
      color_error = { fg = colors.red },
      color_warn = { fg = colors.yellow },
      color_info = { fg = colors.cyan or colors.sky },
    },
  })

  -- Guarded so a broken optional price module can never take down the whole
  -- statusline (the point of failure that made the status screen vanish).
  local asts_ok, asts_price = pcall(require, 'custom.utils.asts_price')
  if asts_ok then
    right_bubble(function() return { fg = colors.green, gui = 'bold' } end, '', {
      asts_price.get_price,
      cond = function() return asts_price.get_price() ~= '' end,
    })
  end

  return config
end

function M.refresh_statusline()
  colors = get_catppuccin_colors()

  local config = build_config()

  local ok, lualine = pcall(require, 'lualine')
  if ok then
    lualine.setup(config)
  else
    vim.notify('Failed to refresh statusline: lualine not available', vim.log.levels.WARN)
  end
end

function M.setup()
  local config = build_config()

  local ok, lualine = pcall(require, 'lualine')
  if not ok then
    vim.notify('Lualine not available, skipping statusline setup', vim.log.levels.WARN)
    return
  end

  lualine.setup(config)

  require('custom.utils.gh_pr_unresolved_comments').setup()

  require('custom.utils.gh_team_prs').setup()

  pcall(function() require('custom.utils.asts_price').setup() end)

  vim.api.nvim_create_autocmd('ColorScheme', {
    pattern = 'catppuccin*',
    callback = M.refresh_statusline,
    desc = 'Refresh statusline when Catppuccin theme changes',
  })
end

return M
