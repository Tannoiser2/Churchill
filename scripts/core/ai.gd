class_name CHAI
extends RefCounted
## IA di Churchill. Ispirata alla logica dei 'Bot del regolamento (11.3: sfruttare le combinazioni fra
## attributi delle carte e temi sul tavolo), ma basata su una stima in punti vittoria di ogni tema,
## di ogni fronte e di ogni marcatore. Usa solo informazioni che avrebbe un giocatore: la propria mano,
## il tavolo e la mappa (mai le carte degli altri).
## Livelli: 0 Facile (molto rumore, non prevede i dibattiti), 1 Normale, 2 Difficile.

const D = preload("res://scripts/data/ch_data.gd")
const UK := 0
const US := 1
const USSR := 2

var level := 1
var rng := RandomNumberGenerator.new()


func noise() -> float:
	var amp: float = [1.6, 0.45, 0.12][clampi(level, 0, 2)]
	return rng.randf_range(-amp, amp)


func decide(e: CHEngine, p: int, req: Dictionary):
	match req.get("type", ""):
		"agenda_card": return agenda_card(e, p)
		"agenda_pick": return agenda_pick(e, p, req)
		"tie_leader": return tie_leader(e, p, req)
		"us_tie": return us_tie(e, p, req)
		"advance": return advance(e, p, req)
		"advance_cos": return advance_cos(e, p, req)
		"hopkins": return 6
		"cond_stop": return cond_stop(e, p, req)
		"debate": return debate(e, p, req)
		"place_do": return place_do(e, p, req)
		"do_order": return best_front(e, p, req["options"])
		"alloc": return alloc(e, p, req)
		"lose_cn": return lose_cn(e, p, req)
		"lead_ctrl": return lead_ctrl(e, p, req)
		"global_move": return global_move(e, p, req)
		"cn": return cn_choice(e, p, req)
		"pa": return pa_choice(e, p, req)
	return null


# =================================================================== valori dei temi

## Utilità (in PV circa) per p se il tema ii finisce con l'esito w (−1 centro, altrimenti la potenza che lo vince).
func util(e: CHEngine, p: int, ii: int, w: int) -> float:
	var d: Dictionary = D.ISSUES[ii]
	var k: String = d["k"]
	match k:
		"prod":
			var f: int = d["f"]
			if w == p and f != p:
				return 1.3
			if w >= 0 and w != p and f == p and w != f:
				return -1.3
			if w >= 0 and w != p:
				return -0.2
			return 0.0
		"do":
			var f2: int = d["f"]
			if w == p:
				return 1.2 if f2 != p else 0.5
			if w >= 0 and f2 == p:
				return -0.8
			return 0.0
		"polmil":
			var v: float = float(d["pa"]) * 2.4 + float(d["cn"]) * 0.9 - 1.0
			if w == p:
				return v
			if w >= 0:
				return -0.45 * v
			return 0.0
		"global":
			if w == p:
				return global_gain(e, p) * 0.9
			if w >= 0:
				return -global_loss(e, p, w)
			return 0.0
		"abomb":
			if p == USSR:
				if w == USSR:
					return (3.0 if e.spy < 4 else 0.0) - 0.4
				return -0.5 if w >= 0 and e.abomb < 4 else 0.0
			if w < 0 or e.abomb >= 4:
				return 0.0
			return 0.9 - (0.9 if w == USSR else 0.0)
		"strat":
			if w < 0:
				return 1.0
			return 1.3 if w == p else -0.3
		"euro", "pac":
			var th := "eu" if k == "euro" else "pa"
			if w == p:
				return 1.6 if p == USSR else (1.3 if e.lead[th] == p else 2.2)
			if w >= 0 and e.lead[th] == p:
				return -1.0
			return 0.0
		"cond":
			if w >= 0:
				return 0.0
			return cond_center_value(e, p, d["id"])
	return 0.0


func cond_center_value(e: CHEngine, p: int, id: String) -> float:
	if id == "second":
		if e.fronts[0]["pos"] != 0:
			return 0.0
		match p:
			US: return 2.6
			USSR: return 2.2
			UK: return 1.2 if e.citaly_conf >= 0 else -1.6
	else:
		if e.fronts[3]["pos"] != 0:
			return 0.0
		match p:
			USSR: return 1.6 if (e.germany_surr or e.conf_no >= 9) else -0.6
			US: return 1.3
			UK: return 0.3
	return 0.0


