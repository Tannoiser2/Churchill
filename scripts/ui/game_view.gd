extends Control
## Vista di gioco. Due viste separate, mostrate quando servono: il tavolo della Conferenza
## (Agenda e Riunione) e la mappa dei fronti (Decisioni e guerra). La vista cambia da sola con la fase
## e si può cambiare a mano. In alto una fascia riassuntiva resta sempre visibile.

const D = preload("res://scripts/data/ch_data.gd")
const TOP_H := 64.0
const CONF_RECT := Rect2(10, 72, 980, 936)
const CRX := 1004.0
const CRW := 906.0
const MIL_RECT := Rect2(10, 72, 838, 1000)
const MRX := 862.0
const MRW := 1048.0
const SHORT := {"west": "OCC", "med": "MED", "east": "EST", "fe": "E.OR", "cbi": "CBI", "cp": "P.C.", "swp": "PSO"}

var main
var config: Dictionary
var engine: CHEngine
var online = null
var humans: Array = []
var hand_seat := -1
var pending: Dictionary = {}
var view := "conf"
var auto_view := true

# selezione
var sel_card := -1
var sel_leader := false

# nodi
var top: Control
var top_lbls := {}
var btn_view: Button
var conf_view: Control
var conf_layer: Control
var mil_view: Control
var mil_layer: Control
var conf_card_box: Control
var conf_card_tex: TextureRect
var conf_card_txt: RichTextLabel
var player_rows: VBoxContainer
var hand_box: Control
var hand_title: Label
var front_box: VBoxContainer
var mil_info: RichTextLabel
var action_box: PanelContainer
var action_msg: RichTextLabel
var action_row: HFlowContainer
var modal: Control
var toast: Control
var zoom: Control
var log_panel: PanelContainer
var log_text: RichTextLabel
var online_lbl: Label
var cover_for := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	online = config.get("online", null)
	var bg := ColorRect.new()
	bg.color = Color("#100d0a")
	bg.size = size
	add_child(bg)

	engine = CHEngine.new()
	add_child(engine)
	engine.setup(config)
	engine.ai_delay = config.get("ai_delay", 0.5)
	if online != null:
		humans = [online.seat]
		online.view = self
		add_child(online)
		engine.online = online
		if online.role != "host":
			online.heartbeat_loop()
	else:
		for p in engine.players:
			if not p["ai"]:
				humans.append(p["p"])
	hand_seat = humans[0] if humans.size() > 0 else -1
	engine.pause_enabled = humans.size() > 0

	_build_conf_view()
	_build_mil_view()
	_build_top()
	_build_action()
	_build_log()
	zoom = Control.new()
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom.visible = false
	add_child(zoom)
	modal = Control.new()
	modal.size = size
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal)
	toast = Control.new()
	toast.size = size
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	_build_online_label()

	engine.changed.connect(refresh)
	engine.log_added.connect(_on_log)
	engine.decision_requested.connect(_on_decision)
	engine.pause_requested.connect(_on_pause)
	engine.phase_changed.connect(_on_phase)
	engine.game_ended.connect(_on_game_end)
	engine.fx.connect(_on_fx)
	_set_view("conf")
	refresh()
	if online != null and online.catchup:
		online_status("Riprendo la partita dal punto in cui era…")
	engine.run.call_deferred()


func _exit_tree() -> void:
	if engine != null:
		engine.abort = true


# =================================================================== costruzione

func _panel(rect: Rect2, bg := Color("#17130eee"), border := Color("#4a3e28")) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", UI.panel_style(bg, border, 1, 6))
	return p


func _build_top() -> void:
	top = Control.new()
	top.size = Vector2(1920, TOP_H)
	add_child(top)
	var bar := Panel.new()
	bar.size = top.size
	bar.add_theme_stylebox_override("panel", UI.panel_style(Color("#0b0907"), UI.BRASS, 0, 0))
	top.add_child(bar)
	var line := ColorRect.new()
	line.color = UI.BRASS
	line.position = Vector2(0, TOP_H - 2)
	line.size = Vector2(1920, 2)
	top.add_child(line)
	var t1 := UI.label("", 22, UI.GOLD, UI.font_title)
	t1.position = Vector2(14, 4)
	top.add_child(t1)
	top_lbls["conf"] = t1
	var t2 := UI.label("", 19, Color("#e8dcc0"), UI.font_bold)
	t2.position = Vector2(14, 34)
	top.add_child(t2)
	top_lbls["phase"] = t2
	for p in range(3):
		var x := 420.0 + p * 188.0
		var chip := Panel.new()
		chip.position = Vector2(x, 6)
		chip.size = Vector2(182, 52)
		chip.add_theme_stylebox_override("panel", UI.panel_style(Color("#16120d"), UI.pcol(p), 2, 5))
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		top.add_child(chip)
		var a := UI.label("", 20, D.POWERS[p]["light"], UI.font_bold)
		a.position = Vector2(8, 2)
		chip.add_child(a)
		var b := UI.label("", 18, Color("#e8e0d0"))
		b.position = Vector2(8, 26)
		chip.add_child(b)
		top_lbls["p%d" % p] = [a, b, chip]
	var ab := UI.label("", 17, Color("#e8e0d0"))
	ab.position = Vector2(992, 4)
	top.add_child(ab)
	top_lbls["ab"] = ab
	var gl := UI.label("", 17, Color("#e8e0d0"))
	gl.position = Vector2(992, 32)
	top.add_child(gl)
	top_lbls["gl"] = gl
	var axis := UI.label("", 17, Color("#e8e0d0"))
	axis.position = Vector2(1262, 4)
	top.add_child(axis)
	top_lbls["axis"] = axis
	var cmd := UI.label("", 17, Color("#e8e0d0"))
	cmd.position = Vector2(1262, 32)
	top.add_child(cmd)
	top_lbls["cmd"] = cmd
	var hb := HBoxContainer.new()
	hb.position = Vector2(1530, 9)
	hb.add_theme_constant_override("separation", 6)
	top.add_child(hb)
	btn_view = UI.button("FRONTI", 130, 46, 19)
	btn_view.pressed.connect(func():
		auto_view = false
		_set_view("mil" if view == "conf" else "conf"))
	hb.add_child(btn_view)
	var b_log := UI.button("DIARIO", 80, 46, 18)
	b_log.pressed.connect(_toggle_log)
	hb.add_child(b_log)
	var b_rules := UI.button("REGOLE", 84, 46, 18)
	b_rules.pressed.connect(_show_rules_popup)
	hb.add_child(b_rules)
	var b_menu := UI.button("MENU", 70, 46, 18)
	b_menu.pressed.connect(_ask_quit)
	hb.add_child(b_menu)


func _build_conf_view() -> void:
	conf_view = Control.new()
	conf_view.size = size
	conf_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(conf_view)
	var fr := _panel(Rect2(CONF_RECT.position - Vector2(4, 4), CONF_RECT.size + Vector2(8, 8)), Color("#000000"), Color("#5a4a2a"))
	conf_view.add_child(fr)
	var img := TextureRect.new()
	img.texture = UI.tex("res://assets/conference.jpg")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.position = CONF_RECT.position
	img.size = CONF_RECT.size
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conf_view.add_child(img)
	conf_layer = Control.new()
	conf_layer.position = CONF_RECT.position
	conf_layer.size = CONF_RECT.size
	conf_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conf_view.add_child(conf_layer)
	# carta Conferenza
	conf_card_box = _panel(Rect2(CRX, 72, CRW, 300))
	conf_view.add_child(conf_card_box)
	conf_card_tex = TextureRect.new()
	conf_card_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	conf_card_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	conf_card_tex.position = Vector2(8, 8)
	conf_card_tex.size = Vector2(203, 284)
	conf_card_tex.mouse_filter = Control.MOUSE_FILTER_STOP
	conf_card_tex.mouse_entered.connect(func(): _show_zoom(conf_card_tex.texture, _conf_card_text(), Vector2(CRX - 330, 80)))
	conf_card_tex.mouse_exited.connect(_hide_zoom)
	conf_card_box.add_child(conf_card_tex)
	var sc := ScrollContainer.new()
	sc.position = Vector2(222, 8)
	sc.size = Vector2(CRW - 232, 284)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	conf_card_box.add_child(sc)
	conf_card_txt = UI.rich(18)
	conf_card_txt.custom_minimum_size = Vector2(CRW - 248, 0)
	sc.add_child(conf_card_txt)
	# giocatori
	player_rows = VBoxContainer.new()
	player_rows.position = Vector2(CRX, 380)
	player_rows.size = Vector2(CRW, 250)
	player_rows.add_theme_constant_override("separation", 6)
	conf_view.add_child(player_rows)
	# mano
	hand_box = _panel(Rect2(CRX, 834, CRW, 238))
	conf_view.add_child(hand_box)
	hand_title = UI.label("", 19, UI.MUTED, UI.font_bold)
	hand_title.position = Vector2(12, 4)
	hand_box.add_child(hand_title)


