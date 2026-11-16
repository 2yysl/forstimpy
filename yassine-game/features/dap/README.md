# Table dap

Select the character's hand on the table to dap. Each press independently chooses an audio outcome, then one of its two comments with equal probability. Repeated outcomes are allowed; no cooldown or streak rules apply.

| Audio | Chance | Character comments |
| --- | ---: | --- |
| `res://assets/sfx/dapbad.wav` | 20% | `we suck` / `look at the elbow` |
| `res://assets/sfx/dapmid.wav` | 35% | `we could do better` / `shibal` |
| `res://assets/sfx/dapmid2.wav` | 35% | `we could do better` / `shibal` |
| `res://assets/sfx/dapgoat.wav` | 10% | `we are goated` / `nice` |

The table reuses its existing hand lift/highlight and reaction Label. Every press updates that feedback immediately. The latest reaction remains for two seconds after the latest press. Opening the full note, starting a chess transition or hiding the table cancels the current dap. Hand input is blocked during entrance, transitions, the note reader and chess.

## Audio and performance

`DapInteraction.tscn` owns one `AudioStreamPlayer` on the existing SFX bus and one reusable, one-shot Timer. Its script owns a dedicated RNG, independent of fist colour assignment, chess openings and RPS. The table script owns input gating and visual feedback; the chess adapter calls the same cancellation method before its dialogue delay.

One voice plays at a time. A fresh press replaces the preceding clip, even if it selects the same outcome. When multiple inputs arrive before the engine's next deferred update, every input still draws an outcome and updates the comment, while one pending call starts only the latest selected sound. This bounds audio restarts per engine update. There are no per-press nodes, waiting coroutines, sound loads or animation objects.

The initial direct-restart implementation exposed temporary Godot playback allocations under 100 presses in a single frame. Starting only the latest sound in that update reduced the measured 95th-percentile cost of a 100-press batch from approximately 20.1 ms to 1.4 ms on this device. Node/object counts remained stable during the final 10,000-press test. Unlimited clicking still requires work per input; the implementation prevents a growing backlog or growing audio concurrency.

## Editing

Open `DapInteraction.tscn` in Godot and select its root node. The Inspector exposes `bad_sound`, `mid_sound`, `mid2_sound`, `goat_sound` as generic AudioStream slots and `volume_db` (default -6 dB). Replace the clips there without changing input or dialogue logic. Comments and cumulative percentage thresholds live at the top of `dap_interaction.gd`.

The existing clips are 0.418–1.858 seconds long and fit the two-second feedback window. If a replacement needs more than two seconds, increase `FeedbackTimer.wait_time` in the scene so the timer does not cut it short.

## Verification — November 16, 2026

Implemented locally on `fist-colour-selection`, after checkpoint `checkpoint-before-dap-interaction` at `4c6df21`. No new branch or worktree was created. Nothing was pushed or merged into main for this feature.

- Native dap suite: **36/36 passed**, including all eight sound/comment combinations, native PulseAudio output for all four WAVs, renewed timeout, 10,000 rapid presses, cancellation, hidden-input protection and independent RNGs.
- Stress distribution with a fixed test seed: **2,081 / 3,485 / 3,412 / 1,022** out of 10,000, consistent with the requested 20/35/35/10 probabilities. Production seeds randomize per table instance.
- Stress performance: 50 scene-tree nodes before and after, stable object counts, approximately 3.7 KiB of retained measurement/runtime memory, and **1.388 ms** at the 95th percentile per 100-press batch on this device.
- Chromium real-input dap suite: **16/16 passed**, including 200 rapid mouse clicks, all four distinct audio samples, a maximum of one active dap voice, feedback renewal, note/chess cancellation and portrait input.
- Existing letter regression: native **28/28** and Chromium **24/24 passed**, including paper audio, complete note text, modal blocking, Back/Escape and portrait layout.
- Existing full-game integration: **37/37 passed**, including the original table scene, both chess colours, bot responses, leaving/re-entering chess, artwork replacement and promotion.
- Fresh single-threaded Web export passed without script errors. Screenshots were reviewed at 1280×720 and 390×844.

Local evidence lives under ignored `builds/dap/verification/`; the playable export is `builds/dap/web/`. Browser tests instrument Web Audio in the test browser only and use the existing external `playwright-core` and `pngjs` dependencies.

```bash
# From the repository root, with a graphical display and working audio backend:
godot --path yassine-game --resolution 1280x720 --script res://features/dap/tests/test_dap.gd

# Export to an empty destination outside the Godot project, then serve locally:
python yassine-game/features/chess/integration/build_web.py builds/dap-review/web
python -m http.server 8765 --bind 127.0.0.1 --directory builds/dap-review/web
node yassine-game/features/dap/tests/browser_dap.cjs http://127.0.0.1:8765 builds/dap-review/screenshots
```