func global_gain(e: CHEngine, p: int) -> float:
	var best := 0.0
	for g in range(3):
		if not p in D.GLOBALS[g]["pair"] or e.glob[g] == p:
			continue
		best = maxf(best, 10.0 if e.glob[g] >= 0 else 5.0)
	return best


func global_loss(e: CHEngine, p: int, w: int) -> float:
	# w vince il tema: sposta il marcatore che gli rende di più
	var best_g := -1
	var best := -1.0
	for g in range(3):
		if not w in D.GLOBALS[g]["pair"] or e.glob[g] == w:
			continue
		var v := 10.0 if e.glob[g] >= 0 else 5.0
		if v > best:
			best = v
			best_g = g
	if best_g < 0:
		return 0.0
	if e.glob[best_g] == p:
		return 5.0
	if p in D.GLOBALS[best_g]["pair"]:
		return 2.0
	return 1.2


# =================================================================== stima degli esiti

func cards_left_frac(e: CHEngine) -> float:
	var n := 0
	for pl in e.players:
		n += pl["hand"].size()
	return clampf(float(n) / 18.0, 0.0, 1.0)


## Probabilità degli esiti [centro, UK, USA, URSS] di un tema in una posizione.
func outcome_probs(pos: Dictionary, frac: float) -> Array:
	var o: int = pos["o"]
	var d: int = pos["d"]
	var fin := [0.0, 0.0, 0.0, 0.0]
	var base := [0.0, 0.0, 0.0, 0.0]
	if d >= 7 or pos.get("cap", false):
		fin[o + 1] = 1.0
		return fin
	if d <= 0:
		fin[0] = 1.0
		base = [0.52, 0.16, 0.16, 0.16]
	else:
		fin[o + 1] = 1.0
		var po := 0.48 + 0.075 * d
		base[o + 1] = po
		base[0] = (1.0 - po) * 0.6
		for q in range(3):
			if q != o:
				base[q + 1] = (1.0 - po) * 0.2
	var out := []
	for i in range(4):
		out.append(frac * base[i] + (1.0 - frac) * fin[i])
	return out


func pos_value(e: CHEngine, p: int, ii: int, pos: Dictionary, frac: float) -> float:
	var pr := outcome_probs(pos, frac)
	var v := 0.0
	for i in range(4):
		if pr[i] > 0.0:
			v += pr[i] * util(e, p, ii, i - 1)
	return v


## Valore della vittoria della conferenza per p in base ai temi attesi.
func conf_term(e: CHEngine, p: int, override := {}) -> float:
	var frac := cards_left_frac(e)
	var ex := [0.0, 0.0, 0.0]
	for ii in e.table:
		var pos: Dictionary = override.get(ii, e.table[ii])
		var pr := outcome_probs(pos, frac)
		for q in range(3):
			ex[q] += pr[q + 1]
	var cw := [3.0, 3.0, 5.0]
	var tot := 0.0
	for q in range(3):
		var mx := -99.0
		for r in range(3):
			if r != q:
				mx = maxf(mx, ex[r])
		var pw := 1.0 / (1.0 + exp(-2.2 * (ex[q] - mx)))
		tot += (cw[q] * pw) if q == p else (-0.4 * cw[q] * pw)
	return tot


## Valore di spostare il tema ii in new_pos, rispetto alla posizione attuale.
func delta(e: CHEngine, p: int, ii: int, new_pos: Dictionary) -> float:
	var frac := cards_left_frac(e)
	var cur: Dictionary = e.table[ii]
	var dv := pos_value(e, p, ii, new_pos, frac) - pos_value(e, p, ii, cur, frac)
	dv += conf_term(e, p, {ii: new_pos}) - conf_term(e, p)
	return dv


static func capped(pos: Dictionary, q: int) -> Dictionary:
	var out := pos.duplicate()
	if out["o"] >= 0 and out["d"] >= 7:
		out["d"] = 7
		out["cap"] = true
	if out["d"] <= 0:
		out["o"] = -1
		out["d"] = 0
	return out


## Valore atteso di una carta dello staff giocata da p sul tema ii (i Capi di S.M. valgono 3,5 in media).
func card_val(e: CHEngine, p: int, cid: int, ii: int, debate: bool) -> int:
	var sd: Dictionary = D.STAFF[p][cid]
	var base := -1
	if int(sd["v"]) == 0:
		base = 3 if rng.randf() < 0.5 else 4
	if e.hopkins_choice(p, cid, ii):
		base = 6
	return e.staff_value(p, cid, ii, debate, base)