func _build_mil_view() -> void:
	mil_view = Control.new()
	mil_view.size = size
	mil_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mil_view)
	var fr := _panel(Rect2(MIL_RECT.position - Vector2(4, 4), MIL_RECT.size + Vector2(8, 8)), Color("#000000"), Color("#5a4a2a"))
	mil_view.add_child(fr)
	var img := TextureRect.new()
	img.texture = UI.tex("res://assets/military.jpg")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.position = MIL_RECT.position
	img.size = MIL_RECT.size
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mil_view.add_child(img)
	mil_layer = Control.new()
	mil_layer.position = MIL_RECT.position
	mil_layer.size = MIL_RECT.size
	mil_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mil_view.add_child(mil_layer)
	var rp := _panel(Rect2(MRX, 72, MRW, 560))
	mil_view.add_child(rp)
	var tt := UI.title("I FRONTI", 26)
	tt.position = Vector2(14, 6)
	rp.add_child(tt)
	front_box = VBoxContainer.new()
	front_box.position = Vector2(12, 46)
	front_box.size = Vector2(MRW - 24, 500)
	front_box.add_theme_constant_override("separation", 3)
	rp.add_child(front_box)
	var ip := _panel(Rect2(MRX, 640, MRW, 226))
	mil_view.add_child(ip)
	var sc := ScrollContainer.new()
	sc.position = Vector2(10, 8)
	sc.size = Vector2(MRW - 20, 210)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ip.add_child(sc)
	mil_info = UI.rich(18)
	mil_info.custom_minimum_size = Vector2(MRW - 40, 0)
	sc.add_child(mil_info)


func _build_action() -> void:
	action_box = PanelContainer.new()
	action_box.add_theme_stylebox_override("panel", UI.panel_style(Color("#211a10f4"), UI.GOLD, 2, 8))
	add_child(action_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	action_box.add_child(vb)
	action_msg = UI.rich(20)
	vb.add_child(action_msg)
	action_row = HFlowContainer.new()
	action_row.add_theme_constant_override("h_separation", 8)
	action_row.add_theme_constant_override("v_separation", 6)
	vb.add_child(action_row)
	action_box.visible = false


func _layout_action() -> void:
	if view == "conf":
		action_box.position = Vector2(CRX, 640)
		action_box.custom_minimum_size = Vector2(CRW, 186)
		action_box.size = Vector2(CRW, 186)
		action_msg.custom_minimum_size = Vector2(CRW - 24, 0)
	else:
		action_box.position = Vector2(MRX, 874)
		action_box.custom_minimum_size = Vector2(MRW, 198)
		action_box.size = Vector2(MRW, 198)
		action_msg.custom_minimum_size = Vector2(MRW - 24, 0)


func _build_log() -> void:
	log_panel = PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", UI.panel_style(Color("#0c0a08f4"), UI.GOLD, 2, 8))
	log_panel.position = Vector2(1060, 72)
	log_panel.size = Vector2(850, 1000)
	log_panel.custom_minimum_size = Vector2(850, 1000)
	log_panel.visible = false
	add_child(log_panel)
	var vb := VBoxContainer.new()
	log_panel.add_child(vb)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	var t := UI.title("DIARIO DELLA PARTITA", 26)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	var c := UI.button("CHIUDI", 120, 44, 20)
	c.pressed.connect(_toggle_log)
	hb.add_child(c)
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.custom_minimum_size = Vector2(820, 920)
	log_text.add_theme_font_size_override("normal_font_size", 19)
	log_text.add_theme_font_size_override("bold_font_size", 19)
	vb.add_child(log_text)


func _toggle_log() -> void:
	log_panel.visible = not log_panel.visible
	if log_panel.visible:
		log_text.text = "\n".join(engine.log_lines)
		log_panel.move_to_front()


func _on_log(t: String) -> void:
	if log_panel.visible:
		log_text.append_text("\n" + t)
	if pending.is_empty() and engine.phase != "end":
		# cronaca: le ultime righe del diario mentre giocano gli altri
		_clear_actions()
		var n := engine.log_lines.size()
		var lines := []
		for k in range(maxi(0, n - 4), n):
			lines.append(engine.log_lines[k])
		action_msg.text = "[color=#bfb39a]" + "\n".join(lines) + "[/color]"
		action_box.visible = true
		_fit_action.call_deferred()


# =================================================================== viste

func _set_view(v: String) -> void:
	view = v
	conf_view.visible = v == "conf"
	mil_view.visible = v == "mil"
	btn_view.text = "MAPPA DEI FRONTI" if v == "conf" else "TAVOLO"
	btn_view.custom_minimum_size.x = 130
	_layout_action()
	refresh()


func _phase_view(ph: String) -> String:
	return "conf" if ph in ["agenda", "meeting"] else "mil"


func _on_phase(_c: int, ph: String) -> void:
	auto_view = true
	_set_view(_phase_view(ph))


func _want_view(v: String) -> void:
	if auto_view and view != v:
		_set_view(v)


# =================================================================== aggiornamento

func refresh() -> void:
	if engine == null or engine.players.is_empty():
		return
	_refresh_top()
	if view == "conf":
		_refresh_conf()
	else:
		_refresh_mil()


func _phase_name() -> String:
	match engine.phase:
		"agenda": return "Agenda" + (": scelta della carta" if engine.step == "agenda_card" else ": scelta dei temi")
		"meeting": return "Riunione: avanzare e dibattere i temi"
		"decision":
			return "Decisioni: " + {"do": "offensive dirette", "production": "produzione", "alloc": "assegnazione della produzione",
				"leadership": "comando dei teatri", "abomb": "ricerca Bomba A", "global": "tema Globale"}.get(engine.step, "esito della conferenza")
		"war":
			return "Guerra: " + {"cn": "reti clandestine", "pa": "allineamenti politici", "military": "riserve dell'Asse e fronti"}.get(engine.step, "")
		"end": return "Fine della partita"
	return ""


func _refresh_top() -> void:
	var e := engine
	var n_conf := e.conf_list.size()
	top_lbls["conf"].text = ("CONFERENZA %d · %s" % [e.conf_no, D.CONF_NAMES[e.conf_no]]) if e.conf_no > 0 else "CHURCHILL"
	top_lbls["phase"].text = "%s · %s · %d di %d" % [D.CONF_DATES[e.conf_no] if e.conf_no > 0 else "", _phase_name(), e.conf_i + 1, n_conf]
	var vp := e.compute_vp()
	for p in range(3):
		var arr: Array = top_lbls["p%d" % p]
		var pl: Dictionary = e.players[p]
		var lname: String = str(pl["leader"]).capitalize()
		var st := "" if e.leader_active(p) else " ·inattivo"
		arr[0].text = "%s%s" % [lname, st]
		var won := ""
		if e.phase == "meeting":
			won = " · temi %d" % _count_track(p)
		elif not e.won_by.is_empty():
			won = " · temi %d" % e.issues_won(p)
		arr[1].text = "%d PV · conf. %d%s" % [vp[p]["tot"], pl["wins"], won]
		var tip := "%s (%s)\n" % [pl["name"], D.POWERS[p]["nation"]]
		for r in vp[p]["rows"]:
			tip += "%+d  %s\n" % [r[1], r[0]]
		tip += "Totale: %d PV (se la partita finisse ora)" % vp[p]["tot"]
		arr[2].tooltip_text = tip
		var win: bool = e.conf_winner == p and e.phase in ["decision", "war"]
		arr[2].add_theme_stylebox_override("panel", UI.panel_style(Color("#3a2e14") if win else Color("#16120d"), UI.GOLD if win else UI.pcol(p), 3 if win else 2, 5))
	top_lbls["ab"].text = "Bomba A: %s" % D.ABOMB[e.abomb]
	top_lbls["ab"].tooltip_text = "Bomba A (USA): %s\nRete di spie sovietica: %s" % [D.ABOMB[e.abomb], D.ABOMB[e.spy]]
	top_lbls["ab"].mouse_filter = Control.MOUSE_FILTER_STOP
	var gc := [0, 0, 0]
	for g in range(3):
		if e.glob[g] >= 0:
			gc[e.glob[g]] += 1
	top_lbls["gl"].text = "Spie: %s · Globali UK %d USA %d URSS %d" % [["–", "Oak R.", "Hanford", "Los Alamos", "Trinity"][e.spy], gc[0], gc[1], gc[2]]
	top_lbls["gl"].tooltip_text = _globals_tip()
	top_lbls["gl"].mouse_filter = Control.MOUSE_FILTER_STOP
	var ax := []
	ax.append("Germania %s" % ("ARRESA" if e.germany_surr else "in guerra"))
	ax.append("Giappone %s" % ("ARRESO" if e.japan_surr else "in guerra"))
	top_lbls["axis"].text = " · ".join(ax)
	top_lbls["cmd"].text = "Comandi: Europa %s · Pacifico %s" % [D.POWERS[e.lead["eu"]]["short"], D.POWERS[e.lead["pa"]]["short"]]


func _globals_tip() -> String:
	var s := ""
	for g in range(3):
		var k: int = engine.glob[g]
		s += "%s: %s\n" % [D.GLOBALS[g]["n"], D.GLOBALS[g]["neutral"] if k < 0 else D.GLOBAL_TEXT["%d:%d" % [g, k]]]
	return s.strip_edges()


func _count_track(p: int) -> int:
	var n := 0
	for i in engine.table:
		if engine.table[i]["o"] == p and engine.table[i]["d"] > 0:
			n += 1
	return n


# ------------------------------------------------------------------- tavolo della conferenza

func _cpos(frac: Vector2) -> Vector2:
	return frac * CONF_RECT.size


func _refresh_conf() -> void:
	var e := engine
	for c in conf_layer.get_children():
		c.queue_free()
	var tok := Vector2(54, 50)
	var clickable := _clickable_issues()
	# temi disponibili (caselle in alto a destra)
	for i in range(D.ISSUES.size()):
		var id: String = D.ISSUES[i]["id"]
		if e.table.has(i):
			continue
		var pos := _cpos(D.ISSUE_SLOTS[id] / Vector2(D.CONF_W, D.CONF_H))
		var dim := not e.issue_available(i)
		_issue_token(i, pos, Vector2(46, 43), clickable.has(i), dim)
	# temi sul tavolo
	var groups := {}
	var center := []
	for i in e.table:
		var t: Dictionary = e.table[i]
		if t["d"] == 0:
			center.append(i)
			continue
		var key := "%d:%d" % [t["o"], mini(t["d"], 7)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)
	center.sort()
	# centro: griglia sotto il cerchio centrale
	if not center.is_empty():
		var cols := 5
		var ts := Vector2(46, 43) if center.size() <= 15 else Vector2(40, 37)
		var rows := int(ceil(center.size() / float(cols)))
		var c0 := _cpos(D.conf_pos(-1, 0)) + Vector2(0, 70)
		var w := cols * (ts.x + 4)
		var bgp := Panel.new()
		bgp.position = c0 + Vector2(-w / 2 - 6, 30)
		bgp.size = Vector2(w + 12, rows * (ts.y + 4) + 30)
		bgp.add_theme_stylebox_override("panel", UI.panel_style(Color("#0c0a08cc"), Color("#c8b27a"), 1, 8))
		bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		conf_layer.add_child(bgp)
		var lb := UI.label("CENTRO DEL TAVOLO", 15, Color("#d8c89a"), UI.font_bold)
		lb.position = bgp.position + Vector2(8, 3)
		conf_layer.add_child(lb)
		for k in range(center.size()):
			var cx := c0.x - w / 2 + (k % cols) * (ts.x + 4) + ts.x / 2 + 2
			var cy := c0.y + 56 + (k / cols) * (ts.y + 4) + ts.y / 2
			_issue_token(center[k], Vector2(cx, cy), ts, clickable.has(center[k]), false)
	for key in groups:
		var arr: Array = groups[key]
		arr.sort()
		var parts: PackedStringArray = key.split(":")
		var o := int(parts[0])
		var d := int(parts[1])
		var base := _cpos(D.conf_pos(o, d))
		for k in range(arr.size()):
			var off := Vector2(k * 14, -k * 12)
			if d >= 7:
				off = Vector2((k % 4) * 46 - 69, (k / 4) * 44 + (40 if o == 0 else -70))
			_issue_token(arr[k], base + off, tok, clickable.has(arr[k]), false)
	# temi Globali
	for g in range(3):
		var gp: Vector2 = D.GLOBAL_POS[g][e.glob[g]]
		var pw := Panel.new()
		var c := _cpos(gp / Vector2(D.CONF_W, D.CONF_H))
		pw.position = c - Vector2(13, 13)
		pw.size = Vector2(26, 26)
		var col := Color("#111111") if e.glob[g] < 0 else UI.pcol(e.glob[g])
		pw.add_theme_stylebox_override("panel", UI.panel_style(col, Color("#f0e0b0"), 2, 13))
		pw.tooltip_text = _globals_tip()
		conf_layer.add_child(pw)
	# Leader: attivo o inattivo sulle sedie
	for p in range(3):
		var cp: Vector2 = _cpos(D.CHAIR_POS[p] / Vector2(D.CONF_W, D.CONF_H))
		var badge := UI.label("ATTIVO" if e.leader_active(p) else "INATTIVO", 15, Color.WHITE, UI.font_bold)
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", UI.panel_style(Color("#1d6b2c") if e.leader_active(p) else Color("#5a1f17"), Color("#f0e0b0"), 1, 4))
		bp.add_child(badge)
		bp.position = cp + Vector2(-34, 52 if p == 0 else 60)
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		conf_layer.add_child(bp)
	_refresh_conf_card()
	_refresh_players()
	_refresh_hand()


func _issue_token(i: int, pos: Vector2, sz: Vector2, click: bool, dim: bool) -> void:
	var c := Panel.new()
	c.position = pos - sz / 2
	c.size = sz
	var border := UI.GOLD if click else Color("#000000")
	c.add_theme_stylebox_override("panel", UI.panel_style(Color("#000000"), border, 3 if click else 1, 4))
	var tr := UI.icon_rect(UI.issue_tex(i), sz - Vector2(4, 4))
	tr.position = Vector2(2, 2)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	c.add_child(tr)
	if dim:
		c.modulate = Color(0.35, 0.35, 0.35, 0.7)
	c.tooltip_text = _issue_tip(i)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	if click:
		var glow := ColorRect.new()
		glow.color = Color(1, 0.85, 0.3, 0.18)
		glow.size = sz
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(glow)
		c.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_issue_click(i))
	if engine.table.has(i) and engine.table[i]["cap"]:
		var ck := UI.label("C", 16, Color.WHITE, UI.font_bold)
		ck.position = Vector2(sz.x - 14, -4)
		c.add_child(ck)
	conf_layer.add_child(c)


