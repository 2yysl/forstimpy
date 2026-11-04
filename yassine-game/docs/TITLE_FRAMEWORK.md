# Title screen framework

## Play
Press F5. A greeting appears on the existing #deffff background.
Click anywhere, tap, press Enter, or press Space to continue.
A 1.2-second camera pan moves down by one visible screen height.
The destination is intentionally empty: no chess scene has been created.

## Edit one thing at a time
- Greetings and visit history: scripts/LoadingMessages.gd
- Title layout, 80% width, colors, prompt: scripts/ui/title_screen.gd
- Shaped multilingual lettering: scripts/ui/ink_text.gd
- Reusable title scene: scenes/ui/title_screen.tscn
- Camera pan and future scene slot: scripts/main.gd
- Starting scene: main.tscn

The title sizes each greeting independently, using actual visible glyph bounds.
It targets 80% width and caps height for unusually wide, short windows.
The title is #ffe9a3; the prompt is #477477. Background remains #deffff.
Fonts are bundled: Darumadrop One Regular, with Baloo Bhaijaan 2 for Arabic
and ZCOOL KuaiLe for Chinese. All include their OFL licenses in assets/fonts.
Arabic is shaped as a complete line with automatic writing direction.

## Add chess later
Create a reusable scene with a Control root and assign it to Main's
Next Scene field in the Inspector. Do not move the stage yourself:
GameHost is positioned exactly one visible screen below the title.
For the planned 3D chess, put the 3D scene and its camera in a SubViewport
inside that Control scene. The outer Camera2D handles the opening pan.
Keep processing inherited. Main disables stage processing during the pan.
Use an optional start_game() method for actions that must wait for arrival:
_ready() still runs when a future scene is instantiated.
Main emits transition_started and stage_entered(stage) for other modules.
No chess, board, 3D environment, or placeholder destination scene is included.

## Greeting history
The six phrases are stored exactly as supplied.
Selection excludes the previous phrase before choosing randomly.
Desktop preview saves history in user://title_history.cfg.
Web uses synchronous localStorage under yassine-game:last-title:v1,
so immediate refreshes can read the preceding visit without waiting for IndexedDB.
History is local to this browser and website origin.
If storage is blocked, cleared, or unavailable, cross-visit non-repeat cannot
be guaranteed; the game logs a warning and still avoids repeats in the session.

## Browser export
Compatibility rendering is configured, with a single-threaded Web preset.
Install export templates matching Godot 4.7.2, then export Web to
build/web/index.html. Serve all output files through a web server.
This change was tested in the native Godot game; Web templates were absent,
so an actual browser export has not been verified.
The preset exports the main scene and dependencies, includes font licenses,
and excludes original backups, documentation, and unused starter fonts.
The Godot AI addon manages exclusion of its development runtime on export.

## Verification
- All six phrases have font coverage, including Arabic diacritics.
- 18 layout cases: six phrases at 1280x720, 390x844, and 844x390.
- 250 random selections: no adjacent duplicates.
- Click-triggered pan ends at the correct camera position.
- Repeated continuation requests cannot create overlapping pans.
- The destination host has zero children.
- Clean launch and runtime logs after fixes.
- Original main scene and scripts are preserved as .txt files in
  backups/title_framework_original to avoid duplicate Godot resource UIDs.

## Research used
- Godot forum camera smoothing discussion:
  https://forum.godotengine.org/t/camera-jumps-sideways-when-switching-after-cinematic-pan/117165
  Used one camera, a tween, and disabled position smoothing.
- Godot Tween reference:
  https://docs.godotengine.org/en/stable/classes/class_tween.html
  Used cubic ease-in-out, sized to the current viewport.
- Godot fonts and TextLine:
  https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html
  https://docs.godotengine.org/en/stable/classes/class_textline.html
  Used bundled fallbacks and whole-line shaping, not per-character rendering.
- Godot Web export:
  https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
  Used Compatibility and a single-threaded preset.
- Fonts: official google/fonts repository, ofl/darumadropone,
  ofl/baloobhaijaan2, and ofl/zcoolkuaile.

## Earlier chat context used
- Create a Godot loading scene: continuous #deffff background and downward pan.
- Plan friendship memory website: browser delivery and future 3D chess,
  dialogue, and clickable keepsakes.
- Create low-poly chess assets: existing assets remain untouched for a later task.
