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
local process_actions = require('custom.actions.process')
local status_actions = require('custom.actions.status')
local worktree_actions = require('custom.actions.worktree')
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

-- ============================================================================
-- Window & Navigation
-- ============================================================================
maps('n', {
  { '<C-h>', '<C-W><C-H>', '󰖲 Move to left window' },
  { '<C-j>', '<C-W><C-J>', '󰖲 Move to bottom window' },
  { '<C-k>', '<C-W><C-K>', '󰖲 Move to top window' },
  { '<C-l>', '<C-W><C-L>', '󰖲 Move to right window' },
  { ']', ':cnext<CR>', '󰮯 Next quickfix item' },
  { '[', ':cprev<CR>', '󰮲 Previous quickfix item' },
})

-- ============================================================================
-- Movement & Scrolling
-- ============================================================================
map('', '<S-J>', '<C-D>', { desc = '󰙲 Scroll down half page' })
map('', '<S-K>', '<C-U>', { desc = '󰙳 Scroll up half page' })
map('n', 'gJ', 'J', { desc = '󰗈 Join lines' })
map('n', 'gK', 'K', { desc = '󰋼 Keyword lookup' })

map('n', '<Leader>i', '<C-i>', { desc = '󰮯 Jump forward' })
map('n', '<Leader>o', '<C-o>', { desc = '󰮲 Jump backward' })

-- Disable macro recording
map('n', 'q', '<Nop>', { desc = '󰜺 Macro recording disabled' })
map('x', 'q', '<Nop>', { desc = '󰜺 Macro recording disabled' })

-- ============================================================================
-- Quit & Write
-- ============================================================================
maps('n', {
  { '<Leader>q', ':q<CR>', '󰩈 Quit' },
  { '<Leader>Q', ':qa!<CR>', '󰩈 Force quit all' },
  { '<Leader>w', ':w<CR>', '󰆓 Write' },
  { '<Leader>W', ':wa<CR>', '󰆓 Write all' },
})

-- ============================================================================
-- Dev Tools (<leader>;)
-- ============================================================================
maps('n', {
  { '<leader>;i', language_actions.fix_and_organize_typescript_imports, '󰉼 Fix and organize imports (TS)' },
  { '<leader>;k', process_actions.kill_port, '󰓛 Kill process on port' },
  { '<leader>;m', language_actions.serve_markdown_folder, '󰌠 Markserve' },
  { '<leader>;s', ':4TermExec cmd="live-server --port=9090"<CR>', '󰌐 Live Server' },
  { '<leader>;M', language_actions.compile_mjml_file, '󰈮 Compile Mjml Html' },
})

-- ============================================================================
-- File & Editor
-- ============================================================================
maps('n', {
  { '<leader>;S', editor_actions.toggle_spellcheck, '󰓆 Toggle spellcheck' },
  { '<leader>;v', editor_actions.toggle_markview, '󰙈 Toggle Markview' },
  { '<leader>;w', editor_actions.toggle_wrap, '󰌪 Toggle text wrap' },
  { '<leader>;z', editor_actions.toggle_maximize, '󰊓 Toggle maximize window' },
  { '<leader>;R', ':e!<CR>', '󰔁 Reload file from disk' },
  { '<leader>j', ':e!<CR>', '󰔁 Refresh current file' },
  { '<leader>fsa', file_actions.grep_current_file_dir, '󰊄 Grep in current file dir' },
  { '<leader>fR', editor_actions.switch_repo_by_zellij_tab, '󰖲 Switch repo + rename Zellij tab' },
  { '<leader>fW', project_actions.switch_project, '󰉋 Switch project' },
})