func _issue_tip(i: int) -> String:
	var d: Dictionary = D.ISSUES[i]
	var s: String = d["n"] + "\n"
	match d["k"]:
		"prod": s += "Chi lo vince (se non è il Regno Unito/gli USA della bandiera) prende 1 Produzione a %s." % D.POWERS[d["f"]]["nation"]
		"do": s += "Chi lo vince lo piazza sullo spazio d'ingresso di un fronte: %s deve spendervi 2 Produzione." % D.POWERS[d["f"]]["nation"]
		"polmil": s += "Chi lo vince può attivarlo con 1 Produzione: %d Allineamenti Politici e %d Reti Clandestine." % [d["pa"], d["cn"]]
		"global": s += "Chi lo vince sposta dalla sua parte uno dei suoi due marcatori Globali (5 PV ciascuno)."
		"abomb": s += "Chi lo vince tira 1d6 (+1 per Produzione investita): con 4-6 la Bomba A avanza. Se lo vince l'URSS avanzano anche le spie."
		"strat": s += "Al centro: +1 Produzione a tutti. Vinto: +1 Produzione a chi lo vince."
		"euro", "pac": s += "Chi lo vince riceve 2 supporti nel teatro e decide se lo comandano gli USA o il Regno Unito."
		"cond":
			if d["id"] == "second":
				s += "Condizionale: solo se finisce al CENTRO il Fronte Occidentale può tentare lo sbarco in Normandia."
			else:
				s += "Condizionale: solo se finisce al CENTRO il Fronte dell'Estremo Oriente può entrare in Manciuria."
	if engine.table.has(i):
		s += "\nPosizione: " + engine.pos_text(engine.table[i])
	elif engine.removed_issues.has(i):
		s += "\n(tolto dal gioco)"
	elif engine.blocked_issues.has(i):
		s += "\n(non disponibile in questa conferenza)"
	return s


func _conf_card_text() -> String:
	if engine.card < 0:
		return ""
	var bands := ["#3d6b2a", "#7a2a22", "#2a4f7a", "#55524c", "#d8d0bc"]
	var who := ["Churchill", "Stalin", "Roosevelt", "Situazione militare", "Reti e allineamenti"]
	var s := ""
	var effs: Array = D.CONF_CARDS[engine.card]
	for k in range(effs.size()):
		s += "[color=%s]•[/color] [b]%s[/b] – %s\n" % [bands[k], who[k], effs[k]["x"]]
	return s.strip_edges()


func _refresh_conf_card() -> void:
	var e := engine
	if e.card < 0:
		conf_card_tex.texture = UI.tex("res://assets/cards/back_conf.jpg")
		conf_card_txt.text = ""
		return
	conf_card_tex.texture = UI.conf_tex(e.card)
	conf_card_txt.text = "[font_size=22][color=#d9b45a][b]%d · %s %s[/b][/color][/font_size]  [i]%s[/i]\n%s" % [e.conf_no, D.CONF_NAMES[e.conf_no], D.conf_variant(e.card), D.CONF_DATES[e.conf_no], _conf_card_text()]


