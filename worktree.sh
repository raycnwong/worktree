#!/usr/bin/env bash
# ===========================================================================
# Git Worktree Script / Bash Function
# ===========================================================================

worktree() {
  local command="$1"
  local branch="$2"
  local base="$3"
  local repo_root

  # Ensure we are actually inside a git repository for local commands
  if [[ "$command" != "import" && "$command" != "i" ]]; then
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Not a git repository."
      return 1
    fi

    repo_root=$(git worktree list | head -n 1 | awk '{print $1}')
  fi

  # =========================================================================
  # Helper Functions
  # =========================================================================

  _wt_require_branch() {
    if [[ -z "$branch" ]]; then
      echo "Error: The '$command' command requires a branch name."
      echo "Example: worktree $command feature/my-branch"
      return 1
    fi
    return 0
  }

  _wt_bootstrap() {
    local target_branch="$1"
    local target_dir="$repo_root/$target_branch"
    local bootstrap_script="$repo_root/bootstrap.sh"

    if [[ -f "$bootstrap_script" ]]; then
      echo "🚀 Found bootstrap.sh in bare root! Executing..."
      # Execute the script in a subshell inside the new worktree directory
      # so it affects the new branch environment (e.g., npm install)
      (
        cd "$target_dir" || exit 1
        bash "$bootstrap_script" "$repo_root" "$target_branch"
      )
    fi
  }

  # =========================================================================
  # CLI Router
  # =========================================================================

  case "$command" in
  import | i)
    local url="$2"
    local folder="$3"

    if [[ -z "$url" ]]; then
      echo "Error: The 'import' command requires a repository URL."
      echo "Example: worktree i git@github.com:user/repo.git [folder]"
      return 1
    fi

    # Default folder to repo name if not provided
    if [[ -z "$folder" ]]; then
      folder="${url##*/}"     # Extract everything after the last /
      folder="${folder%.git}" # Remove .git extension if present
    fi

    if [[ -d "$folder" ]]; then
      echo "❌ Error: Directory '$folder' already exists."
      return 1
    fi

    echo "📥 Importing bare repository into '$folder/.git'..."
    git clone --bare "$url" "$folder/.git" || return 1

    echo "⚙️  Configuring bare repository..."
    cd "$folder" || return 1

    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch origin

    # Detect default branch from the cloned bare repo
    local default_branch
    default_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")

    echo "🌱 Creating default worktree for '$default_branch'..."
    git worktree add "$default_branch"

    # Create bootstrap.sh in the bare root
    echo "📜 Creating bootstrap.sh..."
    cat <<'EOF' >bootstrap.sh
#!/bin/bash

repo_root="$1"
branch="$2"

echo "Bootstrapping branch: $branch"
# Add your setup commands below (e.g., npm install)

EOF
    chmod +x bootstrap.sh

    echo "✅ Import complete!"
    ;;

  switch | s)
    local target_path

    if [[ -n "$branch" ]]; then
      if [[ -z "$target_path" && -d "$repo_root/$branch" ]]; then
        target_path="$repo_root/$branch"
      fi

      if [[ -z "$target_path" ]]; then
        echo "❌ Worktree for '$branch' not found."
        return 1
      fi
    else
      # No argument provided: Pipeline: List -> Filter bare repo -> fzf -> Extract path
      target_path=$(git worktree list |
        fzf --with-nth=2.. --height 40% --reverse --prompt="🌳 Navigate to: " --info=inline |
        awk '{print $1}')
    fi

    # If a selection/match was made, cd into it
    if [[ -n "$target_path" ]]; then
      cd "$target_path" || return 1
      echo "🚀 Navigated to worktree: $(git branch --show-current)"
    fi
    ;;

  add | a)
    _wt_require_branch || return 1

    # If the folder already exists, assume the worktree is already active and exit immediately.
    if [[ -d "$repo_root/$branch" ]]; then
      echo "⚡ Worktree '$branch' is already active at: $repo_root/$branch"
      return 0
    fi

    echo "Checking remote for latest branches..."
    git fetch origin --quiet 2>/dev/null || echo "⚠️  Could not reach remote (offline?). Proceeding with local cache..."

    # Check if the branch already exists locally OR on the remote origin
    if git show-ref --verify --quiet "refs/heads/$branch" || git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      echo "Creating worktree for $branch..."
      git worktree add "$repo_root/$branch" "$branch"
    else
      # Branch doesn't exist. We need to create it using the -b flag.
      if [[ -n "$base" ]]; then
        echo "🌱 Branch '$branch' not found. Creating new branch from '$base'..."
        git worktree add --no-track -b "$branch" "$repo_root/$branch" "$base"
      else
        # Try to read the exact default branch from Git's symbolic reference
        local default_base
        default_base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)

        # Fallback safety net (if offline AND origin/HEAD was never set)
        if [[ -z "$default_base" ]]; then
          if git show-ref --verify --quiet "refs/remotes/origin/main"; then
            default_base="origin/main"
          elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
            default_base="origin/master"
          else
            default_base="HEAD"
          fi
        fi

        echo "🌱 Branch '$branch' not found. Creating new branch from '$default_base'..."
        git worktree add --no-track -b "$branch" "$repo_root/$branch" "$default_base"
      fi
    fi

    if [[ -d "$repo_root/$branch" ]]; then
      _wt_bootstrap "$branch"
      echo "✅ Worktree '$branch' created."
    else
      echo "❌ Failed to create worktree."
      return 1
    fi
    ;;

  remove | rm)
    _wt_require_branch || return 1

    local target_dir="$repo_root/$branch"

    # 🛡️ SAFETY CHECK: Move out of the directory if we are currently inside it
    if [[ "$PWD" == "$target_dir" || "$PWD" == "$target_dir"/* ]]; then
      echo "🔙 Moving out of '$branch' to repo root before deletion..."
      cd "$repo_root" || return 1
    fi

    if [[ -d "$repo_root/$branch" ]]; then
      echo "Removing worktree directory: $branch..."
      if ! git worktree remove "$repo_root/$branch" 2>/dev/null; then
        echo "⚠️  Warning: Worktree '$branch' contains uncommitted changes or untracked files."

        local confirm_force
        printf "Are you sure you want to FORCE delete it? Uncommitted code will be lost! (y/N): "
        read -r confirm_force

        if [[ "$confirm_force" == [Yy]* ]]; then
          echo "Force removing..."
          git worktree remove "$repo_root/$branch" --force
        else
          echo "❌ Removal aborted. Your files have been preserved."
          return 0
        fi
      fi
    else
      echo "Worktree directory not found. Pruning dead references..."
      git worktree prune
    fi

    local delete_branch
    printf "Would you like to delete the local branch '%s' as well? (y/N): " "$branch"
    read -r delete_branch
    if [[ "$delete_branch" == [Yy]* ]]; then
      git branch -D "$branch"
      echo "Branch deleted."
    fi

    echo "Cleanup complete!"
    ;;

  list | ls)
    git worktree list | sed -n 's/.*\[\(.*\)\]/\1/p'
    ;;

  *)
    echo "Usage: worktree <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  import, i <url> [folder]  - Clone a bare repo into <folder>/.git and configure worktrees"
    echo "  switch, s [branch]        - Navigate to [branch] directly, or use fzf to select if omitted"
    echo "  add, a <branch> [base]    - Create a worktree (optionally from [base]) and bootstrap"
    echo "  remove, rm <branch>       - Remove a worktree and optionally delete the local branch"
    echo "  list, ls                  - List all active worktree branches"
    return 1
    ;;
  esac
}
