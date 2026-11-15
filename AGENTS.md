# Repository workflow

- Use `/home/anson/Projects/forstimpy` as the single local working repository and `yassine-game/project.godot` as its Godot project.
- Use ordinary Git branches in this folder. Do not create another clone, worktree or version folder unless the user explicitly requests one.
- Fetch before starting new work. Preserve authorized changes with commits and create a checkpoint tag before major changes.
- Continue from the latest accepted feature version when building on existing features. `main` currently lacks the chess additions. Ask if the required starting version is uncertain; do not silently substitute one.
- Implement, test, commit locally, and push the requested feature branch. Do not push changes to or merge into `main` without explicit instruction.
- Keep the branch's complete playable game available through normal Godot F5 launch.
- Put first-party chess code and related assets in `yassine-game/features/chess/`; keep third-party plugins in `addons/`.
- Keep generated builds/evidence in ignored `builds/`, and preserved local legacy material in ignored `archive/`, outside the Godot project.
- Preserve user edits. Flag conflicting or ambiguous changes rather than silently choosing a version.
- Maintain the root README as the entry point for launch, layout and version instructions. Keep feature documentation with its feature.
