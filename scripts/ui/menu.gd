extends Control
## Menu principale: i tre Grandi (Umano / IA), lo scenario, il livello dell'IA, il gioco online.

const MODES := ["UMANO", "IA"]
const D = preload("res://scripts/data/ch_data.gd")

var main
var seat_mode := [0, 1, 1]      # 0 umano, 1 IA
var tiles := {}
var level := 1
var speed := 1
var scenario := 1
var msg: Label


func _ready() -> void:
	size = Vector2(1920, 1080)
	if main.menu_state.has("seat_mode"):
		seat_mode = main.menu_state["seat_mode"].duplicate()
		level = main.menu_state["level"]
		speed = main.menu_state["speed"]
		scenario = main.menu_state.get("scenario", 1)
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/conference.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(1920, 1080)
	bg.modulate = Color(0.32, 0.3, 0.3)
	add_child(bg)
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.02, 0.02, 0.35))
	g.set_color(1, Color(0.03, 0.02, 0.02, 0.94))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	shade.texture = grad
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(1920, 1080)
	add_child(shade)

	var logo := TextureRect.new()
	logo.texture = UI.tex("res://assets/splash.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(230, 230)
	logo.position = Vector2(62, 22)
	add_child(logo)
	var t := UI.title("CHURCHILL", 92)
	t.position = Vector2(318, 40)
	add_child(t)
	var st := UI.label("Big Three Struggle for Peace · i Tre Grandi e la pace dopo la Seconda guerra mondiale", 28, Color("#d8cdb4"), UI.font_italic)
	st.position = Vector2(324, 162)
	add_child(st)

	var head := UI.title("NUOVA PARTITA", 36)
	head.position = Vector2(62, 280)
	add_child(head)
	var sub := UI.label("Scegli chi guida ogni potenza: le altre le gioca l'IA (le regole dei 'Bot permettono di giocare anche da soli o in due).", 23, Color("#d8d0c0"))
	sub.position = Vector2(64, 330)
	add_child(sub)
	for p in range(3):
		_make_tile(p, Vector2(62 + p * 372, 376))

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(Color("#0d0b08dd"), Color("#4a3e28"), 1, 8))
	box.position = Vector2(1200, 290)
	box.custom_minimum_size = Vector2(660, 0)
	add_child(box)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 10)
	box.add_child(ov)
	ov.add_child(UI.label("Scenario", 28, Color.WHITE, UI.font_bold))
	var sc_desc := UI.label("", 21, Color("#cfc6b4"))
	sc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sc_desc.custom_minimum_size = Vector2(620, 0)
	var names := []
	for s in D.SCENARIOS:
		names.append(s["n"])
	ov.add_child(_segmented("", names, scenario, func(k):
		scenario = k
		sc_desc.text = D.SCENARIOS[k]["desc"], 200))
	sc_desc.text = D.SCENARIOS[scenario]["desc"]
	ov.add_child(sc_desc)
	ov.add_child(HSeparator.new())
	ov.add_child(UI.label("Livello IA", 28, Color.WHITE, UI.font_bold))
	ov.add_child(_segmented("", ["Facile", "Normale", "Difficile"], level, func(k): level = k, 200))
	ov.add_child(UI.label("Velocità IA", 28, Color.WHITE, UI.font_bold))
	ov.add_child(_segmented("", ["Lenta", "Normale", "Veloce", "Istantanea"], speed, func(k): speed = k, 150))

	msg = UI.label("", 26, UI.RED, UI.font_bold)
	msg.position = Vector2(62, 868)
	add_child(msg)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 18)
	btns.position = Vector2(62, 912)
	add_child(btns)
	var b_start := _big_button("INIZIA PARTITA", 420, true)
	b_start.pressed.connect(_on_start)
	btns.add_child(b_start)
	var b_rules := _big_button("REGOLE", 240)
	b_rules.pressed.connect(func():
		_store()
		main.show_rules())
	btns.add_child(b_rules)
	if not OS.has_feature("web"):
		var b_quit := _big_button("ESCI", 200)
		b_quit.pressed.connect(func(): get_tree().quit())
		btns.add_child(b_quit)

	var b_online := _big_button("GIOCA ONLINE", 420)
	b_online.position = Vector2(1438, 912)
	b_online.pressed.connect(_online_panel)
	add_child(b_online)
	var on_note := UI.label("Con gli amici, ognuno dal suo dispositivo:\ncrea una stanza e condividi il codice.", 21, Color("#bdb5a5"))
	on_note.position = Vector2(1440, 840)
	add_child(on_note)
	if not main.lobby.is_empty():
		_online_panel.call_deferred()

	var credits := UI.label("Adattamento digitale non ufficiale per uso personale · Churchill di Mark Herman · © GMT Games · F11 schermo intero", 18, Color("#8a8478"))
	credits.position = Vector2(62, 1040)
	add_child(credits)
	_refresh_tiles()


