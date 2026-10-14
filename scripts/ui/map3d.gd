class_name Map3D
extends SubViewportContainer
## Mappa dei fronti in 3D: tabellone sul tavolo, blocchetti dei fronti, segnalini e dadi.
## Telecamera: trascina col tasto sinistro per spostare, col destro (o centrale) per ruotare, rotellina per lo zoom.
## Un clic senza trascinare sceglie il bersaglio più vicino (paese, riquadro, ingresso di un fronte).

const D = preload("res://scripts/data/ch_data.gd")
const S := 0.01                     # unità 3D per pixel della mappa (1760 × 2100)
const BW := 17.6
const BD := 21.0
const CHIT_FRONT_DOWN := false   # la faccia ×N è quella in basso nel modello

signal picked(key: String)

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var pieces: Node3D
var dice_root: Node3D
var rings: Node3D
var tip_panel: PanelContainer
var tip_lbl: RichTextLabel

var yaw := 0.0
var pitch := 66.0
var dist := 30.0
var target := Vector3(0, 0, 0.6)
var _drag_btn := -1
var _drag_from := Vector2.ZERO
var _dragged := false

var anchors: Dictionary = {}        # chiave → posizione sulla mappa (pixel)
var targets: Dictionary = {}        # chiave → Callable
var tip_fn: Callable                # chiave → testo del suggerimento
var blocks: Dictionary = {}         # indice del fronte → nodo del blocchetto
var _mesh: Dictionary = {}
var _mat: Dictionary = {}


func setup(sz: Vector2) -> void:
	size = sz
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.size = Vector2i(sz)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#120e0a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#fff4e0")
	e.ambient_light_energy = 0.35
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 28, 0)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 200, 0)
	fill.light_energy = 0.3
	world.add_child(fill)
	# tavolo di legno
	var table := MeshInstance3D.new()
	var tm := PlaneMesh.new()
	tm.size = Vector2(80, 80)
	table.mesh = tm
	var wm := StandardMaterial3D.new()
	wm.albedo_texture = load("res://assets/pieces/wood.jpg")
	wm.uv1_scale = Vector3(8, 8, 1)
	wm.roughness = 0.85
	wm.metallic_specular = 0.1
	wm.albedo_color = Color(0.55, 0.42, 0.3)
	table.material_override = wm
	table.position.y = -0.06
	world.add_child(table)
	# tabellone (spesso, con la mappa sopra)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(BW, 0.06, BD)
	board.mesh = bm
	board.position.y = -0.03
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#2a2418")
	board.material_override = edge
	world.add_child(board)
	var top := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(BW, BD)
	top.mesh = pm
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = load("res://assets/pieces/board_mil.jpg")
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.93, 0.92, 0.9)
	mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	top.material_override = mm
	top.position.y = 0.001
	world.add_child(top)
	pieces = Node3D.new()
	world.add_child(pieces)
	rings = Node3D.new()
	world.add_child(rings)
	dice_root = Node3D.new()
	world.add_child(dice_root)
	cam = Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	_update_cam()
	# suggerimento al passaggio del mouse
	tip_panel = PanelContainer.new()
	tip_panel.add_theme_stylebox_override("panel", UI.panel_style(Color("#120f0af0"), UI.GOLD, 1, 6))
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.visible = false
	tip_lbl = UI.rich(17)
	tip_lbl.custom_minimum_size = Vector2(320, 0)
	tip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_child(tip_lbl)
	add_child(tip_panel)


# ------------------------------------------------------------------ coordinate e telecamera

func w(px: Vector2, h := 0.0) -> Vector3:
	return Vector3(px.x * S - BW / 2, h, px.y * S - BD / 2)


func px_of(p: Vector3) -> Vector2:
	return Vector2((p.x + BW / 2) / S, (p.z + BD / 2) / S)


func reset_view() -> void:
	yaw = 0.0
	pitch = 66.0
	dist = 30.0
	target = Vector3(0, 0, 0.6)
	_update_cam()


func _update_cam() -> void:
	pitch = clamp(pitch, 22.0, 89.0)
	dist = clamp(dist, 3.5, 34.0)
	target.x = clamp(target.x, -BW * 0.6, BW * 0.6)
	target.z = clamp(target.z, -BD * 0.6, BD * 0.6)
	var r := deg_to_rad(pitch)
	var y := deg_to_rad(yaw)
	cam.look_at_from_position(target + Vector3(sin(y) * cos(r), sin(r), cos(y) * cos(r)) * dist, target, Vector3.UP)


