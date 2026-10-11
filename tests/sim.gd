extends SceneTree
## Partite IA contro IA senza grafica:
## godot --headless -s res://tests/sim.gd -- <partite> <scenario 0-2> <livello UK> <livello USA> <livello URSS>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 10
	var sc := int(args[1]) if args.size() > 1 else 1
	var lv := [1, 1, 1]
	for i in range(3):
		if args.size() > 2 + i:
			lv[i] = int(args[2 + i])
	var wins := [0, 0, 0]
	var vps := [0, 0, 0]
	var surr := 0
	var t0 := Time.get_ticks_msec()
	for g in range(games):
		var eng := CHEngine.new()
		eng.headless = true
		root.add_child(eng)
		var seats := []
		for p in range(3):
			seats.append({"ai": true, "name": ["Churchill", "Roosevelt", "Stalin"][p], "level": lv[p]})
		eng.setup({"seats": seats, "seed": 1000 + g, "scenario": sc})
		if OS.get_environment("CH_LOG") != "":
			eng.log_added.connect(func(t): print("  ", t))
		await eng.run()
		var r: Dictionary = eng.results
		wins[r["winner"]] += 1
		for p in range(3):
			vps[p] += r["raw"][p]
		if r["germany"] and r["japan"]:
			surr += 1
		print("partita %d: UK %d, USA %d, URSS %d → vince %s  [G:%s J:%s] %s" % [g, r["raw"][0], r["raw"][1], r["raw"][2], ["UK", "USA", "URSS"][r["winner"]], r["germany"], r["japan"], eng.fingerprint().substr(0, 50)])
		eng.queue_free()
	print("vittorie UK %d, USA %d, URSS %d · PV medi %.1f / %.1f / %.1f · resa totale dell'Asse in %d partite · %d ms" % [wins[0], wins[1], wins[2], vps[0] / float(games), vps[1] / float(games), vps[2] / float(games), surr, Time.get_ticks_msec() - t0])
	quit()
