# forstimpy — chess before inventory

Use the permanent repository at `/home/anson/Projects/forstimpy`. Open `yassine-game/project.godot` in Godot and press **F5**, or run `godot --path yassine-game`. The complete game includes the title, invitation and yyslChess with its six-move opening book and fixed-strength search. This version predates the inventory.

All versions use this same local folder. Commit work and close Godot before switching branches, then reopen the same project:

- `main`: original game; merge only when explicitly requested.
- `chess-character-implementation`: this pre-inventory chess version.
- `undo-user-inventory`: current inventory version with the consolidated `features/chess/` layout.
- `checkpoint-before-inventory` and `checkpoint-before-organization`: preserved milestone commits.

This older branch retains its historical `addons/slowbrainn_chess/` feature layout and existing source exports. That folder is part of the complete game, not another project. See its README for feature details. New exports belong in ignored `builds/`, and preserved local legacy material is in ignored `archive/`, outside the Godot project.

For new work, fetch updates, save the current authorized work, checkpoint before major changes, create a feature branch from the agreed version, implement and test, then commit and push the branch. Routine development uses one local repository, without extra clones or worktrees. Continuing inventory work should start from `undo-user-inventory`.