## Inquadra un punto della mappa (usato dai passi della fase militare).
func focus(px: Vector2, d := 12.0) -> void:
	var to := w(px)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float):
		target = target.lerp(to, t)
		dist = lerp(dist, d, t)
		_update_cam(), 0.0, 1.0, 0.6)


func _ground(mp: Vector2) -> Vector3:
	var lp := mp * Vector2(vp.size) / size
	var o := cam.project_ray_origin(lp)
	var d := cam.project_ray_normal(lp)
	if abs(d.y) < 1e-4:
		return Vector3.INF
	var t := -o.y / d.y
	if t < 0:
		return Vector3.INF
	return o + d * t


func _nearest(px: Vector2, pool: Dictionary, maxd := 46.0) -> String:
	var best := ""
	var bd := maxd
	for k in pool:
		var a: Vector2 = anchors.get(k, Vector2.INF)
		if a == Vector2.INF:
			continue
		var dd := a.distance_to(px)
		if dd < bd:
			bd = dd
			best = k
	return best


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# zoom verso il punto sotto il mouse
			var g := _ground(mb.position)
			var f := 0.88 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.88
			if g != Vector3.INF and f < 1.0:
				target = target.lerp(Vector3(g.x, 0, g.z), 0.18)
			dist *= f
			_update_cam()
			accept_event()
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag_btn = mb.button_index
			_drag_from = mb.position
			_dragged = false
			accept_event()
		elif not mb.pressed and mb.button_index == _drag_btn:
			if _drag_btn == MOUSE_BUTTON_LEFT and not _dragged:
				var g2 := _ground(mb.position)
				if g2 != Vector3.INF:
					var k := _nearest(px_of(g2), targets, 80.0)
					if k != "":
						targets[k].call()
						picked.emit(k)
			_drag_btn = -1
			accept_event()
	elif ev is InputEventMouseMotion:
		var mm: InputEventMouseMotion = ev
		if _drag_btn >= 0:
			if mm.position.distance_to(_drag_from) > 4:
				_dragged = true
			if _dragged:
				if _drag_btn == MOUSE_BUTTON_LEFT:
					var k2 := dist * 0.0016
					var y := deg_to_rad(yaw)
					var right := Vector3(cos(y), 0, -sin(y))
					var fwd := Vector3(sin(y), 0, cos(y))
					target -= (right * mm.relative.x + fwd * mm.relative.y) * k2
				else:
					yaw -= mm.relative.x * 0.3
					pitch += mm.relative.y * 0.25
				_update_cam()
			tip_panel.visible = false
		else:
			_hover(mm.position)


func _hover(mp: Vector2) -> void:
	var g := _ground(mp)
	if g == Vector3.INF or not tip_fn.is_valid():
		tip_panel.visible = false
		return
	var k := _nearest(px_of(g), anchors, 60.0)
	var txt := "" if k == "" else str(tip_fn.call(k))
	if txt == "":
		tip_panel.visible = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if targets.has(k) else Control.CURSOR_ARROW
	tip_lbl.text = txt
	tip_panel.visible = true
	tip_panel.reset_size()
	var p := mp + Vector2(18, 18)
	if p.x + tip_panel.size.x > size.x:
		p.x = mp.x - tip_panel.size.x - 12
	if p.y + tip_panel.size.y > size.y:
		p.y = mp.y - tip_panel.size.y - 12
	tip_panel.position = p


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and tip_panel != null:
		tip_panel.visible = false


# ------------------------------------------------------------------ pezzi

func mesh(name: String) -> Mesh:
	if not _mesh.has(name):
		_mesh[name] = load("res://assets/pieces/%s.obj" % name)
	return _mesh[name]


func col_mat(c: Color, rough := 0.55, alpha := 1.0) -> StandardMaterial3D:
	var k := "%s:%f:%f" % [c.to_html(), rough, alpha]
	if not _mat.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c, alpha)
		m.roughness = rough
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat[k] = m
	return _mat[k]


func tex_mat(path: String, rough := 0.6) -> StandardMaterial3D:
	if not _mat.has(path):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(path)
		m.roughness = rough
		_mat[path] = m
	return _mat[path]


