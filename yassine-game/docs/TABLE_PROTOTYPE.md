# Table storyboard prototype

This document records the original prototype. The current F5 game includes playable chess and an interactive table letter; see the repository README and `features/letter/README.md` for current behaviour and verification.

Title -> main table -> overhead seated board -> Back/Escape.

Title scrolls upward as the table and character move into view from below during a 1.2-second camera pan, without fading, against the existing #deffff background. Location controls slide in from the left over 0.45 seconds. As soon as the entrance and location-control slide finish, borderless dialogue asks Want to play chess? and shows two responses; there is no additional delay.

Dap unlocks after the entrance. Hover the right-side hand for a highlight and click for a reaction. The existing cursor keeps its saved orientation; no alternate hand image is connected.

Sure opens the overhead placeholder board. Yes but red shows a placeholder joke for 2.2 seconds before opening that board. Back/Escape returns to the table. Location and dap count persist. Location buttons change placeholder backdrop details; music is not connected. The letter is decorative. Chess rules and final art are not implemented.

Main scene: main.tscn; stage: scenes/ui/table_scene.tscn; stage script: scripts/ui/table_scene.gd.

Verified in native preview: invitation hidden during entrance, dialogue synchronized with entrance completion, dap, both responses, Back, Escape, state persistence, and clean game logs. Browser export not tested.
