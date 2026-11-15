#!/usr/bin/env python3
"""Export the game's configured entry scene, or an explicit test scene."""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Empty export directory outside yassine-game, e.g. builds/web")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--scene", help="Override the configured entry scene for a test export")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[3]
    output = args.output.resolve()
    if output == project or project in output.parents:
        parser.error("Choose an export directory outside yassine-game")
    if output.exists() and any(output.iterdir()):
        parser.error("Choose an empty output directory to preserve existing files")
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="forstimpy-chess-project-") as temp:
        copy = Path(temp) / "project"
        # Existing checked-in web artifacts are not source assets.
        shutil.copytree(project, copy, ignore=shutil.ignore_patterns(".godot", ".git", "index.html", "index.js", "index.wasm", "index.pck", "index.audio*.js"))
        settings = copy / "project.godot"
        text = settings.read_text()
        # Resolve source UIDs before the first import has generated a UID cache.
        # This avoids the original project's cold-import autoload warning.
        for uid_file in copy.rglob("*.uid"):
            source = uid_file.with_suffix("")
            text = text.replace(uid_file.read_text().strip(), "res://" + source.relative_to(copy).as_posix())
        for metadata in copy.rglob("*.import"):
            match = re.search(r'^uid="(uid://[^\"]+)"', metadata.read_text(), re.MULTILINE)
            if match:
                text = text.replace(match[1], "res://" + metadata.with_suffix("").relative_to(copy).as_posix())
        lines = text.splitlines()
        if args.scene:
            lines = [f'run/main_scene="{args.scene}"' if line.startswith("run/main_scene=") else line for line in lines]
        entry_scene = next(line.split('"')[1] for line in lines if line.startswith("run/main_scene="))
        resolved_settings = "\n".join(lines) + "\n"
        # Godot loads a custom cursor before importing its image on a cold
        # project. Restore it after import, before the export snapshot.
        settings.write_text("\n".join(line for line in lines if not line.startswith("mouse_cursor/custom_image=")) + "\n")
        subprocess.run([args.godot, "--headless", "--editor", "--path", str(copy), "--import"], check=True)
        settings.write_text(resolved_settings)
        subprocess.run([args.godot, "--headless", "--path", str(copy), "--export-release", "Web", str(output / "index.html")], check=True)
    print(f"Exported {entry_scene} to {output / 'index.html'}")
    print(f"Serve locally: python -m http.server 8765 --bind 127.0.0.1 --directory {output}")


if __name__ == "__main__":
    main()