## Quanto conviene tenere una carta per più avanti.
func card_cost(e: CHEngine, p: int, cid: int) -> float:
	var sd: Dictionary = D.STAFF[p][cid]
	var v := float(sd["v"]) if int(sd["v"]) > 0 else 3.5
	var c := 0.12 * v
	if sd.has("m"):
		for ii in e.open_issues():
			if e.card_mod(p, cid, ii) > 0:
				c += 0.15
				break
	if level == 0:
		c *= 0.4
	return c


func leader_cost(e: CHEngine, p: int) -> float:
	var frac := cards_left_frac(e)
	var c := 1.4 + 1.6 * frac
	if e.players[p]["leader"] in ["churchill", "roosevelt"]:
		c += 0.8     # rischio per la salute
	if e.players[p]["leader"] == "stalin":
		c += 0.4
	return c


# =================================================================== Agenda

func agenda_card(e: CHEngine, p: int) -> int:
	var hand: Array = e.players[p]["hand"]
	var best := 0
	var bs := -999.0
	for k in range(hand.size()):
		var cid: int = hand[k]
		var sd: Dictionary = D.STAFF[p][cid]
		var v := float(sd["v"]) if int(sd["v"]) > 0 else 3.5
		if p == UK:
			v += 1.0
		var pwin := clampf((v - 2.5) / 3.5, 0.05, 0.95)
		var s := pwin * 2.4 - 0.32 * float(sd["v"] if int(sd["v"]) > 0 else 3.5)
		if sd.has("m") or sd.has("a"):
			s -= 0.35
		s += noise() * 0.6
		if s > bs:
			bs = s
			best = k
	return best


## Affinità della mano con un tema: somma dei bonus delle carte su quel tema.
func hand_affinity(e: CHEngine, p: int, ii: int) -> float:
	var a := 0.0
	var tags := D.issue_tags(ii)
	for cid in e.players[p]["hand"]:
		for m in D.STAFF[p][cid].get("m", []):
			if int(m["v"]) <= 0:
				continue
			for grp in m["c"]:
				var hit := false
				for cnd in grp:
					if cnd.begins_with("i:") and cnd.substr(2) in tags:
						hit = true
				if hit:
					a += float(m["v"]) * 0.35
					break
	return a


func agenda_pick(e: CHEngine, p: int, req: Dictionary) -> int:
	var best: int = req["options"][0]
	var bs := -999.0
	for ii in req["options"]:
		var s := util(e, p, ii, p) + hand_affinity(e, p, ii)
		# un tema che può andare al centro a mio favore (condizionali)
		s = maxf(s, util(e, p, ii, -1))
		if not req.get("first", false):
			# al centro: meglio i temi che gli altri vincerebbero poco
			var oth := 0.0
			for q in range(3):
				if q != p:
					oth += maxf(0.0, util(e, q, ii, q))
			s -= 0.15 * oth
		s += noise()
		if s > bs:
			bs = s
			best = ii
	return best


func tie_leader(e: CHEngine, p: int, req: Dictionary) -> Dictionary:
	var tied: Array = req["tied"]
	if not p in tied:
		return {"use": false}
	if req.get("ctx", "") == "conference":
		return {"use": true}
	# Agenda: il Leader vale di più nella riunione
	if level == 0:
		return {"use": rng.randf() < 0.5}
	return {"use": e.players[p]["hand"].size() <= 2}


func us_tie(e: CHEngine, p: int, req: Dictionary) -> int:
	var vp := e.compute_vp()
	var tied: Array = req["tied"]
	var best: int = tied[0]
	for q in tied:
		if vp[q]["tot"] < vp[best]["tot"]:
			best = q
	return best


# =================================================================== Riunione

