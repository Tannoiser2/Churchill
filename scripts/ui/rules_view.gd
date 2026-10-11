extends Control
## Regole in breve. Si apre dal menu o durante la partita.

const D = preload("res://scripts/data/ch_data.gd")

var main
var embedded := false
var on_close: Callable


func _ready() -> void:
	size = Vector2(1920, 1080)
	var sh := ColorRect.new()
	sh.color = Color(0, 0, 0, 0.7) if embedded else Color("#0d0b09")
	sh.size = size
	sh.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sh)
	if not embedded:
		var bg := TextureRect.new()
		bg.texture = UI.tex("res://assets/military.jpg")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.size = size
		bg.modulate = Color(0.22, 0.22, 0.25)
		add_child(bg)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(Color("#14110cf8"), UI.GOLD, 2, 10))
	box.position = Vector2(80, 30)
	box.custom_minimum_size = Vector2(1760, 1020)
	box.size = Vector2(1760, 1020)
	add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	box.add_child(vb)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	var t := UI.title("REGOLE DI CHURCHILL IN BREVE", 36)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	var close := UI.button("CHIUDI" if embedded else "INDIETRO", 180, 52, 24)
	close.pressed.connect(func():
		if embedded:
			on_close.call()
		else:
			main.show_menu())
	hb.add_child(close)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)
	for txt in [_col1(), _col2(), _col3()]:
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(565, 930)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		cols.add_child(sc)
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.custom_minimum_size = Vector2(545, 0)
		r.add_theme_font_size_override("normal_font_size", 19)
		r.add_theme_font_size_override("bold_font_size", 19)
		r.add_theme_font_size_override("italics_font_size", 19)
		r.text = txt
		sc.add_child(r)


func _h(t: String) -> String:
	return "[font_size=23][color=#d9b45a]%s[/color][/font_size]\n" % t


func _col1() -> String:
	return _h("Scopo") + """Siete Churchill (Regno Unito), Roosevelt (Stati Uniti) e Stalin (URSS): alleati contro l'Asse, ma rivali per il mondo del dopoguerra. Si gioca una serie di conferenze (3, 5 o 10 a seconda dello scenario). La partita finisce dopo Potsdam o quando Germania e Giappone si sono arresi.

""" + _h("Come si vince") + """• [b]Asse arreso, scarto entro 20 PV[/b]: vince chi ha più punti.
• [b]Asse arreso, scarto oltre 20 PV[/b]: se il primo supera la somma degli altri due vince lui, altrimenti vince il secondo.
• [b]Asse non arreso[/b]: il primo −5, il secondo −3, l'ultimo +5, poi vince chi ha di più.
• Parità: USA con la Bomba A, poi URSS sola in Germania, altrimenti Churchill.
• [b]Variante Agenda segreta[/b]: 3 paesi nascosti a testa, +5 PV per ognuno dove c'è un proprio Allineamento (contano prima di stabilire il vincitore).

""" + _h("1. Agenda") + """Si scopre la carta Conferenza e se ne applicano le cinque fasce. Ognuno riceve 7 carte dello staff (rimescolando nelle conferenze dispari) e ne gioca una coperta: conta solo il valore (+1 al Regno Unito; i Capi di Stato Maggiore tirano 1d6). Chi ha il valore più alto mette un tema sul suo tracciato a tanti spazi dal centro quanta è la differenza con la carta più bassa; poi, da sinistra, ognuno mette due temi al centro.
Spareggi: a partire da Stalin e verso sinistra un Leader attivo può risolverli; altrimenti vincono gli USA (o decidono loro).

""" + _h("2. Riunione") + """A turno, da sinistra del vincitore dell'Agenda, si gioca una carta e si fa avanzare un tema verso la propria sedia di tanti spazi quanto il valore (con gli attributi della carta). Un tema sul lato di un altro torna prima verso il centro. Gli altri due (da sinistra) possono [b]dibattere[/b]: una sola carta, che riporta il tema verso il proprio lato (+1 ai sovietici, «Njet»). Chi ha dibattuto può passare al turno successivo.
Se un avanzamento porterebbe il tema sulla sedia (7° spazio) gli altri possono dibattere prima: si confrontano i valori e il tema si muove della differenza. Un tema sulla sedia è [b]catturato[/b].
Il [b]Leader[/b] (valore 7) si usa una volta per conferenza scartando una carta; si può contestare solo con un altro Leader. Attenzione alla salute di Churchill e Roosevelt e alla paranoia di Stalin.
Alla fine i temi sul proprio tracciato sono vinti; chi ne vince di più vince la conferenza (3 PV, 5 all'URSS)."""


