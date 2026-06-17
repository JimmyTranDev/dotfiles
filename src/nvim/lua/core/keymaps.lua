local file_actions = require('custom.actions.files')
local todoist_actions = require('custom.actions.todoist')
local jira_actions = require('custom.actions.jira')
local link_actions = require('custom.actions.links')
local language_actions = require('custom.actions.language')
local errors_actions = require('custom.actions.errors')
local git_actions = require('custom.actions.git')
local github_actions = require('custom.actions.github')
local editor_actions = require('custom.actions.editor')
local project_actions = require('custom.actions.project')
local journal_actions = require('custom.actions.journal')
local notes_actions = require('custom.actions.notes')
local status_actions = require('custom.actions.status')
local session = require('custom.utils.session')
local env_check = require('custom.utils.env_check')
local stock_prompt = require('custom.utils.stock_prompt')

session.setup_autosave()
vim.defer_fn(env_check.check_env_vars, 2000)
stock_prompt.setup()

local function map(mode, lhs, rhs, opts)
  opts = vim.tbl_extend('force', { silent = true, noremap = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

local function maps(mode, mappings)
  for _, m in ipairs(mappings) do
    map(mode, m[1], m[2], { desc = m[3] })
  end
end

maps('n', {
  { '<C-h>', '<C-W><C-H>', '󰖲 Move to left window' },
  { '<C-j>', '<C-W><C-J>', '󰖲 Move to bottom window' },
  { '<C-k>', '<C-W><C-K>', '󰖲 Move to top window' },
  { '<C-l>', '<C-W><C-L>', '󰖲 Move to right window' },
  { ']', ':cnext<CR>', '󰮯 Next quickfix item' },
  { '[', ':cprev<CR>', '󰮲 Previous quickfix item' },
})

map('', '<S-J>', '<C-D>', { desc = '󰙲 Scroll down half page' })
map('', '<S-K>', '<C-U>', { desc = '󰙳 Scroll up half page' })
map('n', 'gJ', 'J', { desc = '󰗈 Join lines' })
map('n', 'gK', 'K', { desc = '󰋼 Keyword lookup' })

maps('n', {
  -- { '<leader><leader>nh', ':vsplit<CR>', '󰖲 Split window vertically (left)' },
  -- { '<leader><leader>nj', ':split<CR><C-W>j', '󰖲 Split window horizontally (below)' },
  -- { '<leader><leader>nk', ':split<CR>', '󰖲 Split window horizontally (above)' },
  -- { '<leader><leader>nl', ':vsplit<CR><C-W>l', '󰖲 Split window vertically (right)' },
  -- { '<leader><leader>nn', ':split<CR>', '󰖲 Split window horizontally' },
  -- { '<leader><leader>nv', ':vsplit<CR>', '󰖲 Split window vertically' },
  -- { '<leader><leader>nc', '<C-W>c', '󰅗 Close current window' },
  -- { '<leader><leader>no', '<C-W>o', '󰅗 Close all other windows' },
  -- { '<A-=>', '<C-W>=', '󰖲 Equalize window sizes' },
  -- { '<A-Up>', '<C-W>+', '󰖲 Increase window height' },
  -- { '<A-Down>', '<C-W>-', '󰖲 Decrease window height' },
  -- { '<A-Right>', '<C-W>>', '󰖲 Increase window width' },
  -- { '<A-Left>', '<C-W><', '󰖲 Decrease window width' },
})

map('n', '<leader>;df', language_actions.fix_and_organize_typescript_imports, { desc = '󰉼 Fix and organize imports (TS)' })
map('n', '<leader>;dm', language_actions.serve_markdown_folder, { desc = '󰌠 Markserve' })
map('n', '<leader>;ds', ':4TermExec cmd="live-server --port=9090"<CR>', { desc = '󰌐 Live Server' })
map('n', '<leader>;dM', language_actions.compile_mjml_file, { desc = '󰈮 Compile Mjml Html' })

-- map('n', '<leader>;fc', file_actions.save_clipboard_to_file, { desc = 'Save clipboard to file' })
-- map('n', '<leader>;fM', file_actions.convert_md_to_pdf, { desc = 'Convert markdown to PDF' })
map('n', '<leader>;fs', editor_actions.toggle_spellcheck, { desc = '󰓆 Toggle spellcheck' })
-- map('n', '<leader>;fC', ':!rm -r ' .. constants.NEOVIM_STATE_DIR .. '<CR>', { desc = '󰆑 Clear swap files' })
-- map('n', '<leader>;fw', ':SudaWrite<CR>', { desc = '󰌾 Sudo write' })
map('n', '<leader>;fm', editor_actions.toggle_markview, { desc = '󰙈 Toggle Markview' })
map('n', '<leader>;fw', editor_actions.toggle_wrap, { desc = '󰌪 Toggle text wrap' })
map('n', '<leader>;fr', ':e!<CR>', { desc = '󰔁 Reload file from disk' })
map('n', '<leader>;r', editor_actions.switch_repo_by_zellij_tab, { desc = '󰖲 Switch repo + rename Zellij tab' })
map('n', '<leader>fa', file_actions.grep_current_file_dir, { desc = '󰊄 Grep in current file dir' })

map('x', '<leader>;Tr', [["zy:%s/\V<C-r>=escape(@z, '/')<CR>//gc<left><left><left>]], { desc = '󰕈 Visual search replace' })

map('n', '<leader>vx', language_actions.run_knip_fix_current_folder, { desc = '󰒡 Knip fix current folder' })
map('n', '<leader>vX', language_actions.run_knip_fix, { desc = '󰒡 Knip fix & remove files (global)' })
map('n', '<leader>ve', language_actions.run_eslint_picker, { desc = '󰒡 ESLint analysis picker' })
map('n', '<leader>vK', language_actions.run_knip_unused_files, { desc = '󰒡 Knip unused files' })
map('n', '<leader>vk', language_actions.run_knip_unused_code, { desc = '󰒡 Knip unused code' })
map('n', '<leader>vd', github_actions.redeploy_pr, { desc = '󰚴 Redeploy PR (#deploy + clean bot comments)' })
map('n', '<leader>vc', language_actions.run_test_coverage, { desc = '󰊕 Run test coverage' })

map('n', '<leader>;ct', todoist_actions.refresh_todoist_cache(), { desc = '󰆘 Refresh Todoist cache' })
map('n', '<leader>;cw', jira_actions.refresh_jira_cache, { desc = '󰆘 Refresh Jira cache' })

map('n', '<leader>;J', jira_actions.generate_done_md, { desc = '󰌧 Generate this week jira tasks' })

-- <leader>c — Copy & Quick Access
maps('n', {
  { '<leader>cj', jira_actions.copy_ticket_with_title, '󰆓 Copy: Jira ticket + title' },
  { '<leader>ct', jira_actions.copy_testable_message, '󰆓 Copy: Jira testable message' },
  { '<leader>cp', github_actions.copy_open_prs, '󰆓 Copy: open PRs' },
  { '<leader>cP', github_actions.select_and_copy_pr, '󰆓 Copy: select PR' },
  { '<leader>cl', github_actions.copy_github_line_url, '󰆓 Copy: GitHub line URL' },
  { '<leader>ca', file_actions.copy_all_files_content, '󰆓 Copy: all files content' },
  { '<leader>cf', file_actions.copy_frontend_project_paths, '󰆓 Copy: frontend project paths' },
  { '<leader>cr', file_actions.copy_repo_path, '󰆓 Copy: repo path' },
  { '<leader>cR', project_actions.copy_project_path, '󰆓 Copy: project path (pick)' },
  { '<leader>cs', git_actions.stash_pull_rebase, '󰓦 Git: stash + pull --rebase + pop' },
  { '<leader>cu', file_actions.copy_current_file_url, '󰆓 Copy: current file URL' },
  { '<leader>co', file_actions.copy_opencode_link, '󰆓 Copy: OpenCode link' },
  { '<leader>cc', file_actions.copy_ai_file_reference, '󰆓 Copy: AI file reference (line)' },
  { '<leader>ce', errors_actions.copy_diagnostic_under_cursor, '󰆓 Copy: diagnostic' },
})
map('v', '<leader>cl', github_actions.copy_github_line_url, { desc = '󰆓 Copy: GitHub line URL' })
map('x', '<leader>cc', file_actions.copy_ai_file_reference_range, { desc = '󰆓 Copy: AI file reference (range)' })

-- map('n', '<leader><leader>ri', replacement_actions.replace_interactive, { desc = 'Interactive replace' })
-- map('n', '<leader><leader>rb', replacement_actions.replace_buffer, { desc = 'Replace in buffer' })
-- map('n', '<leader><leader>rB', replacement_actions.replace_buffer_all, { desc = 'Replace all in buffer' })
-- map('n', '<leader><leader>rp', replacement_actions.replace_buffer_prefilled, { desc = 'Replace in buffer (prefilled)' })
-- map('n', '<leader><leader>rP', replacement_actions.replace_buffer_all_prefilled, { desc = 'Replace all in buffer (prefilled)' })
-- map('v', '<leader><leader>rs', replacement_actions.replace_buffer_selected, { desc = 'Replace selected in buffer' })
-- map('v', '<leader><leader>rS', replacement_actions.replace_buffer_all_selected, { desc = 'Replace all selected in buffer' })
-- map('n', '<leader><leader>rq', replacement_actions.replace_quickfix, { desc = 'Replace in quickfix' })
-- map('n', '<leader><leader>rQ', replacement_actions.replace_quickfix_all, { desc = 'Replace all in quickfix' })
-- map('n', '<leader><leader>rf', replacement_actions.replace_project, { desc = 'Replace in project' })
-- map('n', '<leader><leader>rF', replacement_actions.replace_project_all, { desc = 'Replace all in project' })

map('n', '<Leader>i', '<C-i>', { desc = '󰮯 Jump forward' })
map('n', '<Leader>o', '<C-o>', { desc = '󰮲 Jump backward' })

map('n', '<Leader>q', ':q<CR>', { desc = '󰩈 Quit' })
map('n', '<Leader>Q', ':qa!<CR>', { desc = '󰩈 Force quit all' })
map('n', '<Leader>w', ':w<CR>', { desc = '󰆓 Write' })
map('n', '<Leader>W', ':wa<CR>', { desc = '󰆓 Write all' })

map('n', '<Leader>rt', todoist_actions.log_todoist_task_all_projects(), { desc = '󰌱 Log todoist task' })
map('n', '<Leader>rT', todoist_actions.edit_recent_task, { desc = '󰌱 Edit recent Todoist task' })
map('n', '<Leader>rD', todoist_actions.delete_recent_task, { desc = '󰌱 Delete recent Todoist task' })
map('n', '<Leader>rw', jira_actions.create_jira_task(), { desc = '󰌱 Create Jira task' })
map('n', '<Leader>rW', jira_actions.create_jira_task_with_link(), { desc = '󰌱 Create Jira task + open link' })
map('n', '<Leader>rj', journal_actions.add_journal_entry, { desc = '󰌱 Add journal entry' })
map('n', '<Leader>rJ', journal_actions.open_journal, { desc = '󰌱 Open journal' })
map('n', '<Leader>rr', notes_actions.quick_note, { desc = ' Quick note' })
map('n', '<Leader>rp', notes_actions.add_notes_entry, { desc = '󰌱 Add notes entry' })
map('n', '<Leader>rn', notes_actions.add_sentence, { desc = '󰌱 Add sentence to notes' })
map('n', '<Leader>rN', notes_actions.save_task, { desc = '󰌱 Save task to notes' })
map('n', '<Leader>rc', jira_actions.add_comment_from_branch, { desc = '󰌱 Add Jira comment from branch' })

maps('n', {
  { '<leader>zc', ':Lazy clean<CR>', '󰒲 Lazy clean' },
  { '<leader>zh', ':Lazy health<CR>', '󰒲 Lazy health' },
  { '<leader>zp', ':Lazy profile<CR>', '󰒲 Lazy profile' },
  { '<leader>zr', ':Lazy restore<CR>', '󰒲 Lazy restore' },
  { '<leader>zu', ':Lazy update<CR>', '󰒲 Lazy update' },
  { '<leader>zz', ':Lazy<CR>', '󰒲 Open Lazy' },
})

-- map('n', '<Leader><Leader>tt', ':Typr<CR>', { desc = 'Start typing test' })
-- map('n', '<Leader><Leader>ts', ':TyprStats<CR>', { desc = 'Show typing stats' })

map('n', '<Leader>ud', file_actions.open_current_dir, { desc = '󰦥 Open current directory' })

map('n', '<Leader>ua', function()
  -- Run both interactive gcloud auth flows inside a toggleterm and force the
  -- OAuth consent pages to open in Google Chrome (BROWSER is honoured by
  -- gcloud's underlying Python webbrowser module; %s is substituted with the
  -- URL).
  require('custom.utils.terminal_registry').get_or_create('gcloud-auth', {
    cmd = 'export BROWSER=\'open -a "Google Chrome" %s\'; ' .. 'gcloud auth login && gcloud auth application-default login',
    direction = 'horizontal',
  })
end, { desc = '󰊭 GCloud auth (Chrome)' })

-- GitHub sub-group (<leader>ug)
map('n', '<Leader>ugc', github_actions.open_current_commit_in_github, { desc = '󰦥 GitHub: current commit' })
map('n', '<Leader>ugp', git_actions.open_or_create_pull_request, { desc = '󰦥 GitHub: open/create PR' })
map('n', '<Leader>ugP', git_actions.copy_pr_link, { desc = '󰦥 GitHub: copy PR link' })
map('n', '<Leader>ugr', link_actions.open_current_github_repo, { desc = '󰦥 GitHub: repo page' })
map('n', '<Leader>uga', link_actions.open_current_github_prs, { desc = '󰦥 GitHub: all PRs' })
map('n', '<Leader>ugh', github_actions.open_current_repo_in_browser, { desc = '󰦥 GitHub: repo homepage' })
map('n', '<Leader>ugo', github_actions.list_org_repos_and_open, { desc = '󰦥 GitHub: org repos' })
map('n', '<Leader>ugN', github_actions.show_notifications, { desc = '󰦥 GitHub: comment/mention notifications' })
map('n', '<Leader>ugn', github_actions.show_notifications_by_default_team, { desc = '󰦥 GitHub: team comment/mention notifications' })
map('n', '<Leader>ugb', github_actions.show_notifications_by_team, { desc = '󰦥 GitHub: team notifications (select)' })
map('n', '<Leader>ugw', github_actions.select_open_prs_by_default_team, { desc = '󰦥 GitHub: team + my PRs' })
map('n', '<Leader>ugW', github_actions.select_open_prs_by_people, { desc = '󰦥 GitHub: team + my PRs (select)' })
map('n', '<Leader>ugf', github_actions.open_file_from_clipboard_url, { desc = '󰦥 Open file from clipboard URL' })
map('n', '<Leader>ugi', github_actions.show_current_branch_pr_diff, { desc = '󰦥 GitHub: PR diff (current branch)' })

-- Jira sub-group (<leader>uj)
map('n', '<Leader>ujj', link_actions.open_jira_ticket, { desc = '󰦥 Jira: open ticket from branch' })
map('n', '<Leader>ujJ', jira_actions.browse_my_tasks, { desc = '󰦥 Jira: browse my tasks' })
map('n', '<Leader>ujt', jira_actions.browse_recently_updated_tasks, { desc = '󰦥 Jira: recently updated tasks' })

-- Links sub-group (<leader>ul)
map('n', '<Leader>ull', link_actions.open_useful_link, { desc = '󰦥 Links: useful links' })
map('n', '<Leader>ulL', link_actions.open_private_useful_link, { desc = '󰦥 Links: private links' })
map('n', '<Leader>ult', link_actions.open_technical_link_current_repo, { desc = '󰦥 Links: technical (repo)' })
map('n', '<Leader>ulT', link_actions.open_technical_link, { desc = '󰦥 Links: technical (select)' })

-- Search
map('n', '<Leader>us', link_actions.search_google, { desc = '󰦥 Search: Google' })
map('v', '<Leader>us', link_actions.search_google, { desc = '󰦥 Search: Google (selection)' })

map('n', '<leader>sc', status_actions.show_ci_checks, { desc = '󱖫 CI Checks' })
map('n', '<leader>sp', status_actions.show_pr_status, { desc = '󱖫 PR Status' })
map('n', '<leader>so', status_actions.show_pipeline_overview, { desc = '󱖫 Pipeline Overview' })

-- map('n', '<Leader>ugn', link_actions.open_npm_url, { desc = 'Open NPM link' })
-- map('n', '<Leader>ugw', github_actions.select_open_prs_by_people, { desc = 'Open PRs by people' })
-- map('n', '<Leader>ugI', github_actions.select_org_repo_and_create_issue, { desc = 'Create GitHub issue' })
-- map('n', '<Leader>ugR', github_actions.pr_review_mode, { desc = 'PR review mode' })
-- map('n', '<Leader>ugM', git_actions.diff_vs_main, { desc = 'Diff vs main' })
-- map('n', '<Leader>ugD', git_actions.diff_vs_develop, { desc = 'Diff vs develop' })
-- map('n', '<Leader>ugB', branch_actions.stale_branch_cleanup(), { desc = 'Stale branch cleanup' })

map('n', '<leader>fW', project_actions.switch_project, { desc = 'Switch project' })
map('n', '<leader>;cp', file_actions.clear_plan_files, { desc = 'Clear plan files' })

-- map('n', '<leader><leader>Ss', session.save, { desc = 'Save session' })
-- map('n', '<leader><leader>Sr', session.restore, { desc = 'Restore session' })
-- map('n', '<leader><leader>Sd', session.delete, { desc = 'Delete session' })
-- map('n', '<leader><leader>Sl', session.list_sessions, { desc = 'List sessions' })

-- map('n', '<leader><leader>xb', buffer_actions.smart_close, { desc = 'Smart buffer close' })
-- map('n', '<leader><leader>xo', buffer_actions.close_orphan_splits, { desc = 'Close orphan splits' })
-- map('n', '<leader><leader>xh', health_actions.workspace_health, { desc = 'Workspace health check' })
-- map('n', '<leader>ugG', git_dashboard_actions.git_dashboard, { desc = 'Git status dashboard' })
-- map('n', '<leader><leader>xE', env_check.show_env_status, { desc = 'Env var health check' })

-- map('n', '<leader>tds', docker_actions.start_db, { desc = 'Docker Postgres start' })
-- map('n', '<leader>tdx', docker_actions.stop_db, { desc = 'Docker Postgres stop' })
-- map('n', '<leader>tdi', docker_actions.status, { desc = 'Docker Postgres status' })
-- map('n', '<leader>tdX', docker_actions.cleanup_all, { desc = 'Docker Postgres cleanup all' })
