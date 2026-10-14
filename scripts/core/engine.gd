class_name CHEngine
extends Node
## Motore delle regole di Churchill (GMT Games, 2ª edizione con errata). Nessuna dipendenza dalla UI.
## Ogni scelta passa da `decide()`: l'IA risponde subito, per i giocatori umani viene emesso
## `decision_requested` e si attende `provide_decision()`. Online le scelte passano dal registro
## di mosse (OnlineSession): con lo stesso seme ogni dispositivo ottiene la stessa partita.
## Le carte in mano sono note al motore di ogni dispositivo: è l'interfaccia a mostrare solo le proprie.

signal changed
signal log_added(text: String)
signal phase_changed(conf: int, phase: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(results: Dictionary)
signal fx(kind: String, data: Dictionary)
signal pause_requested(req: Dictionary)
signal step_requested(data: Dictionary)

const D = preload("res://scripts/data/ch_data.gd")
const UK := 0
const US := 1
const USSR := 2

var rng := RandomNumberGenerator.new()
var ai_delay := 0.0
var headless := false
var ais := {}
var online = null
var abort := false
var pause_enabled := false
var current := -1

var players: Array = []
var scenario := 0
var conf_list: Array = []        # carte Conferenza della partita, in ordine
var conf_i := -1
var conf_no := 0
var card := -1                    # carta Conferenza in gioco
var phase := ""                   # agenda, meeting, decision, war, end
var step := ""
var game_over := false
var results := {}
var log_lines: Array = []

# tavolo della conferenza
var table := {}                   # indice tema -> {"o": potenza o −1 al centro, "d": distanza, "cap": bool}
var removed_issues := {}          # temi tolti dal gioco (Secondo Fronte dopo la Normandia…)
var blocked_issues := {}          # temi non disponibili in questa conferenza (già sulla mappa per una carta)
var agenda_play := {}             # potenza -> {"card": id, "v": valore}
var agenda_winner := -1
var conf_winner := -1
var prev_winner := -1
var won_by := {}                  # indice tema -> potenza (fine della riunione)

# mappa militare
var fronts: Array = []            # {"pos", "off", "res", "do": [], "noadv", "last": risultato}
var naval := {}
var countries := {}               # id -> {"cn_p", "cn", "pa", "behind"}
var glob := [-1, -1, -1]          # −1 neutrale, altrimenti potenza sul cui lato è il marcatore
var lead := {"eu": UK, "pa": US}
var abomb := 0
var spy := 0
var secret := false              # variante Agenda segreta (10.0)
var ab_mod := 0
var ger_perm := 0
var jap_perm := 0
var ita_out := false
var navy_out := false
var ijn_left := 2
var card_res := {"ger": 0, "jap": 0, "ruhr": 0}
var ijn_card := ""
var ijn_card_res := 0
var dday_ok := false
var manch_ok := false
var germany_surr := false
var japan_surr := false
var italy_surr := false
var japan_occupied := false
var germany_by := []               # fronti entrati in Germania
var normandy_conf := -1
var citaly_conf := -1
var phil_entered := false
var b29_entered := false
var murmansk := 0
var mand: Array = []              # produzione obbligata dalla carta: {"who", "n", "k", "th", "x"}
var prod_loss := [0, 0, 0]
var uk_lose_cn := false
var war_report: Array = []        # righe della fase militare (per il riepilogo)
var tech_log := ""


# ------------------------------------------------------------------ setup

## config: {"seats":[{"ai":bool,"name":String,"level":int}] × 3 (UK, USA, URSS), "seed":int, "scenario":int}
func setup(config: Dictionary) -> void:
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	scenario = int(config.get("scenario", 1))
	var sc: Dictionary = D.SCENARIOS[scenario]
	players.clear()
	ais.clear()
	var seats: Array = config["seats"]
	for p in range(3):
		var s: Dictionary = seats[p]
		var a := CHAI.new()
		a.level = int(s.get("level", config.get("ai_level", 1)))
		a.rng.seed = int(config.get("seed", 1)) * 7 + p * 131 + 17
		ais[p] = a
		var deck := range(21)
		_shuffle(deck)
		players.append({
			"p": p, "ai": bool(s.get("ai", true)), "name": str(s.get("name", D.POWERS[p]["leader"])),
			"deck": deck, "hand": [], "discard": [], "dead": [],
			"leader": ["churchill", "roosevelt", "stalin"][p], "lstate": "active", "heart": false,
			"no_adv": false, "pass_ok": false, "paranoia": false, "purge": false,
			"prod": 0, "wins": 0, "cn_gain": 0, "pa_gain": 0, "bonus": [], "tech": 0, "pm_act": [],
		})
	# mazzo delle conferenze: una variante a caso per ogni conferenza dello scenario
	conf_list.clear()
	for n in range(int(sc["first"]), 11):
		conf_list.append((n - 1) * 3 + rng.randi_range(0, 2))
	conf_i = -1
	# mappa
	fronts.clear()
	for f in D.FRONTS:
		fronts.append({"pos": int(sc["fronts"][f["id"]]), "off": 0, "res": 0, "do": [], "noadv": false, "last": ""})
	naval.clear()
	for b in D.BOXES:
		naval[b] = int(sc["naval"].get(b, 0))
	countries.clear()
	for c in D.COUNTRY_ORDER:
		countries[c] = {"cn_p": -1, "cn": 0, "pa": -1, "behind": false}
	for e in sc["net"]:
		var c: Dictionary = countries[e[1]]
		c["cn_p"] = e[0]
		c["cn"] = e[2]
		if e[3]:
			c["pa"] = e[0]
	# spazi già superati dai fronti: i paesi collegati sono «dietro il fronte»
	for fi in range(fronts.size()):
		var tr: Array = D.FRONTS[fi]["track"]
		for k in range(maxi(0, fronts[fi]["pos"])):
			_mark_behind(fi, tr[k], false)
	lead = {"eu": int(sc["lead"]["eu"]), "pa": int(sc["lead"]["pa"])}
	abomb = int(sc["abomb"])
	spy = int(sc["spy"])
	ita_out = sc.get("no_ita", false)
	italy_surr = ita_out
	navy_out = sc.get("no_navy", false)
	glob = [-1, -1, -1]
	removed_issues.clear()
	if sc.get("no_second", false):
		removed_issues[D.issue_index("second")] = true
	if fronts[0]["pos"] >= 1:
		normandy_conf = 0
	if fronts[1]["pos"] >= 3:
		citaly_conf = 0
	for fi in range(fronts.size()):
		var tr2: Array = D.FRONTS[fi]["track"]
		for k in range(fronts[fi]["pos"] + 1):
			if D.SPACES[tr2[k]].get("b29", false):
				b29_entered = true
			if tr2[k] == "philippines":
				phil_entered = true
	if fronts[3]["pos"] >= 1:
		removed_issues[D.issue_index("warjapan")] = true
	# Agenda segreta: ognuno pesca a caso tre segnalini (pescati per ultimi, così il resto del seme non cambia)
	secret = bool(config.get("secret", false))
	for p in range(3):
		players[p]["sa"] = []
	if secret:
		var pool := range(D.SA_TOKENS.size())
		_shuffle(pool)
		for p in range(3):
			players[p]["sa"] = pool.slice(p * 3, p * 3 + 3)
	log_lines.clear()
	game_over = false
	results = {}


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func pname(p: int) -> String:
	return players[p]["name"]


func leader_name(p: int) -> String:
	return str(players[p]["leader"]).capitalize()


func log_msg(t: String) -> void:
	log_lines.append(t)
	if log_lines.size() > 600:
		log_lines.pop_front()
	log_added.emit(t)


func left(p: int) -> int:
	return D.LEFT[p]


func any_local_human() -> bool:
	if online != null:
		return true
	for p in players:
		if not p["ai"]:
			return true
	return false


func d6() -> int:
	return rng.randi_range(1, 6)


# ------------------------------------------------------------------ decisioni

func decide(seat: int, req: Dictionary):
	req["seat"] = seat
	current = seat
	if abort:
		return ais[seat].decide(self, seat, req)
	if online != null:
		var r0 = await online.decide(self, seat, req)
		return r0
	if players[seat]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay).timeout
		return ais[seat].decide(self, seat, req)
	decision_requested.emit(req)
	var r = await decision_provided
	return r


func provide_decision(r) -> void:
	decision_provided.emit(r)


## Pausa per far leggere qualcosa (esito dei fronti, fine conferenza): solo con qualcuno davanti allo schermo.
func pause_point(req: Dictionary) -> void:
	if headless or abort or not pause_enabled:
		return
	if online != null and online.catchup:
		return
	if not any_local_human():
		return
	pause_requested.emit(req)
	await decision_provided


## Passo della fase militare mostrato a chi guarda (dadi sul tavolo, spiegazione e AVANTI).
## Non cambia nulla della partita: il motore aspetta solo che la persona vada avanti.
func war_step(text: String, at := "", sides := 0, roll := 0, ok := true) -> void:
	changed.emit()
	if headless or abort or not pause_enabled:
		return
	if online != null and online.catchup:
		return
	if not any_local_human():
		return
	step_requested.emit({"text": text, "at": at, "sides": sides, "roll": roll, "ok": ok})
	await decision_provided


func _fname(fi: int) -> String:
	return D.FRONTS[fi]["n"]


func _set_phase(ph: String) -> void:
	phase = ph
	step = ""
	phase_changed.emit(conf_no, ph)
	changed.emit()


# ------------------------------------------------------------------ partita

func run() -> void:
	for i in range(conf_list.size()):
		conf_i = i
		await conference()
		if abort:
			return
		if germany_surr and japan_surr:
			log_msg("[b]Germania e Giappone si sono arresi: la guerra è finita.[/b]")
			break
	_final_scoring()


func conference() -> void:
	card = conf_list[conf_i]
	conf_no = D.conf_number(card)
	# preparazione della conferenza
	table.clear()
	blocked_issues.clear()
	won_by.clear()
	agenda_play.clear()
	agenda_winner = -1
	conf_winner = -1
	for pl in players:
		pl["lstate"] = "active"
		pl["no_adv"] = false
		pl["pass_ok"] = false
		pl["paranoia"] = false
		pl["purge"] = false
		pl["prod"] = 0
		pl["cn_gain"] = 0
		pl["pa_gain"] = 0
		pl["bonus"] = []
		pl["pm_act"] = []
	if players[UK]["heart"]:
		players[UK]["heart"] = false
		players[UK]["lstate"] = "inactive"
		log_msg("Churchill si sta riprendendo dall'infarto: è inattivo in questa conferenza.")
	for f in fronts:
		f["off"] = 0
		f["res"] = 0
		f["do"] = []
		f["noadv"] = false
		f["last"] = ""
	card_res = {"ger": 0, "jap": 0, "ruhr": 0}
	ijn_card = ""
	ijn_card_res = 0
	murmansk = 0
	mand = []
	prod_loss = [0, 0, 0]
	uk_lose_cn = false
	dday_ok = false
	manch_ok = false
	ab_mod = 0
	war_report = []
	_set_phase("agenda")
	log_msg("[b]Conferenza %d: %s (%s) – carta %s[/b]" % [conf_no, D.CONF_NAMES[conf_no], D.CONF_DATES[conf_no], D.conf_variant(card)])
	if conf_i == 0 and D.SCENARIOS[scenario].get("second_center", false):
		var si := D.issue_index("second")
		table[si] = {"o": -1, "d": 0, "cap": false}
		log_msg("Il Secondo Fronte è al centro del tavolo.")
	fx.emit("conf_card", {"card": card})
	await _apply_conf_card()
	if abort:
		return
	_deal()
	changed.emit()
	await _agenda()
	if abort:
		return
	await _meeting()
	if abort:
		return
	await _decision()
	if abort:
		return
	await _war()
	if abort:
		return
	prev_winner = conf_winner
	# fine della conferenza: le carte giocate vanno negli scarti, le offensive si tolgono
	for f in fronts:
		f["off"] = 0
		f["res"] = 0
		f["do"] = []
	table.clear()
	changed.emit()


