# forstimpy

One local repository contains the complete game and its Git versions. The permanent working folder on this device is `/home/anson/Projects/forstimpy`.

## Open and play

Open `yassine-game/project.godot` in Godot and press **F5**. On `fist-colour-selection`, the normal game launch includes the original title, character invitation, fist colour choice, yyslChess and the inventory. No alternate project or test scene is needed.

On first entering chess, choose one of the two closed fists. The selected hand opens to reveal a White or Black queen, assigning your colour. The board starts automatically after the brief reveal. Back saves the current match in memory; entering chess again resumes the same board, colour and inventory. After any result, **new game** starts fresh fists and preserves the finished game in **match history · this session**. New game is also available at the table after leaving a finished match. Closing the application clears the active game and session archive.

Captured pieces appear beside the capturing side: your collection stays near your end of the board and the character's stays near theirs. These use the existing replaceable piece textures. Collections stay with the saved match, show the correct historical pieces during replay, and revert when an earned takeback returns pieces to the board.

The inventory's **← / →** arrows review every recorded individual move; **live** returns to the current board. Match-history entries show the local finishing time, winner/loser or draw, and ending. Select one to replay it; **my game** restores an unfinished current match. Desktop shows the list beside the board; portrait uses the **match history** button.

For a finished game, **review on Chess.com** copies its complete PGN and opens Chess.com's analysis page. Paste into its PGN field and choose Load. The dialog also provides manual copy and a Lichess import link. Analysis happens on the selected website, with its account/access rules; the game does not grade moves locally or upload automatically.

On the table scene, hover over the letter beside the dap interaction to open it and hear the existing paper-crumple clip. Click the exposed note to read the original birthday note. Back or Escape returns to the same table. The letter stays open while moving between its envelope and note, and closes when the cursor leaves.

Select the character's hand to dap. Each press independently draws bad/mid/mid2/goat at 20%/35%/35%/10% and shows a matching random comment. Repeated presses immediately replace the reaction and restart its two-second window. Audio uses one voice; inputs arriving in the same engine frame start only the latest selected clip. See `yassine-game/features/dap/README.md` for audio replacement and testing.

```bash
godot --editor --path yassine-game
# Or launch the complete game directly:
godot --path yassine-game
```

## Organization

| Location | Purpose |
| --- | --- |
| `yassine-game/` | The only active Godot project |
| `yassine-game/features/chess/` | Chess rules, bot, scene, inventory, related artwork and tests |
| `yassine-game/features/letter/` | Table letter interaction, audio, full-note reader and canonical note text |
| `yassine-game/features/dap/` | Weighted dap outcomes, replaceable audio, feedback timing and tests |
| `yassine-game/scenes/`, `scripts/`, `assets/` | Shared game scenes, scripts and assets |
| `yassine-game/addons/` | Third-party plugins |
| `builds/` | Generated exports and verification evidence; ignored by Git |
| `archive/` | Preserved local legacy projects/exports; ignored by Git, outside the Godot project |

The chess demo and tests are developer tools inside this project. They are not additional game versions. Feature documentation and verification results are in `yassine-game/features/chess/README.md` and `integration/TEST_REPORT.md`.

## Versions

| Git reference | Version |
| --- | --- |
| `main` | Original published game; merges require the user's explicit instruction |
| `chess-character-implementation` | Chess with fixed difficulty, before inventory |
| `undo-user-inventory` | Saved game with inventory and consolidated organization |
| `fist-colour-selection` | Current game with fists, letter, weighted daps, resumable chess, captures, replay, session history and PGN review |
| `checkpoint-before-inventory` | Saved commit immediately before inventory work |
| `checkpoint-before-organization` | Saved inventory commit before this reorganization |
| `checkpoint-before-fist-selection` | Saved consolidated inventory game before fist selection |
| `checkpoint-before-letter-interaction` | Saved fist-selection game before the interactive table letter |
| `checkpoint-before-dap-interaction` | Saved letter-enabled game before weighted dap/audio work |
| `checkpoint-before-chess-resume` | Saved dap-enabled game before session-only chess resume |
| `checkpoint-before-captured-pieces` | Saved resumable chess before captured-piece displays |
| `checkpoint-before-match-history` | Saved captured-piece game before full replay, archive and review work |
| `checkpoint-recovered-match-history` | Local development checkpoint preserving replay/history work after the device crash |

Branches and checkpoint tags preserve versions in Git. Switching branches updates the same local folder; older versions retain their historical internal layout. Save and commit work, close Godot, switch the branch, then reopen the same `project.godot`.

Before a large change: fetch updates, commit the current authorized work, tag a tested checkpoint, and create a feature branch from the agreed starting version. Build on the latest accepted chess branch for continuing chess work; `main` does not contain these additions yet. Implement and test locally, then commit and push the feature branch. Do not create another clone or worktree for routine feature work. Do not merge into `main` without explicit instruction.

```bash
git fetch origin
git switch fist-colour-selection
```

## Web build

Matching Godot export templates are required. Export into an empty directory under `builds/`:

```bash
python yassine-game/features/chess/integration/build_web.py builds/web
python -m http.server 8765 --bind 127.0.0.1 --directory builds/web
```

The helper exports the configured game entry point through a temporary import copy, then removes that temporary copy. It refuses a nonempty output directory or a destination inside the Godot project. For another build, choose a new empty directory under `builds/` or remove an obsolete generated build first.

## Letter content and settings

The original root `birthday note` file now lives at `yassine-game/features/letter/content/birthday_note.txt`, with its contents unchanged. This is the single editable note asset, and the Web preset includes it explicitly. See `yassine-game/features/letter/README.md` for artwork/audio replacement, verification and current local evidence.

## Local archives

The consolidation preserved the unique older dialogue prototype and its original web export in `archive/legacy-web-project.zip`. Old checked-in web bundles and source backups are in `archive/legacy-export-and-source-backups.zip`; their original bytes also remain in Git history. Alternate generated import IDs from the retired worktree are in `archive/retired-inventory-worktree-local-edits.zip`. These local archives are not uploaded to GitHub. Each ZIP was checked against its source files before the originals were retired.
