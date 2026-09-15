extends Control

## Phase 1-D playable slice: renders GameSession and routes touch/mouse to place_from_slot.
## GameSession is the only source of truth for board / tray / game over.

const TOP_SAFE := 120.0
const BOTTOM_SAFE := 140.0 # leave room for banner / privacy chrome
const TRAY_FRACTION := 0.22
const BOARD_MARGIN := 16.0

@onready var _board_view: BoardView = $BoardView
@onready var _tray_row: HBoxContainer = $TrayRow
@onready var _game_over_label: Label = $GameOverLabel
@onready var _drag_piece: PieceView = $DragPiece

var _session: GameSession
var _coords: BoardCoords
var _drag: PlacementDrag = PlacementDrag.new()
var _tray_views: Array[PieceView] = []
var _tray_hit_rects: Array[Rect2] = []
var _input_enabled: bool = true
var _active_pointer_id: int = -1
var _mouse_button_was_down: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over_label.visible = false
	_drag_piece.visible = false
	_drag_piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _tray_row.get_children():
		if child is PieceView:
			_tray_views.append(child)
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	if _session == null:
		start_dev_session()


func start_dev_session(seed_value: int = 1) -> void:
	bind_session(DevPlayConfig.create_dev_session(seed_value))


func bind_session(session: GameSession) -> void:
	_session = session
	_drag.cancel()
	_active_pointer_id = -1
	_board_view.bind_session(_session)
	_relayout()
	_sync_from_session()


func session() -> GameSession:
	return _session


func is_input_enabled() -> bool:
	return _input_enabled


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _relayout() -> void:
	if _session == null or not _session.is_valid():
		return
	var w := size.x
	var h := size.y
	var tray_h := maxf(h * TRAY_FRACTION, 96.0)
	var board_area_top := TOP_SAFE
	var board_area_bottom := h - BOTTOM_SAFE - tray_h
	var board_area_h := maxf(board_area_bottom - board_area_top, 64.0)
	var board_area_w := maxf(w - BOARD_MARGIN * 2.0, 64.0)
	var bw := _session.board_width()
	var bh := _session.board_height()
	var cell := minf(board_area_w / float(bw), board_area_h / float(bh))
	var board_pixel := Vector2(cell * float(bw), cell * float(bh))
	var board_pos := Vector2(
		(w - board_pixel.x) * 0.5,
		board_area_top + (board_area_h - board_pixel.y) * 0.5
	)
	_board_view.position = board_pos
	_board_view.size = board_pixel
	_coords = BoardCoords.create(board_pos, cell, bw, bh)
	_board_view.set_coords(BoardCoords.create(Vector2.ZERO, cell, bw, bh))

	var tray_cell := minf(cell * 0.85, tray_h / 4.0)
	var tray_top := h - BOTTOM_SAFE - tray_h
	_tray_row.position = Vector2(BOARD_MARGIN, tray_top)
	_tray_row.size = Vector2(w - BOARD_MARGIN * 2.0, tray_h)
	_tray_hit_rects.clear()
	var slot_w := _tray_row.size.x / float(PieceTray.SLOT_COUNT)
	for i in range(_tray_views.size()):
		var view := _tray_views[i]
		view.set_cell_size(tray_cell)
		var hit := Rect2(
			Vector2(BOARD_MARGIN + slot_w * float(i), tray_top),
			Vector2(slot_w, tray_h)
		)
		_tray_hit_rects.append(hit)
	_game_over_label.position = Vector2(0.0, board_area_top + board_area_h * 0.35)
	_game_over_label.size = Vector2(w, 64.0)
	_sync_tray_pieces()


func _sync_from_session() -> void:
	if _session == null:
		return
	_board_view.clear_preview()
	_board_view.queue_redraw()
	_sync_tray_pieces()
	_input_enabled = _session.is_valid() and not _session.is_game_over()
	_game_over_label.visible = _session.is_game_over()
	if not _drag.is_dragging():
		_drag_piece.visible = false


func _sync_tray_pieces() -> void:
	if _session == null:
		return
	for i in range(_tray_views.size()):
		var view := _tray_views[i]
		# Keep slot controls visible so HBox layout does not collapse empty slots.
		view.visible = true
		if _session.has_piece(i):
			view.set_piece(_session.piece_at(i))
			view.set_dimmed(_drag.is_dragging() and _drag.slot_index() == i)
		else:
			view.clear_piece()
			view.set_dimmed(false)