func _store() -> void:
	main.menu_state = {"seat_mode": seat_mode.duplicate(), "level": level, "speed": speed, "scenario": scenario}


func _make_tile(p: int, pos: Vector2) -> void:
	var c: Dictionary = D.POWERS[p]
	var root := Control.new()
	root.position = pos
	root.size = Vector2(350, 470)
	add_child(root)
	var frame := Panel.new()
	frame.size = root.size
	root.add_child(frame)
	var por := UI.icon_rect(UI.portrait(["churchill", "roosevelt", "stalin"][p]), Vector2(224, 196))
	por.position = Vector2(63, 18)
	por.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(por)
	var nm := UI.title(c["leader"].to_upper(), 34, c["light"])
	nm.position = Vector2(0, 226)
	nm.size = Vector2(350, 44)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(nm)
	var hs := UI.label(c["nation"], 23, Color("#cfc6b4"))
	hs.position = Vector2(0, 274)
	hs.size = Vector2(350, 30)
	hs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hs)
	var trl := UI.label(["Stato Maggiore Imperiale: +1 nell'Agenda", "Arsenale della Democrazia: vince le parità", "«Njet»: +1 nei dibattiti"][p], 19, Color("#a89c86"), UI.font_italic)
	trl.position = Vector2(0, 306)
	trl.size = Vector2(350, 28)
	trl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(trl)
	var bar := HBoxContainer.new()
	bar.position = Vector2(20, 390)
	bar.size = Vector2(310, 60)
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	var buttons := []
	for k in range(2):
		var b := Button.new()
		b.text = MODES[k]
		b.custom_minimum_size = Vector2(150, 60)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(func():
			seat_mode[p] = k
			msg.text = ""
			_refresh_tiles())
		bar.add_child(b)
		buttons.append(b)
	tiles[p] = {"frame": frame, "buttons": buttons, "color": c["light"], "por": por}
	por.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			seat_mode[p] = 1 - seat_mode[p]
			_refresh_tiles())


func _refresh_tiles() -> void:
	for p in range(3):
		var t: Dictionary = tiles[p]
		var m: int = seat_mode[p]
		t["frame"].add_theme_stylebox_override("panel", UI.panel_style(Color("#0c0a08e6"), t["color"] if m == 0 else Color("#4a4236"), 3 if m == 0 else 1, 8))
		t["por"].modulate = Color.WHITE if m == 0 else Color(0.75, 0.75, 0.75)
		for k in range(2):
			var b: Button = t["buttons"][k]
			var sel := k == m
			b.add_theme_stylebox_override("normal", UI.panel_style(UI.GOLD if sel else Color("#1c1812"), UI.GOLD if sel else Color("#4a4236"), 2, 4))
			b.add_theme_stylebox_override("hover", UI.panel_style(UI.GOLD if sel else Color("#3a3020"), UI.GOLD, 2, 4))
			b.add_theme_color_override("font_color", UI.DARK if sel else Color("#dddddd"))
			b.add_theme_color_override("font_hover_color", UI.DARK if sel else UI.GOLD)


func _segmented(label_text: String, items: Array, cur: int, cb: Callable, w := 200) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	if label_text != "":
		var l := UI.label(label_text, 28, Color.WHITE, UI.font_bold)
		l.custom_minimum_size = Vector2(190, 0)
		hb.add_child(l)
	var btns := []
	for k in range(items.size()):
		var b := Button.new()
		b.text = items[k]
		b.custom_minimum_size = Vector2(w, 50)
		b.add_theme_font_size_override("font_size", 24)
		hb.add_child(b)
		btns.append(b)
	var paint := func(sel: int):
		for k in range(btns.size()):
			var on: bool = k == sel
			btns[k].add_theme_stylebox_override("normal", UI.panel_style(UI.GOLD if on else Color("#1c1812"), UI.GOLD if on else Color("#4a4236"), 2, 4))
			btns[k].add_theme_color_override("font_color", UI.DARK if on else Color("#dddddd"))
			btns[k].add_theme_color_override("font_hover_color", UI.DARK if on else UI.GOLD)
	for k in range(btns.size()):
		btns[k].pressed.connect(func():
			cb.call(k)
			paint.call(k))
	paint.call(cur)
	return hb


func _big_button(text: String, w: float, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 82)
	b.add_theme_font_override("font", UI.font_title)
	b.add_theme_font_size_override("font_size", 34)
	if primary:
		UI.primary(b)
	return b