func _refresh_players() -> void:
	var e := engine
	for c in player_rows.get_children():
		c.queue_free()
	for p in [0, 2, 1]:
		var pl: Dictionary = e.players[p]
		var row := Panel.new()
		row.custom_minimum_size = Vector2(CRW, 78)
		var active: bool = e.current == p and not pending.is_empty() and int(pending.get("seat", -1)) == p
		row.add_theme_stylebox_override("panel", UI.panel_style(Color("#1d1811ee") if not active else Color("#3a2e14ee"), UI.pcol(p), 3 if active else 1, 6))
		player_rows.add_child(row)
		var por := UI.icon_rect(UI.portrait(pl["leader"]), Vector2(80, 70))
		por.position = Vector2(4, 4)
		if not e.leader_active(p):
			por.modulate = Color(0.45, 0.45, 0.45)
		row.add_child(por)
		var nm := UI.label("%s · %s" % [str(pl["leader"]).capitalize(), pl["name"]] if pl["name"] != str(pl["leader"]).capitalize() else str(pl["leader"]).capitalize(), 22, D.POWERS[p]["light"], UI.font_bold)
		nm.position = Vector2(92, 2)
		row.add_child(nm)
		var info := []
		info.append("Leader %s" % ("attivo" if e.leader_active(p) else "inattivo"))
		info.append("%d carte in mano" % pl["hand"].size())
		if e.phase == "meeting":
			info.append("temi sul suo lato: %d" % _count_track(p))
		if pl["no_adv"]:
			info.append("il Leader non può avanzare")
		if pl["pass_ok"]:
			info.append("può passare")
		if p == 2 and pl["paranoia"]:
			info.append("PARANOIA")
		if pl["heart"]:
			info.append("infarto")
		var il := UI.label(" · ".join(info), 19, Color("#e0d8c8"))
		il.position = Vector2(92, 30)
		row.add_child(il)
		var il2 := UI.label("Produzione %d · Reti da piazzare %d · Allineamenti %d · tecnologie %d · morti %d" % [pl["prod"], pl["cn_gain"], pl["pa_gain"], pl["tech"], pl["dead"].size()], 16, UI.MUTED)
		il2.position = Vector2(92, 54)
		row.add_child(il2)
		# carta giocata nell'Agenda
		if e.agenda_play.has(p) and e.phase == "agenda":
			var ap: Dictionary = e.agenda_play[p]
			var show: bool = e.step != "agenda_card" or p in humans and (online != null or humans.size() == 1)
			var t: Texture2D = UI.staff_tex(p, ap["card"]) if show else UI.back_tex(p)
			var cr := UI.icon_rect(t, Vector2(52, 73))
			cr.position = Vector2(CRW - 120, 3)
			row.add_child(cr)
			if e.step != "agenda_card":
				var vl := UI.label(str(ap["v"]), 30, UI.GOLD, UI.font_title)
				vl.position = Vector2(CRW - 60, 18)
				row.add_child(vl)


func _refresh_hand() -> void:
	for c in hand_box.get_children():
		if c != hand_title:
			c.queue_free()
	var e := engine
	var p := _visible_hand()
	if p < 0:
		hand_title.text = "Le carte in mano restano nascoste." if cover_for >= 0 else "Partita fra IA: le carte in mano restano nascoste."
		return
	var hand: Array = e.players[p]["hand"]
	hand_title.text = "Carte di %s (%d) · passa sopra una carta per leggerla" % [str(e.players[p]["leader"]).capitalize(), hand.size()]
	var clickable := _hand_clickable()
	var cw := 106.0
	var ch := 148.0
	for k in range(hand.size()):
		var cid: int = hand[k]
		var x := 10.0 + k * (cw + 6)
		var c := Control.new()
		c.position = Vector2(x, 34 - (14 if k == sel_card else 0))
		c.size = Vector2(cw, ch)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		var tr := UI.icon_rect(UI.staff_tex(p, cid), Vector2(cw, ch))
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		c.add_child(tr)
		var fr := Panel.new()
		fr.size = c.size
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bc := UI.GOLD if k == sel_card else (Color("#7fd36f") if clickable else Color("#000000"))
		fr.add_theme_stylebox_override("panel", _frame(bc, 4 if k == sel_card else (2 if clickable else 1)))
		c.add_child(fr)
		c.mouse_entered.connect(func(): _show_zoom(UI.staff_tex(p, cid), _staff_text(p, cid), Vector2(CRX - 330, 420)))
		c.mouse_exited.connect(_hide_zoom)
		if clickable:
			c.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_on_card_click(k))
		hand_box.add_child(c)
	# Leader
	var lx := 10.0 + 7 * (cw + 6) + 6
	var lc := UI.icon_rect(UI.leader_tex(e.players[p]["leader"]), Vector2(CRW - lx - 10, ch))
	lc.position = Vector2(lx, 34)
	lc.mouse_filter = Control.MOUSE_FILTER_STOP
	if not e.leader_active(p):
		lc.modulate = Color(0.4, 0.4, 0.4)
	var ln: String = e.players[p]["leader"]
	lc.mouse_entered.connect(func(): _show_zoom(UI.leader_tex(ln), D.LEADER_TEXT[ln], Vector2(CRX - 330, 420)))
	lc.mouse_exited.connect(_hide_zoom)
	hand_box.add_child(lc)
	if sel_leader:
		var fr2 := Panel.new()
		fr2.position = lc.position
		fr2.size = lc.size
		fr2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fr2.add_theme_stylebox_override("panel", _frame(UI.GOLD, 4))
		hand_box.add_child(fr2)


func _frame(c: Color, w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = c
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(6)
	return sb


func _staff_text(p: int, cid: int) -> String:
	var sd: Dictionary = D.STAFF[p][cid]
	var v := "1d6 (Capo di S.M.)" if int(sd["v"]) == 0 else str(sd["v"])
	return "[b]%s[/b] – %s\n[i]%s[/i]\n%s" % [sd["n"], v, sd["r"], sd["t"]]


func _visible_hand() -> int:
	if online != null:
		return online.seat
	if cover_for >= 0:
		return -1
	if humans.is_empty():
		return -1
	if not pending.is_empty() and int(pending["seat"]) in humans:
		return int(pending["seat"])
	if humans.size() == 1:
		return humans[0]
	return hand_seat


func _show_zoom(t: Texture2D, txt: String, at: Vector2) -> void:
	for c in zoom.get_children():
		c.queue_free()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(Color("#120f0af6"), UI.GOLD, 2, 8))
	box.position = at
	zoom.add_child(box)
	var vb := VBoxContainer.new()
	box.add_child(vb)
	var tr := UI.icon_rect(t, Vector2(300, 420))
	vb.add_child(tr)
	var r := UI.rich(18)
	r.custom_minimum_size = Vector2(300, 0)
	r.text = txt
	vb.add_child(r)
	zoom.visible = true
	zoom.move_to_front()


func _hide_zoom() -> void:
	zoom.visible = false


# ------------------------------------------------------------------- mappa dei fronti

func _mpos(key: String) -> Vector2:
	return D.mil_pos(key) * MIL_RECT.size


