---
name: init-repo
description: Initialize a private GitHub repo with initial commit in current directory
---

Initialize a new private GitHub repository in the current directory with an initial commit:

1. Check if already a git repository:
   - If `.git` exists, warn the user and ask if they want to proceed (this will create a new GitHub remote)
   - If not, run `git init`

2. Get repository name:
   - If an argument is provided, use it as the repo name
   - Otherwise, use the current directory name

3. Create initial commit:
   - If there are no commits yet, stage all files and create an initial commit with message "Initial commit"
   - Skip common ignored patterns (.env, node_modules, etc.) if no .gitignore exists

4. Create private GitHub repository:
   - Use `gh repo create <repo-name> --private --source=. --push`
   - This creates the repo, adds the remote, and pushes in one command

5. Verify success:
   - Run `git remote -v` to confirm the remote was added
   - Show the GitHub repository URL to the user

Usage: /init-repo [repo-name]

If repo-name is not provided, the current directory name will be used.