func _finger_offset() -> Vector2:
	var cell := _coords.cell_size() if _coords != null else 32.0
	return Vector2(0.0, -cell * DevPlayConfig.DEV_DRAG_FINGER_OFFSET_CELLS)


func _process(_delta: float) -> void:
	# Desktop editor/x11: guarantee move + mouse-up while dragging even if
	# _gui_input/_input miss the release (pointer leave / focus quirks).
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _drag.is_dragging() and _active_pointer_id == 0:
		_on_move(0, get_local_mouse_position())
		if _mouse_button_was_down and not mouse_down:
			_on_release(0)
	_mouse_button_was_down = mouse_down


func _gui_input(event: InputEvent) -> void:
	# Primary path for presses and in-control mouse move/release.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_on_move(drag.index, drag.position)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			_on_press(0, mouse.position)
		else:
			_on_release(0)
		accept_event()
	elif event is InputEventMouseMotion and _drag.is_dragging() and _active_pointer_id == 0:
		var motion := event as InputEventMouseMotion
		_on_move(0, motion.position)
		accept_event()


func _input(event: InputEvent) -> void:
	# Fallback when pointer leaves this control mid-drag (esp. mouse).
	if not _drag.is_dragging():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and touch.index == _active_pointer_id:
			_on_release(touch.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed and _active_pointer_id == 0:
			_on_release(0)
			get_viewport().set_input_as_handled()


func _to_local(viewport_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_pos

func _on_press(pointer_id: int, local_pos: Vector2) -> void:
	if _drag.is_dragging():
		return
	if not _input_enabled:
		return
	var slot := _hit_tray_slot(local_pos)
	if slot < 0:
		return
	if not _drag.begin(_session, slot, local_pos):
		return
	_active_pointer_id = pointer_id
	if pointer_id == 0:
		_mouse_button_was_down = true
	_drag_piece.set_piece(_session.piece_at(slot))
	_drag_piece.set_cell_size(_coords.cell_size() if _coords != null else 24.0)
	_drag_piece.set_dimmed(false)
	_drag_piece.visible = true
	_sync_tray_pieces()
	_on_move(pointer_id, local_pos)


func _on_move(pointer_id: int, local_pos: Vector2) -> void:
	if not _drag.is_dragging() or pointer_id != _active_pointer_id:
		return
	_drag.update(_session, _coords, local_pos, _finger_offset())
	_update_drag_visuals()


func _on_release(pointer_id: int) -> void:
	if not _drag.is_dragging() or pointer_id != _active_pointer_id:
		return
	var result := _drag.release(_session)
	_active_pointer_id = -1
	_mouse_button_was_down = false
	_drag_piece.visible = false
	_board_view.clear_preview()
	# MoveResult is SoT — only success redraws as a committed move.
	# Failed / cancelled drops leave session unchanged; still refresh visuals.
	_sync_from_session()
	if result != null and result.success:
		# Clear after place is already reflected in occupied_cells via session.
		_board_view.queue_redraw()


func _update_drag_visuals() -> void:
	var piece := _session.piece_at(_drag.slot_index()) if _session != null else null
	var cs := _coords.cell_size() if _coords != null else 24.0
	_drag_piece.set_cell_size(cs)
	if piece != null and piece.is_valid():
		_drag_piece.size = _drag_piece.custom_minimum_size
		var min_o := piece.min_offset()
		if (
			_drag.has_preview_origin()
			and _coords != null
			and _coords.is_cell_in_bounds(_drag.preview_origin())
		):
			# PieceView local (0,0) is min_offset cell when size == min size.
			_drag_piece.position = _coords.cell_to_local(_drag.preview_origin() + min_o)
		else:
			var preview_point := _drag.pointer_local() + _finger_offset()
			_drag_piece.position = preview_point - Vector2(cs * 0.5, cs * 0.5)
	var cells: Array[Vector2i] = []
	if _drag.has_preview_origin() and piece != null and piece.is_valid():
		for offset in piece.cells():
			cells.append(_drag.preview_origin() + offset)
	_board_view.set_preview(cells, _drag.preview_valid())


func _hit_tray_slot(local_pos: Vector2) -> int:
	for i in range(_tray_hit_rects.size()):
		if _tray_hit_rects[i].has_point(local_pos):
			return i
	return -1