func _refresh_mil() -> void:
	var e := engine
	for c in mil_layer.get_children():
		c.queue_free()
	var targets := _map_targets()
	# paesi: reti e allineamenti
	for c in D.COUNTRY_ORDER:
		var cc: Dictionary = e.countries[c]
		var pos := _mpos(c)
		if cc["cn"] > 0:
			for k in range(cc["cn"]):
				var dsc := Panel.new()
				dsc.size = Vector2(18, 18)
				dsc.position = pos + Vector2(-26 + k * 20, 6)
				dsc.add_theme_stylebox_override("panel", UI.panel_style(UI.pcol(cc["cn_p"]), Color("#f4ecd8"), 2, 9))
				dsc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mil_layer.add_child(dsc)
		if cc["pa"] >= 0:
			var pa := Panel.new()
			pa.size = Vector2(22, 26)
			pa.position = pos + Vector2(10, -2)
			pa.add_theme_stylebox_override("panel", UI.panel_style(UI.pcol(cc["pa"]), Color("#101010"), 2, 4))
			pa.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mil_layer.add_child(pa)
			var al := UI.label("AP", 12, Color.WHITE, UI.font_bold)
			al.position = Vector2(3, 3)
			pa.add_child(al)
		var hot := Control.new()
		hot.size = Vector2(52, 46)
		hot.position = pos - Vector2(26, 23)
		hot.mouse_filter = Control.MOUSE_FILTER_STOP
		hot.tooltip_text = _country_tip(c)
		mil_layer.add_child(hot)
		if targets.has("c:" + c):
			_target_ring(pos, Vector2(56, 50), targets["c:" + c])
	# riquadri: supporti navali
	for b in D.BOXES:
		var pos2 := _mpos("box:" + b)
		if e.naval[b] > 0:
			_badge(pos2 + Vector2(-34, 8), "naval", str(e.naval[b]), Color("#2a5aa8"))
		if targets.has("b:" + b):
			_target_ring(pos2, Vector2(70, 60), targets["b:" + b])
	# fronti
	var at_space := {}
	for fi in range(e.fronts.size()):
		var f: Dictionary = e.fronts[fi]
		var sp := e.space_of(fi)
		var key: String = ("box:" + D.FRONTS[fi]["box"]) if sp == "" else sp
		var k: int = at_space.get(key, 0)
		at_space[key] = k + 1
		var pos3 := _mpos(key) + Vector2(k * 22 - (8 if k > 0 else 0), k * 16 - 6)
		var mk := Panel.new()
		mk.size = Vector2(52, 26)
		mk.position = pos3 - mk.size / 2
		mk.add_theme_stylebox_override("panel", UI.panel_style(UI.pcol(D.FRONTS[fi]["who"]), Color("#f4ecd8"), 2, 4))
		mk.tooltip_text = _front_tip(fi)
		mil_layer.add_child(mk)
		var ml := UI.label(SHORT[D.FRONTS[fi]["id"]], 15, Color.WHITE, UI.font_bold)
		ml.position = Vector2(4, 1)
		mk.add_child(ml)
		var en := e.entry(fi)
		if en == "":
			continue
		var ep := _mpos(en)
		if fi == 0 and en == "germany":
			ep += Vector2(-30, 26)
		elif fi == 2 and en == "germany":
			ep += Vector2(30, 26)
		if f["off"] > 0:
			_badge(ep + Vector2(-34, 10), "offensive", str(f["off"]), Color("#6b5a3a"))
		if f["res"] > 0 and e.phase in ["war", "agenda", "meeting", "decision"]:
			_cubes(ep + Vector2(8, 10), f["res"], Color("#111111") if D.FRONTS[fi]["th"] == "eu" else Color("#b8a27a"))
		for dd in f["do"]:
			var dm := Panel.new()
			dm.size = Vector2(30, 20)
			dm.position = ep + Vector2(-15 + f["do"].find(dd) * 8, -34)
			dm.add_theme_stylebox_override("panel", UI.panel_style(UI.pcol(dd["flag"]), Color("#ffe080"), 2, 3))
			dm.tooltip_text = "Offensiva Diretta di %s (2 Produzione)" % D.POWERS[dd["flag"]]["nation"]
			mil_layer.add_child(dm)
			var dl := UI.label("OD", 12, Color.WHITE, UI.font_bold)
			dl.position = Vector2(5, 1)
			dm.add_child(dl)
		if targets.has("f:%d" % fi):
			_target_ring(ep, Vector2(64, 54), targets["f:%d" % fi])
	# comando dei teatri
	for th in ["eu", "pa"]:
		var cpos := _mpos("cmd:" + th) + Vector2(0, 44)
		var cm := Panel.new()
		cm.size = Vector2(50, 26)
		cm.position = cpos - cm.size / 2
		cm.add_theme_stylebox_override("panel", UI.panel_style(UI.pcol(e.lead[th]), Color("#f4ecd8"), 2, 13))
		mil_layer.add_child(cm)
		var cl := UI.label(D.POWERS[e.lead[th]]["short"], 14, Color.WHITE, UI.font_bold)
		cl.position = Vector2(8, 2)
		cm.add_child(cl)
	# Bomba A e spie
	var abp := _mpos("ab%d" % e.abomb) + Vector2(-14, 0)
	_pawn(abp, UI.pcol(1), "Bomba A (USA): %s" % D.ABOMB[e.abomb])
	var spp := _mpos("ab%d" % e.spy) + Vector2(14, 0)
	_pawn(spp, UI.pcol(2), "Rete di spie sovietica: %s" % D.ABOMB[e.spy])
	_refresh_fronts_panel()


func _badge(pos: Vector2, icon: String, txt: String, col: Color) -> void:
	var b := Panel.new()
	b.size = Vector2(46, 24)
	b.position = pos
	b.add_theme_stylebox_override("panel", UI.panel_style(col, Color("#f4ecd8"), 1, 4))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mil_layer.add_child(b)
	var ic := UI.icon_rect(UI.icon(icon), Vector2(22, 20))
	ic.position = Vector2(2, 2)
	b.add_child(ic)
	var l := UI.label(txt, 17, Color.WHITE, UI.font_bold)
	l.position = Vector2(27, 0)
	b.add_child(l)


func _cubes(pos: Vector2, n: int, col: Color) -> void:
	for k in range(n):
		var c := ColorRect.new()
		c.color = col
		c.size = Vector2(11, 11)
		c.position = pos + Vector2((k % 4) * 13, (k / 4) * 13)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mil_layer.add_child(c)
		var br := ReferenceRect.new()
		br.border_color = Color("#d0c0a0")
		br.editor_only = false
		br.size = c.size
		br.position = c.position
		br.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mil_layer.add_child(br)


func _pawn(pos: Vector2, col: Color, tip: String) -> void:
	var p := Panel.new()
	p.size = Vector2(20, 26)
	p.position = pos - Vector2(10, 13)
	p.add_theme_stylebox_override("panel", UI.panel_style(col, Color("#f4ecd8"), 2, 10))
	p.tooltip_text = tip
	mil_layer.add_child(p)


func _target_ring(pos: Vector2, sz: Vector2, cb: Callable) -> void:
	var r := Panel.new()
	r.size = sz
	r.position = pos - sz / 2
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.85, 0.3, 0.16)
	sb.border_color = UI.GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	r.add_theme_stylebox_override("panel", sb)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cb.call())
	mil_layer.add_child(r)


func _country_tip(c: String) -> String:
	var cc: Dictionary = engine.countries[c]
	var s: String = D.COUNTRIES[c]["n"] + (" (colonia)" if D.COUNTRIES[c].get("col", false) else "")
	if cc["cn"] > 0:
		s += "\nReti Clandestine: %d di %s" % [cc["cn"], D.POWERS[cc["cn_p"]]["nation"]]
	if cc["pa"] >= 0:
		s += "\nAllineamento Politico: %s (3 PV)" % D.POWERS[cc["pa"]]["nation"]
	if cc["behind"]:
		s += "\nDietro il fronte"
	if D.COUNTRIES[c]["sp"] == "arctic" and engine.naval["arctic"] < 3:
		s += "\nServono 3 supporti navali nell'Artico per piazzare reti o allineamenti"
	return s


func _front_tip(fi: int) -> String:
	var e := engine
	var f: Dictionary = e.fronts[fi]
	var sp := e.space_of(fi)
	var en := e.entry(fi)
	var s: String = D.FRONTS[fi]["n"] + "\n"
	s += "Posizione: %s\n" % (D.BOXES[D.FRONTS[fi]["box"]]["n"] if sp == "" else D.SPACES[sp]["n"])
	if en != "":
		s += "Ingresso: %s%s\n" % [D.SPACES[en]["n"], " (anfibio, %d navali)" % D.SPACES[en]["amph"] if D.SPACES[en].has("amph") else ""]
		s += "Forza: 2 + 2×%d supporti − 2×%d riserve = %d" % [f["off"], f["res"], e.strength(fi)]
		var why := e.attempt_reason(fi)
		if why != "":
			s += "\nNon può avanzare: " + why
	return s


func _refresh_fronts_panel() -> void:
	var e := engine
	for c in front_box.get_children():
		c.queue_free()
	for fi in range(e.fronts.size()):
		var f: Dictionary = e.fronts[fi]
		var row := Panel.new()
		row.custom_minimum_size = Vector2(MRW - 24, 66)
		row.add_theme_stylebox_override("panel", UI.panel_style(Color("#1d1811"), UI.pcol(D.FRONTS[fi]["who"]), 1, 4))
		row.tooltip_text = _front_tip(fi)
		front_box.add_child(row)
		var sp := e.space_of(fi)
		var en := e.entry(fi)
		var nm := UI.label(D.FRONTS[fi]["n"], 20, D.POWERS[D.FRONTS[fi]["who"]]["light"], UI.font_bold)
		nm.position = Vector2(8, 2)
		row.add_child(nm)
		var where: String = D.BOXES[D.FRONTS[fi]["box"]]["n"] if sp == "" else D.SPACES[sp]["n"]
		var l1 := UI.label("in %s%s" % [where, ("  ›  " + D.SPACES[en]["n"]) if en != "" else "  (fine del tracciato)"], 18, Color("#e8e0d0"))
		l1.position = Vector2(360, 4)
		row.add_child(l1)
		var box: String = D.FRONTS[fi]["box"]
		var parts := []
		if en != "":
			parts.append("forza %d (supporti %d, riserve %d)" % [e.strength(fi), f["off"], f["res"]])
			if D.SPACES[en].has("amph"):
				parts.append("navali %d/%d" % [e.naval[box], D.SPACES[en]["amph"]])
			var why := e.attempt_reason(fi)
			if why != "":
				parts.append("[color=#e0a070]" + why + "[/color]")
			if not f["do"].is_empty():
				parts.append("offensive dirette: %d" % f["do"].size())
		if f["last"] != "" and e.phase in ["war", "agenda"]:
			parts.append("[color=#d9b45a]ultimo tiro: %s[/color]" % f["last"])
		var l2 := UI.rich(17)
		l2.position = Vector2(8, 34)
		l2.custom_minimum_size = Vector2(MRW - 40, 0)
		l2.text = " · ".join(parts)
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l2)
	var s := "[b]Artico[/b]: %d supporti navali%s.  " % [e.naval["arctic"], " (reti e allineamenti in Norvegia e Finlandia, +1 Produzione URSS)" if e.naval["arctic"] >= 3 else " (ne servono 3)"]
	s += "[b]Riserve dell'Asse[/b]: tedesche %d%s, giapponesi %d, flotte giapponesi %d.\n" % [6 - e.ger_perm, "" if e.ita_out else " + italiana", 4 - e.jap_perm, e.ijn_left]
	if e.phase == "decision":
		s += "[b]Produzione[/b]: UK %d · USA %d · URSS %d" % [e.players[0]["prod"], e.players[1]["prod"], e.players[2]["prod"]]
		if e.ab_mod > 0:
			s += " · Bomba A +%d" % e.ab_mod
		s += "\n"
		if e.dday_ok:
			s += "[color=#7fd36f]Secondo Fronte al centro: sbarco in Normandia possibile.[/color]\n"
		if e.manch_ok:
			s += "[color=#7fd36f]L'URSS ha dichiarato guerra al Giappone.[/color]\n"
	if not e.war_report.is_empty():
		s += "[b]Fase militare[/b]\n" + "\n".join(e.war_report)
	mil_info.text = s


