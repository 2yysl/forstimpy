"""Independently validate test_record.gd exports using external python-chess.

This is test tooling, not a game dependency. Pass the generated PGN directory.
"""
import json
from pathlib import Path
import sys

import chess.pgn


def main():
    root = Path(sys.argv[1])
    expected = json.loads((root / "expected.json").read_text())
    for name, final_fen in expected.items():
        with (root / name).open() as source:
            game = chess.pgn.read_game(source)
        assert game is not None and not game.errors, (name, getattr(game, "errors", None))
        actual = game.end().board().fen(en_passant="fen")
        assert actual == final_fen, (name, actual, final_fen)
        print("PASS: independent PGN parsing and exact final FEN:", name)
    print(f"INDEPENDENT PGN: {len(expected)}/{len(expected)} checks passed")


if __name__ == "__main__":
    main()
