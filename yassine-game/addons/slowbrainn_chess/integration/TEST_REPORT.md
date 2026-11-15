# Chess character implementation — verification report

Verified November 14, 2026, America/Toronto, against `https://github.com/2yysl/forstimpy`.

## November 15 bot identity update

Renamed the bot to `yyslChess` in the displayed opponent name, draw messages, runtime node name and personality metadata. `chess_behavior.tres` now exposes `display_name` as the shared identity setting. Existing resource paths retain the `slowbrainn_chess` directory for compatibility. Rendered integration: **35/35 checks passed**, exit 0. Search and opening behavior were unchanged by this rename.

## November 15 seated storyboard layout

Rearranged `ChessActivity` to follow `assets/storyboard/scene 2 seated.png`: a three-part top strip, character dialogue bubble, large central board, sealed envelope and a working back arrow. Color/restart/draw controls occupy the strip; promotion choices appear over the board. The original title and table invitation remain unchanged, including the removal of “Not now” recorded below.

Added nine original SVG placeholders in `assets/ui/`, exposed as named texture slots in `chess_visual_theme.tres`. The font is also replaceable in that resource; idle/thinking dialogue text is editable on the activity root. New UI elements are named nodes in `ChessActivity.tscn`. The envelope, memory images and time/music graphic are decorative art.

- Baseline before rearrangement: **31/31** rendered integration checks passed.
- After rearrangement: **35/35** rendered integration checks passed, exit 0, including new artwork slots, dialogue/board arrangement, scene-art swapping without rule changes, promotion and back-arrow navigation.
- Import and fresh Web release export: passed without parser/resource errors.
- Chromium gameplay regression: **17/17** passed, exit 0; real mouse/keyboard input exercised relocated controls and both board orientations.
- Visual review: desktop 1280×720, portrait 390×844 and a native promotion position. Portrait font rendering and dialogue spacing were corrected after the first review.
- Final Web logs/screenshots: `/tmp/forstimpy-storyboard-rfvcxlyp/`; native results are in the execution transcript. The one-off promotion screenshot is `/tmp/forstimpy-storyboard-promotion.png`.
- The rules and bot implementation were unchanged; their rules-only suite was not repeated for the layout change.

## November 15 invitation update

Removed the “Not now” button and its decline state at the user's request. The invitation now contains only “sure” and “yes but red”; the board hotspot still opens chess, and leaving a match restores the invitation. The README and affected tests reflect this behavior.

- Rendered Godot integration: **31/31 passed**, exit 0, including absence of the third choice, both affirmative responses, board entry and restored invitation after leaving.
- Fresh temporary Web export: passed, exit 0, without import/export errors.
- Chromium browser regression: **17/17 passed**, exit 0, including a screenshot check that the removed button's former location shows the table. The invitation screenshot was also inspected visually.
- Browser logs and screenshots: `/tmp/forstimpy-invitation-srnqaj2g/`; native results are recorded in the execution transcript.
- Chess rules were unchanged; the rules-only suite was not repeated for this UI change.

The remaining sections record the original November 14 implementation and its results, including the decline flow that existed at that time.

## Git baseline and scope

- Fresh local clone: `/home/anson/Projects/forstimpy`.
- Initial branch: `main`; initial worktree clean.
- Baseline `main`: `bbe1478a6210230c9573a65e58542e9abffad23f`, matching the freshly cloned remote default branch.
- Implementation branch: `chess-character-implementation`.
- All committed additions are under `yassine-game/addons/slowbrainn_chess/`. No existing tracked source, project settings, export presets or checked-in browser outputs were changed.
- The implementation ZIP was not present locally. This implementation was built from the handoff requirements and current repository source.
- No push, merge or pull request was performed. The requested local branch is the deliverable.

## Environment and outcomes

| Verification | Actual outcome |
| --- | --- |
| Godot | 4.7.2 stable, Arch Linux; native GL Compatibility on Intel Iris Xe |
| Final project import | Passed; no errors, parser failures or warnings in `/tmp/forstimpy-chess-final-import.log` |
| Rules suite | **59/59 passed**, exit 0; last run 1000 ms total |
| Rendered scene integration suite | **30/30 passed**, exit 0; actual graphical Godot window and connected UI signals |
| Clean temporary Web import and release export | Passed, exit 0; no errors or warnings in `/tmp/forstimpy-chess-web-export-clean.log` |
| Browser gameplay suite | **16/16 passed**, exit 0; Chromium 155.0.8059.84, WebGL 2, single-threaded release export |
| Browser viewports | 1280×720 desktop and 390×844 portrait; screenshots inspected visually |
| Browser console | No errors or script exceptions; screenshot captures produced Chromium GPU `ReadPixels` stall warnings |