# =================================================================== decisioni

func _on_decision(req: Dictionary) -> void:
	pending = req
	sel_card = -1
	sel_leader = false
	var p := int(req["seat"])
	# hotseat: più umani sullo stesso dispositivo, si passa il dispositivo
	if online == null and humans.size() > 1 and p != hand_seat and _shows_hand(req):
		hand_seat = p
		cover_for = p
		_cover(p)
		refresh()
		return
	if _shows_hand(req):
		hand_seat = p
	_show_decision()


func _shows_hand(req: Dictionary) -> bool:
	return req["type"] in ["agenda_card", "advance", "advance_cos", "debate", "agenda_pick", "hopkins", "tie_leader"]


func _cover(p: int) -> void:
	var vb := _open_modal("TOCCA A %s" % str(engine.players[p]["leader"]).to_upper(), 640)
	vb.add_child(UI.label("Passa il dispositivo: le carte in mano sono nascoste.", 22))
	var b := UI.primary(UI.button("SONO %s, MOSTRA LE CARTE" % str(engine.players[p]["name"]).to_upper(), 600, 64, 24))
	b.pressed.connect(func():
		cover_for = -1
		_clear_modal()
		_show_decision())
	vb.add_child(b)


func _who(p: int) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [D.POWERS[p]["light"].to_html(false), str(engine.players[p]["leader"]).capitalize()]


func _show_decision() -> void:
	var req := pending
	if req.is_empty():
		return
	var t: String = req["type"]
	var p := int(req["seat"])
	_clear_actions()
	match t:
		"agenda_card", "agenda_pick", "advance", "advance_cos", "debate", "cond_stop", "hopkins":
			_want_view("conf")
		"tie_leader", "us_tie", "global_move":
			pass
		_:
			_want_view("mil")
	refresh()
	action_box.visible = true
	action_box.move_to_front()
	var who := _who(p) + ": "
	match t:
		"agenda_card":
			action_msg.text = who + "scegli la carta da giocare coperta per l'Agenda (conta solo il valore; il Regno Unito ha +1). Chi vince mette un tema sul suo tracciato."
			_add_btn("GIOCA LA CARTA", func(): _provide(sel_card), true).disabled = true
		"agenda_pick":
			if req.get("first", false):
				action_msg.text = who + "hai vinto l'Agenda: scegli un tema (casella in alto a destra) da mettere sul tuo tracciato, a %d spazi dal centro." % int(req.get("diff", 0))
			else:
				action_msg.text = who + "scegli un tema da mettere al centro del tavolo (clic sulle caselle evidenziate in alto a destra)."
			for ii in req["options"]:
				_add_btn(D.ISSUES[ii]["n"], func(): _provide(ii), false, 17)
		"advance":
			_advance_ui()
		"advance_cos":
			action_msg.text = who + "il dado dà %d per %s: scegli il tema da far avanzare (clic sul tavolo)." % [int(req["roll"]), D.STAFF[p][int(req["card"])]["n"]]
		"debate":
			_debate_ui()
		"cond_stop":
			action_msg.text = who + "%s passa dal centro del tavolo. Vuoi fermarlo al centro (così ha effetto)?" % D.ISSUES[int(req["issue"])]["n"]
			_add_btn("FERMA AL CENTRO", func(): _provide(true), true)
			_add_btn("CONTINUA", func(): _provide(false))
		"hopkins":
			action_msg.text = who + "Hopkins sui Materiali Strategici: scegli il suo valore."
			for v in range(1, 7):
				_add_btn(str(v), func(): _provide(v), v == 6)
		"tie_leader":
			_tie_ui()
		"us_tie":
			var vb := _open_modal("ARSENALE DELLA DEMOCRAZIA", 640)
			vb.add_child(UI.label("Parità %s: gli USA decidono chi la vince." % ("nell'Agenda" if req["ctx"] == "agenda" else "per la vittoria della conferenza"), 22))
			for q in req["tied"]:
				var qq: int = q
				vb.add_child(_modal_btn(str(D.POWERS[qq]["leader"]), func(): _provide(qq)))
		"place_do":
			action_msg.text = who + "piazza %s sullo spazio d'ingresso di un fronte (clic sulla mappa o qui sotto): %s dovrà spendervi 2 Produzione." % [D.ISSUES[int(req["issue"])]["n"], D.POWERS[D.ISSUES[int(req["issue"])]["f"]]["nation"]]
			for fi in req["options"]:
				_add_btn("%s (%s)" % [SHORT[D.FRONTS[fi]["id"]], D.SPACES[engine.entry(fi)]["n"]], func(): _provide(fi), false, 17)
		"do_order":
			action_msg.text = who + "la Produzione non basta per tutte le Offensive Dirette: quale finanzi per prima?"
			for fi in req["options"]:
				_add_btn(D.FRONTS[fi]["n"], func(): _provide(fi), false, 17)
		"alloc":
			_alloc_ui()
		"lose_cn":
			action_msg.text = who + "Negoziati con la Turchia: scegli una tua Rete Clandestina da togliere (clic sulla mappa)."
			for c in req["options"]:
				_add_btn(D.COUNTRIES[c]["n"], func(): _provide(c), false, 17)
		"lead_ctrl":
			var vb2 := _open_modal("COMANDO DEL TEATRO %s" % ("EUROPEO" if req["th"] == "eu" else "DEL PACIFICO"), 640)
			vb2.add_child(UI.label("%s ha vinto il tema: chi comanderà il teatro?" % str(engine.players[p]["leader"]).capitalize(), 22))
			vb2.add_child(_modal_btn("STATI UNITI", func(): _provide(1)))
			vb2.add_child(_modal_btn("REGNO UNITO", func(): _provide(0)))
		"global_move":
			var vb3 := _open_modal("TEMA GLOBALE", 720)
			vb3.add_child(UI.label("Quale marcatore sposti dalla tua parte?", 22))
			for g in req["options"]:
				var gg: int = g
				vb3.add_child(_modal_btn("%s › %s" % [D.GLOBALS[gg]["n"], D.GLOBALS[gg]["side"][p]], func(): _provide(gg)))
		"cn", "pa":
			_cnpa_ui()
	refresh()
	_fit_action.call_deferred()


