local git_utils = require('custom.utils.git')
local input_utils = require('custom.utils.input')
local file_utils = require('custom.utils.files')
local async_utils = require('custom.utils.async')
local util = require('custom.actions.git.util')

local M = {}

local function get_scope_suggestions(callback)
  async_utils.run('git log --oneline -100 --format=%s', function(stdout)
    local scopes = {}
    local scope_counts = {}

    for line in stdout:gmatch('[^\n]+') do
      local scope = line:match('%w+%(([^)]+)%)')
      if scope and scope ~= '' then scope_counts[scope] = (scope_counts[scope] or 0) + 1 end
    end

    for _, entry in ipairs(file_utils.scan(vim.fn.getcwd(), { type = 'directory', exclude = { node_modules = true } })) do
      if not scope_counts[entry.name] then scope_counts[entry.name] = 0 end
    end

    for scope, count in pairs(scope_counts) do
      table.insert(scopes, { scope = scope, count = count })
    end

    table.sort(scopes, function(a, b)
      if a.count ~= b.count then return a.count > b.count end
      return a.scope < b.scope
    end)

    callback(scopes)
  end, function() callback({}) end)
end

local function pick_scope(callback)
  get_scope_suggestions(function(suggestions)
    vim.schedule(function()
      if #suggestions == 0 then
        input_utils.get_input('Scope: ', callback)
        return
      end

      local ok, snacks = pcall(require, 'snacks')
      if not ok then
        input_utils.get_input('Scope: ', callback)
        return
      end

      local items = {
        {
          text = 'none',
          label = 'none (no scope)',
          scope = '',
          count = -1,
          idx = 1,
        },
      }
      for _, s in ipairs(suggestions) do
        local label = s.count > 0 and string.format('%s (%d commits)', s.scope, s.count) or s.scope .. ' (directory)'
        table.insert(items, {
          text = s.scope,
          label = label,
          scope = s.scope,
          count = s.count,
          idx = #items + 1,
        })
      end

      snacks.picker({
        title = 'Select Scope (or type custom)',
        items = items,
        format = function(item)
          if item.count == -1 then
            return {
              { 'none', 'Comment' },
              { '  ', 'Comment' },
              { 'no scope', 'Comment' },
            }
          end
          local source = item.count > 0 and string.format('%d commits', item.count) or 'directory'
          return {
            { item.scope, 'Function' },
            { '  ', 'Comment' },
            { source, 'Comment' },
          }
        end,
        confirm = function(picker, item)
          picker:close()
          if item then
            callback(item.scope)
          else
            callback(nil)
          end
        end,
      })
    end)
  end)
end

local function build_branch_name(prefix, callback)
  input_utils.get_input('Jira Ticket: ', function(jira_ticket)
    if jira_ticket then
      local summary = vim.fn.system(string.format("jira issue view %s --raw | jq -r '.fields.summary'", jira_ticket))
      summary = string.gsub(summary, '%s+', '-')
      summary = string.gsub(summary, '[^%w%-]', '')
      callback(string.format('%s/%s_%s', prefix, jira_ticket, summary), summary)
    else
      input_utils.get_input('Branch Description: ', function(branch_description)
        if not branch_description then return end
        local description_part = string.gsub(branch_description, '%s+', '-')
        callback(string.format('%s/%s', prefix, description_part), description_part)
      end)
    end
  end)
end

function M.create_branch(prefix)
  return function()
    build_branch_name(prefix, function(branch_name)
      vim.cmd(string.format('Git checkout -b %s', branch_name))
      vim.cmd("TermExec5 open=0 cmd='git add .'")
      vim.cmd(string.format('TermExec5 open=0 cmd=\'git commit --no-verify -m "%s"\'', util.shell_escape_message(branch_name)))
    end)
  end
end

function M.create_worktree(prefix)
  return function()
    build_branch_name(prefix, function(branch_name, description)
      local worktree_name = string.format('~/Programming/Worktrees/%s_%s', prefix, description)
      vim.cmd(string.format('Git worktree add -b %s %s', branch_name, worktree_name))
    end)
  end
end

local QUICK_UPDATE_MESSAGE = 'feat: update'

function M.create_commit(prefix, emoji, should_push, should_generic)
  return function()
    local branch_name = git_utils.get_current_branch()
    local jira_ticket = git_utils.extract_jira_ticket(branch_name)

    if should_generic then
      local commit_message = prefix .. ': update'
      vim.cmd(string.format('TermExec5 open=0 cmd=\'git commit --no-verify -m "%s"\'', util.shell_escape_message(commit_message)))
      if should_push then vim.cmd("TermExec3 open=0 cmd='git push'") end
      return
    end

    input_utils.get_input('Description: ', function(commit_description)
      if not commit_description then return end

      pick_scope(function(commit_scope)
        local jira_ticket_part = jira_ticket == '' and '' or jira_ticket .. ' '
        local commit_scope_part = (not commit_scope or commit_scope == '') and '' or '(' .. commit_scope .. ')'
        local emoji_part = emoji == '' and '' or ' ' .. emoji

        local commit_message = (prefix or '') .. commit_scope_part .. ':' .. emoji_part .. ' ' .. jira_ticket_part .. commit_description

        vim.cmd(string.format('TermExec5 open=0 cmd=\'git commit --no-verify -m "%s"\'', util.shell_escape_message(commit_message)))

        if should_push then vim.cmd("TermExec3 open=0 cmd='git push'") end
      end)
    end)
  end
end

function M.quick_commit_update() vim.cmd(string.format('Git commit --no-verify -m "%s"', QUICK_UPDATE_MESSAGE)) end

function M.create_commit_from_branch_name()
  local branch_name = git_utils.get_current_branch()
  if not branch_name or branch_name == '' or branch_name == 'main' or branch_name == 'master' then
    vim.notify('Cannot generate commit from current branch name')
    return
  end

  local branch_type = branch_name:match('^([^/]+)/')
  if branch_type == 'feature' then branch_type = 'feat' end

  local known_types =
    { feat = true, fix = true, chore = true, docs = true, style = true, refactor = true, perf = true, test = true, build = true, ci = true, revert = true }
  local prefix = known_types[branch_type] and branch_type or 'feat'

  local jira_ticket = git_utils.extract_jira_ticket(branch_name)
  local jira_ticket_part = jira_ticket == '' and '' or jira_ticket .. ' '

  local description = branch_name:gsub('^[^/]+/', '')
  if jira_ticket ~= '' then description = description:gsub('^' .. jira_ticket:gsub('%-', '%%-') .. '[_%-]?', '') end
  description = description:gsub('_', ' '):gsub('-', ' ')

  local commit_message = prefix .. ': ' .. jira_ticket_part .. description

  vim.cmd(string.format('Git commit --no-verify -m "%s"', util.shell_escape_message(commit_message)))

  vim.notify('Committed: ' .. commit_message)
end

return M