# ------------------------------------------------------------------ carta Conferenza

func _apply_conf_card() -> void:
	for e in D.CONF_CARDS[card]:
		var t: String = e["t"]
		match t:
			"mand":
				var who = e["who"]
				var lst: Array = who if who is Array else [who]
				for w in lst:
					mand.append({"who": int(w), "n": int(e["n"]), "k": e["k"], "th": e["th"], "x": e["x"]})
			"murmansk":
				var m: String = e["m"]
				var ok: bool = m == "fixed"
				if m == "roll" or (m == "north" and naval["arctic"] < 3):
					var r := d6()
					ok = r <= 3
					log_msg("Convoglio di Murmansk: dado %d, %s." % [r, "arriva" if ok else "affondato dagli U-Boot"])
				elif m == "north":
					ok = true
				if ok:
					murmansk += 1
			"prod_loss":
				var apply := true
				if e.get("cond", "") == "v1v2":
					apply = fronts[0]["pos"] < 2
				if apply:
					for w in e["who"]:
						prod_loss[int(w)] += int(e["n"])
				else:
					log_msg("V1/V2: Normandia e Paesi Bassi sono già alleati, nessuna perdita.")
					continue
			"no_adv":
				players[int(e["who"])]["no_adv"] = true
			"inactive":
				players[int(e["who"])]["lstate"] = "inactive"
			"fdr_dies":
				if players[US]["leader"] == "roosevelt":
					players[US]["leader"] = "truman"
					log_msg("[b]Muore Roosevelt: Truman è il nuovo presidente.[/b]")
				else:
					continue
			"issue":
				_card_issue(e)
				continue
			"do_place":
				var ii := D.issue_index(e["id"])
				var fi := D.front_index(e["f"])
				blocked_issues[ii] = true
				if entry(fi) != "" and not theater_surrendered(fi):
					fronts[fi]["do"].append({"flag": USSR, "by": -1})
			"res":
				_card_reserve(e["f"], int(e["n"]))
				if e.has("and"):
					_card_reserve(e["and"], int(e["n"]))
			"res_remove":
				card_res["ruhr"] += int(e["n"])
			"ijn":
				ijn_card = e["f"]
				ijn_card_res = int(e.get("res", 0))
			"no_front":
				fronts[D.front_index(e["f"])]["noadv"] = true
			"uk_lose_cn":
				uk_lose_cn = true
			"partisans":
				log_msg(e["x"])
				for p in [UK, USSR, US]:
					var r2 := d6()
					var k := 2 if r2 <= 3 else 3
					log_msg("%s tira %d: %d Reti Clandestine con la tabella Pol-Mil." % [pname(p), r2, k])
					for j in range(k):
						_polmil_cn(p, _polmil_roll(), e.get("soft", false))
				changed.emit()
				continue
			"dispute", "exile":
				log_msg(e["x"])
				var r3 := d6()
				if r3 > 3:
					log_msg("Dado %d: nessun effetto." % r3)
					continue
				for j in range(r3):
					var c := _polmil_roll()
					if t == "dispute":
						if countries[c]["cn"] > 0:
							log_msg("Tolte le Reti Clandestine da %s." % D.COUNTRIES[c]["n"])
						countries[c]["cn"] = 0
						countries[c]["cn_p"] = -1
					else:
						if countries[c]["pa"] >= 0:
							log_msg("Tolto l'Allineamento Politico (%s) da %s." % [D.POWERS[countries[c]["pa"]]["short"], D.COUNTRIES[c]["n"]])
						countries[c]["pa"] = -1
				changed.emit()
				continue
			"yugo":
				var r4 := d6()
				var y: Dictionary = countries["yugoslavia"]
				if r4 <= 3:
					y["cn"] = 0
					y["cn_p"] = -1
					log_msg("Jugoslavia (dado %d): tolte tutte le Reti Clandestine." % r4)
				else:
					y["pa"] = -1
					log_msg("Jugoslavia (dado %d): tolto l'Allineamento Politico." % r4)
				changed.emit()
				continue
			"tito":
				var y2: Dictionary = countries["yugoslavia"]
				if y2["cn_p"] >= 0 and y2["cn_p"] != USSR:
					y2["cn"] = 0
					y2["cn_p"] = -1
				if y2["cn_p"] == -1:
					y2["cn_p"] = USSR
					y2["cn"] = 1
				elif y2["cn"] < 2:
					y2["cn"] += 1
				log_msg("Tito: in Jugoslavia restano solo Reti sovietiche.")
				changed.emit()
				continue
		log_msg("· " + str(e["x"]))
	changed.emit()


func _card_issue(e: Dictionary) -> void:
	var id: String = e["id"]
	if e.get("cond", "") == "no_normandy" and normandy_conf >= 0:
		log_msg("La Normandia è già alleata: il Secondo Fronte non va sul tavolo.")
		return
	var cand := []
	if id == "prod_us" or id == "do_us":
		cand = [D.issue_index(id + "_a"), D.issue_index(id + "_b")]
	else:
		cand = [D.issue_index(id)]
	for ii in cand:
		if issue_available(ii):
			var o := -1
			var dd := 0
			if e.has("track"):
				o = int(e["track"])
				dd = d6()
			table[ii] = {"o": o, "d": dd, "cap": false}
			log_msg("· " + str(e["x"]) + ((" (dado %d)" % dd) if dd > 0 else ""))
			return
	log_msg("· " + str(e["x"]) + " (tema non disponibile)")


func _card_reserve(f: String, n: int) -> void:
	var fi := D.front_index(f)
	if D.FRONTS[fi]["th"] == "eu":
		card_res["ger"] += n
	else:
		card_res["jap"] += n
	fronts[fi]["res"] += n


func _polmil_roll() -> String:
	var a := d6()
	var b := d6()
	return D.POLMIL_TABLE[a - 1][b - 1]


## Rete Clandestina piazzata dalla tabella Pol-Mil (5.12).
func _polmil_cn(p: int, c: String, soft := false) -> void:
	var cc: Dictionary = countries[c]
	var nm: String = D.COUNTRIES[c]["n"]
	if soft and cc["cn_p"] >= 0 and cc["cn_p"] != p:
		log_msg("  %s: ci sono reti di %s, nessuna rete piazzata." % [nm, D.POWERS[cc["cn_p"]]["short"]])
	elif cc["cn_p"] >= 0 and cc["cn_p"] != p:
		cc["cn"] -= 1
		log_msg("  %s: %s toglie una Rete di %s." % [nm, D.POWERS[p]["short"], D.POWERS[cc["cn_p"]]["short"]])
		if cc["cn"] <= 0:
			cc["cn"] = 0
			cc["cn_p"] = -1
	elif cc["cn_p"] == p and cc["cn"] >= 2:
		log_msg("  %s: %s ha già due Reti, la nuova va persa." % [nm, D.POWERS[p]["short"]])
	else:
		cc["cn_p"] = p
		cc["cn"] += 1
		log_msg("  %s: nuova Rete Clandestina di %s." % [nm, D.POWERS[p]["short"]])


# ------------------------------------------------------------------ carte dello staff

func _deal() -> void:
	for pl in players:
		pl["hand"] = []
		if conf_no % 2 == 1:
			var deck := []
			for c in range(21):
				if not c in pl["dead"]:
					deck.append(c)
			_shuffle(deck)
			pl["deck"] = deck
			pl["discard"] = []
		for k in range(7):
			if pl["deck"].is_empty():
				var dk: Array = pl["discard"].duplicate()
				pl["discard"] = []
				_shuffle(dk)
				pl["deck"] = dk
				if dk.is_empty():
					break
			pl["hand"].append(pl["deck"].pop_back())
	log_msg("Ogni leader riceve sette carte dello staff.")


func staff(p: int, c: int) -> Dictionary:
	return D.STAFF[p][c]


func leader_active(p: int) -> bool:
	return players[p]["lstate"] == "active"


func can_lead_advance(p: int) -> bool:
	return leader_active(p) and not players[p]["no_adv"] and players[p]["hand"].size() > 0


## Condizioni dei modificatori delle carte (vedi D.STAFF).
func _cond(cnd: String, p: int, ii: int) -> bool:
	if cnd.begins_with("i:"):
		return ii >= 0 and cnd.substr(2) in D.issue_tags(ii)
	if cnd.begins_with("t:"):
		if ii < 0 or not table.has(ii):
			return false
		var who := ["uk", "us", "ussr"].find(cnd.substr(2))
		return table[ii]["o"] == who and table[ii]["d"] > 0
	if cnd.begins_with("la:"):
		return leader_active(int(cnd.substr(3)))
	if cnd == "lr":
		return players[US]["leader"] == "roosevelt" and leader_active(US)
	return false


func card_mod(p: int, c: int, ii: int) -> int:
	var tot := 0
	for m in staff(p, c).get("m", []):
		for grp in m["c"]:
			var ok := true
			for cnd in grp:
				if not _cond(cnd, p, ii):
					ok = false
					break
			if ok:
				tot += int(m["v"])
				break
	return tot


## Valore di una carta dello staff giocata su un tema. base = valore stampato (o tirato per i Capi di S.M.).
func staff_value(p: int, c: int, ii: int, debate: bool, base := -1) -> int:
	var sd := staff(p, c)
	var v: int = base if base >= 0 else int(sd["v"])
	if p == USSR and players[USSR]["paranoia"]:
		v = maxi(1, v - 1)
	if sd.get("a", "") == "hopkins":
		if players[US]["leader"] == "truman":
			v -= 3
	v += card_mod(p, c, ii)
	if debate and p == USSR:
		v += 1
	return v


func hopkins_choice(p: int, c: int, ii: int) -> bool:
	return p == US and staff(p, c).get("a", "") == "hopkins" and ii >= 0 and D.ISSUES[ii]["k"] == "strat" and players[US]["leader"] == "roosevelt"


# ------------------------------------------------------------------ temi

func issue_available(ii: int) -> bool:
	return not table.has(ii) and not removed_issues.has(ii) and not blocked_issues.has(ii)


func available_issues() -> Array:
	var out := []
	for i in range(D.ISSUES.size()):
		if issue_available(i):
			out.append(i)
	return out


func open_issues() -> Array:
	var out := []
	for i in table:
		if not table[i]["cap"]:
			out.append(i)
	out.sort()
	return out


## Sposta una posizione di n spazi verso la sedia di q (prima verso il centro se è sul lato di un altro).
static func moved(pos: Dictionary, q: int, n: int) -> Dictionary:
	var o: int = pos["o"]
	var d: int = pos["d"]
	if n <= 0:
		return {"o": o, "d": d}
	if d == 0 or o == q:
		return {"o": q, "d": d + n}
	if n < d:
		return {"o": o, "d": d - n}
	if n == d:
		return {"o": -1, "d": 0}
	return {"o": q, "d": n - d}


func _place(ii: int, pos: Dictionary) -> void:
	var cap: bool = pos["o"] >= 0 and pos["d"] >= 7
	table[ii] = {"o": pos["o"] if pos["d"] > 0 else -1, "d": mini(pos["d"], 7) if pos["d"] > 0 else 0, "cap": cap}


func pos_text(pos: Dictionary) -> String:
	if pos["d"] <= 0:
		return "al centro"
	if pos["d"] >= 7:
		return "sulla sedia di %s" % D.POWERS[pos["o"]]["leader"]
	return "nello spazio %d %s" % [pos["d"], ["britannico", "americano", "sovietico"][pos["o"]]]