## Configurazione scelta nel menu (anche quella che, online, viaggia agli altri).
func _config() -> Dictionary:
	var seats := []
	for p in range(3):
		seats.append({"ai": seat_mode[p] == 1, "name": D.POWERS[p]["leader"], "level": level})
	var speeds := [1.0, 0.5, 0.15, 0.0]
	return {"seats": seats, "ai_level": level, "ai_delay": speeds[speed], "scenario": scenario}


func _on_start() -> void:
	_store()
	main.start_game(_config())


# =================================================================== online

var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button


func _online_panel() -> void:
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = Control.new()
	on_panel.size = Vector2(1920, 1080)
	on_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(on_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.size = on_panel.size
	on_panel.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(Color("#15120df4"), UI.GOLD, 2, 8))
	box.position = Vector2(560, 130)
	box.custom_minimum_size = Vector2(800, 0)
	on_panel.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)
	vb.add_child(UI.title("GIOCA ONLINE", 46))
	var info := UI.label("Chi crea la stanza sceglie prima nel menu le potenze, lo scenario e il livello dell'IA: le potenze su UMANO diventano i posti per gli amici (la prima è la sua). Gli amici entrano con il codice. I posti rimasti liberi li gioca l'IA. Ognuno vede soltanto le proprie carte.", 22, Color("#cccccc"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(760, 0)
	vb.add_child(info)
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 20)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	var b_create := Button.new()
	b_create.text = "CREA UNA STANZA"
	b_create.custom_minimum_size = Vector2(0, 60)
	b_create.add_theme_font_size_override("font_size", 28)
	b_create.pressed.connect(_online_create)
	vb.add_child(b_create)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b_join := Button.new()
	b_join.text = "ENTRA"
	b_join.custom_minimum_size = Vector2(200, 60)
	b_join.add_theme_font_size_override("font_size", 28)
	b_join.pressed.connect(_online_join)
	row.add_child(b_join)
	vb.add_child(row)
	on_lbl = UI.label("", 24, Color.WHITE)
	on_lbl.custom_minimum_size = Vector2(760, 120)
	on_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = _big_button("INIZIA ONLINE", 420, true)
	on_start.pressed.connect(_online_start)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	var b_close := _big_button("INDIETRO", 300)
	b_close.pressed.connect(func():
		on_panel.queue_free())
	row2.add_child(b_close)
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s…" % main.lobby["code"]
	elif str(ses.get("room", "")) != "":
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi ENTRA per rientrare." % ses["room"]


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 60)
	le.add_theme_font_size_override("font_size", 28)
	return le


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seats_text(room: Dictionary) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var who := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero"
		parts.append("%s: %s" % [D.POWERS[int(idx)]["leader"], who])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	var seats := []
	for p in range(3):
		if seat_mode[p] == 0:
			seats.append(p)
	if seats.size() < 2:
		_say("Metti su UMANO almeno due potenze: la prima è la tua, le altre sono i posti per gli amici.")
		return
	_store()
	_say("Creo la stanza…")
	var net: Net = main.get_net()
	var code := await net.create_room(nm, seats)
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": seats[0]}
	net.remember_room(code, seats[0])
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s…" % code)
	var net: Net = main.get_net()
	var seat := await net.join_room(code, nm)
	if seat == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if seat == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s…" % code)
		_begin(room["game"], true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: dai il codice ai tuoi amici.\nPosti: %s.\nQuando ci siete tutti premi INIZIA ONLINE: i posti liberi li gioca l'IA." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room["game"], false)
				return
			_say("Sei nella stanza [ %s ] (%s).\nPosti: %s.\nAspetta che chi l'ha creata avvii la partita." % [code, D.POWERS[int(main.lobby["seat"])]["leader"], _seats_text(room)])
		await get_tree().create_timer(2.0).timeout


## Chi ha creato la stanza avvia: potenze, scenario e seme valgono per tutti.
func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	var my_seat := int(main.lobby["seat"])
	if not seats_db.has(str(my_seat)) or cfg["seats"][my_seat]["ai"]:
		_say("Hai cambiato le potenze dopo aver creato la stanza: creane una nuova.")
		return
	for i in range(3):
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary and not cfg["seats"][i]["ai"]:
			cfg["seats"][i]["name"] = str(seats_db[k].get("name", cfg["seats"][i]["name"]))
		else:
			cfg["seats"][i]["ai"] = true
	cfg["seed"] = 1 + randi() % 2000000000
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_begin(g, false)


## Avvio (o rientro) della partita online.
func _begin(g: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	var ses := OnlineSession.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	main.lobby = {}
	main.start_game(cfg)
