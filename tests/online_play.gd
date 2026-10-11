extends SceneTree
## Prova del gioco online: due istanze di Churchill (chi crea la stanza con Churchill e un amico con
## Stalin) giocano una partita intera sul finto Firebase (tests/firebase_mock.py); Roosevelt lo gioca l'IA.
## Le persone sono simulate dall'IA. CH_ROLE=host|guest, CH_CODEFILE=file per il codice della stanza,
## CH_PHASE=drop: l'ospite esce a metà (per provare il rientro con CH_PHASE=back).
## Alla fine ognuno stampa l'impronta della partita: devono coincidere.

var main
var t0 := 0
var hooked := false
var ai := CHAI.new()

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec()
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	await _wait(0.5)
	var role := OS.get_environment("CH_ROLE")
	var cf := OS.get_environment("CH_CODEFILE")
	var phase := OS.get_environment("CH_PHASE")
	var sc := int(OS.get_environment("CH_SCENARIO")) if OS.get_environment("CH_SCENARIO") != "" else 0
	var menu = main.current
	menu.seat_mode = [0, 1, 0]
	menu.speed = 3
	menu.scenario = sc
	menu.secret = 1 if OS.get_environment("CH_SECRET") != "" else 0
	menu._online_panel()
	menu.on_name.text = "Host" if role == "host" else "Ospite"
	if role == "host":
		await menu._online_create()
		var code: String = main.lobby.get("code", "")
		print("CHTEST stanza ", code)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		while true:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _wait(0.5)
		await menu._online_start()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		menu.on_code.text = code
		await menu._online_join()
	var hidden_ok := true
	while true:
		await process_frame
		if Time.get_ticks_msec() - t0 > 1500000:
			print("CHTEST tempo scaduto")
			quit(2)
			return
		var view = main.current
		if view == null or not ("engine" in view) or view.engine == null:
			continue
		var e: CHEngine = view.engine
		if not hooked:
			hooked = true
			var go := func():
				view._clear_modal()
				e.provide_decision(true)
			e.pause_requested.connect(func(_t): go.call_deferred())
		# la vista mostra solo la mano del proprio posto
		if view._visible_hand() != view.online.seat:
			hidden_ok = false
		var req: Dictionary = view.pending
		if not req.is_empty() and view.online._mine_pending:
			view._provide(ai.decide(e, req["seat"], req))
		if phase == "drop" and e.conf_i >= 1 and e.phase == "meeting":
			print("CHTEST esco a metà partita, mossa ", view.online.n)
			quit(0)
			return
		if e.game_over:
			await _wait(0.5)
			print("CHTEST mani nascoste: ", hidden_ok)
			print("CHTEST impronta ", view.online.n, " | ", e.fingerprint())
			if e.secret:
				print("CHTEST agende ", e.agenda_of(0), e.agenda_of(1), e.agenda_of(2), " PV ", e.results.get("raw", []))
			quit(0)
			return