# ------------------------------------------------------------------ Agenda

func _agenda() -> void:
	step = "agenda_card"
	changed.emit()
	for p in [UK, USSR, US]:
		var hand: Array = players[p]["hand"]
		if hand.is_empty():
			continue
		var r = await decide(p, {"type": "agenda_card"})
		if abort:
			return
		var k := clampi(int(r) if (r is int or r is float) else 0, 0, hand.size() - 1)
		var cid: int = hand[k]
		hand.remove_at(k)
		players[p]["discard"].append(cid)
		agenda_play[p] = {"card": cid, "v": 0}
		changed.emit()
	# rivelazione
	var parts := []
	for p in [UK, USSR, US]:
		if not agenda_play.has(p):
			continue
		var cid: int = agenda_play[p]["card"]
		var v: int = int(staff(p, cid)["v"])
		var note := ""
		if v == 0:
			v = d6()
			note = " (dado)"
		if p == UK:
			v += 1
			note += " +1 Stato Maggiore Imperiale"
		agenda_play[p]["v"] = v
		parts.append("%s %s: %d%s" % [D.POWERS[p]["leader"], staff(p, cid)["n"], v, note])
	log_msg("Agenda: " + "; ".join(parts) + ".")
	fx.emit("agenda", {})
	changed.emit()
	var best := -1
	for p in agenda_play:
		best = maxi(best, agenda_play[p]["v"])
	var tied := []
	for p in [UK, USSR, US]:
		if agenda_play.has(p) and agenda_play[p]["v"] == best:
			tied.append(p)
	var w: int = tied[0]
	if tied.size() > 1:
		w = await _tiebreak(tied, "agenda")
		if abort:
			return
	agenda_winner = w
	var low := 99
	for p in agenda_play:
		if p != w:
			low = mini(low, agenda_play[p]["v"])
	if low == 99:
		low = best
	var diff := maxi(0, agenda_play[w]["v"] - low)
	log_msg("[b]%s vince l'Agenda[/b] (differenza %d)." % [D.POWERS[w]["leader"], diff])
	await pause_point({"type": "ack", "ctx": "agenda"})
	step = "agenda_pick"
	changed.emit()
	# il vincitore sceglie un tema e lo mette sul suo tracciato
	if not available_issues().is_empty():
		var r2 = await decide(w, {"type": "agenda_pick", "first": true, "diff": diff, "options": available_issues()})
		if abort:
			return
		var ii := _pick_issue(r2)
		table[ii] = {"o": w if diff > 0 else -1, "d": mini(diff, 6), "cap": false}
		log_msg("%s mette %s %s." % [D.POWERS[w]["leader"], D.ISSUES[ii]["n"], pos_text(table[ii])])
		changed.emit()
	# poi ognuno, da sinistra del vincitore, ne mette due al centro
	var q := left(w)
	for k in range(3):
		for j in range(2):
			if available_issues().is_empty():
				break
			var r3 = await decide(q, {"type": "agenda_pick", "first": false, "options": available_issues()})
			if abort:
				return
			var i3 := _pick_issue(r3)
			table[i3] = {"o": -1, "d": 0, "cap": false}
			log_msg("%s mette al centro: %s." % [D.POWERS[q]["leader"], D.ISSUES[i3]["n"]])
			changed.emit()
		q = left(q)


func _pick_issue(r) -> int:
	var av := available_issues()
	var ii := int(r) if (r is int or r is float) else -1
	if ii in av:
		return ii
	return av[0]


## Spareggio (4.5): a partire da Stalin e verso sinistra un Leader attivo può risolverlo; altrimenti decidono gli USA.
func _tiebreak(tied: Array, ctx: String) -> int:
	var names := []
	for p in tied:
		names.append(D.POWERS[p]["leader"])
	log_msg("Parità fra %s." % ", ".join(names))
	for p in D.TIE_ORDER:
		if not leader_active(p):
			continue
		var r = await decide(p, {"type": "tie_leader", "tied": tied, "ctx": ctx})
		if abort:
			return tied[0]
		if r is Dictionary and r.get("use", false):
			var w: int = p if p in tied else int(r.get("win", tied[0]))
			if not w in tied:
				w = tied[0]
			players[p]["lstate"] = "inactive"
			log_msg("%s usa il suo Leader per risolvere la parità: vince %s." % [D.POWERS[p]["leader"], D.POWERS[w]["leader"]])
			changed.emit()
			return w
	if US in tied:
		log_msg("Arsenale della Democrazia: la parità va agli Stati Uniti.")
		return US
	var r2 = await decide(US, {"type": "us_tie", "tied": tied, "ctx": ctx})
	var w2: int = int(r2) if (r2 is int or r2 is float) else int(tied[0])
	if not w2 in tied:
		w2 = tied[0]
	log_msg("Arsenale della Democrazia: gli USA assegnano la parità a %s." % D.POWERS[w2]["leader"])
	return w2


# ------------------------------------------------------------------ Riunione

func _meeting() -> void:
	_set_phase("meeting")
	log_msg("[b]Riunione[/b]")
	var p := left(agenda_winner)
	var guard := 0
	while guard < 200:
		guard += 1
		var any := false
		for pl in players:
			if not pl["hand"].is_empty():
				any = true
		if not any:
			break
		if players[p]["hand"].is_empty():
			p = left(p)
			continue
		await _advance_turn(p)
		if abort:
			return
		p = left(p)
	# fine della riunione: i temi sui tracciati sono vinti
	for i in table:
		if table[i]["o"] >= 0 and table[i]["d"] > 0:
			won_by[i] = table[i]["o"]
	changed.emit()


func _advance_turn(p: int) -> void:
	step = "advance"
	var pl: Dictionary = players[p]
	var can_pass: bool = pl["pass_ok"]
	pl["pass_ok"] = false
	var opts := open_issues()
	if opts.is_empty():
		var c0: int = pl["hand"][0]
		_discard(p, 0, false)
		log_msg("%s scarta %s: non c'è più alcun tema da discutere." % [D.POWERS[p]["leader"], staff(p, c0)["n"]])
		changed.emit()
		return
	var r = await decide(p, {"type": "advance", "can_pass": can_pass, "leader_ok": can_lead_advance(p), "issues": opts})
	if abort:
		return
	if not (r is Dictionary):
		r = {}
	if can_pass and r.get("pass", false):
		log_msg("%s passa (aveva dibattuto)." % D.POWERS[p]["leader"])
		changed.emit()
		return
	var hand: Array = pl["hand"]
	var k := int(r.get("card", 0))
	if k < 0 or k >= hand.size():
		k = 0
	var use_leader: bool = r.get("leader", false) and can_lead_advance(p)
	var ii := int(r.get("issue", -1))
	var cid: int = hand[k]
	if opts.is_empty():
		_discard(p, k, false)
		log_msg("%s gioca %s, ma non c'è più alcun tema da discutere." % [D.POWERS[p]["leader"], staff(p, cid)["n"]])
		changed.emit()
		return
	var val := 0
	var who_txt := ""
	if use_leader:
		if not ii in opts:
			ii = opts[0]
		_discard(p, k, true)
		val = _leader_value(p)
		who_txt = leader_name(p)
		var pre_pos: Dictionary = table[ii].duplicate()
		await _move_and_debate(p, ii, val, true, who_txt)
		_leader_after(p, ii, pre_pos)
	else:
		var base := -1
		if int(staff(p, cid)["v"]) == 0:
			base = d6()
			log_msg("%s gioca %s: il dado dà %d." % [D.POWERS[p]["leader"], staff(p, cid)["n"], base])
			if not ii in opts:
				var r2 = await decide(p, {"type": "advance_cos", "card": cid, "roll": base, "issues": opts})
				if abort:
					return
				ii = int(r2) if (r2 is int or r2 is float) else -1
		if not ii in opts:
			ii = opts[0]
		if hopkins_choice(p, cid, ii):
			var r3 = await decide(p, {"type": "hopkins", "issue": ii})
			if abort:
				return
			base = clampi(int(r3) if (r3 is int or r3 is float) else 6, 1, 6)
		val = staff_value(p, cid, ii, false, base)
		who_txt = staff(p, cid)["n"]
		_play_staff(p, k, ii)
		await _move_and_debate(p, ii, val, false, who_txt)
		_after_staff(p, cid, ii)
	changed.emit()


## Valore del Leader quando lo si usa per avanzare o dibattere.
func _leader_value(p: int) -> int:
	if players[p]["leader"] == "truman" and abomb < 4:
		var a := d6()
		var b := d6()
		if a + b <= 5:
			log_msg("Inesperienza di Truman (%d+%d): vale 4." % [a, b])
			return 4
	return 7


## Effetti del Leader dopo l'uso (attributi e salute).
func _leader_after(p: int, ii: int, pre: Dictionary) -> void:
	var pl: Dictionary = players[p]
	pl["lstate"] = "inactive"
	var k: String = D.ISSUES[ii]["k"]
	match pl["leader"]:
		"stalin":
			if k == "polmil":
				pl["cn_gain"] += 1
				log_msg("Stalin: +1 Rete Clandestina.")
			var a := d6()
			var b := d6()
			if a + b <= 4:
				pl["paranoia"] = true
				log_msg("[color=#f08a7c]Paranoia di Stalin (%d+%d): le carte sovietiche valgono 1 in meno per il resto della conferenza.[/color]" % [a, b])
		"churchill":
			if k == "global":
				pl["pa_gain"] += 1
				log_msg("Churchill: +1 Allineamento Politico.")
			var a2 := d6()
			var b2 := d6()
			if a2 + b2 <= 4:
				pl["heart"] = true
				log_msg("[color=#f08a7c]Infarto di Churchill (%d+%d): sarà inattivo nella prossima conferenza.[/color]" % [a2, b2])
		"roosevelt":
			if k == "global" and pre["o"] in [UK, USSR] and pre["d"] > 0:
				pl["pa_gain"] += 1
				log_msg("Roosevelt: +1 Allineamento Politico.")
			var a3 := d6()
			var b3 := d6()
			if a3 + b3 <= 3:
				pl["leader"] = "truman"
				log_msg("[b][color=#f08a7c]Roosevelt muore (%d+%d): gli succede Truman.[/color][/b]" % [a3, b3])
		"truman":
			if abomb >= 4:
				pl["pa_gain"] += 1
				log_msg("Truman: +1 Allineamento Politico.")


## Gioca una carta dello staff (la toglie dalla mano) e applica le azioni immediate.
func _play_staff(p: int, k: int, ii: int) -> void:
	var cid: int = players[p]["hand"][k]
	players[p]["hand"].remove_at(k)
	players[p]["discard"].append(cid)
	var sd := staff(p, cid)
	var a: String = sd.get("a", "")
	var is_do: bool = ii >= 0 and D.ISSUES[ii]["k"] == "do"
	match a:
		"anderson":
			var r := d6()
			if r == 1:
				players[p]["bonus"].append({"n": 2, "k": "off", "th": "any", "x": "Anderson"})
				log_msg("Anderson (dado 1): +2 supporti offensivi.")
			else:
				log_msg("Anderson: dado %d, niente." % r)
		"noble":
			if fronts[0]["pos"] < 0 and not germany_surr:
				_add_naval("west", 1, "Noble")
		"tovey":
			var en := entry(1)
			if en != "" and D.SPACES[en].has("amph") and not germany_surr:
				fronts[1]["off"] += 1
				log_msg("Tovey: +1 supporto offensivo al Mediterraneo.")
		"knox":
			if ii >= 0 and D.ISSUES[ii]["k"] == "prod":
				players[p]["bonus"].append({"n": 2, "k": "naval", "th": "any", "x": "Knox"})
				log_msg("Knox: +2 supporti navali.")
		"king":
			_king_pending = true
		"kuznetsov":
			if not germany_surr:
				_add_naval("arctic", 1, "Kuznecov")
		"vasilevsky":
			_card_off("fe", 1, "Vasilevskij")
		"east_do":
			if is_do:
				_card_off("east", 1, sd["n"])
		"fe_do":
			if is_do:
				_card_off("fe", 1, sd["n"])


