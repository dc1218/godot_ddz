extends Control

enum Phase {BIDDING, ROBBING, PLAYING, FINISHED}

const SUITS := ["♣", "♦", "♥", "♠"]
const SUIT_COLORS := [Color(0.12, 0.16, 0.13), Color(0.76, 0.12, 0.09), Color(0.76, 0.12, 0.09), Color(0.12, 0.16, 0.13)]
const PLAYER_NAMES := ["你", "上家", "下家"]

var phase: Phase = Phase.BIDDING
var deck: Array[int] = []
var hands: Array = [[], [], []]
var bottom_cards: Array[int] = []
var selected_cards: Array[int] = []
var played_cards_by_seat: Array = [[], [], []]
var turn := 0
var landlord := -1
var highest_bid := 0
var bid_turns := 0
var rob_queue: Array[int] = []
var multiplier := 1
var last_cards: Array[int] = []
var last_player := -1
var pass_count := 0
var ai_thinking := false
var status_text := ""

var stage_label: Label
var player_labels: Array[Label] = []
var table_label: Label
var played_cards_areas: Array[FlowContainer] = []
var status_label: Label
var hand_area: Control
var action_area: HBoxContainer
var hand_card_buttons: Dictionary = {}
var hand_card_styles: Dictionary = {}
var is_drag_selecting := false
var drag_selection_state := false

var bgm_player: AudioStreamPlayer
var sounds: Dictionary


func _ready() -> void:
	_build_ui()
	_start_round()


func _build_ui() -> void:
	var felt := ColorRect.new()
	felt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	felt.color = Color(0.025, 0.24, 0.16)
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(felt)

	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base_offset = 14
	frame.offset_left = base_offset
	frame.offset_top = base_offset
	frame.offset_right = - base_offset
	frame.offset_bottom = - base_offset
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.035, 0.19, 0.13, 0.45)
	frame_style.set_border_width_all(2)
	frame_style.border_color = Color(0.77, 0.61, 0.3, 0.8)
	frame_style.set_corner_radius_all(18)
	frame.add_theme_stylebox_override("panel", frame_style)
	add_child(frame)

	var title := _make_label("斗地主", 23, Color(1, 0.87, 0.55), Rect2(0.035, 0.025, 0.25, 0.07))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(title)
	stage_label = _make_label("", 17, Color(0.96, 0.8, 0.45), Rect2(0.34, 0.025, 0.32, 0.07))
	add_child(stage_label)

	var restart_button := _make_button("重新开始", Vector2(112, 42), Color(0.14, 0.34, 0.24))
	restart_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	restart_button.position = Vector2(-250, 18)
	restart_button.pressed.connect(_start_round)
	add_child(restart_button)
	var back_button := _make_button("返回大厅", Vector2(112, 42), Color(0.14, 0.34, 0.24))
	back_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	back_button.position = Vector2(-130, 18)
	back_button.pressed.connect(_return_to_lobby)
	add_child(back_button)

	var left_player := _make_label("上家", 18, Color(1, 0.91, 0.69), Rect2(0.035, 0.16, 0.28, 0.12))
	left_player.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	player_labels.append(left_player)
	add_child(left_player)
	var right_player := _make_label("下家", 18, Color(1, 0.91, 0.69), Rect2(0.685, 0.16, 0.28, 0.12))
	right_player.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_labels.append(right_player)
	add_child(right_player)

	table_label = _make_label("", 20, Color(1, 0.92, 0.72), Rect2(0.36, 0.14, 0.28, 0.13))
	add_child(table_label)
	played_cards_areas.append(_make_played_cards_area(Rect2(0.08, 0.49, 0.84, 0.14)))
	played_cards_areas.append(_make_played_cards_area(Rect2(0.025, 0.3, 0.31, 0.25)))
	played_cards_areas.append(_make_played_cards_area(Rect2(0.665, 0.3, 0.31, 0.25)))
	status_label = _make_label("", 16, Color(0.98, 0.77, 0.42), Rect2(0.2, 0.33, 0.6, 0.04))
	add_child(status_label)


	action_area = HBoxContainer.new()
	action_area.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	action_area.anchor_left = 0.15
	action_area.anchor_right = 0.85
	action_area.anchor_top = 0.67
	action_area.anchor_bottom = 0.77
	action_area.offset_left = 0
	action_area.offset_right = 0
	action_area.offset_top = 0
	action_area.offset_bottom = 0
	action_area.alignment = BoxContainer.ALIGNMENT_CENTER
	action_area.add_theme_constant_override("separation", 12)
	add_child(action_area)

	hand_area = Control.new()
	hand_area.anchor_left = 0.025
	hand_area.anchor_top = 0.77
	hand_area.anchor_right = 0.975
	hand_area.anchor_bottom = 0.99
	add_child(hand_area)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = load("res://assets/sounds/login_bg.ogg")
	bgm_player.autoplay = true
	bgm_player.volume_db = -12.0
	add_child(bgm_player)
	
	var sounds_name := [
		"bomb",
		"pair",
		"rob_0",
		"rob_1",
		"score_0",
		"score_1",
		"score_2",
		"score_3",
	]
	for sound in sounds_name:
		var s = AudioStreamPlayer.new()
		s.stream = load("res://sounds/" + sound + ".wav")
		s.volume_db = -10
		add_child(s)
		sounds[sound] = s


