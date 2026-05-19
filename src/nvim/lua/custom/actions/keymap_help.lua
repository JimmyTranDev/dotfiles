local M = {}

local function get_buf_keymaps(buf, mode)
  local buf_maps = vim.api.nvim_buf_get_keymap(buf, mode)
  local global_maps = vim.api.nvim_get_keymap(mode)

  local results = {}

  for _, m in ipairs(buf_maps) do
    if m.desc and m.desc ~= '' and m.desc ~= '_' then
      table.insert(results, {
        lhs = m.lhs,
        desc = m.desc,
        source = 'buffer',
        mode = mode,
      })
    end
  end

  for _, m in ipairs(global_maps) do
    if m.desc and m.desc ~= '' and m.desc ~= '_' then
      table.insert(results, {
        lhs = m.lhs,
        desc = m.desc,
        source = 'global',
        mode = mode,
      })
    end
  end

  return results
end

local function get_context_info()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  local has_lsp = #vim.lsp.get_clients({ bufnr = buf }) > 0
  local is_git = vim.fn.finddir('.git', vim.fn.expand('%:p:h') .. ';') ~= ''

  return {
    filetype = ft,
    has_lsp = has_lsp,
    is_git = is_git,
  }
end

local function categorize_keymaps(keymaps, context)
  local categories = {
    { name = 'LSP & Diagnostics', pattern = { 'lsp', 'diagnostic', 'hover', 'definition', 'reference', 'rename', 'code action', 'format' }, items = {} },
    { name = 'Git', pattern = { 'git', 'hunk', 'blame', 'diff', 'commit', 'push', 'pull', 'branch', 'stash', 'pr' }, items = {} },
    { name = 'Navigation', pattern = { 'jump', 'goto', 'find', 'search', 'buffer', 'window', 'split', 'tab', 'next', 'prev' }, items = {} },
    { name = 'Editing', pattern = { 'comment', 'surround', 'indent', 'fold', 'sort', 'replace', 'delete', 'yank', 'paste', 'wrap' }, items = {} },
    { name = 'Tools', pattern = { 'terminal', 'lazy', 'mason', 'todoist', 'jira', 'knip', 'eslint', 'copilot' }, items = {} },
    { name = 'Other', pattern = {}, items = {} },
  }

  for _, km in ipairs(keymaps) do
    local desc_lower = km.desc:lower()
    local placed = false

    for _, cat in ipairs(categories) do
      if cat.name ~= 'Other' then
        for _, pat in ipairs(cat.pattern) do
          if desc_lower:find(pat, 1, true) then
            table.insert(cat.items, km)
            placed = true
            break
          end
        end
      end
      if placed then break end
    end

    if not placed then table.insert(categories[#categories].items, km) end
  end

  local filtered = {}
  for _, cat in ipairs(categories) do
    if cat.name == 'LSP & Diagnostics' and not context.has_lsp then goto continue end
    if #cat.items > 0 then
      table.sort(cat.items, function(a, b)
        if a.source ~= b.source then return a.source == 'buffer' end
        return a.lhs < b.lhs
      end)
      table.insert(filtered, cat)
    end
    ::continue::
  end

  return filtered
end

function M.contextual_help()
  local snacks_ok, snacks = pcall(require, 'snacks')
  if not snacks_ok then return end

  local context = get_context_info()
  local buf = vim.api.nvim_get_current_buf()
  local all_keymaps = {}

  for _, mode in ipairs({ 'n', 'x' }) do
    local maps = get_buf_keymaps(buf, mode)
    for _, m in ipairs(maps) do
      table.insert(all_keymaps, m)
    end
  end

  local seen = {}
  local unique = {}
  for _, km in ipairs(all_keymaps) do
    local key = km.mode .. '|' .. km.lhs
    if not seen[key] then
      seen[key] = true
      table.insert(unique, km)
    end
  end

  local categories = categorize_keymaps(unique, context)

  local items = {}
  for _, cat in ipairs(categories) do
    table.insert(items, {
      text = '── ' .. cat.name .. ' ──',
      is_header = true,
    })
    for _, km in ipairs(cat.items) do
      local mode_tag = km.mode ~= 'n' and (' [' .. km.mode .. ']') or ''
      local source_tag = km.source == 'buffer' and ' *' or ''
      table.insert(items, {
        text = string.format('  %-28s %s%s%s', km.lhs, km.desc, mode_tag, source_tag),
        keymap = km,
      })
    end
  end

  local title_parts = { context.filetype ~= '' and context.filetype or 'no filetype' }
  if context.has_lsp then table.insert(title_parts, 'LSP') end
  if context.is_git then table.insert(title_parts, 'Git') end

  snacks.picker({
    title = 'Keymaps: ' .. table.concat(title_parts, ' | '),
    items = items,
    format = function(item)
      if item.is_header then return { { item.text, 'Title' } } end
      local hl = 'Normal'
      if item.keymap and item.keymap.source == 'buffer' then hl = 'DiagnosticOk' end
      return { { item.text, hl } }
    end,
    confirm = function(picker, item)
      if item.keymap then
        picker:close()
        vim.notify(item.keymap.lhs .. ' → ' .. item.keymap.desc, vim.log.levels.INFO)
      end
    end,
  })
end

return M