var _king_pending := false


func _after_staff(p: int, cid: int, ii: int) -> void:
	var sd := staff(p, cid)
	if _king_pending:
		_king_pending = false
		_king(p)
	_purge_check(p, cid)
	if sd.has("h"):
		var r := d6()
		if r <= int(sd["h"]):
			_kill(p, cid, "muore" if sd["n"] != "Nikolaj Vatutin" else "cade in un'imboscata")
	if sd.get("p", false):
		players[p]["purge"] = true


func _king(p: int) -> void:
	# Prima il Pacifico: se nessun Fronte alleato è in una base B29, +2 offensive al Pacifico Centrale o Sud-Occidentale.
	if japan_surr:
		return
	for fi in range(fronts.size()):
		var sp := space_of(fi)
		if sp != "" and D.SPACES[sp].get("b29", false):
			return
	var cp := D.front_index("cp")
	var sw := D.front_index("swp")
	var opts := []
	for fi in [cp, sw]:
		if entry(fi) != "":
			opts.append(fi)
	if opts.is_empty():
		return
	var tgt: int = opts[0]
	if opts.size() > 1:
		tgt = cp if ais[p].king_choice(self, p) == "cp" else sw
	fronts[tgt]["off"] += 2
	log_msg("King, «prima il Pacifico»: +2 supporti offensivi al %s." % D.FRONTS[tgt]["n"])


func _purge_check(p: int, cid: int) -> void:
	if p != USSR or not players[USSR]["purge"]:
		return
	players[USSR]["purge"] = false
	var r := d6()
	if r == 1:
		_kill(USSR, cid, "è eliminato dalle purghe")
	else:
		log_msg("Purghe: %s se la cava (dado %d)." % [staff(USSR, cid)["n"], r])


func _kill(p: int, cid: int, why: String) -> void:
	players[p]["dead"].append(cid)
	players[p]["discard"].erase(cid)
	log_msg("[color=#f08a7c]%s %s: la carta esce dal gioco.[/color]" % [staff(p, cid)["n"], why])


func _discard(p: int, k: int, for_leader: bool) -> void:
	var cid: int = players[p]["hand"][k]
	players[p]["hand"].remove_at(k)
	players[p]["discard"].append(cid)
	if for_leader:
		log_msg("%s scarta %s per usare %s." % [D.POWERS[p]["leader"], staff(p, cid)["n"], leader_name(p)])
	_purge_check(p, cid)


func _card_off(f: String, n: int, who: String) -> void:
	var fi := D.front_index(f)
	if entry(fi) == "" or theater_surrendered(fi):
		return
	fronts[fi]["off"] += n
	log_msg("%s: +%d supporto offensivo al %s." % [who, n, D.FRONTS[fi]["n"]])


func _add_naval(b: String, n: int, who: String) -> void:
	var before: int = naval[b]
	naval[b] = mini(5, naval[b] + n)
	if naval[b] > before:
		log_msg("%s: +%d supporto navale nel %s." % [who, naval[b] - before, D.BOXES[b]["n"]])


## Muove il tema e gestisce dibattito e cattura (5.22–5.24).
func _move_and_debate(p: int, ii: int, val: int, by_leader: bool, who: String) -> void:
	var pre: Dictionary = table[ii].duplicate()
	var target := moved(pre, p, val)
	var no_debate: bool = by_leader and players[p]["leader"] == "stalin" and D.ISSUES[ii]["k"] == "abomb"
	if target["o"] == p and target["d"] >= 7:
		log_msg("%s: %s porta %s verso la sedia (%d)." % [D.POWERS[p]["leader"], who, D.ISSUES[ii]["n"], val])
		fx.emit("advance", {"seat": p, "issue": ii})
		var deb: Dictionary = {}
		if not no_debate:
			deb = await _debate_offer(p, ii, val, by_leader, true)
		if abort:
			return
		if deb.is_empty():
			_place(ii, {"o": p, "d": 7})
			log_msg("[b]%s cattura %s.[/b]" % [D.POWERS[p]["leader"], D.ISSUES[ii]["n"]])
			fx.emit("capture", {"seat": p, "issue": ii})
			return
		var q: int = deb["seat"]
		var diff: int = val - int(deb["v"])
		var pos := pre
		if diff > 0:
			pos = moved(pre, p, diff)
		elif diff < 0:
			pos = moved(pre, q, -diff)
		_place(ii, pos)
		if table[ii]["cap"]:
			log_msg("[b]%s cattura %s.[/b]" % [D.POWERS[table[ii]["o"]]["leader"], D.ISSUES[ii]["n"]])
			fx.emit("capture", {"seat": table[ii]["o"], "issue": ii})
		else:
			log_msg("Dopo il dibattito %s resta %s." % [D.ISSUES[ii]["n"], pos_text(table[ii])])
		return
	var final: Dictionary = await _maybe_stop(p, ii, pre, val)
	_place(ii, final)
	log_msg("%s: %s porta %s %s (%d)." % [D.POWERS[p]["leader"], who, D.ISSUES[ii]["n"], pos_text(table[ii]), val])
	fx.emit("advance", {"seat": p, "issue": ii})
	changed.emit()
	if no_debate:
		return
	var deb2: Dictionary = await _debate_offer(p, ii, val, by_leader, false)
	if abort or deb2.is_empty():
		return
	var q2: int = deb2["seat"]
	var cur: Dictionary = table[ii].duplicate()
	var fin: Dictionary = await _maybe_stop(q2, ii, cur, int(deb2["v"]))
	_place(ii, fin)
	if table[ii]["cap"]:
		log_msg("[b]%s cattura %s nel dibattito.[/b]" % [D.POWERS[q2]["leader"], D.ISSUES[ii]["n"]])
		fx.emit("capture", {"seat": q2, "issue": ii})
	else:
		log_msg("Dopo il dibattito %s è %s." % [D.ISSUES[ii]["n"], pos_text(table[ii])])
	changed.emit()


## Temi condizionali: chi li fa passare per il centro può fermarli lì (5.22).
func _maybe_stop(p: int, ii: int, pre: Dictionary, n: int) -> Dictionary:
	var fin := moved(pre, p, n)
	if D.ISSUES[ii]["k"] != "cond":
		return fin
	if pre["d"] > 0 and pre["o"] != p and n > pre["d"]:
		var r = await decide(p, {"type": "cond_stop", "issue": ii, "pos": fin})
		if r == true:
			log_msg("%s ferma %s al centro del tavolo." % [D.POWERS[p]["leader"], D.ISSUES[ii]["n"]])
			return {"o": -1, "d": 0}
	return fin


## Offre il dibattito agli altri due giocatori, a partire da quello a sinistra di chi ha avanzato.
func _debate_offer(p: int, ii: int, val: int, by_leader: bool, capture: bool) -> Dictionary:
	step = "debate"
	var q := left(p)
	for k in range(2):
		var pl: Dictionary = players[q]
		var can: bool = not pl["hand"].is_empty() and (not by_leader or leader_active(q))
		if can:
			var r = await decide(q, {"type": "debate", "issue": ii, "adv_seat": p, "adv_val": val, "leader_only": by_leader,
				"leader_ok": leader_active(q), "capture": capture})
			if abort:
				return {}
			if r is Dictionary and r.has("card"):
				var hand: Array = pl["hand"]
				var kk := int(r["card"])
				if kk >= 0 and kk < hand.size():
					var use_leader: bool = (r.get("leader", false) or by_leader) and leader_active(q)
					if by_leader and not use_leader:
						q = left(q)
						continue
					pl["pass_ok"] = true
					var v := 0
					if use_leader:
						var pre: Dictionary = table[ii].duplicate()
						_discard(q, kk, true)
						v = _leader_value(q)
						log_msg("%s dibatte con %s (%d)." % [D.POWERS[q]["leader"], leader_name(q), v])
						_leader_after(q, ii, pre)
					else:
						var cid: int = hand[kk]
						var base := -1
						if int(staff(q, cid)["v"]) == 0:
							base = d6()
						if hopkins_choice(q, cid, ii):
							var r3 = await decide(q, {"type": "hopkins", "issue": ii})
							base = clampi(int(r3) if (r3 is int or r3 is float) else 6, 1, 6)
						v = staff_value(q, cid, ii, true, base)
						log_msg("%s dibatte con %s (%d%s)." % [D.POWERS[q]["leader"], staff(q, cid)["n"], v, ", dado" if int(staff(q, cid)["v"]) == 0 else ""])
						_play_staff(q, kk, ii)
						_after_staff(q, cid, ii)
					fx.emit("debate", {"seat": q, "issue": ii})
					step = "advance"
					return {"seat": q, "v": v}
		q = left(q)
	step = "advance"
	return {}


# ------------------------------------------------------------------ Decisioni

func issues_won(p: int) -> int:
	var n := 0
	for i in won_by:
		if won_by[i] == p:
			n += 1
	return n


