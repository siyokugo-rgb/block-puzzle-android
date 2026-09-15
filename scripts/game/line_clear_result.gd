class_name LineClearResult
extends RefCounted

## Phase 1-A: outcome of detecting and clearing completed rows/columns.
## Score is not computed here; cleared_* fields are enough for later scoring.

var cleared_rows: Array[int] = []
var cleared_columns: Array[int] = []
var cleared_cell_count: int = 0


func has_clears() -> bool:
	return cleared_cell_count > 0
