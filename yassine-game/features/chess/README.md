# yyslChess — character chess activity

Optional offline chess against `yyslChess`, integrated with the existing character, title screen and camera pan. The bot's identity is set by `display_name` in `chess_behavior.tres`. This first-party feature lives in `features/chess/`, with its scenes, assets and tests grouped together. See the repository's root README for the single-project workflow and version checkpoints.

## Run

From the Git repository root, with Godot 4.7.2 (the version used for verification):

```bash
godot --headless --editor --path yassine-game --import
godot --path yassine-game
```

For an isolated character harness:

```bash
godot --path yassine-game res://features/chess/demo/ChessCharacterTest.tscn
```

Open `yassine-game/project.godot` and press F5 to launch the complete game. The configured entry scene is `integration/ChessIntegratedMain.tscn`, which reuses the original title and game flow and selects the chess-enabled character stage. The isolated harness above is a developer tool.

Accept either invitation response ("sure" or "yes but red") to play, or use the board hotspot. The character asks **"choose a fist."** Both fists start closed, with one White queen and one Black queen assigned randomly to opposite hands before input. Selecting either hand opens only that hand and shows its queen. The result is locked immediately; after 1.2 seconds the board starts in that colour. White moves first, so yyslChess makes the opening move when you draw Black. The colour shuffle has its own RNG and does not affect opening variation or AI strength.

Manual White/Black buttons and Restart have been removed. Back saves the current match in memory and restores the table; entering chess again resumes that same match. Colour, board orientation, rule state, inventory history, previews, promotion choices and RPS commitments are preserved. Leaving during the fist reveal pauses its remaining time. Interrupted bot work is cancelled and restarted once on return, with its opening RNG state preserved. Hidden chess rejects input and cannot advance the board. Finished and resigned games also remain saved. This is session-only: closing the application or reloading the browser starts a fresh session. There is no new Restart control.

During play, select a piece and then a highlighted destination. Promotion offers Queen, Rook, Bishop or Knight. Escape first closes an open challenge or preview; otherwise it suspends the match and restores the invitation. One hidden activity instance is retained by the table adapter; no save file, additional project or global manager is used.

## Inventory

The bottom inventory contains three placeholder buttons, with named nodes in `ChessActivity.tscn` for later design work:

- **undo** toggles a read-only view of the position before the latest individual move, highlighting its origin and destination and naming it in the dialogue bubble. Press it again or Escape to return to live play. It never changes the match. A pending bot reply can finish while reviewing; the preview stays on the selected move.
- **takeback** opens rock–paper–scissors against yyslChess during an active match. Win one decisive round to restore the start of your previous turn, removing your last move and the character's reply if it has arrived. Ties replay. A win or loss consumes that committed player move's challenge; you must make another chess move before trying again. A loss leaves the position unchanged. Cancelling before a decisive result keeps the attempt available. Older takebacks cannot be chained after a win.
- **resign** concedes the match to the character immediately. This replaces the former player-facing Claim draw control.

The character commits an independently randomized RPS hand before each choice. Chess input is blocked while the challenge is open, and any pending bot reply is cancelled; closing an unresolved or lost challenge resumes that turn. A successful takeback restores pieces, castling rights, en passant, move counters, repetition history, last-move highlights and the opening RNG state. Replaying the same move therefore preserves the book reply. Only the three most recent before-move snapshots are retained, sufficient for these actions. A fresh match clears inventory history and challenge eligibility.

No inventory currency, disk persistence or final artwork is introduced. Inventory state stays with the resumable match. The controls reuse the current theme and stay below or beside the board according to available space.

## Captured pieces

The capturing side keeps each captured opponent piece in capture order. White taking a Black knight puts that Black knight in White's collection. `PlayerCaptures` stays near the player's end of the board, and `CharacterCaptures` stays near the character's end, so their colour ownership follows the chosen orientation. Desktop uses two trays beside the board; portrait uses strips above and below it. Compact windows reduce the header/board layout to keep the trays and inventory separate.