func _option_score(e: CHEngine, p: int, ii: int, val: int, by_leader: bool) -> float:
	var cur: Dictionary = e.table[ii]
	var np := capped(CHEngine.moved(cur, p, val), p)
	if D.ISSUES[ii]["k"] == "cond" and cur["d"] > 0 and cur["o"] != p and val > cur["d"]:
		var c := capped({"o": -1, "d": 0}, p)
		if delta(e, p, ii, c) > delta(e, p, ii, np):
			np = c
	var s := delta(e, p, ii, np)
	if level >= 1 and not by_leader:
		# rischio di dibattito dei giocatori seguenti
		var q := e.left(p)
		for k in range(2):
			var cards: int = e.players[q]["hand"].size()
			if cards > 0:
				var hurt := -(pos_value(e, q, ii, np, cards_left_frac(e)) - pos_value(e, q, ii, cur, cards_left_frac(e)))
				var pd := clampf(hurt / 3.0, 0.0, 0.75) * (1.0 if level == 2 else 0.6)
				if pd > 0.0:
					var dv := 3.5 + (1.0 if q == USSR else 0.0)
					var after: Dictionary
					if np.get("cap", false):
						var diff := float(val) - dv
						after = capped(CHEngine.moved(cur, p if diff > 0 else q, int(absf(diff))), p)
					else:
						after = capped(CHEngine.moved(np, q, int(dv)), q)
					s = (1.0 - pd) * s + pd * delta(e, p, ii, after)
					break
			q = e.left(q)
	return s


func advance(e: CHEngine, p: int, req: Dictionary) -> Dictionary:
	var hand: Array = e.players[p]["hand"]
	var opts: Array = req["issues"]
	var best := {"card": 0, "issue": opts[0] if not opts.is_empty() else -1}
	var bs := -999.0
	for k in range(hand.size()):
		var cid: int = hand[k]
		var cos: bool = int(D.STAFF[p][cid]["v"]) == 0
		var cs := card_cost(e, p, cid)
		var best_here := -999.0
		var best_ii := -1
		for ii in opts:
			var v := card_val(e, p, cid, ii, false)
			var s := _option_score(e, p, ii, v, false) - cs + noise()
			if s > best_here:
				best_here = s
				best_ii = ii
		if cos:
			best_here -= 0.2
		if best_here > bs:
			bs = best_here
			best = {"card": k, "issue": -1 if cos else best_ii}
	# il Leader (scartando la carta meno utile)
	if req.get("leader_ok", false) and level >= 1:
		var worst := _worst_card(e, p)
		for ii in opts:
			var s2 := _option_score(e, p, ii, 7, true) - leader_cost(e, p) + noise()
			if s2 > bs:
				bs = s2
				best = {"card": worst, "issue": ii, "leader": true}
	if req.get("can_pass", false) and bs < 0.25 and hand.size() >= 2:
		return {"pass": true}
	return best


func _worst_card(e: CHEngine, p: int) -> int:
	var hand: Array = e.players[p]["hand"]
	var w := 0
	var wc := 999.0
	for k in range(hand.size()):
		var c := card_cost(e, p, hand[k])
		if c < wc:
			wc = c
			w = k
	return w


func advance_cos(e: CHEngine, p: int, req: Dictionary) -> int:
	var opts: Array = req["issues"]
	var best: int = opts[0]
	var bs := -999.0
	for ii in opts:
		var v := e.staff_value(p, int(req["card"]), ii, false, int(req["roll"]))
		var s := _option_score(e, p, ii, v, false) + noise()
		if s > bs:
			bs = s
			best = ii
	return best


func cond_stop(e: CHEngine, p: int, req: Dictionary) -> bool:
	var ii: int = req["issue"]
	var fin: Dictionary = capped(req["pos"], p)
	return delta(e, p, ii, {"o": -1, "d": 0}) > delta(e, p, ii, fin)


func debate(e: CHEngine, p: int, req: Dictionary) -> Dictionary:
	var ii: int = req["issue"]
	var cur: Dictionary = e.table[ii]
	var adv: int = req["adv_seat"]
	var av: int = req["adv_val"]
	var hand: Array = e.players[p]["hand"]
	var capture: bool = req.get("capture", false)
	# valore della situazione se non dibatto
	var base_pos: Dictionary = capped(CHEngine.moved(cur, adv, av), adv) if capture else cur
	var best := {}
	var bs := 0.35 if level >= 1 else 0.8
	var cands := []
	if not req.get("leader_only", false):
		for k in range(hand.size()):
			cands.append({"card": k, "v": card_val(e, p, hand[k], ii, true), "cost": card_cost(e, p, hand[k]) - 0.25})
	if req.get("leader_ok", false) and hand.size() > 0:
		var lv := 7 if e.players[p]["leader"] != "truman" or e.abomb >= 4 else 5
		cands.append({"card": _worst_card(e, p), "v": lv, "leader": true, "cost": leader_cost(e, p)})
	for c in cands:
		var after: Dictionary
		if capture:
			var diff: int = av - int(c["v"])
			if diff > 0:
				after = capped(CHEngine.moved(cur, adv, diff), adv)
			elif diff < 0:
				after = capped(CHEngine.moved(cur, p, -diff), p)
			else:
				after = cur
		else:
			after = capped(CHEngine.moved(cur, p, int(c["v"])), p)
		var s := delta(e, p, ii, after) - delta(e, p, ii, base_pos) - float(c["cost"]) + noise()
		if s > bs:
			bs = s
			best = {"card": c["card"], "leader": c.get("leader", false)}
	return best