The rules suite checks reference move-generation counts: starting position 20/400/8902 at depths 1/2/3, Kiwipete 48/2039 at depths 1/2, and the rook/pawn reference ending 2812 at depth 3. It also exercises illegal moves, en passant and a pinned en passant rejection, castling through attack, rook relocation and castling-right removal, all four promotions and Black promotion, mate, stalemate, insufficient material, threefold/fivefold repetition and 50/75-move rules. Opening-book choices and legal fallback are checked. The last measured native fallback search took **154 ms** with the test's zero thinking delay; this is one desktop measurement, not a mobile latency guarantee.

The rendered integration suite ran both the isolated character harness and the alternate integrated main. It verified the original title and camera pan, invitation, decline, continued character and location interaction, board re-entry, both affirmative callbacks including preserved joke dialogue, legal and illegal input, player White and player Black moves with legal replies, out-of-book continuation, restart with a pending reply, exit with a pending reply, and re-entry without duplicate activity nodes. It also replaced a texture with a different-aspect image without changing the position, then exercised the promotion chooser and an insufficient-material draw.

The browser suite used real canvas mouse and keyboard input rather than calling game methods. It verified decline-to-board entry, destination highlights, illegal e2–e5 rejection, e2–e4 with c7–c6, d2–d4 with d7–d5, restart cancellation, reversed Black orientation, a human Black c7–c6 move, both invitation responses, and legal fallback after h2–h4. It captured return-to-table/re-entry and portrait layouts for visual inspection. The final portrait check verifies that the board occupies the available width rather than shrinking the desktop controls.

These were automated interactive runs plus visual screenshot review. No separate human F6 session, full-length manual match, device lab or measured Elo evaluation is claimed.

## Commands and local evidence

Run from the repository root:

```bash
godot --headless --editor --path yassine-game --import
godot --headless --path yassine-game --script res://addons/slowbrainn_chess/tests/test_chess_rules.gd
godot --path yassine-game --resolution 1280x720 --script res://addons/slowbrainn_chess/tests/test_integration.gd
python yassine-game/addons/slowbrainn_chess/integration/build_web.py /tmp/forstimpy-chess-web-clean
python -m http.server 8768 --bind 127.0.0.1 --directory /tmp/forstimpy-chess-web-clean
```

Browser regression on this device used the existing test dependencies:

```bash
NODE_PATH=/home/anson/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules \
node yassine-game/addons/slowbrainn_chess/tests/browser_smoke.cjs \
  http://127.0.0.1:8768 /tmp/forstimpy-chess-browser-complete
```

Evidence remains locally in `/tmp` and is not committed: `forstimpy-chess-rules.log`, `forstimpy-chess-final-import.log`, `forstimpy-chess-web-export-clean.log`, `forstimpy-chess-browser-complete-results.log`, and `forstimpy-chess-browser-complete/` (screenshots and console log). The rendered integration's final 30-check output is recorded in the execution transcript; the earlier 28-check run is also preserved in `/tmp/forstimpy-chess-integration.log`. Re-running the export command requires a new or empty output directory.

## Findings resolved during implementation

- The handoff's claimed `_answer(false)` indentation bug is **absent in the current `main`**. A rendered baseline test confirmed that “sure” transitions and clears `changing_view`. No original-script repair was made. The new adapter overrides acceptance to open the playable activity.
- Fixed a release-only opening-book initialization issue: state advancement must execute outside assertions. Browser release tests now confirm c6/d5 preferences.
- Fixed portrait scaling locally in the activity overlay without changing the original project's canvas-stretch settings.
- Fixed the temporary export copy's cold-cache UID/custom-cursor import order. The final fresh export logs are clean. The original project's settings remain unchanged.
- The native integration test clears the custom cursor before shutdown; its final run has no renderer-shutdown resource errors.

## Remaining limits

- **950–1200 Chess.com strength remains an uncalibrated design target.** Original PGNs were unavailable; opening counts come from the handoff.
- The original default main scene is intentionally unchanged. Launch the alternate scene explicitly, or use `build_web.py` to export it. A normal export of the unchanged project does not select the chess integration.
- Search has a 650 ms scheduling budget and yields work around a 4 ms frame budget; a move-generation call is indivisible. Broad mobile performance and browser compatibility have not been measured.
- Threefold/50-move claims work once the current position qualifies; advance claims by announcing a proposed move are not implemented. Common insufficient-material draws are supported; no general dead-position solver is claimed.
- No clocks, resignation, PGN export, network play, matchmaking, service worker or offline installation workflow. Loaded gameplay itself makes no chess-related network requests.
- This device had no configured Git author identity. The local implementation commit uses `Codex <codex@local.invalid>` without changing global Git settings.

When ready to publish the branch yourself:

```bash
git push -u origin chess-character-implementation
```
