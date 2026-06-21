local github_utils = require('custom.utils.github')

local M = {}

function M.select_org_repo_and_create_issue()
  local valid_orgs = github_utils.get_github_owners()

  if #valid_orgs == 0 then
    vim.notify('No GitHub organizations configured in environment', vim.log.levels.ERROR)
    return
  end

  vim.ui.select(valid_orgs, {
    prompt = 'Select organization:',
  }, function(selected_org)
    if not selected_org then return end

    vim.system(
      { 'gh', 'repo', 'list', selected_org, '--limit', '30', '--json', 'name,url' },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          vim.notify('Failed to fetch repositories for ' .. selected_org, vim.log.levels.ERROR)
          return
        end

        local ok, repos = pcall(vim.json.decode, result.stdout)
        if not ok or type(repos) ~= 'table' or #repos == 0 then
          vim.notify('No repositories found for ' .. selected_org, vim.log.levels.ERROR)
          return
        end

        local repo_names = {}
        for _, repo in ipairs(repos) do
          table.insert(repo_names, repo.name)
        end

        vim.ui.select(repo_names, {
          prompt = 'Select repository:',
        }, function(selected_repo)
          if not selected_repo then return end

          vim.ui.input({
            prompt = 'Issue title: ',
          }, function(title)
            if not title or title == '' then return end

            vim.system(
              { 'gh', 'issue', 'create', '--repo', selected_org .. '/' .. selected_repo, '--title', title, '--web' },
              { text = true },
              vim.schedule_wrap(function(issue_result)
                if issue_result.code == 0 then
                  vim.notify('Issue creation opened in browser', vim.log.levels.INFO)
                else
                  vim.notify('Failed to create issue: ' .. (issue_result.stderr or issue_result.stdout), vim.log.levels.ERROR)
                end
              end)
            )
          end)
        end)
      end)
    )
  end)
end

return M