# =================================================================== mappa: fronti e supporti

## Valore per p di un passo avanti del fronte fi (PV attesi, approssimati).
func front_value(e: CHEngine, p: int, fi: int) -> float:
	var en := e.entry(fi)
	if en == "":
		return 0.0
	var id: String = D.FRONTS[fi]["id"]
	var base: float = {
		"west": [1.4, 2.4, 0.2], "med": [2.2, 0.7, 0.1], "east": [-0.3, -0.1, 2.8],
		"fe": [0.1, 0.8, 1.8], "cbi": [1.9, 0.5, 0.0], "cp": [0.7, 2.2, -0.2], "swp": [0.3, 2.0, -0.4],
	}[id][p]
	match en:
		"normandy":
			if p == UK and e.citaly_conf < 0:
				base -= 1.0
			if p == US and e.citaly_conf < 0:
				base += 1.5
			if p == USSR:
				base += 1.2
		"rhineland", "wgermany", "germany":
			if fi == 0:
				if p != USSR:
					base += 1.5
				else:
					base -= 0.8
		"citaly":
			if p == UK:
				base += 2.0 + (1.5 if e.normandy_conf < 0 else 0.0)
		"nitaly":
			if p == UK:
				base += 1.0
			if p == US:
				base += 1.5
		"prussia", "egermany":
			if p == USSR:
				base += 2.0
		"korea":
			if p == USSR:
				base += 4.0
		"philippines":
			if p != US:
				base -= 2.5
		"okinawa", "kyushu", "iwojima":
			if p == US:
				base += 1.5
		"formosa":
			if p == UK:
				base += 2.5
		"japan":
			if p != USSR or fi == 3:
				base += 2.0
	if id == "east" and en == "germany" and p == USSR:
		base += 3.0
	# pressione per la resa dell'Asse: chi è in testa la vuole (evita −5), chi è ultimo no
	if id in ["west", "east", "cbi", "cp", "swp", "fe"]:
		var rank := vp_rank(e, p)
		var late := clampf(float(e.conf_no - 4) / 6.0, 0.0, 1.0)
		var press: float = [2.2, 1.2, 0.2][rank] * (0.6 + late)
		if id in ["west", "east"] and e.germany_surr:
			press = 0.0
		if not id in ["west", "east"] and e.japan_surr:
			press = 0.0
		base += press * (0.6 if id in ["west", "east"] else 0.35)
	return base


var _rank_cache := {}

## Posizione di p in classifica (0 primo, 2 ultimo) secondo il punteggio attuale.
func vp_rank(e: CHEngine, p: int) -> int:
	var key := "%d:%d:%s" % [e.conf_no, e.phase.length(), e.step]
	if not _rank_cache.has(key):
		_rank_cache.clear()
		var vp := e.compute_vp()
		var r := [0, 0, 0]
		for q in range(3):
			for o in range(3):
				if vp[o]["tot"] > vp[q]["tot"]:
					r[q] += 1
		_rank_cache[key] = r
	return mini(2, int(_rank_cache[key][p]))


## Paesi dove p potrebbe mettere un Allineamento (dove ha già una rete e il tema Globale lo permette).
func pa_spots(e: CHEngine, p: int) -> int:
	var n := 0
	for c in D.COUNTRY_ORDER:
		var cc: Dictionary = e.countries[c]
		if cc["pa"] == -1 and e.arctic_ok(c) and e.global_allows(p, c) and (cc["cn_p"] == p or cc["cn_p"] == -1):
			n += 1
	return n