func _col2() -> String:
	return _h("3. Decisioni") + """Dal giocatore a sinistra del vincitore:
1. [b]Offensive Dirette[/b]: chi le ha vinte le piazza sullo spazio d'ingresso di un fronte; la potenza della bandiera vi spenderà 2 Produzione.
2. [b]Temi condizionali[/b]: Secondo Fronte e Guerra al Giappone hanno effetto solo se finiscono [b]al centro[/b] (sbarco in Normandia, ingresso in Manciuria).
3. [b]Produzione[/b]: UK 4, USA 6, URSS 3, più i temi Produzione vinti (si prende 1 alla potenza della bandiera), Materiali Strategici, convogli di Murmansk, Artico sicuro (3 navali: +1 URSS), meno le perdite della carta.
4. [b]Assegnazione[/b]: prima quella imposta dalla carta, poi le Offensive Dirette, poi a scelta: 1 supporto offensivo (spazio d'ingresso di un fronte) o navale (riquadro del teatro, massimo 5), attivare un Pol-Mil vinto (X Allineamenti/Y Reti), +1 alla Bomba A. Si piazzano anche i supporti dei comandi: 1 per teatro a chi lo comanda, 2 a chi vince il tema Comando, 2 in più a chi li vince entrambi.
5. [b]Comando dei teatri[/b]: chi ha vinto il tema decide se comandano USA o Regno Unito.
6. [b]Bomba A[/b]: chi vince il tema tira 1d6 (+ Produzione investita): con 4+ la Bomba avanza. Se vince l'URSS avanzano anche le spie (3 PV a casella).
7. [b]Tema Globale[/b]: chi lo vince sposta dalla sua parte uno dei suoi due marcatori (5 PV ciascuno).

""" + _h("Temi Globali") + """• Churchill–Roosevelt: [i]neutrale[/i] nessun Allineamento nelle colonie; Autodeterminazione tutti; Colonialismo solo il Regno Unito.
• Churchill–Stalin: [i]neutrale[/i] nessun Allineamento nei paesi dei fronti occidentale e orientale; Europa libera tutti; Sfere d'influenza: Stati baltici, Polonia, Romania, Bulgaria, Finlandia solo URSS; Francia, Belgio, Olanda solo UK e USA.
• Roosevelt–Stalin: [i]neutrale[/i] togliere un Allineamento costa 1; Nazioni Unite 2; Quadri comunisti 2 per gli allineamenti sovietici nei paesi delle sfere e nelle colonie."""


func _col3() -> String:
	return _h("4. Guerra") + """• [b]Reti Clandestine[/b]: 1 a testa più quelle guadagnate; chi ne ha di più piazza per primo. Massimo 2 per paese, di una sola potenza; dove ci sono reti avversarie se ne toglie una.
• [b]Allineamenti Politici[/b]: solo dove si ha una rete, uno per paese; si può togliere quello di un altro (1 o 2 marcatori secondo il tema Globale).
• Norvegia e Finlandia solo con 3 supporti navali nell'Artico.
• [b]Riserve dell'Asse[/b]: si piazzano con le priorità della mappa (Germania, Orda orientale, Vallo Atlantico, U-Boot, flotta giapponese…).
• [b]Fronti[/b]: forza 2 + 2 per supporto − 2 per riserva; si avanza con 1d10 ≤ forza. Con forza 10+ e tiro modificato 10+ c'è lo sfondamento (due spazi se il secondo è di terra). Gli spazi anfibi richiedono 3 navali nel riquadro (5 per la Normandia). I supporti offensivi si tolgono dopo il tiro.
• Un fronte che supera uno spazio mette «dietro il fronte» i paesi collegati: un fronte anglo-americano toglie una rete sovietica, uno sovietico una rete anglo-americana.
• La Germania si arrende quando un fronte vi entra; il Giappone quando un fronte vi entra o con le tre condizioni dell'Imperatore (Germania arresa, Bomba A a Trinity con un fronte in una base B29, Estremo Oriente in Manciuria).

""" + _h("Punti vittoria") + """3 per Allineamento, 1 per rete senza allineamento, 5 per tema Globale, conferenze vinte; UK 2 per colonia libera; fronti: Occidentale (Renania 2, Germania Ovest 5, Germania 8 a USA e UK), Orientale (Prussia 2, Germania Est 5, Germania 8 all'URSS, +5 se è sola), Italia centrale UK 2, settentrionale UK 3 e USA 2, chi arriva prima fra Normandia e Italia centrale 2, Iwo Jima 2, Okinawa 5, Kyushu 5 (USA), Formosa 5 (UK), Giappone 8 (USA e UK), Corea o Giappone 8 (URSS), rivalità USA 5 e MacArthur 3 (UK e URSS), Bomba A 3 (USA e UK) oppure 3 all'URSS, spie 3 a casella, tecnologia tedesca 1.

""" + _h("Comandi") + """Tavolo: clic su una carta in basso, poi sul tema evidenziato. Il pulsante in alto passa dal tavolo alla mappa dei fronti; la vista cambia da sola con la fase. Sulla mappa si clicca sui riquadri evidenziati. Tasto destro: annulla la scelta della carta. Passa il mouse su carte, temi, paesi e fronti per i dettagli; sulle schede in alto per il dettaglio dei punti."""