func _decision() -> void:
	_set_phase("decision")
	# vincitore della conferenza
	var counts := []
	var best := -1
	for p in range(3):
		counts.append(issues_won(p))
		best = maxi(best, counts[p])
	var tied := []
	for p in [UK, USSR, US]:
		if counts[p] == best:
			tied.append(p)
	var w: int = tied[0]
	if tied.size() > 1:
		w = await _tiebreak(tied, "conference")
		if abort:
			return
	conf_winner = w
	players[w]["wins"] += 1
	log_msg("[b]%s vince la conferenza[/b] (temi vinti: UK %d, USA %d, URSS %d)." % [D.POWERS[w]["leader"], counts[UK], counts[US], counts[USSR]])
	fx.emit("conf_win", {"seat": w})
	changed.emit()
	await pause_point({"type": "ack", "ctx": "meeting_end"})
	var order := [left(w), left(left(w)), w]
	# 1. offensive dirette
	step = "do"
	for p in order:
		for i in won_by:
			if won_by[i] != p or D.ISSUES[i]["k"] != "do":
				continue
			var opts := do_targets()
			if opts.is_empty():
				log_msg("%s: nessun fronte può ricevere %s." % [D.POWERS[p]["leader"], D.ISSUES[i]["n"]])
				continue
			var r = await decide(p, {"type": "place_do", "issue": i, "options": opts})
			if abort:
				return
			var fi := int(r) if (r is int or r is float) else -1
			if not fi in opts:
				fi = opts[0]
			fronts[fi]["do"].append({"flag": int(D.ISSUES[i]["f"]), "by": p})
			log_msg("%s piazza %s sul %s (%s)." % [D.POWERS[p]["leader"], D.ISSUES[i]["n"], D.FRONTS[fi]["n"], D.SPACES[entry(fi)]["n"]])
			changed.emit()
	# 2. temi condizionali
	var si := D.issue_index("second")
	var wi := D.issue_index("warjapan")
	dday_ok = table.has(si) and table[si]["d"] == 0
	manch_ok = table.has(wi) and table[wi]["d"] == 0
	if dday_ok:
		log_msg("Secondo Fronte al centro: il Fronte Occidentale può tentare lo sbarco in Normandia.")
	if manch_ok:
		log_msg("L'URSS dichiara guerra al Giappone: il Fronte dell'Estremo Oriente può entrare in Manciuria.")
	# 3. produzione
	step = "production"
	for p in range(3):
		players[p]["prod"] = D.BASE_PROD[p] - prod_loss[p]
	for i in won_by:
		if D.ISSUES[i]["k"] == "prod":
			var f: int = D.ISSUES[i]["f"]
			if won_by[i] != f:
				players[won_by[i]]["prod"] += 1
				players[f]["prod"] -= 1
	var st := D.issue_index("strat")
	if table.has(st):
		if table[st]["d"] == 0:
			for p in range(3):
				players[p]["prod"] += 1
			log_msg("Materiali Strategici al centro: +1 Produzione a tutti.")
		elif won_by.has(st):
			players[won_by[st]]["prod"] += 1
	if naval["arctic"] >= 3:
		players[USSR]["prod"] += 1
		log_msg("Artico sicuro (3+ supporti navali): +1 Produzione all'URSS.")
	if murmansk > 0:
		players[USSR]["prod"] += murmansk
		log_msg("Convoglio di Murmansk: +%d Produzione all'URSS." % murmansk)
	for p in range(3):
		players[p]["prod"] = maxi(0, players[p]["prod"])
	log_msg("Produzione: UK %d, USA %d, URSS %d." % [players[UK]["prod"], players[US]["prod"], players[USSR]["prod"]])
	# bonus di comando dei teatri (6.91, 6.92)
	for th in ["eu", "pa"]:
		var holder: int = lead[th]
		players[holder]["bonus"].append({"n": 1, "k": "any", "th": th, "x": "Comando %s" % ("Europa" if th == "eu" else "Pacifico")})
	var lw := {}
	for id in ["euro", "pac"]:
		var ii := D.issue_index(id)
		if won_by.has(ii):
			var q: int = won_by[ii]
			players[q]["bonus"].append({"n": 2, "k": "any", "th": "eu" if id == "euro" else "pa", "x": D.ISSUES[ii]["n"]})
			lw[id] = q
	if lw.size() == 2 and lw["euro"] == lw["pac"]:
		players[lw["euro"]]["bonus"].append({"n": 2, "k": "any", "th": "any", "x": "entrambi i Comandi"})
	changed.emit()
	# 4. assegnazione della produzione
	step = "alloc"
	for p in order:
		await _allocate(p)
		if abort:
			return
	# Negoziati con la Turchia
	if uk_lose_cn:
		var mine := []
		for c in D.COUNTRY_ORDER:
			if countries[c]["cn_p"] == UK:
				mine.append(c)
		if not mine.is_empty():
			var r2 = await decide(UK, {"type": "lose_cn", "options": mine})
			var c2: String = str(r2) if str(r2) in mine else mine[0]
			countries[c2]["cn"] -= 1
			if countries[c2]["cn"] <= 0:
				countries[c2]["cn"] = 0
				countries[c2]["cn_p"] = -1
			log_msg("Negoziati con la Turchia: il Regno Unito perde la Rete in %s." % D.COUNTRIES[c2]["n"])
	# 5. comando dei teatri
	step = "leadership"
	for id in ["euro", "pac"]:
		if not lw.has(id):
			continue
		var th := "eu" if id == "euro" else "pa"
		var q2: int = lw[id]
		var r3 = await decide(q2, {"type": "lead_ctrl", "th": th})
		if abort:
			return
		var who := int(r3) if (r3 is int or r3 is float) else (q2 if q2 != USSR else UK)
		if not who in [UK, US]:
			who = UK
		lead[th] = who
		log_msg("%s affida il comando del teatro %s a %s." % [D.POWERS[q2]["leader"], "europeo" if th == "eu" else "del Pacifico", D.POWERS[who]["nation"]])
		changed.emit()
	# 6. ricerca Bomba A
	step = "abomb"
	var ab := D.issue_index("abomb")
	if won_by.has(ab):
		var q3: int = won_by[ab]
		if abomb < 4:
			var r4 := d6()
			var tot := r4 + ab_mod
			if tot >= 4:
				abomb += 1
				log_msg("Ricerca Bomba A: %d%s = %d, la Bomba avanza a %s." % [r4, (" +%d" % ab_mod) if ab_mod > 0 else "", tot, D.ABOMB[abomb]])
				fx.emit("abomb", {})
			else:
				log_msg("Ricerca Bomba A: %d%s = %d, nessun progresso." % [r4, (" +%d" % ab_mod) if ab_mod > 0 else "", tot])
		if q3 == USSR and spy < 4:
			spy += 1
			log_msg("La rete di spie sovietica avanza a %s." % D.ABOMB[spy])
		changed.emit()
	# 7. tema Globale
	step = "global"
	var gi := D.issue_index("global")
	if won_by.has(gi):
		var q4: int = won_by[gi]
		var opts2 := []
		for g in range(3):
			if q4 in D.GLOBALS[g]["pair"] and glob[g] != q4:
				opts2.append(g)
		if opts2.is_empty():
			log_msg("%s ha già entrambi i temi Globali dalla sua parte." % D.POWERS[q4]["leader"])
		else:
			var g2: int = opts2[0]
			if opts2.size() > 1:
				var r5 = await decide(q4, {"type": "global_move", "options": opts2})
				if abort:
					return
				g2 = int(r5) if (r5 is int or r5 is float) and int(r5) in opts2 else opts2[0]
			glob[g2] = q4
			log_msg("[b]Tema Globale %s: %s.[/b]" % [D.GLOBALS[g2]["n"], D.GLOBALS[g2]["side"][q4]])
			fx.emit("global", {"g": g2})
		changed.emit()


func do_targets() -> Array:
	var out := []
	for fi in range(fronts.size()):
		if entry(fi) != "" and not theater_surrendered(fi):
			out.append(fi)
	return out


## Bersagli per un marcatore di produzione o di supporto.
## k: "off", "naval", "any"; th: "eu", "pa", "any" o un teatro specifico (west, med, cbi, cp, swp, fe, arctic, pacific).
func support_targets(k: String, th: String) -> Array:
	var out := []
	if k == "off" or k == "any":
		for fi in range(fronts.size()):
			var f: Dictionary = D.FRONTS[fi]
			if entry(fi) == "" or theater_surrendered(fi):
				continue
			if _th_match(f["box"], f["th"], th):
				out.append({"k": "off", "f": fi})
	if k == "naval" or k == "any":
		for b in ["west", "med", "arctic", "fe", "cbi", "cp", "swp"]:
			var bt: String = D.BOXES[b]["th"]
			if naval[b] >= 5:
				continue
			if (bt == "eu" and germany_surr) or (bt == "pa" and japan_surr):
				continue
			if _th_match(b, bt, th):
				out.append({"k": "naval", "b": b})
	return out


func _th_match(box: String, bt: String, th: String) -> bool:
	match th:
		"any": return true
		"eu", "pa": return bt == th
		"pacific": return bt == "pa"
	return box == th


func theater_surrendered(fi: int) -> bool:
	return germany_surr if D.FRONTS[fi]["th"] == "eu" else japan_surr


func _allocate(p: int) -> void:
	var pl: Dictionary = players[p]
	var left_prod: int = pl["prod"]
	if left_prod <= 0 and pl["bonus"].is_empty():
		return
	# 1) produzione imposta dalla carta Conferenza
	for m in mand:
		if m["who"] != p:
			continue
		for j in range(int(m["n"])):
			if left_prod <= 0:
				break
			left_prod -= 1
			var opts := support_targets(m["k"], m["th"])
			if opts.is_empty():
				log_msg("%s: la produzione imposta dalla carta va persa (teatro non disponibile)." % D.POWERS[p]["leader"])
				continue
			var r = await decide(p, {"type": "alloc", "mode": "mand", "options": opts, "left": left_prod + 1, "why": m["x"]})
			if abort:
				return
			_apply_support(p, _pick_opt(r, opts), "produzione imposta")
	# 2) offensive dirette della propria bandiera (2 marcatori ciascuna)
	var dos := []
	for fi in range(fronts.size()):
		for dd in fronts[fi]["do"]:
			if dd["flag"] == p:
				dos.append(fi)
	if not dos.is_empty():
		if left_prod < dos.size() * 2 and dos.size() > 1:
			var r2 = await decide(p, {"type": "do_order", "options": dos, "left": left_prod})
			if abort:
				return
			var first: int = int(r2) if (r2 is int or r2 is float) and int(r2) in dos else dos[0]
			dos.erase(first)
			dos.push_front(first)
		for fi in dos:
			if theater_surrendered(fi) or entry(fi) == "":
				continue
			for j in range(2):
				if left_prod <= 0:
					break
				left_prod -= 1
				_do_support(p, fi)
	# 3) produzione libera e marcatori di supporto dei bonus
	var guard := 0
	while left_prod > 0 and guard < 40:
		guard += 1
		var opts2 := _free_targets(p)
		if opts2.is_empty():
			log_msg("%s non può usare %d Produzione: va persa." % [D.POWERS[p]["leader"], left_prod])
			break
		var r3 = await decide(p, {"type": "alloc", "mode": "free", "options": opts2, "left": left_prod})
		if abort:
			return
		left_prod -= 1
		var o := _pick_opt(r3, opts2)
		if o["k"] == "pm":
			var ii: int = o["i"]
			pl["pm_act"].append(ii)
			pl["pa_gain"] += int(D.ISSUES[ii]["pa"])
			pl["cn_gain"] += int(D.ISSUES[ii]["cn"])
			log_msg("%s attiva %s: +%d Allineamento, +%d Reti." % [D.POWERS[p]["leader"], D.ISSUES[ii]["n"], D.ISSUES[ii]["pa"], D.ISSUES[ii]["cn"]])
		elif o["k"] == "ab":
			ab_mod += 1
			log_msg("%s investe 1 Produzione nella Ricerca Bomba A (+%d)." % [D.POWERS[p]["leader"], ab_mod])
		else:
			_apply_support(p, o, "produzione")
		changed.emit()
	for b in pl["bonus"]:
		for j in range(int(b["n"])):
			var opts3 := support_targets(b["k"], b["th"])
			if opts3.is_empty():
				break
			var r4 = await decide(p, {"type": "alloc", "mode": "bonus", "options": opts3, "left": int(b["n"]) - j, "why": b["x"]})
			if abort:
				return
			_apply_support(p, _pick_opt(r4, opts3), b["x"])
	pl["bonus"] = []
	changed.emit()


func _free_targets(p: int) -> Array:
	var out := support_targets("any", "any")
	for i in won_by:
		if won_by[i] == p and D.ISSUES[i]["k"] == "polmil" and not i in players[p]["pm_act"]:
			out.append({"k": "pm", "i": i})
	var ab := D.issue_index("abomb")
	if won_by.has(ab) and abomb < 4 and ab_mod < 3:
		out.append({"k": "ab"})
	return out


func _pick_opt(r, opts: Array) -> Dictionary:
	if r is Dictionary:
		for o in opts:
			if _same_opt(o, r):
				return o
	if r is int or r is float:
		var k := int(r)
		if k >= 0 and k < opts.size():
			return opts[k]
	return opts[0]


static func _same_opt(a: Dictionary, b: Dictionary) -> bool:
	if a.get("k", "") != b.get("k", ""):
		return false
	return int(a.get("f", -1)) == int(b.get("f", -1)) and str(a.get("b", "")) == str(b.get("b", "")) and int(a.get("i", -1)) == int(b.get("i", -1))