func _make_label(text: String, font_size: int, color: Color, anchors: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.anchor_left = anchors.position.x
	label.anchor_top = anchors.position.y
	label.anchor_right = anchors.position.x + anchors.size.x
	label.anchor_bottom = anchors.position.y + anchors.size.y
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_button(text: String, minimum_size: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(1, 0.94, 0.79))
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.88, 0.68, 0.34)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	return button


func _make_played_cards_area(anchors: Rect2) -> FlowContainer:
	var area := FlowContainer.new()
	area.anchor_left = anchors.position.x
	area.anchor_top = anchors.position.y
	area.anchor_right = anchors.position.x + anchors.size.x
	area.anchor_bottom = anchors.position.y + anchors.size.y
	area.alignment = FlowContainer.ALIGNMENT_CENTER
	area.add_theme_constant_override("h_separation", 3)
	area.add_theme_constant_override("v_separation", 2)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(area)
	return area


func _start_round() -> void:
	phase = Phase.BIDDING
	deck.clear()
	hands = [[], [], []]
	selected_cards.clear()
	played_cards_by_seat = [[], [], []]
	bottom_cards.clear()
	turn = randi_range(0, 2)
	landlord = -1
	highest_bid = 0
	bid_turns = 0
	rob_queue.clear()
	multiplier = 1
	last_cards.clear()
	last_player = -1
	pass_count = 0
	status_text = "牌已洗好，准备叫分"
	for card_id in range(54):
		deck.append(card_id)
	deck.shuffle()
	for index in range(51):
		hands[index % 3].append(deck[index])
	bottom_cards = deck.slice(51, 54)
	for hand in hands:
		hand.sort_custom(Callable(self, "_card_sort"))
	_render()


func _render() -> void:
	stage_label.text = _phase_name() + "    底分 ×" + str(multiplier)
	for seat in range(1, 3):
		var label_index := seat - 1
		var role := " · 地主" if landlord == seat else " · 农民" if phase == Phase.PLAYING or phase == Phase.FINISHED else ""
		var turn_mark := "  ◀行动中" if turn == seat and phase != Phase.FINISHED else ""
		player_labels[label_index].text = PLAYER_NAMES[seat] + role + turn_mark + "\n手牌 " + str(hands[seat].size()) + " 张"
		player_labels[label_index].add_theme_color_override("font_color", Color(1, 0.9, 0.62) if turn == seat else Color(0.86, 0.84, 0.72))
	status_label.text = status_text
	if phase == Phase.BIDDING:
		table_label.text = "叫分\n当前最高：" + str(highest_bid) + " 分"
	elif phase == Phase.ROBBING:
		table_label.text = "抢地主\n当前地主：" + PLAYER_NAMES[landlord] + "\n底牌即将揭晓"
	elif phase == Phase.PLAYING or phase == Phase.FINISHED:
		var last_text: String = "等待首手出牌" if last_cards.is_empty() else ""
		var bottom_text := "\n底牌：" + _cards_text(bottom_cards) if phase == Phase.PLAYING or phase == Phase.FINISHED else ""
		table_label.text = last_text + bottom_text
	_render_played_cards()
	_render_hand()
	_render_actions()
	_schedule_ai_turn()


