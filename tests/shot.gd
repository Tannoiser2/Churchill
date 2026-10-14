extends SceneTree
## Screenshot automatici dell'interfaccia (serve un display: xvfb-run).
## godot --path . -s res://tests/shot.gd -- <modo: menu|rules|game> [scenario]
## In modalità game si gioca una partita intera dall'interfaccia: le decisioni del giocatore umano
## (Churchill) le prende l'IA ma passano dai pulsanti e dai clic della vista, come farebbe una persona.

var main
var n := 0
var ai := CHAI.new()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(OS.get_user_data_dir() + "/shots/%02d_%s.png" % [n, name])
	print("shot ", name)


func wait(f := 10) -> void:
	for i in range(f):
		await process_frame


func gv():
	return main.current


## Risponde alla decisione in corso usando l'interfaccia (clic su carte, temi e bersagli).
func ui_answer() -> void:
	var g = gv()
	var req: Dictionary = g.pending
	if req.is_empty():
		return
	var p := int(req["seat"])
	var r = ai.decide(g.engine, p, req)
	match req["type"]:
		"advance":
			if r is Dictionary and r.has("card") and not r.get("pass", false):
				g._on_card_click(int(r["card"]))
				if r.get("leader", false):
					g.sel_leader = true
				if int(r.get("issue", -1)) >= 0:
					g._on_issue_click(int(r["issue"]))
					return
		"agenda_pick", "advance_cos":
			g._on_issue_click(int(r))
			return
		"agenda_card":
			g._on_card_click(int(r))
	if not g.pending.is_empty():
		g._provide(r)


func _run() -> void:
	ai.level = 2
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "game"
	await wait(5)
	await shot("menu")
	if mode == "menu":
		quit()
		return
	if mode == "rules":
		main.show_rules()
		await wait(5)
		await shot("regole")
		quit()
		return
	var sc := int(args[1]) if args.size() > 1 else 1
	var seats := [{"ai": false, "name": "Stefano"}, {"ai": true, "name": "Roosevelt", "level": 1}, {"ai": mode != "hot", "name": "Stalin", "level": 1}]
	main.start_game({"seats": seats, "seed": 42, "ai_delay": 0.0, "scenario": sc, "secret": OS.get_environment("CH_SECRET") != ""})
	await wait(10)
	var taken := {}
	var guard := 0
	while guard < 20000:
		guard += 1
		await wait(2)
		var g = gv()
		if g.engine.game_over:
			await wait(8)
			await shot("fine")
			g._clear_modal()
			g._set_view("mil")
			await wait(4)
			await shot("fine_mappa")
			break
		if g.step_waiting:
			var nst: int = taken.get("_steps", 0)
			taken["_steps"] = nst + 1
			if nst < 5 or (nst % 9 == 0 and nst < 60):
				await wait(30)
				await shot("passo_%02d" % nst)
				if OS.get_environment("CH_STEPS") != "" and nst >= 4:
					quit()
					return
			g.step_waiting = false
			g._clear_actions()
			g.engine.provide_decision(true)
			continue
		var req: Dictionary = g.pending
		if req.is_empty():
			if g.modal.get_child_count() > 0 and g.engine.phase != "end":
				var key0 := "pausa_%s_%d" % [g.engine.phase, g.engine.conf_no]
				if not taken.has(key0) and g.engine.conf_i <= 1:
					taken[key0] = true
					await shot(key0)
				g._clear_modal()
				g.engine.provide_decision(true)
			continue
		if g.modal.get_child_count() > 0 and g.cover_for >= 0:
			# schermata «passa il dispositivo» (più umani sullo stesso dispositivo)
			if not taken.has("cover"):
				taken["cover"] = true
				await shot("passa_dispositivo")
			g.cover_for = -1
			g._clear_modal()
			g._show_decision()
			await wait(2)
		var key := "%s_%d" % [req["type"], g.engine.conf_no]
		if not taken.has(key) and (g.engine.conf_i == 0 or req["type"] in ["cn", "pa", "alloc", "place_do"]) and taken.size() < 40:
			taken[key] = true
			await shot(key)
			if req["type"] == "advance":
				g._on_card_click(0)
				await wait(3)
				await shot(key + "_carta")
				g.sel_card = -1
		await ui_answer()
	print("partita finita: ", g_res())
	quit()


func g_res() -> String:
	var g = gv()
	return "%s %s" % [str(g.engine.results.get("raw", [])), g.engine.results.get("how", "")]