func _apply_support(p: int, o: Dictionary, why: String) -> void:
	if o["k"] == "off":
		fronts[o["f"]]["off"] += 1
		log_msg("%s: supporto offensivo al %s (%s)." % [D.POWERS[p]["short"], D.FRONTS[o["f"]]["n"], why])
	elif o["k"] == "naval":
		naval[o["b"]] = mini(5, naval[o["b"]] + 1)
		log_msg("%s: supporto navale nel %s (%s)." % [D.POWERS[p]["short"], D.BOXES[o["b"]]["n"], why])
	fx.emit("support", {"o": o})


## Un marcatore per un'Offensiva Diretta: navale finché lo spazio anfibio non ha i supporti necessari.
func _do_support(p: int, fi: int) -> void:
	var en := entry(fi)
	var box: String = D.FRONTS[fi]["box"]
	var req := int(D.SPACES[en].get("amph", 0))
	if req > 0 and naval[box] < req:
		naval[box] += 1
		log_msg("%s: Offensiva Diretta, supporto navale nel %s." % [D.POWERS[p]["short"], D.BOXES[box]["n"]])
	else:
		fronts[fi]["off"] += 1
		log_msg("%s: Offensiva Diretta, supporto offensivo al %s." % [D.POWERS[p]["short"], D.FRONTS[fi]["n"]])


# ------------------------------------------------------------------ fronti

func entry(fi: int) -> String:
	var tr: Array = D.FRONTS[fi]["track"]
	var k: int = fronts[fi]["pos"] + 1
	return tr[k] if k < tr.size() else ""


func space_of(fi: int) -> String:
	var k: int = fronts[fi]["pos"]
	return D.FRONTS[fi]["track"][k] if k >= 0 else ""


## Il fronte può tentare di avanzare in questa conferenza? (7.73)
func can_attempt(fi: int) -> bool:
	var en := entry(fi)
	if en == "" or theater_surrendered(fi) or fronts[fi]["noadv"]:
		return false
	if en == "normandy" and not dday_ok:
		return false
	if en == "manchuria" and not manch_ok:
		return false
	return true


func attempt_reason(fi: int) -> String:
	var en := entry(fi)
	if en == "":
		return "fine del tracciato"
	if theater_surrendered(fi):
		return "resa dell'Asse"
	if fronts[fi]["noadv"]:
		return "bloccato dalla carta Conferenza"
	if en == "normandy" and not dday_ok:
		return "serve il Secondo Fronte al centro"
	if en == "manchuria" and not manch_ok:
		return "l'URSS non ha dichiarato guerra al Giappone"
	var req := int(D.SPACES[en].get("amph", 0))
	if req > 0 and naval[D.FRONTS[fi]["box"]] < req:
		return "servono %d supporti navali" % req
	return ""


func strength(fi: int) -> int:
	return 2 + 2 * int(fronts[fi]["off"]) - 2 * int(fronts[fi]["res"])


func _mark_behind(fi: int, sp: String, remove_cn: bool) -> void:
	var soviet: bool = D.FRONTS[fi]["who"] == USSR
	for c in D.COUNTRIES:
		if D.COUNTRIES[c]["sp"] != sp:
			continue
		var cc: Dictionary = countries[c]
		if cc["behind"]:
			continue
		cc["behind"] = true
		if not remove_cn or cc["cn"] <= 0:
			continue
		var victim: int = cc["cn_p"]
		if (soviet and victim != USSR) or (not soviet and victim == USSR):
			cc["cn"] -= 1
			if cc["cn"] <= 0:
				cc["cn"] = 0
				cc["cn_p"] = -1
			war_report.append("%s dietro il fronte: tolta una Rete di %s." % [D.COUNTRIES[c]["n"], D.POWERS[victim]["short"]])
			log_msg("%s è ora dietro il %s: tolta una Rete Clandestina di %s." % [D.COUNTRIES[c]["n"], D.FRONTS[fi]["n"], D.POWERS[victim]["short"]])


func _enter(fi: int) -> void:
	var old := space_of(fi)
	if old != "":
		_mark_behind(fi, old, true)
	fronts[fi]["pos"] += 1
	var sp := space_of(fi)
	var sd: Dictionary = D.SPACES[sp]
	var box: String = D.FRONTS[fi]["box"]
	if sd.get("kami", false):
		naval[box] = maxi(0, naval[box] - 1)
		log_msg("Kamikaze a %s: perso un supporto navale nel %s." % [sd["n"], D.BOXES[box]["n"]])
	if sd.get("b29", false):
		b29_entered = true
	match sp:
		"uk":
			if not navy_out:
				navy_out = true
				log_msg("Vinta la battaglia dell'Atlantico: la marina tedesca esce dal gioco.")
		"normandy":
			normandy_conf = conf_no
			removed_issues[D.issue_index("second")] = true
			log_msg("[b]D-Day: gli Alleati sbarcano in Normandia![/b]")
		"wgermany", "egermany":
			ger_perm += 1
			log_msg("Crollo militare tedesco: un'armata tedesca esce dal gioco.")
		"sitaly":
			if not italy_surr:
				italy_surr = true
				ita_out = true
				log_msg("[b]L'Italia si arrende.[/b]")
		"citaly":
			citaly_conf = conf_no
		"manchuria":
			jap_perm += 1
			removed_issues[D.issue_index("warjapan")] = true
			log_msg("Distrutta l'Armata del Kwantung: un'armata giapponese esce dal gioco.")
		"philippines":
			phil_entered = true
		"germany":
			germany_by.append(fi)
		"japan":
			japan_occupied = true
	fx.emit("front", {"f": fi})


# ------------------------------------------------------------------ fase di guerra

func _war() -> void:
	_set_phase("war")
	log_msg("[b]Fase di guerra[/b]")
	for p in range(3):
		players[p]["cn_gain"] += 1
	await _place_markers("cn")
	if abort:
		return
	await _place_markers("pa")
	if abort:
		return
	step = "military"
	changed.emit()
	if not germany_surr:
		await war_step("[b]Teatro europeo[/b]: le riserve tedesche e italiane si schierano contro i fronti alleati, poi ogni fronte tenta di avanzare con 1d10.")
		await _reserves_europe()
		for fi in [0, 1, 2]:
			await _advance_front(fi)
			if abort:
				return
		if not germany_by.is_empty():
			germany_surr = true
			var w: bool = 0 in germany_by
			var e: bool = 2 in germany_by
			if w and e:
				for p in range(3):
					players[p]["tech"] += 1
				tech_log = "both"
			elif w:
				players[UK]["tech"] += 1
				players[US]["tech"] += 1
				tech_log = "west"
			else:
				players[USSR]["tech"] += 2
				tech_log = "east"
			log_msg("[b][color=#e8c25a]La Germania si arrende![/color][/b]")
			war_report.append("LA GERMANIA SI ARRENDE")
			fx.emit("surrender", {"who": "germany"})
	if not japan_surr:
		await war_step("[b]Teatro del Pacifico[/b]: le riserve giapponesi si schierano, poi ogni fronte tenta di avanzare con 1d10.")
		await _reserves_pacific()
		for fi in [3, 4, 5, 6]:
			await _advance_front(fi)
			if abort:
				return
		if japan_occupied:
			japan_surr = true
		elif germany_surr and abomb >= 4 and b29_entered and fronts[3]["pos"] >= 1:
			japan_surr = true
			log_msg("Le condizioni dell'Imperatore sono soddisfatte.")
		if japan_surr:
			log_msg("[b][color=#e8c25a]Il Giappone si arrende![/color][/b]")
			war_report.append("IL GIAPPONE SI ARRENDE")
			fx.emit("surrender", {"who": "japan"})
	changed.emit()
	await pause_point({"type": "ack", "ctx": "war"})


## Ordine di piazzamento: chi ha più marcatori va per primo; le parità le decidono gli USA.
func _marker_order(key: String) -> Array:
	var order := [UK, USSR, US]
	order.sort_custom(func(a, b): return players[a][key] > players[b][key])
	# parità: gli USA scelgono (l'IA americana si mette per ultima, il vantaggio di chi piazza dopo)
	var out := []
	var i := 0
	while i < order.size():
		var grp := [order[i]]
		var j := i + 1
		while j < order.size() and players[order[j]][key] == players[order[i]][key]:
			grp.append(order[j])
			j += 1
		if grp.size() > 1 and US in grp:
			grp.erase(US)
			grp.append(US)
		out.append_array(grp)
		i = j
	return out


func _place_markers(kind: String) -> void:
	var key := "cn_gain" if kind == "cn" else "pa_gain"
	step = kind
	changed.emit()
	for p in _marker_order(key):
		var guard := 0
		while players[p][key] > 0 and guard < 30:
			guard += 1
			var opts := cn_options(p) if kind == "cn" else pa_options(p)
			if opts.is_empty():
				var nn: int = players[p][key]
				var what := ("Rete Clandestina" if nn == 1 else "Reti Clandestine") if kind == "cn" else ("marcatore di Allineamento Politico" if nn == 1 else "marcatori di Allineamento Politico")
				log_msg("%s non può piazzare %d %s: %s." % [D.POWERS[p]["leader"], nn, what, "va perso" if nn == 1 and kind == "pa" else ("va persa" if nn == 1 else "vanno persi")])
				players[p][key] = 0
				break
			var r = await decide(p, {"type": kind, "options": opts, "left": players[p][key]})
			if abort:
				return
			var o := _pick_cnpa(r, opts)
			if kind == "cn":
				_apply_cn(p, o)
			else:
				_apply_pa(p, o)
			changed.emit()


func _pick_cnpa(r, opts: Array) -> Dictionary:
	if r is Dictionary:
		for o in opts:
			if o["c"] == r.get("c", "") and bool(o.get("rm", false)) == bool(r.get("rm", false)):
				return o
	if r is int or r is float:
		var k := int(r)
		if k >= 0 and k < opts.size():
			return opts[k]
	return opts[0]


func arctic_ok(c: String) -> bool:
	return D.COUNTRIES[c]["sp"] != "arctic" or naval["arctic"] >= 3


## Mosse possibili per una Rete Clandestina: {"c": paese, "rm": false} piazza, {"rm": true} toglie una rete avversaria.
func cn_options(p: int) -> Array:
	var out := []
	for c in D.COUNTRY_ORDER:
		if not arctic_ok(c):
			continue
		var cc: Dictionary = countries[c]
		if cc["cn_p"] == -1 or (cc["cn_p"] == p and cc["cn"] < 2):
			out.append({"c": c, "rm": false})
		elif cc["cn_p"] != p:
			out.append({"c": c, "rm": true})
	return out


func _apply_cn(p: int, o: Dictionary) -> void:
	var cc: Dictionary = countries[o["c"]]
	players[p]["cn_gain"] -= 1
	if o["rm"]:
		var v: int = cc["cn_p"]
		cc["cn"] -= 1
		if cc["cn"] <= 0:
			cc["cn"] = 0
			cc["cn_p"] = -1
		log_msg("%s toglie una Rete Clandestina di %s in %s." % [D.POWERS[p]["leader"], D.POWERS[v]["short"], D.COUNTRIES[o["c"]]["n"]])
	else:
		cc["cn_p"] = p
		cc["cn"] += 1
		log_msg("%s piazza una Rete Clandestina in %s." % [D.POWERS[p]["leader"], D.COUNTRIES[o["c"]]["n"]])
	fx.emit("cn", {"c": o["c"]})


## Il tema Globale permette a p di mettere o togliere un Allineamento in c?
func global_allows(p: int, c: String) -> bool:
	var col: bool = D.COUNTRIES[c].get("col", false)
	if col:
		if glob[0] == -1:
			return false
		if glob[0] == UK and p != UK:
			return false
	else:
		if glob[1] == -1 and c in D.WEST_EAST:
			return false
		if glob[1] == USSR:
			if c in D.SPHERE_USSR and p != USSR:
				return false
			if c in D.SPHERE_WEST and p == USSR:
				return false
	return true


