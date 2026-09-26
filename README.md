# Worktree

> Effortless Git worktree management for your terminal.

**Worktree** is a lightweight shell script to simplify Git worktree workflow. It provides a simple, intuitive CLI to clone bare repositories, quickly switch contexts using `fzf`, and easily bootstrap or clean up worktree branches.

## ✨ Features

* **📦 Import:** Clone a bare repository and instantly configure your worktree structure.
* **🔄 Switch:** Instantly jump between branches, or use interactive fuzzy-finding (`fzf`) to select one.
* **🌱 Add:** Create new worktrees (optionally from a base branch) with automated bootstrapping.
* **🧹 Remove:** Safely delete a worktree and optionally clean up the associated local branch in one command.
* **📋 List:** Quickly view all of your active worktree branches.

## 🚀 Installation

### For Oh My Zsh

1. Clone this repository into your custom plugins folder:

```bash
git clone https://github.com/raycnwong/worktree.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/worktree
```

2. Enable `worktree` plugin using the Oh My Zsh CLI:

```zsh
omz plugin enable worktree
```

3. Restart your terminal or reload your config:

```bash
source ~/.zshrc
```

## 🛠️ Usage

```text
Usage: worktree  [arguments]

Commands:
  import, i <url> [folder]  - Clone a bare repo into <folder>/.git and configure worktrees
  switch, s [branch]        - Navigate to [branch] directly, or use fzf to select if omitted
  add, a <branch> [base]    - Create a worktree (optionally from [base]) and bootstrap
  remove, rm <branch>       - Remove a worktree and optionally delete the local branch
  list, ls                  - List all active worktree branches
```
