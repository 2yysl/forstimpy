extends Resource
## Design target only. No measured Chess.com rating is claimed.
@export var display_name := "yyslChess"
@export var target_rating_label := "950–1200 target · uncalibrated"
@export_range(0, 6) var book_full_moves := 6
@export_range(1, 4) var search_depth := 3
@export_range(1, 16) var frame_budget_ms := 4
@export_range(0.0, 2.0) var think_delay_seconds := 0.25