## Costo (in marcatori) per togliere l'Allineamento di un avversario.
func pa_remove_cost(p: int, c: String) -> int:
	var v: int = countries[c]["pa"]
	if glob[2] == US:
		return 2
	if glob[2] == USSR and v == USSR and (c in D.SPHERE_USSR or D.COUNTRIES[c].get("col", false)):
		return 2
	return 1


func pa_options(p: int) -> Array:
	var out := []
	var have: int = players[p]["pa_gain"]
	for c in D.COUNTRY_ORDER:
		var cc: Dictionary = countries[c]
		if cc["cn_p"] != p or cc["cn"] <= 0 or not arctic_ok(c):
			continue
		if not global_allows(p, c):
			continue
		if cc["pa"] == -1:
			out.append({"c": c, "rm": false})
		elif cc["pa"] != p:
			var cost := pa_remove_cost(p, c)
			if cost <= have:
				out.append({"c": c, "rm": true, "cost": cost})
	return out


func _apply_pa(p: int, o: Dictionary) -> void:
	var cc: Dictionary = countries[o["c"]]
	if o["rm"]:
		var v: int = cc["pa"]
		cc["pa"] = -1
		players[p]["pa_gain"] -= int(o.get("cost", 1))
		log_msg("%s toglie l'Allineamento Politico di %s in %s (costo %d)." % [D.POWERS[p]["leader"], D.POWERS[v]["short"], D.COUNTRIES[o["c"]]["n"], int(o.get("cost", 1))])
	else:
		cc["pa"] = p
		players[p]["pa_gain"] -= 1
		log_msg("%s piazza un Allineamento Politico in %s." % [D.POWERS[p]["leader"], D.COUNTRIES[o["c"]]["n"]])
	fx.emit("pa", {"c": o["c"]})


func _res(fi: int, n: int) -> void:
	fronts[fi]["res"] += n


func _reserves_europe() -> void:
	var ger: int = maxi(0, 6 - ger_perm - card_res["ger"] - card_res["ruhr"])
	var ita := 0 if ita_out else 1
	var navy := 0 if navy_out else 1
	var W := 0
	var M := 1
	var E := 2
	var wg: bool = can_attempt(W) and entry(W) == "germany"
	var eg: bool = can_attempt(E) and entry(E) == "germany"
	# 1. difesa della Germania
	if (wg or eg) and ger > 0:
		var n := mini(2, ger)
		ger -= n
		if wg and eg:
			var a := n / 2
			var b := n - a
			if n % 2 == 1 and rng.randi_range(0, 1) == 0:
				var t := a
				a = b
				b = t
			_res(W, a)
			_res(E, b)
		else:
			_res(W if wg else E, n)
		await war_step("Difesa della Germania: %d armat%s tedesc%s a protezione di Berlino contro %s." % [n, "a" if n == 1 else "e", "a" if n == 1 else "he", "i Fronti Occidentale e Orientale" if wg and eg else ("il Fronte Occidentale" if wg else "il Fronte Orientale")], "germany")
	# 2. un'armata contro il Fronte Orientale
	if ger > 0 and entry(E) != "":
		ger -= 1
		_res(E, 1)
		await war_step("Un'armata tedesca resta sempre contro il Fronte Orientale (in %s)." % D.SPACES[entry(E)]["n"], entry(E))
	# 3. battaglia dell'Atlantico
	if fronts[W]["pos"] < 0 and navy > 0:
		navy = 0
		if naval["west"] > 0:
			naval["west"] -= 1
			war_report.append("U-Boot: perso un supporto navale nel Teatro Occidentale.")
			await war_step("Battaglia dell'Atlantico: il Fronte Occidentale non ha ancora lasciato il suo riquadro, gli U-Boot affondano un supporto navale nel Teatro Occidentale.", "box:west")
	# 4. orda orientale
	if fronts[W]["pos"] < 1 and ger > 0 and entry(E) != "":
		var n4 := mini(4, ger)
		ger -= n4
		_res(E, n4)
		await war_step("Orda orientale: il Fronte Occidentale non è ancora sbarcato, quindi %d armate tedesche vanno contro il Fronte Orientale." % n4, entry(E))
	# 5. Vallo Atlantico
	if fronts[W]["pos"] == 0 and ger > 0:
		ger -= 1
		_res(W, 1)
		await war_step("Vallo Atlantico: un'armata tedesca difende la Normandia dallo sbarco.", entry(W))
	# 6. dopo lo sbarco: due armate contro il fronte più vicino alla Germania
	if normandy_conf >= 0 and ger > 0 and entry(W) != "" and entry(E) != "":
		var dw: int = 5 - fronts[W]["pos"]
		var de: int = 5 - fronts[E]["pos"]
		var n6 := mini(2, ger)
		ger -= n6
		if dw < de:
			_res(W, n6)
		elif de < dw:
			_res(E, n6)
		else:
			_res(W, 1)
			if n6 > 1:
				_res(E, 1)
		await war_step("Dopo lo sbarco in Normandia: %d armate tedesche contro il fronte più vicino alla Germania%s." % [n6, " (sono alla stessa distanza: una per parte)" if dw == de else ""], entry(W) if dw <= de else entry(E))
	# 7. l'armata italiana
	if ita > 0 and entry(M) != "":
		_res(M, 1)
		await war_step("L'armata italiana difende contro il Fronte del Mediterraneo.", entry(M))
	# 8. le altre armate a caso
	for k in range(ger):
		var r := d6()
		var txt := "Armata tedesca di riserva (%d di %d): 1-2 Occidentale, 3-4 Orientale, 5 Mediterraneo, 6 Artico. " % [k + 1, ger]
		var at := ""
		if r <= 2:
			_res(W, 1)
			txt += "Va contro il Fronte Occidentale."
			at = entry(W)
		elif r <= 4:
			_res(E, 1)
			txt += "Va contro il Fronte Orientale."
			at = entry(E)
		elif r == 6 and naval["arctic"] >= 3:
			naval["arctic"] -= 1
			war_report.append("Riserva tedesca nell'Artico: perso un supporto navale.")
			txt += "Attacca i convogli dell'Artico: perso un supporto navale."
			at = "box:arctic"
		else:
			_res(M, 1)
			txt += "Va contro il Fronte del Mediterraneo%s." % (" (senza 3 supporti navali nell'Artico il 6 vale come 5)" if r == 6 else "")
			at = entry(M)
		await war_step(txt, at, 6, r)


func _reserves_pacific() -> void:
	var jap: int = maxi(0, 4 - jap_perm - card_res["jap"])
	var FE := 3
	var CBI := 4
	var CP := 5
	var SW := 6
	# 1. difesa del Giappone
	var att := []
	for fi in [FE, CBI, CP, SW]:
		if can_attempt(fi) and entry(fi) == "japan":
			att.append(fi)
	if not att.is_empty() and jap > 0:
		var per := jap / att.size()
		var extra := jap % att.size()
		var order := att.duplicate()
		_shuffle(order)
		var names := []
		for k in range(order.size()):
			_res(order[k], per + (1 if k < extra else 0))
			names.append(D.FRONTS[order[k]]["id"])
		await war_step("Difesa del Giappone: tutte le %d armate giapponesi restano in patria contro i fronti che tentano lo sbarco." % jap, "japan")
		jap = 0
	# 2. contro il Fronte dell'Estremo Oriente se è uscito dal suo riquadro
	if fronts[FE]["pos"] >= 0 and jap > 0 and entry(FE) != "":
		var n2 := mini(2, jap)
		jap -= n2
		_res(FE, n2)
		await war_step("Il Fronte dell'Estremo Oriente è entrato in guerra: %d armate giapponesi lo fronteggiano." % n2, entry(FE))
	# 3. basi B29
	for fi in [CP, SW, CBI]:
		if jap <= 0:
			break
		if can_attempt(fi) and D.SPACES[entry(fi)].get("b29", false):
			jap -= 1
			_res(fi, 1)
			await war_step("Basi dei B29: un'armata giapponese difende %s dal %s." % [D.SPACES[entry(fi)]["n"], _fname(fi)], entry(fi))
	# flotta giapponese uscita per la carta Conferenza
	if ijn_card != "" and ijn_left > 0:
		var fi2 := D.front_index(ijn_card)
		await war_step("La carta Conferenza fa uscire la flotta giapponese contro il %s." % _fname(fi2), "box:" + D.FRONTS[fi2]["box"])
		await _ijn(fi2)
		if ijn_card_res > 0 and jap > 0:
			jap -= 1
			_res(fi2, 1)
	elif ijn_left > 0:
		# 4. sortita della flotta giapponese
		var r := d6()
		await war_step("Sortita della flotta giapponese: con 1-2 attacca un fronte che sta per sbarcare, con 3-6 resta in porto. %s" % ("Esce in mare!" if r <= 2 else "Resta in porto."), "japan", 6, r, r > 2)
		if r <= 2:
			var tgt := -1
			for fi in [CP, SW, CBI]:
				var en := entry(fi)
				if can_attempt(fi) and en != "" and D.SPACES[en].has("amph") and naval[D.FRONTS[fi]["box"]] >= int(D.SPACES[en]["amph"]):
					tgt = fi
					break
			if tgt < 0:
				tgt = [CP, SW, CBI][rng.randi_range(0, 2)]
			await _ijn(tgt)
	# 6. le altre armate a caso
	for k in range(jap):
		var r2 := d6()
		var fr: int = CP if r2 <= 2 else (SW if r2 <= 4 else CBI)
		_res(fr, 1)
		await war_step("Armata giapponese di riserva (%d di %d): 1-2 Pacifico Centrale, 3-4 Pacifico Sud-Occidentale, 5-6 Cina-Birmania-India. Va contro il %s." % [k + 1, jap, _fname(fr)], entry(fr) if entry(fr) != "" else "box:" + D.FRONTS[fr]["box"], 6, r2)


func _ijn(fi: int) -> void:
	var box: String = D.FRONTS[fi]["box"]
	if naval[box] > 0:
		naval[box] -= 1
	var r := d6()
	var msg := "La flotta giapponese attacca nel %s: perso un supporto navale" % D.BOXES[box]["n"]
	if r <= 4:
		ijn_left -= 1
		msg += "; la flotta viene distrutta (dado %d)." % r
	else:
		msg += "; la flotta rientra in Giappone (dado %d)." % r
	war_report.append(msg)
	log_msg(msg)
	await war_step("Battaglia navale: la flotta giapponese affonda un supporto navale nel %s. Con 1-4 la flotta viene distrutta, con 5-6 rientra in Giappone. %s" % [D.BOXES[box]["n"], "Distrutta!" if r <= 4 else "Rientra in Giappone."], "box:" + box, 6, r, r <= 4)