`captured_pieces.gd` draws the existing theme's piece textures inside simple placeholder trays, without creating an icon node for each capture. Replace piece artwork through `chess_visual_theme.tres`; change the named tray nodes/script for later table art. Both trays are hidden during fist selection. Each side can collect at most the opponent's 15 non-king pieces, including promoted pieces at their captured identity.

The activity records captures only after a successful committed move, through one shared human/bot path. It handles en passant, capture-promotion and later captures of promoted pieces. Quiet promotion and castling do not create captures. Capture lists remain outside the rules/search position, avoiding extra history copies during AI search. Three bounded inventory snapshots include copies of both lists for previews and takebacks. Back/resume retains the complete collections even when their original captures have fallen out of the three-snapshot window.

## Browser export

Export templates matching the installed Godot version are required. This helper copies source into a temporary project, imports resources, exports the configured game entry scene, and uses the single-threaded Web preset. The temporary project is removed afterward. It refuses a nonempty output directory or a destination inside `yassine-game`. Use `--scene` only to export a test scene.

```bash
python yassine-game/features/chess/integration/build_web.py builds/web
python -m http.server 8765 --bind 127.0.0.1 --directory builds/web
```

Open `http://127.0.0.1:8765/` in a browser with WebGL 2. The export needs no chess server, external API or engine executable. No service worker/offline installation is added; “offline” means gameplay has no network dependency after local assets load. The helper resolves source UIDs and defers custom-cursor loading until after import in the temporary copy so a fresh export does not depend on an existing editor cache.

## Artwork and behavior

Edit `chess_visual_theme.tres` in the inspector to replace any of its 12 named White/Black piece textures, square colors, highlights, panel background or ink color. Transparent PNG, WebP and SVG textures are supported by Godot. Pieces retain their aspect ratio within each square. The included SVG silhouettes are original placeholders and have no external font dependency.

The activity follows `assets/storyboard/scene 2 seated.png`: a three-part top strip, character dialogue bubble, large central chessboard, sealed envelope and back arrow. Desktop uses the horizontal composition; portrait stacks the strip's controls and keeps a readable board below the dialogue. The envelope, memory images and time/music illustration are decorative placeholders.

All scene artwork is configured in the same visual theme, under **Scene artwork**:

| Theme slot | Artwork |
| --- | --- |
| `top_strip` | Top strip background and separators |
| `time_music` | Clock/music illustration |
| `portrait_idle`, `portrait_thinking` | Character expressions |
| `memories` | Photo/video-area illustration |
| `dialogue_bubble` | Speech bubble background |
| `board_frame` | Board surround |
| `sealed_envelope` | Envelope and seal |
| `back_arrow` | Navigation arrow |

The supplied SVGs live in `assets/ui/`. Replace a slot's texture in the theme and rerun the scene; no chess code changes are needed. Portraits, memories, envelope and arrow preserve aspect ratio. The strip and board frame use nine-patch borders (14 px and 12 px respectively); the dialogue background stretches to its layout area. Choose matching margins when replacing frame artwork.

The **Fist choice artwork** group adds four independent slots: `left_fist_closed`, `right_fist_closed`, `left_fist_opened`, `right_fist_opened`. Their SVG placeholders are 240×240 with transparent backgrounds. Replacement open-hand art should leave the palm around the same location; the separate `Hand/Queen` TextureRect in `FistChoice.tscn` places the queen within normalized bounds `(0.32, 0.45)`–`(0.68, 0.81)`. Adjust those anchors for a different palm position. White/Black queens reuse the existing piece texture slots, so the four hand images do not need colour variants. `fist_choice.gd` handles the committed assignment and image swap; the activity owns the reveal delay and match startup.

The **Typography** group exposes `interface_font`. The activity uses a local copy of that font for sharp text in the existing project's stretched viewport. Edit `idle_dialogue` and `thinking_dialogue` on the `ChessActivity` root to personalize the bubble's text. `ChessActivity.tscn` contains the named controls and artwork nodes; responsive placement lives in `chess_activity.gd`.