map('x', '<leader>;T', [["zy:%s/\V<C-r>=escape(@z, '/')<CR>//gc<left><left><left>]], { desc = '󰕈 Visual search replace' })

-- ============================================================================
-- Code Quality & Verification (<leader>v)
-- ============================================================================
maps('n', {
  { '<leader>vx', language_actions.run_knip_fix_current_folder, '󰒡 Knip fix current folder' },
  { '<leader>vX', language_actions.run_knip_fix, '󰒡 Knip fix & remove files (global)' },
  { '<leader>ve', language_actions.run_eslint_picker, '󰒡 ESLint analysis picker' },
  { '<leader>vK', language_actions.run_knip_unused_files, '󰒡 Knip unused files' },
  { '<leader>vk', language_actions.run_knip_unused_code, '󰒡 Knip unused code' },
  { '<leader>vd', github_actions.redeploy_pr, '󰚴 Redeploy PR (#deploy + clean bot comments)' },
  { '<leader>vc', language_actions.run_test_coverage, '󰊕 Run test coverage' },
  { '<leader>vp', file_actions.clear_plan_files, '󰃢 Clear plan files' },
})

-- ============================================================================
-- Caches & Jira Reports (<leader>rc, <leader>;J)
-- ============================================================================
maps('n', {
  { '<leader>rct', todoist_actions.refresh_todoist_cache(), '󰆘 Refresh Todoist cache' },
  { '<leader>rcw', jira_actions.refresh_jira_cache, '󰆘 Refresh Jira cache' },
  { '<leader>;J', jira_actions.generate_done_md, '󰌧 Generate this week jira tasks' },
})

-- ============================================================================
-- Copy & Quick Access (<leader>c)
-- ============================================================================

-- Jira sub-group (<leader>cj/ct)
maps('n', {
  { '<leader>cj', jira_actions.copy_ticket_with_title, '󰆓 Jira ticket + title' },
  { '<leader>ct', jira_actions.copy_testable_message, '󰆓 Jira testable message' },
})

-- GitHub sub-group (<leader>cp/cP/cl)
maps('n', {
  { '<leader>cp', github_actions.copy_open_prs, '󰆓 Open PRs' },
  { '<leader>cP', github_actions.select_and_copy_pr, '󰆓 Select PR' },
  { '<leader>cl', github_actions.copy_github_line_url, '󰆓 GitHub line URL' },
})

-- Paths sub-group (<leader>ca/cf/cr/cR/cg)
maps('n', {
  { '<leader>ca', file_actions.copy_all_files_content, '󰆓 All files content' },
  { '<leader>cf', file_actions.copy_frontend_project_paths, '󰆓 Frontend project paths' },
  { '<leader>cr', file_actions.copy_repo_path, '󰆓 Repo path' },
  { '<leader>cR', project_actions.copy_project_path, '󰆓 Project path (pick)' },
  { '<leader>cg', project_actions.pull_and_copy_project_path, '󰆓 Pull repo + copy path' },
})

-- File reference sub-group (<leader>cu/co/cc/cm)
maps('n', {
  { '<leader>cu', file_actions.copy_current_file_url, '󰆓 Current file URL' },
  { '<leader>co', file_actions.copy_opencode_link, '󰆓 OpenCode link' },
  { '<leader>cc', file_actions.copy_ai_file_reference, '󰆓 AI file reference (line)' },
  { '<leader>cm', file_actions.copy_as_markdown_code_block, '󰆓 Markdown code block (buffer)' },
})

-- Diagnostics sub-group (<leader>ce)
maps('n', {
  { '<leader>ce', errors_actions.copy_diagnostic_under_cursor, '󰆓 Diagnostic' },
})

-- Git sub-group (<leader>cs/cd)
maps('n', {
  { '<leader>cs', git_actions.stash_pull_rebase, '󰓦 Stash + pull --rebase + pop' },
  { '<leader>cd', git_actions.copy_diff_link, '󰆓 Diff link (branch vs base)' },
})

-- Visual mode copy
map('v', '<leader>cl', github_actions.copy_github_line_url, { desc = '󰆓 GitHub line URL' })
map('x', '<leader>cc', file_actions.copy_ai_file_reference_range, { desc = '󰆓 AI file reference (range)' })
map('x', '<leader>cm', file_actions.copy_as_markdown_code_block_range, { desc = '󰆓 Markdown code block (selection)' })

-- ============================================================================
-- Capture & Log (<leader>r)
-- ============================================================================

-- Todoist sub-group (<leader>rt)
maps('n', {
  { '<Leader>rtt', todoist_actions.log_todoist_task_all_projects(), '󰐕 Log task' },
  { '<Leader>rte', todoist_actions.edit_recent_task, '󰏫 Edit recent task' },
  { '<Leader>rtd', todoist_actions.delete_recent_task, '󰆴 Delete recent task' },
})

-- Jira sub-group (<leader>rj)
maps('n', {
  { '<Leader>rjj', jira_actions.create_jira_task(), '󰐕 Create task' },
  { '<Leader>rjJ', jira_actions.create_jira_task_with_link(), '󰐕 Create task + open link' },
  { '<Leader>rjm', jira_actions.add_comment_from_branch, '󰊢 Comment from branch' },
})

-- Journal/Log sub-group (<leader>rl)
maps('n', {
  { '<Leader>rll', journal_actions.add_journal_entry, '󰠮 Add entry' },
  { '<Leader>rlo', journal_actions.open_journal, '󰈙 Open journal' },
})

-- Categorized notes sub-group (<leader>rN)
maps('n', {
  { '<Leader>rnn', notes_actions.add_categorized_note, '󰠮 Add note (continuous)' },
  { '<Leader>rnh', notes_actions.add_categorized_heading, '󰉫 Add heading' },
})

-- ============================================================================
-- Open & Utilities (<leader>u)
-- ============================================================================

-- Directory & auth
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
maps('n', {
  { '<Leader>ugc', github_actions.open_current_commit_in_github, '󰜘 Current commit' },
  { '<Leader>ugl', git_actions.show_commits_current_folder, '󰜘 Commits affecting current folder' },
  { '<Leader>ugp', git_actions.open_or_create_pull_request, '󰓢 Open/create PR' },
  { '<Leader>ugP', git_actions.copy_pr_link, '󰆏 Copy PR link' },
  -- { '<Leader>ugr', link_actions.open_current_github_repo, 'Repo page' },
  { '<Leader>uga', github_actions.open_my_authored_prs, '󰓢 PRs authored by me' },
  { '<Leader>ugh', github_actions.open_current_repo_in_browser, '󰖟 Repo homepage' },
  { '<Leader>ugo', github_actions.list_org_repos_and_open, '󰊤 Org repos' },
  { '<Leader>ugC', github_actions.select_owner_repo_and_clone, '󰊢 Clone repo' },
  { '<Leader>ugi', github_actions.create_owner_repo_and_clone, '󰐕 Create + clone repo' },
  { '<Leader>ugn', github_actions.show_notifications_by_default_team, '󰂚 Team comment/mention notifications' },
  -- { '<Leader>ugN', github_actions.show_notifications, 'Comment/mention notifications' },
  { '<Leader>ugN', github_actions.show_notifications_by_team, '󰂚 Team notifications (select)' },
  { '<Leader>ugt', github_actions.select_open_prs_by_default_team, '󰓢 Team + my PRs' },
  { '<Leader>ugT', github_actions.select_open_prs_by_people, '󰓢 Team + my PRs (select)' },
  -- { '<Leader>ugo', github_actions.open_file_from_clipboard_url, 'Open file from clipboard URL' },
  -- { '<Leader>ugd', github_actions.show_current_branch_pr_diff, 'PR diff (current branch)' },
})

-- Worktree sub-group (<leader>uw)
maps('n', {
  { '<Leader>uwr', worktree_actions.rename_current_worktree, '󰑕 Rename worktree (folder+branch+remote)' },
})

-- Jira sub-group (<leader>uj)
maps('n', {
  { '<Leader>ujj', link_actions.open_jira_ticket, '󰌧 Open ticket from branch' },
  { '<Leader>ujJ', jira_actions.browse_my_tasks, '󰌧 Browse my tasks' },
  { '<Leader>ujt', jira_actions.browse_recently_updated_tasks, '󰥔 Recently updated tasks' },
})

-- Links sub-group (<leader>ul)
maps('n', {
  { '<Leader>ull', link_actions.open_useful_link, '󰌧 Useful links' },
  { '<Leader>ulL', link_actions.open_private_useful_link, '󰌾 Private links' },
  { '<Leader>ult', link_actions.open_technical_link_current_repo, '󰖟 Technical (repo)' },
  { '<Leader>ulT', link_actions.open_technical_link, '󰖟 Technical (select)' },
  { '<Leader>ulf', link_actions.open_fms_link, '󰖟 FMS admin (project)' },
})

-- Search sub-group (<leader>us)
map('n', '<Leader>us', link_actions.search_google, { desc = '󰊭 Google' })
map('v', '<Leader>us', link_actions.search_google, { desc = '󰊭 Google (selection)' })

-- ============================================================================
-- Status (<leader>s)
-- ============================================================================
maps('n', {
  { '<leader>sc', status_actions.show_ci_checks, '󱖫 CI Checks' },
  { '<leader>sp', status_actions.show_pr_status, '󱖫 PR Status' },
  { '<leader>so', status_actions.show_pipeline_overview, '󱖫 Pipeline Overview' },
})

-- ============================================================================
-- Lazy (<leader>z)
-- ============================================================================
maps('n', {
  { '<leader>zc', ':Lazy clean<CR>', '󰒲 Lazy clean' },
  { '<leader>zh', ':Lazy health<CR>', '󰒲 Lazy health' },
  { '<leader>zp', ':Lazy profile<CR>', '󰒲 Lazy profile' },
  { '<leader>zr', ':Lazy restore<CR>', '󰒲 Lazy restore' },
  { '<leader>zu', ':Lazy update<CR>', '󰒲 Lazy update' },
  { '<leader>zz', ':Lazy<CR>', '󰒲 Open Lazy' },
})

-- ============================================================================
-- Disabled / Future Mappings
-- ============================================================================

-- Window splits
-- map('n', '<leader><leader>nh', ':vsplit<CR>', { desc = '󰖲 Split window vertically (left)' })
-- map('n', '<leader><leader>nj', ':split<CR><C-W>j', { desc = '󰖲 Split window horizontally (below)' })
-- map('n', '<leader><leader>nk', ':split<CR>', { desc = '󰖲 Split window horizontally (above)' })
-- map('n', '<leader><leader>nl', ':vsplit<CR><C-W>l', { desc = '󰖲 Split window vertically (right)' })
-- map('n', '<leader><leader>nn', ':split<CR>', { desc = '󰖲 Split window horizontally' })
-- map('n', '<leader><leader>nv', ':vsplit<CR>', { desc = '󰖲 Split window vertically' })
-- map('n', '<leader><leader>nc', '<C-W>c', { desc = '󰅗 Close current window' })
-- map('n', '<leader><leader>no', '<C-W>o', { desc = '󰅗 Close all other windows' })
-- map('n', '<A-=>', '<C-W>=', { desc = '󰖲 Equalize window sizes' })
-- map('n', '<A-Up>', '<C-W>+', { desc = '󰖲 Increase window height' })
-- map('n', '<A-Down>', '<C-W>-', { desc = '󰖲 Decrease window height' })
-- map('n', '<A-Right>', '<C-W>>', { desc = '󰖲 Increase window width' })
-- map('n', '<A-Left>', '<C-W><', { desc = '󰖲 Decrease window width' })

-- File & editor
-- map('n', '<leader>;fc', file_actions.save_clipboard_to_file, { desc = 'Save clipboard to file' })
-- map('n', '<leader>;fM', file_actions.convert_md_to_pdf, { desc = 'Convert markdown to PDF' })
-- map('n', '<leader>;fC', ':!rm -r ' .. constants.NEOVIM_STATE_DIR .. '<CR>', { desc = '󰆑 Clear swap files' })
-- map('n', '<leader>;fw', ':SudaWrite<CR>', { desc = '󰌾 Sudo write' })

-- Typing test
-- map('n', '<Leader><Leader>tt', ':Typr<CR>', { desc = 'Start typing test' })
-- map('n', '<Leader><Leader>ts', ':TyprStats<CR>', { desc = 'Show typing stats' })

-- GitHub & git extras
-- map('n', '<Leader>ugn', link_actions.open_npm_url, { desc = 'Open NPM link' })
-- map('n', '<Leader>ugw', github_actions.select_open_prs_by_people, { desc = 'Open PRs by people' })
-- map('n', '<Leader>ugI', github_actions.select_org_repo_and_create_issue, { desc = 'Create GitHub issue' })
-- map('n', '<Leader>ugR', github_actions.pr_review_mode, { desc = 'PR review mode' })
-- map('n', '<Leader>ugM', function() git_actions.diff_vs('main') end, { desc = 'Diff vs main' })
-- map('n', '<Leader>ugD', function() git_actions.diff_vs('develop') end, { desc = 'Diff vs develop' })
-- map('n', '<Leader>ugB', branch_actions.stale_branch_cleanup(), { desc = 'Stale branch cleanup' })

-- Sessions
-- map('n', '<leader><leader>Ss', session.save, { desc = 'Save session' })
-- map('n', '<leader><leader>Sr', session.restore, { desc = 'Restore session' })
-- map('n', '<leader><leader>Sd', session.delete, { desc = 'Delete session' })
-- map('n', '<leader><leader>Sl', session.list_sessions, { desc = 'List sessions' })

-- Buffers & health
-- map('n', '<leader><leader>xb', buffer_actions.smart_close, { desc = 'Smart buffer close' })
-- map('n', '<leader><leader>xo', buffer_actions.close_orphan_splits, { desc = 'Close orphan splits' })
-- map('n', '<leader><leader>xh', health_actions.workspace_health, { desc = 'Workspace health check' })
-- map('n', '<leader>ugG', git_dashboard_actions.git_dashboard, { desc = 'Git status dashboard' })
-- map('n', '<leader><leader>xE', env_check.show_env_status, { desc = 'Env var health check' })

-- Docker
-- map('n', '<leader>tds', docker_actions.start_db, { desc = 'Docker Postgres start' })
-- map('n', '<leader>tdx', docker_actions.stop_db, { desc = 'Docker Postgres stop' })
-- map('n', '<leader>tdi', docker_actions.status, { desc = 'Docker Postgres status' })
-- map('n', '<leader>tdX', docker_actions.cleanup_all, { desc = 'Docker Postgres cleanup all' })