func _advance_front(fi: int) -> void:
	var f: Dictionary = fronts[fi]
	var nm: String = D.FRONTS[fi]["n"]
	var why := attempt_reason(fi)
	if entry(fi) == "":
		f["off"] = 0
		f["last"] = ""
		return
	if why != "":
		f["last"] = "fermo: " + why
		war_report.append("%s: fermo (%s)." % [nm, why])
		log_msg("%s non avanza: %s." % [nm, why])
		f["off"] = 0
		await war_step("[b]%s[/b]: non può tentare di avanzare (%s)." % [nm, why], entry(fi))
		return
	var s := strength(fi)
	if s <= 0:
		f["last"] = "forza %d, nessun tiro" % s
		war_report.append("%s: forza %d (%d supporti, %d riserve), nessun tiro." % [nm, s, f["off"], f["res"]])
		log_msg("%s: forza %d, non può avanzare." % [nm, s])
		f["off"] = 0
		await war_step("[b]%s[/b]: forza %d (2 + 2×%d supporti − 2×%d riserve). Con forza 0 o meno non si tira: nessun progresso." % [nm, s, f["off"], f["res"]], entry(fi))
		return
	var r := rng.randi_range(1, 10)
	var ent0 := entry(fi)
	var off0: int = f["off"]
	var mr := r + maxi(0, s - 10)
	var ok: bool = s >= 10 or r <= s
	var txt := "%s: forza %d (%d supporti, %d riserve), dado %d" % [nm, s, f["off"], f["res"], r]
	if mr != r:
		txt += " → %d" % mr
	if ok:
		var from := space_of(fi)
		_enter(fi)
		var dest := space_of(fi)
		var two := false
		if s >= 10 and mr >= 10:
			var en2 := entry(fi)
			if en2 != "" and not D.SPACES[en2].has("amph") and not (en2 == "manchuria" and not manch_ok):
				_enter(fi)
				dest = space_of(fi)
				two = true
		txt += ": %s %s%s." % ["sfonda fino a" if two else "avanza in", D.SPACES[dest]["n"], ""]
		f["last"] = ("sfondamento: " if two else "avanza: ") + D.SPACES[dest]["n"]
	else:
		txt += ": nessun progresso."
		f["last"] = "dado %d, fermo" % r
	war_report.append(txt)
	log_msg(txt)
	var ex := "[b]%s[/b]: forza %d (2 + 2×%d supporti − 2×%d riserve). " % [nm, s, off0, f["res"]]
	if s >= 10:
		ex += "Con forza 10 o più avanza sempre; il dado più l'eccedenza (%d) a 10 o più dà lo sfondamento di due spazi. " % (s - 10)
	else:
		ex += "Serve un dado da 1 a %d per entrare in %s. " % [s, D.SPACES[ent0]["n"]]
	ex += "Dado %d: %s" % [r, txt.get_slice(": ", txt.get_slice_count(": ") - 1)]
	f["off"] = 0
	await war_step(ex, ent0, 10, r, ok)


# ------------------------------------------------------------------ punteggio

## Paesi dell'Agenda segreta di p (uno per segnalino, con i doppioni).
func agenda_of(p: int) -> Array:
	var out := []
	for t in players[p].get("sa", []):
		out.append(D.SA_TOKENS[int(t)])
	return out


## Punti dell'Agenda segreta di p con la mappa attuale (5 PV per segnalino con un proprio Allineamento).
func agenda_vp(p: int) -> int:
	var v := 0
	for c in agenda_of(p):
		if countries[c]["pa"] == p:
			v += D.SA_VP
	return v


## Punti vittoria correnti (come se la partita finisse ora), con il dettaglio per voce.
## reveal: aggiunge l'Agenda segreta (solo alla fine, quando i segnalini si scoprono).
func compute_vp(reveal := false) -> Array:
	var out := []
	for p in range(3):
		out.append({"tot": 0, "rows": []})
	var add := func(p: int, v: int, why: String):
		if v != 0:
			out[p]["tot"] += v
			out[p]["rows"].append([why, v])
	for p in range(3):
		add.call(p, players[p]["wins"] * (5 if p == USSR else 3), "Conferenze vinte (%d)" % players[p]["wins"])
		var g := 0
		for k in range(3):
			if glob[k] == p:
				g += 1
		add.call(p, g * 5, "Temi Globali dalla propria parte (%d)" % g)
		var npa := 0
		var ncn := 0
		for c in countries:
			var cc: Dictionary = countries[c]
			if cc["pa"] == p:
				npa += 1
			elif cc["pa"] == -1 and cc["cn_p"] == p and cc["cn"] > 0:
				ncn += 1
		add.call(p, npa * 3, "Allineamenti Politici (%d)" % npa)
		add.call(p, ncn, "Reti senza Allineamento (%d)" % ncn)
		add.call(p, players[p]["tech"], "Tecnologia tedesca")
	var free_col := 0
	for c in countries:
		if D.COUNTRIES[c].get("col", false) and countries[c]["pa"] == -1 and countries[c]["cn"] == 0:
			free_col += 1
	add.call(UK, free_col * 2, "Colonie senza reti né allineamenti (%d)" % free_col)
	# Europa
	var w := space_of(0)
	var wv: int = {"rhineland": 2, "wgermany": 5, "germany": 8}.get(w, 0)
	add.call(US, wv, "Fronte Occidentale")
	add.call(UK, wv, "Fronte Occidentale")
	var m := space_of(1)
	if m == "citaly":
		add.call(UK, 2, "Mediterraneo in Italia centrale")
	elif m == "nitaly":
		add.call(UK, 3, "Mediterraneo in Italia settentrionale")
		add.call(US, 2, "Mediterraneo in Italia settentrionale")
	var e := space_of(2)
	add.call(USSR, {"prussia": 2, "egermany": 5, "germany": 8}.get(e, 0), "Fronte Orientale")
	if normandy_conf >= 0 and (citaly_conf < 0 or normandy_conf < citaly_conf):
		add.call(US, 2, "Normandia prima dell'Italia centrale")
	if citaly_conf >= 0 and (normandy_conf < 0 or citaly_conf < normandy_conf):
		add.call(UK, 2, "Italia centrale prima della Normandia")
	if germany_surr and tech_log == "east":
		add.call(USSR, 5, "Germania occupata solo dall'URSS")
	# Pacifico
	var cp := space_of(5)
	if cp == "iwojima":
		add.call(US, 2, "Pacifico Centrale a Iwo Jima")
	elif cp == "okinawa":
		add.call(US, 5, "Pacifico Centrale a Okinawa")
	if space_of(6) == "kyushu":
		add.call(US, 5, "Pacifico Sud-Occidentale a Kyushu")
	if space_of(4) == "formosa":
		add.call(UK, 5, "Cina-Birmania-India a Formosa")
	var west_japan := false
	for fi in [4, 5, 6]:
		if space_of(fi) == "japan":
			west_japan = true
	if west_japan:
		add.call(US, 8, "Fronte alleato in Giappone")
		add.call(UK, 8, "Fronte alleato in Giappone")
	if space_of(3) in ["korea", "japan"]:
		add.call(USSR, 8, "Estremo Oriente in Corea o Giappone")
	var dcp := _dist_japan(5)
	var dsw := _dist_japan(6)
	if absi(dcp - dsw) > 1:
		add.call(UK, 5, "Rivalità fra le forze armate USA")
		add.call(USSR, 5, "Rivalità fra le forze armate USA")
	if not phil_entered:
		add.call(UK, 3, "MacArthur non è tornato nelle Filippine")
		add.call(USSR, 3, "MacArthur non è tornato nelle Filippine")
	if japan_surr and not japan_occupied:
		add.call(US, 5, "Il Giappone si arrende senza occupazione")
	# Bomba A
	if abomb >= 4:
		add.call(US, 3, "Bomba A a Trinity")
		add.call(UK, 3, "Bomba A a Trinity")
	else:
		add.call(USSR, 3, "Gli USA non hanno la Bomba A")
	add.call(USSR, spy * 3, "Rete di spie del Progetto Manhattan (%d)" % spy)
	if secret and reveal:
		for p in range(3):
			for c in agenda_of(p):
				if countries[c]["pa"] == p:
					add.call(p, D.SA_VP, "Agenda segreta: %s" % D.COUNTRIES[c]["n"])
	return out


func _dist_japan(fi: int) -> int:
	var tr: Array = D.FRONTS[fi]["track"]
	return tr.size() - 1 - fronts[fi]["pos"]


func _final_scoring() -> void:
	_set_phase("end")
	if secret:
		for p in range(3):
			var names := []
			for c in agenda_of(p):
				names.append(D.COUNTRIES[c]["n"] + (" (allineato)" if countries[c]["pa"] == p else " (no)"))
			log_msg("Agenda segreta di %s: %s (+%d PV)." % [D.POWERS[p]["leader"], ", ".join(names), agenda_vp(p)])
	var vp := compute_vp(true)
	var raw := [vp[0]["tot"], vp[1]["tot"], vp[2]["tot"]]
	var adj := raw.duplicate()
	var how := ""
	var winner := -1
	var by_score := [0, 1, 2]
	by_score.sort_custom(func(a, b): return raw[a] > raw[b])
	var hi: int = raw[by_score[0]]
	var lo: int = raw[by_score[2]]
	if germany_surr and japan_surr:
		if hi - lo <= 20:
			how = "Vittoria dell'alleanza: l'Asse si è arreso e i punteggi sono entro 20 PV, vince chi ne ha di più."
			winner = _final_tie(_top(adj), adj)
		else:
			var top := _top(raw)
			if top.size() > 1:
				how = "Alleanza spezzata: parità in testa, si usa lo spareggio finale."
				winner = _final_tie(top, raw)
			else:
				var others: int = raw[by_score[1]] + raw[by_score[2]]
				if hi > others:
					how = "Alleanza spezzata (scarto oltre 20 PV): il primo supera la somma degli altri due e vince."
					winner = by_score[0]
				else:
					how = "Alleanza spezzata (scarto oltre 20 PV): gli altri due insieme superano il primo, vince il secondo."
					if raw[by_score[1]] == raw[by_score[2]]:
						winner = _final_tie([by_score[1], by_score[2]], raw)
					else:
						winner = by_score[1]
	else:
		how = "L'Asse non si è arreso del tutto: il primo perde 5 PV, il secondo 3, l'ultimo ne guadagna 5."
		var top2 := _top(raw)
		var bottom := []
		for p in range(3):
			if raw[p] == lo:
				bottom.append(p)
		if top2.size() >= 2:
			for p in range(3):
				adj[p] = raw[p] - 5 if p in top2 else raw[p] + 5
		elif bottom.size() >= 2:
			for p in range(3):
				adj[p] = raw[p] + 5 if p in bottom else raw[p] - 5
		else:
			adj[by_score[0]] -= 5
			adj[by_score[1]] -= 3
			adj[by_score[2]] += 5
		winner = _final_tie(_top(adj), adj)
	results = {"vp": vp, "raw": raw, "adj": adj, "winner": winner, "how": how,
		"germany": germany_surr, "japan": japan_surr, "secret": secret}
	game_over = true
	log_msg("[b]Fine partita: vince %s.[/b] %s" % [D.POWERS[winner]["leader"], how])
	changed.emit()
	game_ended.emit(results)


func _top(sc: Array) -> Array:
	var mx: int = maxi(sc[0], maxi(sc[1], sc[2]))
	var out := []
	for p in range(3):
		if sc[p] == mx:
			out.append(p)
	return out


## Spareggio finale (4.44).
func _final_tie(tied: Array, _sc: Array) -> int:
	if tied.size() == 1:
		return tied[0]
	if US in tied and abomb >= 4:
		return US
	if USSR in tied and germany_by == [2]:
		return USSR
	return UK


## Impronta della partita (per verificare che due dispositivi siano allineati).
func fingerprint() -> String:
	var parts := []
	for p in players:
		parts.append("%d:%d:%s:%d" % [p["wins"], p["tech"], p["leader"].substr(0, 2), p["dead"].size()])
	var fr := []
	for f in fronts:
		fr.append(str(f["pos"]))
	var cs := []
	for c in D.COUNTRY_ORDER:
		cs.append("%d%d%d" % [countries[c]["cn_p"] + 1, countries[c]["cn"], countries[c]["pa"] + 1])
	var nv := []
	for b in D.BOXES:
		nv.append(str(naval[b]))
	return "%s|%s|%s|%s|%s|%d%d|%s" % ["/".join(parts), ",".join(fr), "".join(cs), "".join(nv), str(glob), abomb, spy, str(results.get("winner", -1))]
