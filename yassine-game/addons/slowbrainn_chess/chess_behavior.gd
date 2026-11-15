extends Resource
## Design target only. No measured Chess.com rating is claimed.
@export var display_name := "yyslChess"
@export var target_rating_label := "950–1200 target · uncalibrated"
@export_range(0.0, 200.0) var evaluation_noise := 65.0
@export_range(1, 5000) var search_budget_ms := 650
@export_range(1, 16) var frame_budget_ms := 4
@export_range(0.0, 2.0) var think_delay_seconds := 0.25
