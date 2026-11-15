# yyslChess opening repertoire

The runtime source of truth is `chess_opening_book.gd`: nine reference lines, plus four equivalent move-order aliases. They are cached as position-to-move entries on first use. No external opening service or model runs during play.

Book lookup is allowed through Black's sixth move. From White's seventh move onward it is disabled, even if an earlier board position repeats. An unsupported position immediately uses the same deterministic search; a supported transposition may re-enter the book before the cutoff.

White always begins 1.e4. Against 1...e5, the second-move weights favor Scotch development (22) over the Center Game (5). Other opponent replies are not forced into these openings. Black favors ...c6 and ...d5 in the registered Caro-Kann and Slav positions.

| Side | Reference | First six full moves |
| --- | --- | --- |
| White | Scotch Classical / Blackburne | 1.e4 e5 2.Nf3 Nc6 3.d4 exd4 4.Nxd4 Bc5 5.Be3 Qf6 6.c3 Nge7 |
| White | Scotch Mieses | 1.e4 e5 2.Nf3 Nc6 3.d4 exd4 4.Nxd4 Nf6 5.Nxc6 bxc6 6.e5 Qe7 |
| White | Center Game / Kupreichik | 1.e4 e5 2.d4 exd4 3.Qxd4 Nc6 4.Qe3 Nf6 5.Nc3 Bb4 6.Bd2 O-O |
| White | Center Game / Charousek | 1.e4 e5 2.d4 exd4 3.Qxd4 Nc6 4.Qe3 Bb4+ 5.c3 Be7 6.c4 Nf6 |
| Black | Caro-Kann Classical | 1.e4 c6 2.d4 d5 3.Nc3 dxe4 4.Nxe4 Bf5 5.Ng3 Bg6 6.h4 h6 |
| Black | Caro-Kann Advance / Short | 1.e4 c6 2.d4 d5 3.e5 Bf5 4.Nf3 e6 5.Be2 c5 6.O-O Nc6 |
| Black | Caro-Kann Exchange | 1.e4 c6 2.d4 d5 3.exd5 cxd5 4.Bd3 Nc6 5.c3 Nf6 6.Bf4 Bg4 |
| Black | Slav Czech / Wiesbaden, by transposition | 1.d4 c6 2.c4 d5 3.Nf3 Nf6 4.Nc3 dxc4 5.a4 Bf5 6.Ne5 e6 |
| Black | Slav Exchange Symmetrical, by transposition | 1.d4 c6 2.c4 d5 3.cxd5 cxd5 4.Nc3 Nf6 5.Nf3 Nc6 6.Bf4 Bf5 |

Aliases cover 3.Nd2 in the Classical Caro-Kann, 1.c4 c6 2.d4 d5 in both Slav branches, and 1.Nf3 c6 2.d4 d5 3.c4 Nf6 in the Czech Slav. They lead to the same registered positions and preserve legal castling/en-passant state.

## References and scope

- [Lichess opening database](https://github.com/lichess-org/chess-openings), CC0: Scotch and Center classifications in `c.tsv`, Caro-Kann in `b.tsv`, and Slav in `d.tsv`. File blob SHAs checked: `c882c56bcf34c6325b9ca60d20afac2e55604f08`, `81e29d1a65aa7e7f0c607b5e47c140a08cfb72ae`, and `a829bac9d2f288b033d605e842f3b802379e3455` respectively.
- [Caro-Kann reference course](https://chessgm.net/learn/openings/caro-kann) lists the full Classical, Short and Exchange continuations shown above.
- [Scotch Mieses reference](https://www.chess.com/openings/Scotch-Game-Schmidt-Mieses-Variation) identifies the 6.e5 branch; 6...Qe7 is its standard continuation.
- The Charousek definition through 5...Be7 is in Lichess `c.tsv`; the sixth-move continuation 6.c4 Nf6 was checked in [Lichess's master-game explorer](https://explorer.lichess.ovh/masters?play=e2e4,e7e5,d2d4,e5d4,d1d4,b8c6,d4e3,f8b4,c2c3,b4e7,c3c4&topGames=1&moves=3), reference game `nlhAHs3e` (2018). This is a rarer reference continuation, not a claim that it is the main line or best possible move.

The book is a small supported repertoire, not complete opening theory. Every stored move is validated by the actual rules implementation, including in release builds; invalid data produces an error and is rejected. Legality checks do not establish opening quality. No Elo estimate is inferred from the book.