func _render_played_cards() -> void:
	for seat in range(3):
		var area := played_cards_areas[seat]
		for child in area.get_children():
			child.queue_free()
		for card_id in played_cards_by_seat[seat]:
			var card := Panel.new()
			card.custom_minimum_size = Vector2(46, 62)
			var card_style := StyleBoxFlat.new()
			card_style.bg_color = Color(1, 0.96, 0.84)
			card_style.border_color = Color(0.88, 0.73, 0.42)
			card_style.set_border_width_all(1)
			card_style.set_corner_radius_all(5)
			card.add_theme_stylebox_override("panel", card_style)
			var face := Label.new()
			face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			face.offset_left = 2
			face.offset_top = 1
			face.offset_right = -2
			face.offset_bottom = -1
			face.text = _card_text(card_id)
			face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			face.add_theme_font_size_override("font_size", 16)
			var suit := floori(card_id / 13.0)
			var card_color: Color = SUIT_COLORS[suit] if suit < SUIT_COLORS.size() else Color(0.76, 0.12, 0.09) if card_id == 53 else Color(0.12, 0.16, 0.13)
			face.add_theme_color_override("font_color", card_color)
			card.add_child(face)
			area.add_child(card)


func _clear_played_cards() -> void:
	played_cards_by_seat = [[], [], []]