`chess_behavior.tres` contains one session-independent preset: `book_full_moves = 6`, `search_depth = 3`, a 4 ms work-slice target and a 0.25 s presentation delay. Search completes its selected depth with alpha-beta pruning and stable capture/positional move ordering. It has no wall-clock strength cutoff, shuffled candidate order or random evaluation noise. Longer searches yield across frames; they do not reduce difficulty. Session tokens cancel stale work when starting a match or leaving. No worker thread is required.

Opening variation is restricted to the small, legal position book in `chess_opening_book.gd`. White plays Scotch/Center Game lines; Black plays Caro-Kann/Slav-related lines. Book lookup stops after six full moves (12 plies). Unsupported replies automatically use the fixed search; recognized transpositions can return to the book before the cutoff. From move seven, search always applies. See `data/OPENINGS.md` for the nine reference lines, move-order aliases, sources and coverage limits. Original PGN counts remain provenance only; there is no White d4 sideline in this repertoire.

The **950–1200 Chess.com rating target is uncalibrated**. Three-ply search is a repeatable difficulty policy, not a measured rating. Think time can vary with position and device. The 4 ms yield interval is a scheduling target: a synchronous legality-generation call is indivisible. Search evaluates mate/stalemate at the horizon, common insufficient material and claimable 50-move draws; future repetitions are not predicted, while the activity still enforces repetition draws in the actual match.

The bot exposes per-search measurements (`last_source`, `last_completed_depth`, `last_nodes`, `last_cutoffs`, `last_search_ms`, `last_cpu_ms`, `last_max_slice_ms`). Search time includes frame waits but excludes the cosmetic delay; `last_total_ms` includes it. These are diagnostics and do not change difficulty.

Draw handling includes stalemate, common insufficient-material positions, automatic fivefold repetition/75-move draws, and the bot claiming threefold repetition/50-move draws on its turn. The inventory's resign button replaces the human draw-claim action; it concedes rather than claiming a draw. Advance draw claims based on a proposed next move are not implemented. This MVP does not implement a general solver for every possible dead position, clocks, PGN export, networking or matchmaking.

## Verification

```bash
godot --headless --path yassine-game --script res://features/chess/tests/test_chess_rules.gd
godot --headless --path yassine-game --script res://features/chess/tests/test_fist_choice.gd
godot --path yassine-game --resolution 1280x720 --script res://features/chess/tests/test_integration.gd
godot --path yassine-game --resolution 1280x720 --script res://features/chess/tests/test_inventory.gd
godot --path yassine-game --resolution 1280x720 --script res://features/chess/tests/test_resume.gd
godot --path yassine-game --resolution 1280x720 --script res://features/chess/tests/test_captured_pieces.gd
```

The latter two commands need a graphical display. The inventory suite includes viewport bounds checks; Godot's headless display reports 64×64 on this device, so use the rendered command above. It exercises RPS wins/losses/ties, one-attempt limits, read-only review, restoration of special moves and complete match state, pending reply cancellation, Black orientation and resignation. Browser regression uses actual canvas mouse/keyboard input and screenshot checks:

```bash
# Install these in an external test environment, outside the game project:
# npm install playwright-core pngjs
# Set NODE_PATH if those packages are not otherwise discoverable.
node yassine-game/features/chess/tests/browser_smoke.cjs http://127.0.0.1:8765 /tmp/chess-browser-evidence
```

Set `CHROMIUM_PATH` if Chromium is not `/usr/bin/chromium`. See `integration/TEST_REPORT.md` for actual results, evidence locations and limitations. Test tooling is not a runtime dependency.

Additional bot/repertoire verification:

```bash
godot --headless --path yassine-game --script res://features/chess/tests/test_chess_bot.gd
```

The same suite can be exported as a single-threaded release scene with `build_web.py OUTPUT --scene res://features/chess/tests/BotBrowserChecks.tscn`. Serve that directory, then run `tests/browser_bot.cjs URL` with the existing Playwright test dependencies. This checks the real GDScript implementation, not a separately reimplemented engine.