func expected_res(e: CHEngine, fi: int) -> float:
	var id: String = D.FRONTS[fi]["id"]
	var r := float(e.fronts[fi]["res"])
	match id:
		"east": r += 5.0 if e.fronts[0]["pos"] < 1 else 2.0
		"west": r += 1.0 if e.fronts[0]["pos"] >= 0 else 0.3
		"med": r += 1.0
		_: r += 0.8
	if e.entry(fi) in ["germany", "japan"]:
		r += 1.5
	return r


func p_success(s: float) -> float:
	return clampf(s, 0.0, 10.0) / 10.0


func off_value(e: CHEngine, p: int, fi: int, budget := 1) -> float:
	if not e.can_attempt(fi):
		return -0.1
	var en := e.entry(fi)
	var req := int(D.SPACES[en].get("amph", 0))
	if req > 0 and float(e.naval[D.FRONTS[fi]["box"]]) - naval_loss(e, D.FRONTS[fi]["box"]) < float(req):
		return -0.05
	var s := 2.0 + 2.0 * float(e.fronts[fi]["off"]) - 2.0 * expected_res(e, fi)
	var fv := front_value(e, p, fi)
	var dp := p_success(s + 2.0) - p_success(s)
	# concentrazione: quanto rende in media se ci metto tutto quello che mi resta
	var b := clampi(budget, 1, 8)
	var avg := (p_success(s + 2.0 * float(b)) - p_success(s)) / float(b)
	return maxf(dp, avg * 0.9) * fv


## Supporti navali che probabilmente si perderanno prima del tiro (U-Boot, flotta giapponese, kamikaze).
func naval_loss(e: CHEngine, b: String) -> float:
	if b == "west":
		return 1.0 if e.fronts[0]["pos"] < 0 and not e.navy_out else 0.0
	if b in ["cp", "swp", "cbi"]:
		return 0.4 if e.ijn_left > 0 else 0.0
	return 0.0


func naval_value(e: CHEngine, p: int, b: String) -> float:
	if b == "arctic":
		if e.naval["arctic"] >= 3:
			return 0.1
		var gain := 1.4 if p == USSR else 0.25
		return gain / float(3 - e.naval["arctic"])
	var best := 0.0
	for fi in range(e.fronts.size()):
		if D.FRONTS[fi]["box"] != b:
			continue
		var en := e.entry(fi)
		if en == "" or e.theater_surrendered(fi):
			continue
		var req := int(D.SPACES[en].get("amph", 0))
		var fv := front_value(e, p, fi)
		if req == 0:
			# il prossimo spazio anfibio più avanti
			for k in range(e.fronts[fi]["pos"] + 2, D.FRONTS[fi]["track"].size()):
				var r2 := int(D.SPACES[D.FRONTS[fi]["track"][k]].get("amph", 0))
				if r2 > 0:
					req = r2
					fv *= 0.35
					break
		if req == 0:
			continue
		var missing: int = req - int(e.naval[b]) + int(ceil(naval_loss(e, b)))
		if int(e.naval[b]) >= 5:
			missing = 0
		if en == "normandy" and not e.dday_ok:
			fv *= 0.6
		if missing > 0:
			best = maxf(best, 0.5 * fv / float(missing))
		else:
			best = maxf(best, 0.08 * fv)
	return best


func support_value(e: CHEngine, p: int, o: Dictionary, budget := 1) -> float:
	match o["k"]:
		"off": return off_value(e, p, o["f"], budget)
		"naval": return naval_value(e, p, o["b"])
		"pm":
			var ii: int = o["i"]
			var spots := pa_spots(e, p)
			var pa := float(mini(int(D.ISSUES[ii]["pa"]), spots + int(D.ISSUES[ii]["cn"])))
			return pa * 2.2 + float(D.ISSUES[ii]["cn"]) * 0.9
		"ab":
			if p == USSR:
				return -1.0
			var need := 4 - 3 - e.ab_mod
			return 0.7 if need > 0 else 0.05
	return 0.0


func alloc(e: CHEngine, p: int, req: Dictionary) -> int:
	var opts: Array = req["options"]
	var best := 0
	var bs := -999.0
	var budget := int(req.get("left", 1))
	for k in range(opts.size()):
		var s := support_value(e, p, opts[k], budget) + noise() * 0.3
		if s > bs:
			bs = s
			best = k
	return best


func best_front(e: CHEngine, p: int, fronts: Array) -> int:
	var best: int = fronts[0]
	var bs := -999.0
	for fi in fronts:
		var s := off_value(e, p, fi) + 0.3 * front_value(e, p, fi) + noise() * 0.3
		if s > bs:
			bs = s
			best = fi
	return best


