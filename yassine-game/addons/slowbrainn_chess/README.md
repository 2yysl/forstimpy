# yyslChess — character chess activity

Optional offline chess against `yyslChess`, integrated with the existing character, title screen and camera pan. The bot's identity is set by `display_name` in `chess_behavior.tres`. The existing add-on directory remains `slowbrainn_chess` for resource-path compatibility. All source additions live in this add-on. Existing files on `main` remain unchanged.

## Run

From the Git repository root, with Godot 4.7.2 (the version used for verification):

```bash
godot --headless --editor --path yassine-game --import
godot --path yassine-game res://addons/slowbrainn_chess/integration/ChessIntegratedMain.tscn
```

For an isolated character harness:

```bash
godot --path yassine-game res://addons/slowbrainn_chess/demo/ChessCharacterTest.tscn
```

The original project's default entry scene is unchanged. Use the explicit alternate scene above, or open it in the Godot editor and press F6.

Accept either invitation response ("sure" or "yes but red") to play, or use the board hotspot. Select a piece and then a highlighted destination. Promotion offers Queen, Rook, Bishop or Knight. White/Black in the top strip starts a new match in the selected color. Restart resets the current color. The back arrow or Escape returns to the character and restores the invitation.

## Browser export

Export templates matching the installed Godot version are required. This helper copies source into a temporary project, imports resources, changes only that copy's main scene, and uses the existing single-threaded Web preset. The temporary project is removed afterward. It refuses a nonempty output directory or a destination inside the repository.

```bash
python yassine-game/addons/slowbrainn_chess/integration/build_web.py /tmp/forstimpy-chess-review
python -m http.server 8765 --bind 127.0.0.1 --directory /tmp/forstimpy-chess-review
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

The **Typography** group exposes `interface_font`. The activity uses a local copy of that font for sharp text in the existing project's stretched viewport. Edit `idle_dialogue` and `thinking_dialogue` on the `ChessActivity` root to personalize the bubble's text. `ChessActivity.tscn` contains the named controls and artwork nodes; responsive placement lives in `chess_activity.gd`.

`chess_behavior.tres` controls evaluation noise, the search time budget (650 ms), frame work budget (4 ms) and a short thinking delay. Search yields between root candidates and during evaluation. A move-generation call is indivisible, so these are scheduling budgets rather than hard real-time guarantees. Session tokens cancel stale work on restart and exit. There is no worker-thread requirement.

The bot uses a legal, exact-position opening book and a two-ply material/position search after deviations. White initially weights e4:d4 as 22:1. Matching Black opening positions favor c6 followed by d5. Preferences are based on the handoff's summarized counts, not independently verified PGNs. The **950–1200 Chess.com rating target is uncalibrated**; no measured-strength claim is made.

Draw handling includes stalemate, common insufficient-material positions, claimable threefold repetition/50-move draws, and automatic fivefold repetition/75-move draws. Claims are offered once the current position qualifies; advance claims based on a proposed next move are not implemented. This MVP does not implement a general solver for every possible dead position, clocks, resignation, PGN export, networking or matchmaking.

## Verification

```bash
godot --headless --path yassine-game --script res://addons/slowbrainn_chess/tests/test_chess_rules.gd
godot --path yassine-game --resolution 1280x720 --script res://addons/slowbrainn_chess/tests/test_integration.gd
```

The second command needs a graphical display. Browser regression uses actual canvas mouse/keyboard input and screenshot checks:

```bash
# Install these in an external test environment, outside the game project:
# npm install playwright-core pngjs
# Set NODE_PATH if those packages are not otherwise discoverable.
node yassine-game/addons/slowbrainn_chess/tests/browser_smoke.cjs http://127.0.0.1:8765 /tmp/chess-browser-evidence
```

Set `CHROMIUM_PATH` if Chromium is not `/usr/bin/chromium`. See `integration/TEST_REPORT.md` for actual results, evidence locations and limitations. Test tooling is not a runtime dependency.