func _mi(m: Mesh, mat: Material, pos: Vector3, sc: float, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3.ONE * sc
	(parent if parent != null else pieces).add_child(mi)
	return mi


## Blocchetto di legno di un fronte (in piedi, con l'adesivo verso il basso della mappa).
func front_block(fi: int, px: Vector2, label: String) -> void:
	var b: Node3D = blocks.get(fi)
	var to := w(px, 0.28)
	if b == null or not is_instance_valid(b):
		b = Node3D.new()
		world.add_child(b)
		var tex: String = {"west": "gJ5MHWn", "med": "mXunuFJ", "east": "ZCWT568", "fe": "TZcULTQ", "cbi": "mXunuFJ", "cp": "RQR8hlb", "swp": "RQR8hlb"}[D.FRONTS[fi]["id"]]
		var m := _mi(mesh("block"), tex_mat("res://assets/pieces/blk_%s.jpg" % tex, 0.7), Vector3.ZERO, 0.28, b)
		m.rotation_degrees = Vector3(-8, 0, 0)
		var l := Label3D.new()
		l.text = label
		l.font_size = 64
		l.pixel_size = 0.0035
		l.outline_size = 14
		l.modulate = Color.WHITE
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = Vector3(0, 0.48, 0)
		b.add_child(l)
		b.position = to
		blocks[fi] = b
	elif b.position.distance_to(to) > 0.01:
		var mid := (b.position + to) / 2 + Vector3(0, 0.9, 0)
		var tw := create_tween()
		tw.tween_property(b, "position", mid, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "position", to, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func clear_pieces() -> void:
	for c in pieces.get_children():
		c.queue_free()
	for c in rings.get_children():
		c.queue_free()


## Pila di gettoni dei supporti (offensivi o navali), i gettoni a due facce del gioco:
## sul retro c'è il valore multiplo (×3 navali, ×2 offensivi), usato per le pile grandi.
func chips(px: Vector2, n: int, img: String, sz := 0.5) -> void:
	var multi := 3 if img == "naval" else 2
	var big := n / multi
	var small := n % multi
	var mat := tex_mat("res://assets/pieces/chit_%s.jpg" % ("naval" if img == "naval" else "off"), 0.75)
	var k := 0
	for i in range(big + small):
		var flip := i < big
		var mi := _mi(mesh("chit"), mat, w(px + Vector2(k % 2 * 5, -k * 3), 0.026 + k * 0.034), sz / 0.67)
		mi.rotation_degrees = Vector3(180 if flip == CHIT_FRONT_DOWN else 0, (k * 7) % 11 - 5 + (0 if flip else 180), 0)
		k += 1


## Cubetti di legno (armate dell'Asse).
func cubes(px: Vector2, n: int, c: Color) -> void:
	for k in range(n):
		var p := px + Vector2((k % 3) * 17 - 17, (k / 3) * 17)
		var mi := _mi(BoxMesh.new(), col_mat(c, 0.7), w(p, 0.075), 1.0)
		(mi.mesh as BoxMesh).size = Vector3(0.15, 0.15, 0.15)
		mi.rotation_degrees.y = (k * 13) % 20 - 10


func cn_disc(px: Vector2, c: Color) -> void:
	_mi(mesh("cn"), col_mat(c.lightened(0.15), 0.15, 0.85), w(px, 0.035), 0.25)


func pa_pawn(px: Vector2, c: Color) -> void:
	_mi(mesh("pa"), col_mat(c, 0.6), w(px, 0.2), 0.33)


func pawn(px: Vector2, c: Color) -> void:
	_mi(mesh("pawn"), col_mat(c, 0.5), w(px, 0.2), 0.19)


func cmd_block(px: Vector2, c: Color, txt: String) -> void:
	var n := Node3D.new()
	n.position = w(px, 0.25)
	pieces.add_child(n)
	var m := _mi(mesh("block"), col_mat(c, 0.7), Vector3.ZERO, 0.25, n)
	m.rotation_degrees = Vector3(-8, 0, 0)
	var l := Label3D.new()
	l.text = txt
	l.font_size = 56
	l.pixel_size = 0.0035
	l.outline_size = 12
	l.position = Vector3(0, 0, 0.14)
	l.rotation_degrees = Vector3(-8, 0, 0)
	n.add_child(l)


func issue_chit(px: Vector2, tex: Texture2D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.04, 0.42)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	mi.material_override = m
	mi.position = w(px, 0.03)
	pieces.add_child(mi)


func ring(px: Vector2, r := 0.36) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r
	tm.outer_radius = r + 0.06
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.82, 0.3)
	m.emission_enabled = true
	m.emission = Color(1, 0.75, 0.2)
	m.emission_energy_multiplier = 1.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position = w(px, 0.05)
	rings.add_child(mi)
	var tw := mi.create_tween().set_loops()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.12, 0.5)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.5)


# ------------------------------------------------------------------ dadi

func _num_label(t: String, pos: Vector3, normal: Vector3, col: Color, fs := 72) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = fs
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 0
	l.double_sided = false
	l.position = pos + normal * 0.004
	var up := Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	l.basis = Basis.looking_at(-normal, up)
	return l