func place_do(e: CHEngine, p: int, req: Dictionary) -> int:
	var ii: int = req["issue"]
	var flag: int = D.ISSUES[ii]["f"]
	var best: int = req["options"][0]
	var bs := -999.0
	for fi in req["options"]:
		var s := front_value(e, p, fi)
		if not e.can_attempt(fi):
			s -= 1.0
		if flag != p:
			# meglio spendere la produzione dell'avversario dove serve a me
			s += 0.2
		s += noise() * 0.4
		if s > bs:
			bs = s
			best = fi
	return best


func king_choice(e: CHEngine, p: int) -> String:
	return "cp" if off_value(e, p, 5) >= off_value(e, p, 6) else "swp"


func lead_ctrl(e: CHEngine, p: int, req: Dictionary) -> int:
	if p != USSR:
		return p
	var vp := e.compute_vp()
	return UK if vp[UK]["tot"] <= vp[US]["tot"] else US


func global_move(e: CHEngine, p: int, req: Dictionary) -> int:
	var best: int = req["options"][0]
	var bs := -999.0
	for g in req["options"]:
		var s := (10.0 if e.glob[g] >= 0 else 5.0) + noise()
		if s > bs:
			bs = s
			best = g
	return best


# =================================================================== reti e allineamenti

## Rischio che un fronte avversario passi oltre il paese (e tolga una mia rete).
func risk(e: CHEngine, p: int, c: String) -> float:
	var sp: String = D.COUNTRIES[c]["sp"]
	for fi in range(e.fronts.size()):
		var tr: Array = D.FRONTS[fi]["track"]
		var k := tr.find(sp)
		if k < 0:
			continue
		var soviet: bool = D.FRONTS[fi]["who"] == USSR
		var hostile: bool = (soviet and p != USSR) or (not soviet and p == USSR)
		if not hostile or e.countries[c]["behind"]:
			return 0.0
		var dist: int = k + 1 - int(e.fronts[fi]["pos"])
		return clampf(1.0 - 0.2 * float(dist), 0.1, 0.9)
	return 0.0


func cn_choice(e: CHEngine, p: int, req: Dictionary) -> int:
	var opts: Array = req["options"]
	var best := 0
	var bs := -999.0
	var pa_left: int = e.players[p]["pa_gain"]
	for k in range(opts.size()):
		var o: Dictionary = opts[k]
		var c: String = o["c"]
		var cc: Dictionary = e.countries[c]
		var s := 0.0
		if o["rm"]:
			s = 0.5 + (0.5 if cc["cn"] == 1 and cc["pa"] == -1 else 0.0)
			if cc["pa"] >= 0 and cc["pa"] != p and e.global_allows(p, c):
				s += 0.7
		elif cc["cn_p"] == p:
			s = 0.25 + 1.2 * risk(e, p, c)
		else:
			s = 1.2
			if cc["pa"] == -1 and e.global_allows(p, c):
				s += 1.0 + (1.0 if pa_left > 0 else 0.0)
			elif cc["pa"] >= 0 and cc["pa"] != p:
				s += 0.5
			elif cc["pa"] == p:
				s -= 0.6
			s -= 0.8 * risk(e, p, c)
			if D.COUNTRIES[c].get("col", false) and p != UK:
				s += 0.2   # toglie al Regno Unito i 2 PV della colonia libera
		s += noise() * 0.3
		if s > bs:
			bs = s
			best = k
	return best


func pa_choice(e: CHEngine, p: int, req: Dictionary) -> int:
	var opts: Array = req["options"]
	var best := 0
	var bs := -999.0
	for k in range(opts.size()):
		var o: Dictionary = opts[k]
		var s := 3.0 - risk(e, p, o["c"]) * 0.3
		if o["rm"]:
			s = 2.6 - 1.2 * float(int(o.get("cost", 1)) - 1)
		s += noise() * 0.3
		if s > bs:
			bs = s
			best = k
	return best


func lose_cn(e: CHEngine, p: int, req: Dictionary) -> String:
	var best: String = req["options"][0]
	var bs := 999.0
	for c in req["options"]:
		var cc: Dictionary = e.countries[c]
		var loss := 1.0
		if cc["pa"] == p:
			loss = 0.1
		elif cc["cn"] >= 2:
			loss = 0.3
		if loss < bs:
			bs = loss
			best = c
	return best