func _add_btn(text: String, cb: Callable, primary := false, fs := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", fs)
	if primary:
		UI.primary(b)
	b.pressed.connect(cb)
	action_row.add_child(b)
	return b


func _clear_actions() -> void:
	for c in action_row.get_children():
		c.queue_free()
	action_msg.text = ""
	_fit_action.call_deferred()


## Riporta il riquadro delle azioni alla sua misura (i contenitori crescono ma non si restringono da soli).
func _fit_action() -> void:
	action_box.size = action_box.custom_minimum_size
	await get_tree().process_frame
	if is_instance_valid(action_box):
		action_box.size = action_box.custom_minimum_size


func _provide(r) -> void:
	if pending.is_empty():
		return
	pending = {}
	sel_card = -1
	sel_leader = false
	_clear_actions()
	_hide_zoom()
	engine.provide_decision(r)
	refresh()


func _idle() -> void:
	action_box.visible = false


# ------------------------------------------------------------------- riunione

func _hand_clickable() -> bool:
	if pending.is_empty():
		return false
	return pending["type"] in ["agenda_card", "advance", "debate"]


func _clickable_issues() -> Dictionary:
	var out := {}
	if pending.is_empty():
		return out
	match pending["type"]:
		"agenda_pick":
			for ii in pending["options"]:
				out[ii] = true
		"advance":
			if sel_card >= 0:
				var cid: int = engine.players[int(pending["seat"])]["hand"][sel_card]
				var cos := int(D.STAFF[int(pending["seat"])][cid]["v"]) == 0 and not sel_leader
				if not cos:
					for ii in pending["issues"]:
						out[ii] = true
		"advance_cos":
			for ii in pending["issues"]:
				out[ii] = true
	return out


func _on_issue_click(ii: int) -> void:
	if pending.is_empty():
		return
	match pending["type"]:
		"agenda_pick":
			_provide(ii)
		"advance_cos":
			_provide(ii)
		"advance":
			if sel_card >= 0:
				_provide({"card": sel_card, "issue": ii, "leader": sel_leader})


func _on_card_click(k: int) -> void:
	if pending.is_empty():
		return
	sel_card = k if sel_card != k else -1
	match pending["type"]:
		"agenda_card":
			var p := int(pending["seat"])
			_clear_actions()
			if sel_card >= 0:
				var cid: int = engine.players[p]["hand"][sel_card]
				var v := int(D.STAFF[p][cid]["v"])
				action_msg.text = _who(p) + ": giochi %s per l'Agenda (valore %s%s)." % [D.STAFF[p][cid]["n"], "1d6" if v == 0 else str(v), " +1" if p == 0 else ""]
				_add_btn("GIOCA LA CARTA", func(): _provide(sel_card), true)
			else:
				_show_decision()
		"advance":
			_advance_ui()
		"debate":
			_debate_ui()
	refresh()


func _advance_ui() -> void:
	var req := pending
	var p := int(req["seat"])
	_clear_actions()
	var who := _who(p) + ": "
	if sel_card < 0:
		action_msg.text = who + "scegli una carta dello staff (in basso), poi il tema da far avanzare verso la tua sedia."
		if req.get("leader_ok", false):
			action_msg.text += " Per usare il Leader (valore 7) premi USA IL LEADER e poi scegli la carta da scartare."
	else:
		var cid: int = engine.players[p]["hand"][sel_card]
		var sd: Dictionary = D.STAFF[p][cid]
		if sel_leader:
			action_msg.text = who + "usi %s scartando %s: clic sul tema da far avanzare (valore 7%s)." % [str(engine.players[p]["leader"]).capitalize(), sd["n"], ", poi la prova di salute" if engine.players[p]["leader"] in ["churchill", "roosevelt"] else ""]
		elif int(sd["v"]) == 0:
			action_msg.text = who + "%s è un Capo di Stato Maggiore: il suo valore si tira con 1d6 prima di scegliere il tema." % sd["n"]
			_add_btn("TIRA IL DADO", func(): _provide({"card": sel_card, "issue": -1}), true)
		else:
			var vals := []
			for ii in req["issues"]:
				var v := engine.staff_value(p, cid, ii, false)
				if v != int(sd["v"]):
					vals.append("%s %d" % [D.ISSUES[ii]["n"], v])
			action_msg.text = who + "%s (%d): clic sul tema da far avanzare.%s" % [sd["n"], int(sd["v"]), (" Valori modificati: " + ", ".join(vals) + ".") if not vals.is_empty() else ""]
	if req.get("leader_ok", false):
		var b := _add_btn("USA IL LEADER" if not sel_leader else "NON USARE IL LEADER", func():
			sel_leader = not sel_leader
			_advance_ui()
			refresh())
		if sel_leader:
			UI.primary(b)
	if req.get("can_pass", false):
		_add_btn("PASSA (hai dibattuto)", func(): _provide({"pass": true}))


func _debate_ui() -> void:
	var req := pending
	var p := int(req["seat"])
	var ii := int(req["issue"])
	_clear_actions()
	var adv := int(req["adv_seat"])
	var txt := _who(p) + ": %s ha portato [b]%s[/b] %s con valore %d. " % [_who(adv), D.ISSUES[ii]["n"], "verso la sua sedia (cattura)" if req.get("capture", false) else engine.pos_text(engine.table[ii]), int(req["adv_val"])]
	if req.get("leader_only", false):
		txt += "Ha usato il Leader: puoi dibattere solo con il tuo Leader (scartando una carta)."
	else:
		txt += "Vuoi dibattere? Scegli una carta (i sovietici hanno +1)."
	if sel_card >= 0 and not req.get("leader_only", false) and not sel_leader:
		var cid: int = engine.players[p]["hand"][sel_card]
		var v := engine.staff_value(p, cid, ii, true)
		txt += " Con %s vali %s." % [D.STAFF[p][cid]["n"], "1d6" + (" +1" if p == 2 else "") if int(D.STAFF[p][cid]["v"]) == 0 else str(v)]
		_add_btn("DIBATTI CON %s" % str(D.STAFF[p][cid]["n"]).to_upper(), func(): _provide({"card": sel_card}), true, 18)
	if req.get("leader_ok", false):
		if sel_card >= 0:
			_add_btn("DIBATTI CON %s (scarta la carta scelta)" % str(engine.players[p]["leader"]).to_upper(), func(): _provide({"card": sel_card, "leader": true}), req.get("leader_only", false), 18)
		else:
			txt += " Per usare il Leader scegli prima la carta da scartare."
	_add_btn("NON DIBATTERE", func(): _provide({}))
	action_msg.text = txt


func _tie_ui() -> void:
	var req := pending
	var p := int(req["seat"])
	var tied: Array = req["tied"]
	var names := []
	for q in tied:
		names.append(D.POWERS[q]["leader"])
	var vb := _open_modal("PARITÀ", 720)
	var l := UI.label("Parità %s fra %s. %s, vuoi usare il tuo Leader per risolverla? Diventerà inattivo per il resto della conferenza (nessuna carta da scartare)." % ["nell'Agenda" if req["ctx"] == "agenda" else "per la vittoria della conferenza", ", ".join(names), str(engine.players[p]["leader"]).capitalize()], 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(680, 0)
	vb.add_child(l)
	if p in tied:
		vb.add_child(_modal_btn("SÌ, VINCO IO", func(): _provide({"use": true})))
	else:
		for q in tied:
			var qq: int = q
			vb.add_child(_modal_btn("SÌ, FACCIO VINCERE %s" % str(D.POWERS[qq]["leader"]).to_upper(), func(): _provide({"use": true, "win": qq})))
	vb.add_child(_modal_btn("NO", func(): _provide({"use": false})))


# ------------------------------------------------------------------- mappa: produzione, reti, allineamenti

func _opt_text(o: Dictionary) -> String:
	match o["k"]:
		"off": return "Offensiva: %s" % SHORT[D.FRONTS[o["f"]]["id"]]
		"naval": return "Navale: %s" % D.BOXES[o["b"]]["n"].replace("Teatro ", "")
		"pm": return "Attiva %s" % D.ISSUES[o["i"]]["n"]
		"ab": return "Bomba A +1"
	return "?"


func _alloc_ui() -> void:
	var req := pending
	var p := int(req["seat"])
	var who := _who(p) + ": "
	var mode: String = req["mode"]
	match mode:
		"mand": action_msg.text = who + "produzione imposta dalla carta (%s). Scegli dove (clic sulla mappa)." % str(req.get("why", ""))
		"bonus": action_msg.text = who + "piazza un supporto (%s, ne restano %d)." % [str(req.get("why", "")), int(req["left"])]
		_: action_msg.text = who + "assegna la Produzione (ne restano %d): supporti offensivi sugli spazi d'ingresso, navali nei riquadri, Pol-Mil vinti o Bomba A." % int(req["left"])
	var opts: Array = req["options"]
	for k in range(opts.size()):
		var kk := k
		_add_btn(_opt_text(opts[k]), func(): _provide(kk), false, 16)


func _cnpa_ui() -> void:
	var req := pending
	var p := int(req["seat"])
	var kind: String = req["type"]
	action_msg.text = _who(p) + (": piazza una Rete Clandestina (ne restano %d). Clic su un paese: dove ci sono reti avversarie la tua rete ne toglie una." if kind == "cn" else ": piazza un Allineamento Politico (ne restano %d) dove hai una rete; dove c'è un allineamento avversario lo togli (costo 1 o 2).") % int(req["left"])
	var opts: Array = req["options"]
	for k in range(opts.size()):
		var o: Dictionary = opts[k]
		var kk := k
		var t: String = D.COUNTRIES[o["c"]]["n"]
		if o["rm"]:
			t = "Togli in " + t + (" (%d)" % int(o.get("cost", 1)) if kind == "pa" else "")
		_add_btn(t, func(): _provide(kk), false, 16)


## Bersagli cliccabili sulla mappa per la decisione in corso.
func _map_targets() -> Dictionary:
	var out := {}
	if pending.is_empty():
		return out
	var t: String = pending["type"]
	match t:
		"place_do", "do_order":
			for fi in pending["options"]:
				var f2: int = fi
				out["f:%d" % fi] = func(): _provide(f2)
		"alloc":
			var opts: Array = pending["options"]
			for k in range(opts.size()):
				var o: Dictionary = opts[k]
				var kk := k
				if o["k"] == "off":
					out["f:%d" % o["f"]] = func(): _provide(kk)
				elif o["k"] == "naval":
					out["b:" + o["b"]] = func(): _provide(kk)
		"cn", "pa":
			var opts2: Array = pending["options"]
			for k in range(opts2.size()):
				var kk2 := k
				out["c:" + opts2[k]["c"]] = func(): _provide(kk2)
		"lose_cn":
			for c in pending["options"]:
				var cc: String = c
				out["c:" + c] = func(): _provide(cc)
	return out


# =================================================================== modali, pause, effetti

func _clear_modal() -> void:
	for c in modal.get_children():
		c.queue_free()
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open_modal(title_text: String, w := 640.0, dim := true) -> VBoxContainer:
	_clear_modal()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.move_to_front()
	if dim:
		var sh := ColorRect.new()
		sh.color = Color(0, 0, 0, 0.55)
		sh.size = size
		modal.add_child(sh)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(Color("#16120cf8"), UI.GOLD, 2, 10))
	box.custom_minimum_size = Vector2(w, 0)
	modal.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)
	vb.add_child(UI.title(title_text, 32))
	_center_box.call_deferred(box)
	return vb