func _render_hand() -> void:
	for child in hand_area.get_children():
		child.queue_free()
	hand_card_buttons.clear()
	hand_card_styles.clear()
	if phase == Phase.FINISHED:
		return
	var hand: Array = hands[0]
	var card_width := 78.0
	var max_spread := 62.0
	var spread := max_spread
	if hand.size() > 1:
		spread = minf(max_spread, maxf(28.0, (hand_area.size.x - card_width) / float(hand.size() - 1)))
	for index in range(hand.size()):
		var card_id: int = hand[index]
		var button := Button.new()
		button.text = _card_text(card_id)
		button.position = Vector2(float(index) * spread, 8.0 if selected_cards.has(card_id) else 24.0)
		button.size = Vector2(card_width, 106)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 20)
		var suit := floori(card_id / 13.0)
		var card_color: Color = SUIT_COLORS[suit] if suit < SUIT_COLORS.size() else Color(0.76, 0.12, 0.09) if card_id == 53 else Color(0.12, 0.16, 0.13)
		button.add_theme_color_override("font_color", card_color)
		button.add_theme_color_override("font_hover_color", card_color)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 0.96, 0.84)
		style.border_color = Color(0.91, 0.75, 0.42) if selected_cards.has(card_id) else Color(0.73, 0.7, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.button_down.connect(_begin_card_drag.bind(card_id))
		button.mouse_entered.connect(_drag_select_card.bind(card_id))
		hand_card_buttons[card_id] = button
		hand_card_styles[card_id] = style
		hand_area.add_child(button)


func _render_actions() -> void:
	for child in action_area.get_children():
		child.queue_free()
	if phase == Phase.FINISHED:
		_add_action("再来一局", _start_round)
		return
	if turn != 0:
		return
	match phase:
		Phase.BIDDING:
			_add_action("不叫", _submit_bid.bind(0))
			for score in range(highest_bid + 1, 4):
				_add_action("叫 " + str(score) + " 分", _submit_bid.bind(score))
		Phase.ROBBING:
			_add_action("不抢", _submit_rob.bind(false))
			_add_action("抢地主", _submit_rob.bind(true))
		Phase.PLAYING:
			if not last_cards.is_empty() and last_player != 0:
				_add_action("不出", _pass_turn)
			_add_action("出牌", _play_selected)


func _add_action(text: String, callback: Callable) -> void:
	var button := _make_button(text, Vector2(112, 46), Color(0.72, 0.13, 0.08) if text != "不出" and text != "不叫" and text != "不抢" else Color(0.14, 0.34, 0.24))
	button.pressed.connect(callback)
	action_area.add_child(button)


func _begin_card_drag(card_id: int) -> void:
	is_drag_selecting = true
	drag_selection_state = not selected_cards.has(card_id)
	_set_card_selected(card_id, drag_selection_state)


func _drag_select_card(card_id: int) -> void:
	if is_drag_selecting:
		_set_card_selected(card_id, drag_selection_state)


func _set_card_selected(card_id: int, is_selected: bool) -> void:
	var currently_selected := selected_cards.has(card_id)
	if currently_selected == is_selected:
		return
	if is_selected:
		selected_cards.append(card_id)
	else:
		selected_cards.erase(card_id)
	var button: Button = hand_card_buttons.get(card_id)
	if button == null:
		return
	button.position.y = 8.0 if is_selected else 24.0
	var style: StyleBoxFlat = hand_card_styles[card_id]
	style.border_color = Color(0.91, 0.75, 0.42) if is_selected else Color(0.73, 0.7, 0.6)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_drag_selecting = false


func _submit_bid(score: int) -> void:
	if score > 0:
		highest_bid = score
		landlord = turn
		status_text = PLAYER_NAMES[turn] + "叫了 " + str(score) + " 分"
	else:
		status_text = PLAYER_NAMES[turn] + "不叫"
	bid_turns += 1
	sounds["score_" + str(score)].play()
	if highest_bid == 3:
		_begin_robbing()
	elif bid_turns >= 3:
		if highest_bid == 0:
			status_text = "无人叫分，重新发牌"
			_render()
			_start_round()
		else:
			_begin_robbing()
	else:
		turn = _next_seat(turn)
		_render()


func _begin_robbing() -> void:
	phase = Phase.ROBBING
	multiplier = maxi(1, highest_bid)
	rob_queue = [_next_seat(landlord), _next_seat(_next_seat(landlord))]
	status_text = PLAYER_NAMES[landlord] + "成为当前地主，其他玩家可抢地主"
	_advance_rob_queue()


func _submit_rob(claim: bool) -> void:
	if claim:
		landlord = turn
		multiplier *= 2
		status_text = PLAYER_NAMES[turn] + "抢到了地主，倍数翻倍"
		sounds["rob_1"].play()
	else:
		status_text = PLAYER_NAMES[turn] + "选择不抢"
		sounds["rob_0"].play()
	_advance_rob_queue()


func _advance_rob_queue() -> void:
	if rob_queue.is_empty():
		phase = Phase.PLAYING
		hands[landlord].append_array(bottom_cards)
		hands[landlord].sort_custom(Callable(self, "_card_sort"))
		turn = landlord
		last_cards.clear()
		last_player = -1
		pass_count = 0
		status_text = PLAYER_NAMES[landlord] + "拿到底牌，开始出牌"
	else:
		turn = rob_queue.pop_front()
	_render()


func _play_selected() -> void:
	if selected_cards.is_empty():
		status_text = "请先选择要出的牌"
		_render()
		return
	var combo: Dictionary = _combo_info(selected_cards)
	if combo.is_empty():
		status_text = "牌型不符合规则"
		_render()
		return
	var target: Dictionary = _combo_info(last_cards) if not last_cards.is_empty() else {}
	if not _beats(combo, target):
		status_text = "需要打出更大的同类型牌"
		_render()
		return
	var played := selected_cards.duplicate()
	for card_id in played:
		hands[0].erase(card_id)
	selected_cards.clear()
	last_cards = played
	played_cards_by_seat[0] = played.duplicate()
	last_player = 0
	pass_count = 0
	status_text = "你打出牌：" + _cards_text(last_cards)
	_check_round_end(0)
	if phase != Phase.FINISHED:
		turn = _next_seat(0)
	_render()


func _pass_turn() -> void:
	if last_cards.is_empty() or last_player == 0:
		return
	status_text = PLAYER_NAMES[0] + "不出"
	pass_count += 1
	turn = _next_seat(turn)
	if pass_count >= 2:
		turn = last_player
		last_cards.clear()
		_clear_played_cards()
		last_player = -1
		pass_count = 0
		status_text = PLAYER_NAMES[turn] + "重新取得出牌权"
	_render()


func _perform_ai_turn() -> void:
	await get_tree().create_timer(0.7).timeout
	ai_thinking = false
	if phase == Phase.FINISHED or turn == 0:
		return
	match phase:
		Phase.BIDDING:
			var score := _ai_bid_score(turn)
			_submit_bid(score if score > highest_bid else 0)
		Phase.ROBBING:
			var strength := _hand_strength(turn)
			_submit_rob(strength >= 7 and randi_range(0, 3) != 0)
		Phase.PLAYING:
			_ai_play()


func _schedule_ai_turn() -> void:
	if phase == Phase.FINISHED or turn == 0 or ai_thinking:
		return
	ai_thinking = true
	_perform_ai_turn()


func _ai_bid_score(player: int) -> int:
	var strength := _hand_strength(player)
	if strength >= 12:
		return 3
	if strength >= 8:
		return 2
	if strength >= 4:
		return 1
	return 0


func _hand_strength(player: int) -> int:
	var counts: Dictionary = {}
	var score := 0
	for card_id in hands[player]:
		var rank := _rank(card_id)
		counts[rank] = counts.get(rank, 0) + 1
		if rank == 17:
			score += 4
		elif rank == 16:
			score += 3
		elif rank == 15:
			score += 2
		elif rank == 14:
			score += 1
	for count in counts.values():
		if count == 4:
			score += 4
		elif count == 3:
			score += 2
	return score


func _ai_play() -> void:
	var play: Array[int] = []
	if last_cards.is_empty():
		play = [hands[turn][0]]
	else:
		var target: Dictionary = _combo_info(last_cards)
		play = _find_beating_combo(turn, target)
	if play.is_empty():
		pass_count += 1
		status_text = PLAYER_NAMES[turn] + "不出"
		turn = _next_seat(turn)
		if pass_count >= 2:
			turn = last_player
			last_cards.clear()
			_clear_played_cards()
			last_player = -1
			pass_count = 0
			status_text = PLAYER_NAMES[turn] + "重新取得出牌权"
	else:
		for card_id in play:
			hands[turn].erase(card_id)
		last_cards = play
		played_cards_by_seat[turn] = play.duplicate()
		last_player = turn
		pass_count = 0
		status_text = PLAYER_NAMES[turn] + "打出牌：" + _cards_text(last_cards)
		_check_round_end(turn)
		if phase != Phase.FINISHED:
			turn = _next_seat(turn)
	_render()


func _find_beating_combo(player: int, target: Dictionary) -> Array[int]:
	var candidate := _search_combo(player, int(target.size), target, false)
	if not candidate.is_empty():
		return candidate
	if target.kind != "bomb":
		candidate = _search_combo(player, 4, target, true)
		if not candidate.is_empty():
			return candidate
	if target.kind != "rocket" and hands[player].has(52) and hands[player].has(53):
		return [52, 53]
	return []


func _search_combo(player: int, needed: int, target: Dictionary, bombs_only: bool) -> Array[int]:
	var best: Array[int] = []
	_collect_candidates(hands[player], 0, needed, [], target, bombs_only, best)
	return best


func _collect_candidates(hand: Array, start: int, needed: int, current: Array, target: Dictionary, bombs_only: bool, best: Array) -> void:
	if needed == 0:
		var combo: Dictionary = _combo_info(current)
		if not combo.is_empty() and (not bombs_only or combo.kind == "bomb") and _beats(combo, target):
			if best.is_empty() or int(combo.power) < int(_combo_info(best).power):
				best.clear()
				best.append_array(current)
		return
	for index in range(start, hand.size() - needed + 1):
		current.append(hand[index])
		_collect_candidates(hand, index + 1, needed - 1, current, target, bombs_only, best)
		current.pop_back()


func _combo_info(cards: Array) -> Dictionary:
	if cards.is_empty():
		return {}
	var counts: Dictionary = {}
	for card_id in cards:
		var rank := _rank(card_id)
		counts[rank] = counts.get(rank, 0) + 1
	var ranks: Array = counts.keys()
	ranks.sort()
	var frequencies: Array = counts.values()
	frequencies.sort()
	var combo_size := cards.size()
	if combo_size == 2 and ranks == [16, 17]:
		return {"kind": "rocket", "size": combo_size, "power": 17}
	if combo_size == 1:
		return {"kind": "single", "size": combo_size, "power": ranks[-1]}
	if combo_size == 2 and frequencies == [2]:
		return {"kind": "pair", "size": combo_size, "power": ranks[-1]}
	if combo_size == 3 and frequencies == [3]:
		return {"kind": "triple", "size": combo_size, "power": ranks[-1]}
	if combo_size == 4 and frequencies == [1, 3]:
		return {"kind": "triple_single", "size": combo_size, "power": _rank_with_count(counts, 3)}
	if combo_size == 4 and frequencies == [4]:
		return {"kind": "bomb", "size": combo_size, "power": ranks[-1]}
	if combo_size == 5 and frequencies == [2, 3]:
		return {"kind": "triple_pair", "size": combo_size, "power": _rank_with_count(counts, 3)}
	if combo_size >= 5 and frequencies.size() == combo_size and _is_consecutive(ranks):
		return {"kind": "straight", "size": combo_size, "power": ranks[-1]}
	if combo_size >= 6 and combo_size % 2 == 0 and frequencies.size() * 2 == combo_size and _all_counts(counts, 2) and _is_consecutive(ranks):
		return {"kind": "pair_straight", "size": combo_size, "power": ranks[-1]}
	if combo_size >= 6 and combo_size % 3 == 0 and frequencies.size() * 3 == combo_size and _all_counts(counts, 3) and _is_consecutive(ranks):
		return {"kind": "triple_straight", "size": combo_size, "power": ranks[-1]}
	return {}


func _beats(candidate: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		return true
	if candidate.kind == "rocket":
		return target.kind != "rocket"
	if target.kind == "rocket":
		return false
	if candidate.kind == "bomb":
		return target.kind != "bomb" or int(candidate.power) > int(target.power)
	return candidate.kind == target.kind and candidate.size == target.size and int(candidate.power) > int(target.power)


func _rank_with_count(counts: Dictionary, expected: int) -> int:
	for rank in counts:
		if counts[rank] == expected:
			return rank
	return 0


func _all_counts(counts: Dictionary, expected: int) -> bool:
	for count in counts.values():
		if count != expected:
			return false
	return true


func _is_consecutive(ranks: Array) -> bool:
	if ranks.is_empty() or ranks[-1] > 14:
		return false
	for index in range(1, ranks.size()):
		if ranks[index] != ranks[index - 1] + 1:
			return false
	return true


func _check_round_end(player: int) -> void:
	if not hands[player].is_empty():
		return
	phase = Phase.FINISHED
	var team_won := (player == landlord) == (landlord == 0)
	status_text = ("你方获胜" if team_won else "电脑获胜") + " · 倍数 ×" + str(multiplier)


func _phase_name() -> String:
	match phase:
		Phase.BIDDING:
			return "叫分阶段"
		Phase.ROBBING:
			return "抢地主阶段"
		Phase.PLAYING:
			return "出牌阶段"
		_:
			return "本局结束"


func _card_sort(left: int, right: int) -> bool:
	if _rank(left) == _rank(right):
		return left < right
	return _rank(left) < _rank(right)


func _rank(card_id: int) -> int:
	if card_id == 52:
		return 16
	if card_id == 53:
		return 17
	return card_id % 13 + 3


func _card_text(card_id: int) -> String:
	var rank := _rank(card_id)
	if rank == 16:
		return "小\n王"
	if rank == 17:
		return "大\n王"
	var rank_text := _rank_text(rank)
	return rank_text + "\n" + SUITS[floori(card_id / 13.0)]


func _cards_text(cards: Array) -> String:
	var result: Array[String] = []
	for card_id in cards:
		var rank := _rank(card_id)
		if rank == 16:
			result.append("小王")
		elif rank == 17:
			result.append("大王")
		else:
			var rank_text := _rank_text(rank)
			result.append(rank_text + SUITS[floori(card_id / 13.0)])
	return " ".join(result)


func _rank_text(rank: int) -> String:
	match rank:
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		14:
			return "A"
		15:
			return "2"
		_:
			return str(rank)


func _next_seat(seat: int) -> int:
	return (seat + 2) % 3


func _return_to_lobby() -> void:
	get_tree().change_scene_to_file("res://login.tscn")
