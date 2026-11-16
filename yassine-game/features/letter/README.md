# Table letter

The letter beside the table's dap interaction opens on hover, plays `res://assets/sfx/paper crumple.wav`, and exposes a clickable note. Selecting that note opens a full-screen reader. Back or Escape returns to the existing table with its location, dap count and invitation state preserved. The envelope inside the chess layout remains decorative.

## Behaviour

- A closed envelope reacts only to hovering its visible body. Its still-hidden note cannot be clicked.
- Envelope and exposed note form one continuous hover area. Deferred exit reconciliation prevents a child-control transition from closing the letter or retriggering sound.
- Each new entry starts the assigned paper sound once. Holding the pointer does not loop it. Rapid re-entry restarts the same player, with one voice, rather than stacking sounds. Moving away closes the envelope and lets the current sound finish.
- Selecting the exposed note opens the reader without extra audio. The long note scrolls; Back remains visible. Input cannot reach dap, location or chess controls underneath.
- Back/Escape restores the letter according to the current pointer position without a phantom sound. Another real entry plays again.
- The letter is disabled during entrance/scene transitions and chess. Hiding the table also closes any reader overlay.

## Editing

`LetterInteraction.tscn` and `letter_interaction.gd` expose `closed_texture`, `open_texture`, `paper_sound`, `paper_volume_db` and `note_path` in Godot's Inspector. The included placeholders use matching 152×128 SVG canvases. The open image includes the sticking-out paper; the separate `Note` button covers that exposed region. Adjust `EnvelopeHover` and `Note` rectangles when replacing the art with a different shape. The table scene places this component in its existing scaled UI.

The original root `birthday note` file was moved to `content/birthday_note.txt`, without editing its 1386 bytes. Original SHA-256: `3639dc4c6bb6de754e79bc130505312675d564a2f1b0c05fe0f6cf4fbd837e82`. This is now the canonical text asset. The reader uses a plain Label, preserving the wording and explicit line breaks while adding visual word wrapping. The Web export preset's include filter packages `features/letter/content/*.txt`; retain this filter in future export presets.

`default_bus_layout.tres` provides Master and SFX buses. The letter uses one `AudioStreamPlayer`, defaults to -6 dB, and exposes the sound as a generic AudioStream so clips can be replaced without scripting. There is no new audio plugin, global manager, per-frame hover polling or dynamically allocated sound player. The separate dap component also uses SFX; opening the full note cancels any current dap, and dap input is blocked while reading. See `../dap/README.md`.

## Verification — November 16, 2026

Developed locally on `fist-colour-selection`, with checkpoint `checkpoint-before-letter-interaction` at `ce93cc5`. No new worktree or branch was created, and nothing was pushed for this feature.

- Native letter suite: **28/28 passed**, including complete-text hash, modal input blocking, scroll, Back/Escape, table-state preservation, scene cleanup and restored chess entry.
- Native audio: PulseAudio SFX capture produced 11,776 frames with a nonzero peak of approximately 0.0329 after hover. Moving off the letter did not stop playback; re-entry restarted it.
- Fresh single-threaded Web export: passed. The exact original note bytes were found in its PCK package.
- Real-input Chromium letter suite: **24/24 passed**, including hover transitions, rapid re-entry, running Web Audio with nonzero samples from the 1.434-second clip, no phantom return sounds, modal input blocking and desktop/portrait reading.
- Existing native game integration: **37/37 passed**. Existing browser chess/fist/inventory regression: **36/36 passed**, recorded in `chess-browser.log`.
- Visual review: desktop 1280×720 and portrait 390×844, including note beginning, ending, scrolling and the fixed Back button.

Evidence is under ignored `builds/letter/verification/`: `native-letter.log`, `integration.log`, `export.log`, `browser.log`, screenshots, and the existing chess browser regression. The playable Web export is `builds/letter/web/`.

```bash
# Run from the repository root; a graphical display/audio backend is required.
godot --path yassine-game --resolution 1280x720 --script res://features/letter/tests/test_letter.gd
# Export to a new empty directory, then serve it locally.
python yassine-game/features/chess/integration/build_web.py builds/letter-review/web
python -m http.server 8765 --bind 127.0.0.1 --directory builds/letter-review/web
node yassine-game/features/letter/tests/browser_letter.cjs http://127.0.0.1:8765 builds/letter-review/screenshots
```

Browser tooling uses the same external `playwright-core` and `pngjs` dependencies as the chess tests. It instruments Web Audio in the test browser only; no test/debug hooks are added to the product UI.