func _center_box(box: Control) -> void:
	if is_instance_valid(box):
		box.position = (size - box.size) / 2


func _modal_btn(text: String, cb: Callable) -> Button:
	var b := UI.button(text, 0, 56, 22)
	b.pressed.connect(func():
		_clear_modal()
		cb.call())
	return b


func _on_pause(req: Dictionary) -> void:
	var ctx: String = req.get("ctx", "")
	match ctx:
		"agenda":
			var vb := _open_modal("AGENDA", 760)
			var r := UI.rich(21)
			r.custom_minimum_size = Vector2(720, 0)
			var s := ""
			for p in [0, 2, 1]:
				if engine.agenda_play.has(p):
					var ap: Dictionary = engine.agenda_play[p]
					s += "%s: [b]%s[/b], valore %d\n" % [_who(p), D.STAFF[p][ap["card"]]["n"], ap["v"]]
			s += "\nVince l'Agenda %s." % _who(engine.agenda_winner)
			r.text = s
			vb.add_child(r)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			for p in [0, 2, 1]:
				if engine.agenda_play.has(p):
					hb.add_child(UI.icon_rect(UI.staff_tex(p, engine.agenda_play[p]["card"]), Vector2(150, 210)))
			vb.add_child(hb)
		"meeting_end":
			var vb2 := _open_modal("FINE DELLA RIUNIONE", 760)
			var r2 := UI.rich(21)
			r2.custom_minimum_size = Vector2(720, 0)
			var s2 := ""
			for p in [0, 2, 1]:
				var names := []
				for i in engine.won_by:
					if engine.won_by[i] == p:
						names.append(D.ISSUES[i]["n"])
				s2 += "%s (%d): %s\n" % [_who(p), names.size(), ", ".join(names) if not names.is_empty() else "nessun tema"]
			var cen := []
			for i in engine.table:
				if engine.table[i]["d"] == 0:
					cen.append(D.ISSUES[i]["n"])
			if not cen.is_empty():
				s2 += "Al centro: %s\n" % ", ".join(cen)
			s2 += "\n[font_size=24]%s vince la conferenza (%s PV).[/font_size]" % [_who(engine.conf_winner), "5" if engine.conf_winner == 2 else "3"]
			r2.text = s2
			vb2.add_child(r2)
		"war":
			_set_view("mil")
			var vb3 := _open_modal("FASE MILITARE", 820)
			var r3 := UI.rich(20)
			r3.custom_minimum_size = Vector2(780, 0)
			r3.text = "\n".join(engine.war_report) if not engine.war_report.is_empty() else "Nessun fronte ha potuto avanzare."
			vb3.add_child(r3)
		_:
			var vb4 := _open_modal("", 500)
			vb4.add_child(UI.label("Continua", 22))
	var vbl: VBoxContainer = modal.get_child(modal.get_child_count() - 1).get_child(0)
	var b := UI.primary(UI.button("CONTINUA", 300, 56, 24))
	b.pressed.connect(func():
		_clear_modal()
		engine.provide_decision(true))
	vbl.add_child(b)


func _on_fx(kind: String, data: Dictionary) -> void:
	match kind:
		"capture":
			_toast("%s cattura %s" % [D.POWERS[data["seat"]]["leader"], D.ISSUES[data["issue"]]["n"]], UI.pcol(data["seat"]))
		"conf_win":
			_toast("%s vince la conferenza" % D.POWERS[data["seat"]]["leader"], UI.pcol(data["seat"]))
		"surrender":
			_toast("LA GERMANIA SI ARRENDE" if data["who"] == "germany" else "IL GIAPPONE SI ARRENDE", UI.GOLD)
		"conf_card":
			_want_view("conf")


func _toast(t: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.panel_style(Color("#120f0aee"), col, 3, 8))
	var l := UI.title(t, 30, Color.WHITE)
	p.add_child(l)
	p.position = Vector2(500, 110)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(p)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if sel_card >= 0 or sel_leader:
			sel_card = -1
			sel_leader = false
			_show_decision()


func _on_game_end(res: Dictionary) -> void:
	pending = {}
	action_box.visible = false
	if online != null:
		online.finish()
		online_status("")
	var vb := _open_modal("FINE DELLA PARTITA", 1500)
	var w: int = res["winner"]
	var t := UI.title("VINCE %s (%s)" % [str(engine.players[w]["leader"]).to_upper(), D.POWERS[w]["nation"]], 40, D.POWERS[w]["light"])
	vb.add_child(t)
	var how := UI.label(res["how"], 22, Color("#e8e0d0"))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(1440, 0)
	vb.add_child(how)
	var st := UI.label("Germania: %s · Giappone: %s" % ["arresa" if res["germany"] else "non arresa", "arreso" if res["japan"] else "non arreso"], 21, UI.MUTED)
	vb.add_child(st)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	for p in [0, 2, 1]:
		var col := PanelContainer.new()
		col.add_theme_stylebox_override("panel", UI.panel_style(Color("#1d1811"), UI.pcol(p), 3 if p == w else 1, 8))
		col.custom_minimum_size = Vector2(480, 0)
		hb.add_child(col)
		var cv := VBoxContainer.new()
		col.add_child(cv)
		cv.add_child(UI.title(str(engine.players[p]["leader"]).to_upper(), 28, D.POWERS[p]["light"]))
		var r := UI.rich(18)
		r.custom_minimum_size = Vector2(450, 0)
		var s := ""
		for row in res["vp"][p]["rows"]:
			s += "%+d  %s\n" % [row[1], row[0]]
		s += "\n[b]Totale: %d PV[/b]" % res["raw"][p]
		if res["adj"][p] != res["raw"][p]:
			s += "  › [b]%d[/b] dopo l'aggiustamento" % res["adj"][p]
		r.text = s
		cv.add_child(r)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 12)
	vb.add_child(bh)
	var b1 := UI.primary(UI.button("MENU", 260, 60, 26))
	b1.pressed.connect(func(): main.show_menu())
	bh.add_child(b1)
	var b2 := UI.button("RIVEDI LA MAPPA", 300, 60, 22)
	b2.pressed.connect(func():
		_clear_modal()
		_set_view("mil"))
	bh.add_child(b2)


func _ask_quit() -> void:
	var vb := _open_modal("TORNARE AL MENU?", 600)
	vb.add_child(UI.label("La partita in corso andrà persa." if online == null else "Potrai rientrare nella stanza con lo stesso codice.", 22))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var y := UI.primary(UI.button("SÌ, AL MENU", 240, 56, 22))
	y.pressed.connect(func():
		if online != null:
			main.get_net().set_away(online.code, online.seat, true)
		main.show_menu())
	hb.add_child(y)
	var n := UI.button("NO", 160, 56, 22)
	n.pressed.connect(func():
		_clear_modal()
		if not pending.is_empty():
			_show_decision())
	hb.add_child(n)


func _show_rules_popup() -> void:
	var r := preload("res://scripts/ui/rules_view.gd").new()
	r.main = main
	r.embedded = true
	r.on_close = func(): r.queue_free()
	add_child(r)


# =================================================================== online

func _build_online_label() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.panel_style(Color("#0b0907ee"), UI.GOLD, 1, 6))
	p.position = Vector2(14, 1030)
	add_child(p)
	online_lbl = UI.label("", 20, Color.WHITE)
	p.add_child(online_lbl)
	p.visible = false
	online_lbl.set_meta("box", p)


func online_status(t: String) -> void:
	if online_lbl == null:
		return
	online_lbl.text = t
	var b: Control = online_lbl.get_meta("box")
	b.visible = t != ""
	b.move_to_front()


func online_waiting(seat: int, is_slow: bool) -> void:
	if seat < 0:
		online_status("")
		return
	var t := "Online · stanza %s · tocca a %s" % [online.code, engine.players[seat]["name"]]
	if is_slow:
		t += " (non risponde da un po')"
	online_status(t)


func online_caught_up() -> void:
	online_status("")
	refresh()


func online_cancel_decision(t: String) -> void:
	pending = {}
	_clear_modal()
	action_box.visible = false
	online_status(t)