func _make_d6(col: Color) -> Array:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.5, 0.5)
	mi.mesh = bm
	mi.material_override = col_mat(col, 0.35)
	n.add_child(mi)
	var faces := {1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.FORWARD, 5: Vector3.BACK, 3: Vector3.RIGHT, 4: Vector3.LEFT}
	for v in faces:
		n.add_child(_num_label(str(v), faces[v] * 0.25, faces[v], Color.WHITE if col.get_luminance() < 0.5 else Color("#111111"), 78))
	return [n, faces]


func _make_d10(col: Color) -> Array:
	var h := 0.36
	var c := 0.1056 * h
	var r := 0.3
	var T := Vector3(0, h, 0)
	var B := Vector3(0, -h, 0)
	var U := []
	var L := []
	for k in range(5):
		var a := deg_to_rad(72.0 * k)
		var a2 := deg_to_rad(72.0 * k + 36.0)
		U.append(Vector3(cos(a) * r, c, sin(a) * r))
		L.append(Vector3(cos(a2) * r, -c, sin(a2) * r))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := {}
	var quads := []
	for k in range(5):
		quads.append([T, U[(k + 1) % 5], L[k], U[k]])
		quads.append([B, L[k], U[(k + 1) % 5], L[(k + 1) % 5]])
	var num := 1
	for q in quads:
		var nrm: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
		if nrm.dot((q[0] + q[1] + q[2] + q[3]) / 4.0) < 0:
			nrm = -nrm
			q = [q[0], q[3], q[2], q[1]]
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for v in tri:
				st.set_normal(nrm)
				st.add_vertex(v)
		faces[num] = nrm
		num += 1
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = col_mat(col, 0.3)
	n.add_child(mi)
	var nums := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var k2 := 0
	var faces2 := {}
	for i in faces:
		var q: Array = quads[i - 1]
		var ctr: Vector3 = (q[0] * 0.6 + q[2] * 1.4 + q[1] + q[3]) / 4.0
		var nrm2: Vector3 = faces[i]
		var lbl := _num_label("0" if nums[k2] == 10 else str(nums[k2]), ctr, nrm2, Color.WHITE, 48)
		n.add_child(lbl)
		faces2[nums[k2]] = nrm2
		k2 += 1
	return [n, faces2]


## Lancia un dado sul tavolo vicino al punto px e lo fa fermare sul valore dato.
func roll_die(sides: int, value: int, px: Vector2, col := Color("#7a1616")) -> void:
	for c in dice_root.get_children():
		c.queue_free()
	var made := _make_d10(col) if sides == 10 else _make_d6(col)
	var die: Node3D = made[0]
	var faces: Dictionary = made[1]
	dice_root.add_child(die)
	die.scale = Vector3.ONE * 1.6
	var land := w(px + Vector2(150, 110), 0.0)
	var start := land + Vector3(-3.0, 2.6, 2.2)
	var nrm: Vector3 = faces.get(value, Vector3.UP)
	var final := Quaternion(Vector3.UP, randf() * TAU) * Quaternion(nrm.normalized(), Vector3.UP)
	var axis := Vector3(randf() - 0.5, randf() * 0.4, randf() - 0.5).normalized()
	var spins := TAU * 3.0
	var rest_h := 0.25 * 1.6
	if sides == 10:
		rest_h = _rest_height(faces[value], die) * 1.6
	var dur := 1.1
	var tw := die.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(die):
			return
		# traiettoria: arco e due rimbalzi
		var p := start.lerp(land, min(1.0, t * 1.15))
		var bounce: float = abs(sin(t * PI * 2.6)) * (1.0 - t) * 1.4
		p.y = rest_h + bounce + max(0.0, 1.0 - t * 3.0) * 1.6
		die.position = p
		var spin := Quaternion(axis, spins * pow(1.0 - t, 2.0))
		die.quaternion = spin * final, 0.0, 1.0, dur)
	tw.tween_callback(func():
		if is_instance_valid(die):
			die.position = Vector3(land.x, rest_h, land.z)
			die.quaternion = final)
	await get_tree().create_timer(dur + 0.25).timeout


func _rest_height(nrm: Vector3, die: Node3D) -> float:
	# distanza della faccia dal centro: il dado poggia sulla faccia opposta a quella in alto
	var best := 0.0
	for c in die.get_children():
		if c is MeshInstance3D:
			var arr: Array = (c as MeshInstance3D).mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				best = max(best, v.dot(nrm.normalized()))
	return best


func clear_dice() -> void:
	for c in dice_root.get_children():
		c.queue_free()
