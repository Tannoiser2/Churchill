class_name CHData
extends RefCounted
## Dati di Churchill (GMT Games, Mark Herman, 2ª edizione con errata): potenze, carte dello staff,
## Leader, carte Conferenza, temi, fronti, paesi e coordinate sulle due metà della mappa.

const UK := 0
const US := 1
const USSR := 2

const POWERS := [
	{"id": 0, "key": "uk", "nation": "Regno Unito", "short": "UK", "leader": "Churchill", "col": Color("#5f9a3c"), "light": Color("#a4d67e"), "dark": Color("#2f5420")},
	{"id": 1, "key": "us", "nation": "Stati Uniti", "short": "USA", "leader": "Roosevelt", "col": Color("#3a73b5"), "light": Color("#8fbcf0"), "dark": Color("#1c3c63")},
	{"id": 2, "key": "ussr", "nation": "Unione Sovietica", "short": "URSS", "leader": "Stalin", "col": Color("#c23a2c"), "light": Color("#f08a7c"), "dark": Color("#6a1c14")},
]

## Ordine al tavolo (senso orario): Churchill → Stalin → Roosevelt → Churchill.
const LEFT := {0: 2, 2: 1, 1: 0}
## Spareggi: si comincia da Stalin e si procede verso sinistra.
const TIE_ORDER := [2, 1, 0]
const BASE_PROD := [4, 6, 3]

# ------------------------------------------------------------------ carte dello staff
# v = valore (0 = Capo di Stato Maggiore: valore tirato con 1d6).
# m = modificatori: [{"v": n, "c": [[condizione, ...], ...]}] (OR di AND).
# Condizioni: "i:<tipo>" tema giocato; "t:uk|us|ussr" tema su quel tracciato; "la:<potenza>" Leader attivo.
# a = azioni speciali; h = salute (morte con 1d6 ≤ h dopo ogni uso); p = purga (Beria, Merkulov).
const STAFF := [
	[ # Regno Unito
		{"n": "Anthony Eden", "r": "Ministro degli Esteri", "v": 5, "m": [{"v": 1, "c": [["i:polmil", "t:ussr"], ["i:polmil", "t:us"]]}], "t": "Tema Pol-Mil sul tracciato sovietico o americano: +1."},
		{"n": "Clement Atlee", "r": "Vice Primo Ministro", "v": 5, "m": [{"v": -2, "c": [["la:0"]]}], "t": "Se Churchill è ancora attivo nella conferenza: −2."},
		{"n": "Sir Stafford Cripps", "r": "Lord del Sigillo Privato", "v": 5, "m": [{"v": 1, "c": [["i:prod_uk"]]}], "t": "Tema Produzione UK: +1."},
		{"n": "Ernest Bevin", "r": "Ministro del Lavoro", "v": 5, "m": [{"v": -1, "c": [["i:polmil", "t:ussr"]]}], "t": "Tema Pol-Mil sul tracciato sovietico: −1."},
		{"n": "John Anderson", "r": "Lord Presidente del Consiglio", "v": 4, "a": "anderson", "t": "Mobilitazione: tira 1d6, con 1 ottieni 2 supporti offensivi."},
		{"n": "Oliver Lyttleton", "r": "Ministro della Produzione", "v": 4, "m": [{"v": 1, "c": [["i:prod_uk"]]}], "t": "Tema Produzione UK: +1."},
		{"n": "Sir Hastings Ismay", "r": "Segretario dei Capi di Stato Maggiore", "v": 4, "m": [{"v": 1, "c": [["la:0"]]}], "t": "Se Churchill è ancora attivo: +1."},
		{"n": "Sir John Dill", "r": "Rappresentante del Primo Ministro", "v": 4, "m": [{"v": 1, "c": [["t:us"]]}], "h": 3, "t": "Tema sul tracciato americano: +1. Salute: dopo ogni uso 1d6, con 1-3 muore."},
		{"n": "Lord Beaverbrook", "r": "Ministro della Produzione Aeronautica", "v": 3, "m": [{"v": 2, "c": [["la:0"]]}], "t": "Se Churchill è ancora attivo: +2."},
		{"n": "Sir Douglas Evill", "r": "Rappresentante del Capo di S.M. dell'Aviazione", "v": 3, "m": [{"v": 1, "c": [["i:do_uk"]]}], "t": "Offensiva Diretta UK: +1."},
		{"n": "Sir Gordon Macready", "r": "Vice Capo dello S.M. Imperiale", "v": 3, "m": [{"v": 1, "c": [["i:do_us", "t:us"]]}], "t": "Offensiva Diretta USA sul tracciato americano: +1."},
		{"n": "Sir Henry Wemyss", "r": "Segretario militare", "v": 3, "m": [{"v": 1, "c": [["i:do_uk", "t:us"]]}], "t": "Offensiva Diretta UK sul tracciato americano: +1."},
		{"n": "Sir Percy Noble", "r": "Comandante degli Approcci Occidentali", "v": 2, "a": "noble", "t": "Se il Fronte Occidentale è ancora nel suo riquadro: 1 supporto navale nel Teatro Occidentale."},
		{"n": "Sir Andrew Cunningham", "r": "Primo Lord del Mare", "v": 2, "m": [{"v": 2, "c": [["i:euro"]]}], "t": "Tema Comando Europa: +2."},
		{"n": "Sir John Tovey", "r": "Comandante della Home Fleet", "v": 2, "a": "tovey", "t": "Se lo spazio d'ingresso del Fronte del Mediterraneo è anfibio: 1 supporto offensivo lì."},
		{"n": "Sir Henry Wilson", "r": "Comandante supremo nel Mediterraneo", "v": 2, "m": [{"v": 3, "c": [["i:abomb"]]}], "t": "Ricerca Bomba A: +3."},
		{"n": "Sir Stuart Menzies «C»", "r": "Capo dei Servizi Segreti", "v": 1, "m": [{"v": 3, "c": [["i:polmil"]]}], "t": "Tema Pol-Mil: +3."},
		{"n": "Sir Charles Portal", "r": "Capo di S.M. dell'Aviazione", "v": 1, "m": [{"v": 2, "c": [["t:us"]]}], "t": "Tema sul tracciato americano: +2."},
		{"n": "Sir Dudley Pound", "r": "Primo Lord del Mare", "v": 1, "m": [{"v": 3, "c": [["i:strat"]]}], "h": 3, "t": "Materiali Strategici: +3. Salute: dopo ogni uso 1d6, con 1-3 muore."},
		{"n": "Lord Louis Mountbatten", "r": "Comandante supremo nel Sud-Est asiatico", "v": 1, "m": [{"v": 2, "c": [["i:pac"]]}], "t": "Tema Comando Pacifico: +2."},
		{"n": "Sir Alan Brooke", "r": "Capo dello Stato Maggiore Imperiale", "v": 0, "m": [{"v": 1, "c": [["i:do_uk"], ["i:do_us"]]}], "t": "Offensiva Diretta UK o USA: +1. Compromesso: il valore è 1d6."},
	],
	[ # Stati Uniti
		{"n": "Cordell Hull", "r": "Segretario di Stato", "v": 5, "m": [{"v": 1, "c": [["i:polmil"]]}], "t": "Tema Pol-Mil: +1."},
		{"n": "Harry Hopkins", "r": "Consigliere del Presidente", "v": 5, "a": "hopkins", "t": "Materiali Strategici con Roosevelt vivo: valore da 1 a 6 a scelta. Con Truman presidente: −3."},
		{"n": "Henry Stimson", "r": "Segretario alla Guerra", "v": 5, "m": [{"v": 1, "c": [["i:polmil"]]}], "t": "Tema Pol-Mil: +1."},
		{"n": "Frank Knox", "r": "Segretario della Marina", "v": 5, "a": "knox", "t": "Tema Produzione: ottieni 2 supporti navali."},
		{"n": "Averell Harriman", "r": "Inviato speciale", "v": 4, "m": [{"v": 1, "c": [["t:ussr"], ["la:0"]]}], "t": "Tema sul tracciato sovietico o Churchill attivo: +1."},
		{"n": "Jesse H. Jones", "r": "Segretario al Commercio", "v": 4, "m": [{"v": 1, "c": [["i:strat"]]}], "t": "Materiali Strategici: +1."},
		{"n": "Henry Morgenthau Jr.", "r": "Segretario al Tesoro", "v": 4, "m": [{"v": 1, "c": [["i:global"]]}], "t": "Tema Globale: +1."},
		{"n": "Frances Perkins", "r": "Segretaria al Lavoro", "v": 4, "m": [{"v": 1, "c": [["i:prod_us"]]}], "t": "Produzione USA: +1."},
		{"n": "Harold L. Ickes", "r": "Segretario agli Interni", "v": 3, "m": [{"v": 1, "c": [["lr"]]}], "t": "Se Roosevelt è attivo nella conferenza: +1."},
		{"n": "Claude Wickard", "r": "Segretario all'Agricoltura", "v": 3, "m": [{"v": 1, "c": [["i:prod_us"]]}], "t": "Produzione USA: +1."},
		{"n": "J. Edgar Hoover", "r": "Direttore dell'FBI", "v": 3, "m": [{"v": 1, "c": [["i:polmil"]]}], "t": "Tema Pol-Mil: +1."},
		{"n": "Francis Biddle", "r": "Procuratore generale", "v": 3, "m": [{"v": -1, "c": [["t:ussr"]]}], "t": "Tema sul tracciato sovietico: −1."},
		{"n": "Frank C. Walker", "r": "Direttore generale delle Poste", "v": 2, "m": [{"v": 2, "c": [["lr"]]}], "t": "Se Roosevelt è attivo: +2."},
		{"n": "James F. Byrnes", "r": "Ufficio di Mobilitazione Bellica", "v": 2, "m": [{"v": 2, "c": [["la:1"]]}], "t": "Se Roosevelt o Truman è attivo: +2."},
		{"n": "Leo T. Crowley", "r": "Amministrazione Economica Estera", "v": 2, "m": [{"v": 1, "c": [["i:strat"]]}], "t": "Materiali Strategici: +1."},
		{"n": "William J. Donovan", "r": "Office of Strategic Services", "v": 2, "m": [{"v": 3, "c": [["i:polmil"]]}], "t": "Tema Pol-Mil: +3."},
		{"n": "William H. Leahy", "r": "Capo di S.M. del Presidente", "v": 1, "m": [{"v": 2, "c": [["i:do"], ["i:prod_us"]]}], "t": "Offensiva Diretta o Produzione USA: +2."},
		{"n": "Ernest J. King", "r": "Capo delle Operazioni Navali", "v": 1, "m": [{"v": 3, "c": [["i:pac"]]}], "a": "king", "t": "Comando Pacifico: +3. Prima il Pacifico: se nessun Fronte alleato è in una base B29, 2 supporti offensivi al Fronte del Pacifico Centrale o Sud-Occidentale."},
		{"n": "Henry H. Arnold", "r": "Capo delle Forze Aeree", "v": 1, "m": [{"v": 3, "c": [["i:abomb"]]}], "h": 1, "t": "Ricerca Bomba A: +3. Salute: dopo ogni uso 1d6, con 1 muore."},
		{"n": "Stanley Embick", "r": "Comitato strategico congiunto", "v": 1, "m": [{"v": 2, "c": [["i:do"]]}], "t": "Offensiva Diretta: +2."},
		{"n": "George C. Marshall", "r": "Capo di S.M. dell'Esercito", "v": 0, "m": [{"v": 2, "c": [["i:do", "t:ussr"], ["i:do", "t:uk"]]}], "t": "Offensiva Diretta sul tracciato sovietico o britannico: +2. Compromesso: il valore è 1d6."},
	],
	[ # Unione Sovietica
		{"n": "Vjačeslav Molotov", "r": "Ministro degli Esteri", "v": 5, "m": [{"v": 1, "c": [["i:global"]]}], "t": "Tema Globale: +1."},
		{"n": "Semën Timošenko", "r": "Ministro della Difesa", "v": 5, "m": [{"v": 1, "c": [["i:do"]]}], "t": "Offensiva Diretta: +1."},
		{"n": "Kliment Vorošilov", "r": "Alto Comando", "v": 5, "m": [{"v": 1, "c": [["la:2"]]}], "t": "Se Stalin è attivo: +1."},
		{"n": "Semën Budënnyj", "r": "Ispettore della Cavalleria", "v": 5, "m": [{"v": -2, "c": [["la:2"]]}], "t": "Se Stalin è attivo: −2."},
		{"n": "Nikolaj Kuznecov", "r": "Comandante della Marina sovietica", "v": 4, "a": "kuznetsov", "t": "1 supporto navale nel Teatro Artico."},
		{"n": "Grigorij Kulik", "r": "Rappresentante dell'Alto Comando", "v": 4, "m": [{"v": 1, "c": [["i:do_ussr"]]}], "t": "Offensiva Diretta URSS: +1."},
		{"n": "Boris Šapošnikov", "r": "Capo di Stato Maggiore", "v": 4, "m": [{"v": 1, "c": [["i:prod", "t:us"]]}], "t": "Tema Produzione sul tracciato americano: +1."},
		{"n": "Aleksandr Vasilevskij", "r": "Capo di Stato Maggiore", "v": 4, "a": "vasilevsky", "t": "1 supporto offensivo al Fronte dell'Estremo Oriente."},
		{"n": "Lavrentij Berija", "r": "Capo dell'NKVD", "v": 3, "m": [{"v": 3, "c": [["i:abomb"]]}], "p": true, "t": "Ricerca Bomba A: +3. Purghe: dopo la prossima carta sovietica giocata o scartata in questa conferenza, 1d6: con 1 è eliminata."},
		{"n": "Aleksandr Novikov", "r": "Comandante dell'Aviazione", "v": 3, "a": "east_do", "t": "Su un'Offensiva Diretta: 1 supporto offensivo al Fronte Orientale."},
		{"n": "Nikolaj Voronov", "r": "Comandante dell'Artiglieria", "v": 3, "a": "east_do", "t": "Su un'Offensiva Diretta: 1 supporto offensivo al Fronte Orientale."},
		{"n": "Anastas Mikojan", "r": "Ministro del Commercio Estero", "v": 3, "m": [{"v": 1, "c": [["i:prod"]]}], "t": "Tema Produzione: +1."},
		{"n": "Lazar' Kaganovič", "r": "Ministro dei Trasporti", "v": 2, "m": [{"v": 1, "c": [["la:2"]]}], "t": "Se Stalin è attivo: +1."},
		{"n": "Nikolaj Voznesenskij", "r": "Comitato di Pianificazione", "v": 2, "m": [{"v": 1, "c": [["i:prod"]]}], "t": "Tema Produzione: +1."},
		{"n": "Andrej Ždanov", "r": "Consiglio militare di Leningrado", "v": 2, "m": [{"v": 2, "c": [["i:prod"]]}], "t": "Tema Produzione: +2."},
		{"n": "Kirill Mereckov", "r": "Fronte del Volchov", "v": 2, "a": "east_do", "t": "Su un'Offensiva Diretta: 1 supporto offensivo al Fronte Orientale."},
		{"n": "Georgij Malenkov", "r": "Comitato di Difesa dello Stato", "v": 1, "m": [{"v": 3, "c": [["i:strat", "t:uk"], ["i:strat", "t:us"]]}], "t": "Materiali Strategici sul tracciato britannico o americano: +3."},
		{"n": "Nikolaj Vatutin", "r": "Fronte di Voronež", "v": 1, "a": "east_do", "h": 2, "t": "Su un'Offensiva Diretta: 1 supporto offensivo al Fronte Orientale. Dopo l'uso 1d6: con 1-2 cade in un'imboscata."},
		{"n": "Pavel Žigarev", "r": "Vice Commissario alla Difesa", "v": 1, "a": "fe_do", "t": "Su un'Offensiva Diretta: 1 supporto offensivo in Estremo Oriente."},
		{"n": "Vsevolod Merkulov", "r": "Commissario alla Sicurezza", "v": 1, "m": [{"v": 1, "c": [["i:polmil"]]}], "p": true, "t": "Tema Pol-Mil: +1. Gulag: dopo la prossima carta sovietica giocata o scartata in questa conferenza, 1d6: con 1 è eliminata."},
		{"n": "Georgij Žukov", "r": "Vice Comandante supremo", "v": 0, "m": [{"v": 1, "c": [["i:prod"]]}], "t": "Tema Produzione: +1. Scavalcato: il valore è 1d6."},
	],
]

## Posizione della carta nel foglio dell'immagine (indice riga per riga).
const LEADER_CARD := {"stalin": 0, "churchill": 1, "roosevelt": 2, "truman": 3}
const LEADER_TEXT := {
	"churchill": "Sir Winston Churchill (7). Sul tema Globale: +1 marcatore di Allineamento Politico. Salute: dopo ogni uso 2d6, con 2-4 un infarto lo rende inattivo nella conferenza successiva. Carattere nazionale: Stato Maggiore Imperiale, +1 nell'Agenda.",
	"roosevelt": "Franklin D. Roosevelt (7). Se il tema Globale è sul tracciato britannico o sovietico: +1 Allineamento Politico. Salute: dopo ogni uso 2d6, con 2-3 muore e lo sostituisce Truman. Carattere nazionale: Arsenale della Democrazia, vince gli spareggi.",
	"truman": "Harry S. Truman (7). Con la Bomba A a Trinity: +1 Allineamento Politico su qualsiasi tema. Inesperienza: se la Bomba A non è a Trinity tira 2d6, con 2-5 vale 4 invece di 7. Arsenale della Democrazia.",
	"stalin": "Iosif Stalin (7). Sul tema Pol-Mil: +1 Rete Clandestina; se fa avanzare la Ricerca Bomba A non si può contestare. Paranoia: dopo ogni uso 2d6, con 2-4 tutte le carte sovietiche valgono 1 in meno per il resto della conferenza (minimo 1). Carattere nazionale: «Njet», +1 alle carte dello staff nei dibattiti.",
}

# ------------------------------------------------------------------ temi della conferenza
# k = tipo; f = potenza della bandiera (produzione, offensive dirette); pa/cn = Pol-Mil X/Y.
const ISSUES := [
	{"id": "second", "n": "Secondo Fronte", "k": "cond", "img": "second"},
	{"id": "warjapan", "n": "L'URSS dichiara guerra al Giappone", "k": "cond", "img": "warjapan"},
	{"id": "global", "n": "Tema Globale", "k": "global", "img": "global"},
	{"id": "abomb", "n": "Ricerca Bomba A", "k": "abomb", "img": "abomb"},
	{"id": "strat", "n": "Materiali Strategici", "k": "strat", "img": "strat"},
	{"id": "euro", "n": "Comando del Teatro Europeo", "k": "euro", "img": "euro"},
	{"id": "pac", "n": "Comando del Teatro del Pacifico", "k": "pac", "img": "pac"},
	{"id": "prod_us_a", "n": "Produzione USA", "k": "prod", "f": 1, "img": "prod_us"},
	{"id": "prod_us_b", "n": "Produzione USA (2)", "k": "prod", "f": 1, "img": "prod_us"},
	{"id": "prod_uk", "n": "Produzione UK", "k": "prod", "f": 0, "img": "prod_uk"},
	{"id": "do_us_a", "n": "Offensiva Diretta USA", "k": "do", "f": 1, "img": "do_us"},
	{"id": "do_us_b", "n": "Offensiva Diretta USA (2)", "k": "do", "f": 1, "img": "do_us"},
	{"id": "do_uk", "n": "Offensiva Diretta UK", "k": "do", "f": 0, "img": "do_uk"},
	{"id": "do_ussr", "n": "Offensiva Diretta URSS", "k": "do", "f": 2, "img": "do_ussr"},
	{"id": "pm11", "n": "Pol-Mil 1/1", "k": "polmil", "pa": 1, "cn": 1, "img": "pm11"},
	{"id": "pm12", "n": "Pol-Mil 1/2", "k": "polmil", "pa": 1, "cn": 2, "img": "pm12"},
	{"id": "pm22", "n": "Pol-Mil 2/2", "k": "polmil", "pa": 2, "cn": 2, "img": "pm22"},
	{"id": "pm13", "n": "Pol-Mil 1/3", "k": "polmil", "pa": 1, "cn": 3, "img": "pm13"},
]

static var _issue_idx := {}

static func issue_index(id: String) -> int:
	if _issue_idx.is_empty():
		for i in range(ISSUES.size()):
			_issue_idx[ISSUES[i]["id"]] = i
	return int(_issue_idx.get(id, -1))


static func issue_tags(i: int) -> Array:
	## Etichette usate dalle condizioni delle carte: "polmil", "prod", "prod_us", "do", "do_uk"…
	var d: Dictionary = ISSUES[i]
	var out := [d["k"]]
	var id: String = d["id"]
	if d["k"] == "prod":
		out.append("prod_us" if d["f"] == 1 else "prod_uk")
	elif d["k"] == "do":
		out.append(["do_uk", "do_us", "do_ussr"][d["f"]])
	return out

# ------------------------------------------------------------------ mappa militare
# Fronti: tracciato a partire dal riquadro del teatro (posizione −1) verso la potenza dell'Asse.
const FRONTS := [
	{"id": "west", "n": "Fronte Occidentale", "who": 1, "th": "eu", "box": "west", "track": ["uk", "normandy", "lowlands", "rhineland", "wgermany", "germany"]},
	{"id": "med", "n": "Fronte del Mediterraneo", "who": 0, "th": "eu", "box": "med", "track": ["nafrica", "sicily", "sitaly", "citaly", "nitaly"]},
	{"id": "east", "n": "Fronte Orientale", "who": 2, "th": "eu", "box": "east", "track": ["don", "belorussia", "ukraine", "prussia", "egermany", "germany"]},
	{"id": "fe", "n": "Fronte dell'Estremo Oriente", "who": 2, "th": "pa", "box": "fe", "track": ["nomohon", "manchuria", "jehol", "korea", "japan"]},
	{"id": "cbi", "n": "Fronte Cina-Birmania-India", "who": 0, "th": "pa", "box": "cbi", "track": ["burma", "kra", "indochina", "hongkong", "formosa", "japan"]},
	{"id": "cp", "n": "Fronte del Pacifico Centrale", "who": 1, "th": "pa", "box": "cp", "track": ["marshall", "caroline", "marianas", "iwojima", "okinawa", "japan"]},
	{"id": "swp", "n": "Fronte del Pacifico Sud-Occidentale", "who": 1, "th": "pa", "box": "swp", "track": ["solomon", "papua", "vogelkop", "philippines", "kyushu", "japan"]},
]

const SPACES := {
	"uk": {"n": "Regno Unito (Bolero)", "amph": 3}, "normandy": {"n": "Normandia (D-Day)", "amph": 5},
	"lowlands": {"n": "Paesi Bassi"}, "rhineland": {"n": "Renania"}, "wgermany": {"n": "Germania Ovest"},
	"germany": {"n": "Germania"}, "egermany": {"n": "Germania Est"}, "prussia": {"n": "Prussia"},
	"ukraine": {"n": "Ucraina"}, "belorussia": {"n": "Bielorussia"}, "don": {"n": "Don"},
	"nafrica": {"n": "Nordafrica"}, "sicily": {"n": "Sicilia", "amph": 3}, "sitaly": {"n": "Italia meridionale", "amph": 3},
	"citaly": {"n": "Italia centrale (Roma)"}, "nitaly": {"n": "Italia settentrionale"},
	"nomohon": {"n": "Nomonhan"}, "manchuria": {"n": "Manciuria"}, "jehol": {"n": "Jehol (Cina)"}, "korea": {"n": "Corea"},
	"japan": {"n": "Giappone", "amph": 3},
	"burma": {"n": "Birmania"}, "kra": {"n": "Istmo di Kra"}, "indochina": {"n": "Indocina francese"},
	"hongkong": {"n": "Hong Kong", "amph": 3}, "formosa": {"n": "Formosa", "amph": 3, "b29": true},
	"marshall": {"n": "Isole Marshall", "amph": 3}, "caroline": {"n": "Isole Caroline", "amph": 3},
	"marianas": {"n": "Isole Marianne", "amph": 3, "b29": true}, "iwojima": {"n": "Iwo Jima", "amph": 3, "b29": true},
	"okinawa": {"n": "Okinawa", "amph": 3, "b29": true, "kami": true},
	"solomon": {"n": "Isole Salomone", "amph": 3}, "papua": {"n": "Papua Nuova Guinea", "amph": 3},
	"vogelkop": {"n": "Vogelkop (Nuova Guinea)", "amph": 3}, "philippines": {"n": "Filippine", "amph": 3, "kami": true},
	"kyushu": {"n": "Kyushu", "amph": 3, "b29": true, "kami": true},
}

## Riquadri dei teatri (per i supporti navali). L'Artico non ha fronte.
const BOXES := {
	"west": {"n": "Teatro Occidentale", "th": "eu"}, "med": {"n": "Teatro del Mediterraneo", "th": "eu"},
	"east": {"n": "Teatro Orientale", "th": "eu"}, "arctic": {"n": "Teatro Artico", "th": "eu"},
	"fe": {"n": "Teatro dell'Estremo Oriente", "th": "pa"}, "cbi": {"n": "Teatro Cina-Birmania-India", "th": "pa"},
	"cp": {"n": "Teatro del Pacifico Centrale", "th": "pa"}, "swp": {"n": "Teatro del Pacifico Sud-Occidentale", "th": "pa"},
}

## Paesi e colonie. sp = spazio del tracciato a cui sono collegati ("arctic" per Norvegia e Finlandia).
const COUNTRIES := {
	"france": {"n": "Francia", "sp": "normandy"}, "netherlands": {"n": "Olanda", "sp": "lowlands"},
	"belgium": {"n": "Belgio", "sp": "lowlands"}, "denmark": {"n": "Danimarca", "sp": "wgermany"},
	"czech": {"n": "Cecoslovacchia", "sp": "wgermany"}, "norway": {"n": "Norvegia", "sp": "arctic"},
	"finland": {"n": "Finlandia", "sp": "arctic"}, "austria": {"n": "Austria", "sp": "egermany"},
	"hungary": {"n": "Ungheria", "sp": "prussia"}, "yugoslavia": {"n": "Jugoslavia", "sp": "prussia"},
	"greece": {"n": "Grecia", "sp": "prussia"}, "baltic": {"n": "Stati baltici", "sp": "ukraine"},
	"poland": {"n": "Polonia", "sp": "ukraine"}, "rumania": {"n": "Romania", "sp": "ukraine"},
	"bulgaria": {"n": "Bulgaria", "sp": "ukraine"}, "middleeast": {"n": "Medio Oriente", "sp": "nafrica"},
	"persia": {"n": "Persia", "sp": "sicily"}, "siam": {"n": "Siam", "sp": "kra", "col": true},
	"dei": {"n": "Indie orientali olandesi", "sp": "kra", "col": true}, "malaya": {"n": "Malesia", "sp": "kra", "col": true},
	"vietnam": {"n": "Vietnam", "sp": "indochina", "col": true}, "cambodia": {"n": "Cambogia/Laos", "sp": "indochina", "col": true},
}
## Variante Agenda segreta (10.0): i 36 segnalini nell'ordine del foglio (assets/cards/agenda.jpg, 10 colonne;
## la cella 39 è il retro). Alcuni paesi compaiono due volte: è voluto.
const SA_TOKENS := ["austria", "austria", "dei", "belgium", "baltic", "yugoslavia", "yugoslavia", "finland", "malaya", "norway",
	"bulgaria", "bulgaria", "cambodia", "cambodia", "france", "france", "greece", "greece", "rumania", "rumania",
	"hungary", "malaya", "middleeast", "middleeast", "siam", "siam", "czech", "czech", "netherlands", "denmark",
	"poland", "poland", "vietnam", "vietnam", "persia", "persia"]
const SA_BACK := 39
const SA_VP := 5

const COUNTRY_ORDER := ["norway", "finland", "netherlands", "belgium", "france", "denmark", "czech", "austria", "hungary",
	"yugoslavia", "greece", "baltic", "poland", "rumania", "bulgaria", "middleeast", "persia",
	"siam", "dei", "malaya", "vietnam", "cambodia"]
## Paesi collegati ai tracciati occidentale e orientale (tema Globale Churchill–Stalin neutrale).
const WEST_EAST := ["france", "netherlands", "belgium", "denmark", "czech", "austria", "hungary", "yugoslavia", "greece", "baltic", "poland", "rumania", "bulgaria"]
const SPHERE_USSR := ["baltic", "poland", "rumania", "bulgaria", "finland"]
const SPHERE_WEST := ["france", "belgium", "netherlands"]

## Tabella Pol-Mil: riga = primo dado (rosso), colonna = secondo dado (blu).
const POLMIL_TABLE := [
	["france", "netherlands", "belgium", "denmark", "czech", "norway"],
	["finland", "austria", "hungary", "yugoslavia", "greece", "baltic"],
	["poland", "rumania", "bulgaria", "siam", "dei", "malaya"],
	["vietnam", "cambodia", "persia", "middleeast", "poland", "france"],
	["austria", "greece", "siam", "bulgaria", "rumania", "cambodia"],
	["yugoslavia", "czech", "malaya", "vietnam", "middleeast", "persia"],
]

## Tracciato della Bomba A: 0 Lettera a Roosevelt … 4 Trinity.
const ABOMB := ["Lettera a Roosevelt", "Oak Ridge", "Hanford", "Los Alamos", "Trinity"]

## Temi Globali: coppia di potenze; il lato di ciascuna dà le sue regole.
const GLOBALS := [
	{"pair": [0, 1], "n": "Churchill–Roosevelt", "side": {0: "Colonialismo", 1: "Autodeterminazione"}, "neutral": "Neutrale: nessun Allineamento Politico nelle colonie."},
	{"pair": [0, 2], "n": "Churchill–Stalin", "side": {0: "Europa libera", 2: "Sfere d'influenza"}, "neutral": "Neutrale: nessun Allineamento Politico nei paesi collegati ai fronti occidentale e orientale."},
	{"pair": [1, 2], "n": "Roosevelt–Stalin", "side": {1: "Nazioni Unite", 2: "Quadri comunisti"}, "neutral": "Neutrale: togliere un Allineamento avversario costa 1 marcatore."},
]
const GLOBAL_TEXT := {
	"0:0": "Colonialismo: solo il Regno Unito può mettere o togliere Allineamenti nelle colonie.",
	"0:1": "Autodeterminazione: tutti possono mettere o togliere Allineamenti nelle colonie.",
	"1:0": "Europa libera: nessuna restrizione nei paesi (non colonie).",
	"1:2": "Sfere d'influenza: solo l'URSS in Stati baltici, Polonia, Romania, Bulgaria e Finlandia; solo UK e USA in Francia, Belgio e Olanda.",
	"2:1": "Nazioni Unite: togliere un Allineamento avversario costa 2 marcatori ovunque.",
	"2:2": "Quadri comunisti: togliere un Allineamento sovietico in Stati baltici, Polonia, Romania, Bulgaria, Finlandia e nelle colonie costa 2; altrove 1.",
}

# ------------------------------------------------------------------ conferenze
const CONF_NAMES := ["", "Casablanca – SYMBOL", "Washington – TRIDENT", "Québec – QUADRANT", "Il Cairo – SEXTANT",
	"Teheran – EUREKA", "Londra – PM", "Québec – OCTAGON", "Mosca – TOLSTOY", "Jalta – ARGONAUT", "Potsdam – TERMINAL"]
const CONF_DATES := ["", "gennaio 1943", "maggio 1943", "agosto 1943", "novembre 1943", "novembre 1943", "giugno 1944",
	"settembre 1944", "ottobre 1944", "febbraio 1945", "luglio 1945"]

## Effetti delle 30 carte Conferenza (3 varianti per ognuna delle 10 conferenze), nell'ordine delle fasce:
## verde (Churchill), rossa (Stalin), blu (Roosevelt), grigia (militare), bianca (reti e allineamenti).
## Ogni effetto: {"t": tipo, …, "x": testo in italiano}.
const CONF_CARDS := [
	# 1 Casablanca
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "med", "x": "Montgomery: Churchill deve usare 1 Produzione per un supporto offensivo nel Mediterraneo."},
	 {"t": "murmansk", "m": "fixed", "x": "Incrociatore Gneisenau danneggiato: convoglio di Murmansk, +1 Produzione all'URSS."},
	 {"t": "mand", "who": 1, "n": 2, "k": "any", "th": "pacific", "x": "Pressione dell'opinione pubblica: Roosevelt deve usare 2 Produzione nel Pacifico."},
	 {"t": "prod_loss", "who": [1], "n": 1, "x": "Passo di Kasserine: gli USA perdono 1 Produzione."},
	 {"t": "partisans", "x": "Attività partigiana: ogni giocatore tira 1d6, con 1-3 ottiene 2 Reti Clandestine, con 4-6 ne ottiene 3, piazzate con la tabella Pol-Mil."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "naval", "th": "west", "x": "Battaglia dell'Atlantico: Churchill deve usare 1 Produzione per un supporto navale nel Teatro Occidentale."},
	 {"t": "murmansk", "m": "roll", "x": "Sortita dello Scharnhorst: 1d6, con 1-3 convoglio di Murmansk (+1 Produzione URSS), con 4-6 nessun convoglio."},
	 {"t": "prod_loss", "who": [1], "n": 1, "x": "La «Gobba»: gli USA perdono 1 Produzione per gli aiuti alla Cina."},
	 {"t": "uk_lose_cn", "x": "Negoziati con la Turchia: il Regno Unito perde 1 Rete Clandestina nella fase delle Decisioni."},
	 {"t": "partisans", "x": "Attività partigiana: ogni giocatore tira 1d6, con 1-3 ottiene 2 Reti Clandestine, con 4-6 ne ottiene 3, piazzate con la tabella Pol-Mil."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "cbi", "x": "Arakan: Churchill deve usare 1 Produzione per un supporto offensivo in Cina-Birmania-India."},
	 {"t": "murmansk", "m": "roll", "x": "Rinforzi della Luftflotte: 1d6, con 1-3 convoglio di Murmansk (+1 Produzione URSS)."},
	 {"t": "mand", "who": 1, "n": 2, "k": "any", "th": "pacific", "x": "Pressione politica: Roosevelt deve usare 2 Produzione nel Pacifico."},
	 {"t": "no_front", "f": "swp", "x": "Operazione KE (evacuazione di Guadalcanal): il Fronte del Pacifico Sud-Occidentale non avanza."},
	 {"t": "partisans", "x": "Attività partigiana: ogni giocatore tira 1d6, con 1-3 ottiene 2 Reti Clandestine, con 4-6 ne ottiene 3, piazzate con la tabella Pol-Mil."}],
	# 2 Washington
	[{"t": "mand", "who": 0, "n": 1, "k": "any", "th": "med", "x": "Ventre molle: Churchill deve usare 1 Produzione nel Mediterraneo."},
	 {"t": "no_adv", "who": 2, "x": "Stalin resta a Mosca: non può far avanzare temi (può dibattere)."},
	 {"t": "issue", "id": "prod_us", "x": "Sostegno alleato: il tema Produzione USA va sul tavolo."},
	 {"t": "res", "f": "east", "n": 1, "x": "Kursk: una riserva tedesca al Fronte Orientale."},
	 {"t": "partisans", "x": "Attività partigiana: ogni giocatore tira 1d6, con 1-3 ottiene 2 Reti Clandestine, con 4-6 ne ottiene 3, piazzate con la tabella Pol-Mil."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "any", "th": "west", "x": "Preparativi di Bolero: Churchill deve usare 1 Produzione nel Teatro Occidentale."},
	 {"t": "no_adv", "who": 2, "x": "Stalin resta a Mosca: non può far avanzare temi (può dibattere)."},
	 {"t": "prod_loss", "who": [1], "n": 1, "x": "Minacce di Chiang Kai-shek: gli USA perdono 1 Produzione per gli aiuti alla Cina."},
	 {"t": "res", "f": "med", "n": 1, "x": "Tunisia: una riserva tedesca al Mediterraneo."},
	 {"t": "partisans", "soft": true, "x": "Attività partigiana: ogni giocatore tira 1d6, con 1-3 ottiene 2 Reti Clandestine, con 4-6 ne ottiene 3, piazzate con la tabella Pol-Mil; dove ci sono reti avversarie non se ne piazza nessuna."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "any", "th": "west", "x": "Preparativi di Bolero: Churchill deve usare 1 Produzione nel Teatro Occidentale."},
	 {"t": "no_adv", "who": 2, "x": "Stalin resta a Mosca: non può far avanzare temi (può dibattere)."},
	 {"t": "issue", "id": "do_us", "x": "Stallo dei Capi di Stato Maggiore: l'Offensiva Diretta USA va sul tavolo."},
	 {"t": "res_remove", "n": 1, "x": "Distrutte le dighe della Ruhr: una riserva tedesca in meno in questa conferenza."},
	 {"t": "partisans", "x": "Attività partigiana: ogni giocatore tira 1d6, con 1-3 ottiene 2 Reti Clandestine, con 4-6 ne ottiene 3, piazzate con la tabella Pol-Mil."}],
	# 3 Québec QUADRANT
	[{"t": "issue", "id": "do_uk", "x": "Churchill non è d'accordo: l'Offensiva Diretta UK va sul tavolo."},
	 {"t": "murmansk", "m": "roll", "x": "U-Boot: 1d6, con 1-3 convoglio di Murmansk (+1 Produzione URSS)."},
	 {"t": "issue", "id": "abomb", "x": "Gen. Groves: la Ricerca Bomba A va sul tavolo."},
	 {"t": "mand", "who": [0, 1], "n": 1, "k": "off", "th": "med", "x": "Sicilia: USA e Regno Unito devono usare 1 Produzione ciascuno per un supporto offensivo nel Mediterraneo."},
	 {"t": "yugo", "x": "Contrasti fra i partigiani jugoslavi: 1d6, con 1-3 si tolgono tutte le Reti dalla Jugoslavia, con 4-6 il suo Allineamento Politico."}],
	[{"t": "issue", "id": "do_uk", "x": "Churchill non è d'accordo: l'Offensiva Diretta UK va sul tavolo."},
	 {"t": "murmansk", "m": "roll", "x": "Rinforzi della Luftflotte: 1d6, con 1-3 convoglio di Murmansk (+1 Produzione URSS)."},
	 {"t": "issue", "id": "abomb", "x": "Gen. Groves: la Ricerca Bomba A va sul tavolo."},
	 {"t": "mand", "who": 1, "n": 1, "k": "off", "th": "swp", "x": "Nuova Georgia: gli USA devono usare 1 Produzione per un supporto offensivo nel Pacifico Sud-Occidentale."},
	 {"t": "tito", "x": "Tito: si tolgono le Reti non sovietiche dalla Jugoslavia e l'URSS vi mette 1 Rete Clandestina."}],
	[{"t": "issue", "id": "do_uk", "x": "Churchill non è d'accordo: l'Offensiva Diretta UK va sul tavolo."},
	 {"t": "murmansk", "m": "roll", "x": "Sortita dello Scharnhorst: 1d6, con 1-3 convoglio di Murmansk (+1 Produzione URSS)."},
	 {"t": "issue", "id": "abomb", "x": "Gen. Groves: la Ricerca Bomba A va sul tavolo."},
	 {"t": "prod_loss", "who": [0], "n": 1, "x": "Sciopero di Gandhi e dei lavoratori indiani: il Regno Unito perde 1 Produzione."},
	 {"t": "partisans", "x": "Attività partigiana: ogni giocatore tira 1d6, con 1-3 ottiene 2 Reti Clandestine, con 4-6 ne ottiene 3, piazzate con la tabella Pol-Mil."}],
	# 4 Il Cairo
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "med", "x": "8ª Armata: Churchill deve usare 1 Produzione per un supporto offensivo nel Mediterraneo."},
	 {"t": "no_adv", "who": 2, "x": "Stalin irritato dalla presenza di Chiang Kai-shek: non può far avanzare temi."},
	 {"t": "mand", "who": 1, "n": 1, "k": "any", "th": "west", "x": "Preparativi di Bolero: Roosevelt deve usare 1 Produzione nel Teatro Occidentale."},
	 {"t": "prod_loss", "who": [1], "n": 1, "x": "Pesanti perdite dell'8ª Air Force: gli USA perdono 1 Produzione."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "cbi", "x": "Aeroporti della «Gobba»: Churchill deve usare 1 Produzione per un supporto offensivo in Cina-Birmania-India."},
	 {"t": "no_adv", "who": 2, "x": "Stalin irritato dalla presenza di Chiang Kai-shek: non può far avanzare temi."},
	 {"t": "mand", "who": 1, "n": 1, "k": "any", "th": "cbi", "x": "Stilwell addestra l'esercito cinese: Roosevelt deve usare 1 Produzione in Cina-Birmania-India."},
	 {"t": "uk_lose_cn", "x": "Negoziati con la Turchia: il Regno Unito perde 1 Rete Clandestina nella fase delle Decisioni."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "cbi", "x": "SEAC attivato: Churchill deve usare 1 Produzione per un supporto offensivo in Cina-Birmania-India."},
	 {"t": "no_adv", "who": 2, "x": "Stalin irritato dalla presenza di Chiang Kai-shek: non può far avanzare temi."},
	 {"t": "mand", "who": 1, "n": 1, "k": "off", "th": "cp", "x": "Galvanic (Tarawa): gli USA devono usare 1 Produzione per un supporto offensivo nel Pacifico Centrale."},
	 {"t": "res", "f": "swp", "n": 1, "x": "Rabaul: una riserva giapponese al Pacifico Sud-Occidentale."},
	 {"t": "issue", "id": "pm12", "x": "Cina: il tema Pol-Mil 1/2 va sul tavolo."}],
	# 5 Teheran
	[{"t": "issue", "id": "euro", "x": "Eisenhower al comando dello SHAEF: il tema Comando Europa va sul tavolo."},
	 {"t": "murmansk", "m": "fixed", "x": "Affondato lo Scharnhorst: convoglio di Murmansk, +1 Produzione all'URSS."},
	 {"t": "issue", "id": "do_us", "x": "Stallo dei Capi di Stato Maggiore: l'Offensiva Diretta USA va sul tavolo."},
	 {"t": "res", "f": "east", "n": 1, "x": "Offensiva sovietica d'inverno: una riserva tedesca al Fronte Orientale."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	[{"t": "issue", "id": "do_uk", "x": "Churchill non è d'accordo: l'Offensiva Diretta UK va sul tavolo."},
	 {"t": "murmansk", "m": "roll", "x": "U-Boot: 1d6, con 1-3 convoglio di Murmansk (+1 Produzione URSS)."},
	 {"t": "issue", "id": "second", "cond": "no_normandy", "x": "D-Day: se la Normandia non è ancora alleata, il Secondo Fronte va sul tavolo."},
	 {"t": "res", "f": "west", "n": 1, "x": "Costruzione del Vallo Atlantico: una riserva tedesca al Fronte Occidentale."},
	 {"t": "issue", "id": "pm13", "x": "Jugoslavia, Turchia, Polonia: il tema Pol-Mil 1/3 va sul tavolo."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "med", "x": "Ventre molle: Churchill deve usare 1 Produzione per un supporto offensivo nel Mediterraneo."},
	 {"t": "murmansk", "m": "roll", "x": "U-Boot: 1d6, con 1-3 convoglio di Murmansk (+1 Produzione URSS)."},
	 {"t": "issue", "id": "abomb", "x": "Oppenheimer: la Ricerca Bomba A va sul tavolo."},
	 {"t": "res", "f": "swp", "n": 1, "x": "Contrattacco in Nuova Britannia: una riserva giapponese al Pacifico Sud-Occidentale."},
	 {"t": "partisans", "x": "Attività partigiana: ogni giocatore tira 1d6, con 1-3 ottiene 2 Reti Clandestine, con 4-6 ne ottiene 3, piazzate con la tabella Pol-Mil."}],
	# 6 Londra
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "west", "x": "D-Day: Churchill deve usare 1 Produzione per un supporto offensivo nel Teatro Occidentale."},
	 {"t": "mand", "who": 2, "n": 1, "k": "naval", "th": "arctic", "x": "Finlandia: Stalin deve usare 1 Produzione nel Teatro Artico."},
	 {"t": "issue", "id": "second", "cond": "no_normandy", "x": "D-Day: se la Normandia non è ancora alleata, il Secondo Fronte va sul tavolo."},
	 {"t": "res", "f": "west", "n": 1, "x": "Costruzione del Vallo Atlantico: una riserva tedesca al Fronte Occidentale."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "med", "x": "Operazione Dragoon: Churchill deve usare 1 Produzione per un supporto offensivo nel Mediterraneo."},
	 {"t": "murmansk", "m": "roll", "x": "U-Boot: 1d6, con 1-3 convoglio di Murmansk (+1 Produzione URSS)."},
	 {"t": "issue", "id": "do_us", "x": "D-Day: l'Offensiva Diretta USA va sul tavolo."},
	 {"t": "prod_loss", "who": [0, 1], "n": 1, "cond": "v1v2", "x": "V1/V2: se Normandia o Paesi Bassi sono ancora tedeschi, USA e Regno Unito perdono 1 Produzione."},
	 {"t": "exile", "x": "Governi in esilio: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si toglie l'Allineamento Politico da quei luoghi."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "cbi", "x": "Offensiva della Ledo Road: Churchill deve usare 1 Produzione per un supporto offensivo in Cina-Birmania-India."},
	 {"t": "mand", "who": 2, "n": 1, "k": "any", "th": "fe", "x": "Scaramucce di confine: Stalin deve usare 1 Produzione in Estremo Oriente."},
	 {"t": "mand", "who": 1, "n": 1, "k": "any", "th": "swp", "x": "Task Force Hurricane (Biak): Roosevelt deve usare 1 Produzione nel Pacifico Sud-Occidentale."},
	 {"t": "ijn", "f": "cp", "x": "Battaglia del Mare delle Filippine: la flotta giapponese esce nel Pacifico Centrale."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	# 7 Québec OCTAGON
	[{"t": "mand", "who": 0, "n": 1, "k": "any", "th": "west", "x": "Montgomery: Churchill deve usare 1 Produzione nel Teatro Occidentale."},
	 {"t": "no_adv", "who": 2, "x": "Stalin resta a Mosca: non può far avanzare temi (può dibattere)."},
	 {"t": "mand", "who": 1, "n": 1, "k": "any", "th": "west", "x": "Patton: Roosevelt deve usare 1 Produzione nel Teatro Occidentale."},
	 {"t": "res", "f": "west", "n": 1, "x": "Market Garden: una riserva tedesca al Fronte Occidentale."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "med", "x": "Offensiva in Italia: Churchill deve usare 1 Produzione per un supporto offensivo nel Mediterraneo."},
	 {"t": "no_adv", "who": 2, "x": "Stalin resta a Mosca: non può far avanzare temi (può dibattere)."},
	 {"t": "mand", "who": 1, "n": 1, "k": "any", "th": "west", "x": "7ª Armata: Roosevelt deve usare 1 Produzione nel Teatro Occidentale."},
	 {"t": "res", "f": "med", "n": 1, "x": "Linea Gotica: una riserva tedesca al Mediterraneo."},
	 {"t": "exile", "x": "Governi in esilio: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si toglie l'Allineamento Politico da quei luoghi."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "cbi", "x": "Slim, offensiva della 14ª Armata: Churchill deve usare 1 Produzione per un supporto offensivo in Cina-Birmania-India."},
	 {"t": "no_adv", "who": 2, "x": "Stalin resta a Mosca: non può far avanzare temi (può dibattere)."},
	 {"t": "issue", "id": "abomb", "track": 2, "d6": true, "x": "Falla nella sicurezza: la Ricerca Bomba A va sul tracciato sovietico, nello spazio indicato da 1d6."},
	 {"t": "res", "f": "swp", "n": 1, "and": "cp", "x": "MacArthur e Nimitz: una riserva giapponese al Pacifico Sud-Occidentale e una al Pacifico Centrale."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	# 8 Mosca
	[{"t": "issue", "id": "global", "x": "Il «documento birichino» di Churchill: il tema Globale va sul tavolo."},
	 {"t": "murmansk", "m": "north", "x": "Fianco settentrionale: con meno di 3 supporti navali nell'Artico 1d6, con 1-3 convoglio di Murmansk; con 3 o più il convoglio arriva (+1 Produzione URSS)."},
	 {"t": "no_adv", "who": 1, "x": "Roosevelt resta a Washington: non può far avanzare temi (può dibattere)."},
	 {"t": "res", "f": "west", "n": 1, "x": "Battaglia delle Ardenne: una riserva tedesca al Fronte Occidentale."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	[{"t": "issue", "id": "global", "x": "Il «documento birichino» di Churchill: il tema Globale va sul tavolo."},
	 {"t": "murmansk", "m": "north", "x": "Fianco settentrionale: con meno di 3 supporti navali nell'Artico 1d6, con 1-3 convoglio di Murmansk; con 3 o più il convoglio arriva (+1 Produzione URSS)."},
	 {"t": "no_adv", "who": 1, "x": "Roosevelt resta a Washington: non può far avanzare temi (può dibattere)."},
	 {"t": "res", "f": "east", "n": 1, "x": "Difesa di Budapest: una riserva tedesca al Fronte Orientale."},
	 {"t": "exile", "x": "Governi in esilio: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si toglie l'Allineamento Politico da quei luoghi."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "cbi", "x": "Churchill e Mountbatten al Cairo: Churchill deve usare 1 Produzione per un supporto offensivo in Cina-Birmania-India."},
	 {"t": "murmansk", "m": "north", "x": "Fianco settentrionale: con meno di 3 supporti navali nell'Artico 1d6, con 1-3 convoglio di Murmansk; con 3 o più il convoglio arriva (+1 Produzione URSS)."},
	 {"t": "no_adv", "who": 1, "x": "Roosevelt resta a Washington: non può far avanzare temi (può dibattere)."},
	 {"t": "ijn", "f": "swp", "res": 1, "x": "Golfo di Leyte: la flotta giapponese esce nel Pacifico Sud-Occidentale con una riserva giapponese."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	# 9 Jalta
	[{"t": "no_adv", "who": 0, "x": "Churchill messo da parte dagli alleati: non può far avanzare temi (può dibattere)."},
	 {"t": "issue", "id": "do_ussr", "x": "Pressioni per la guerra al Giappone: l'Offensiva Diretta URSS va sul tavolo."},
	 {"t": "no_adv", "who": 1, "x": "Roosevelt in cattiva salute: non può far avanzare temi (può dibattere)."},
	 {"t": "res", "f": "west", "n": 1, "x": "Operazione Grenade: una riserva tedesca al Fronte Occidentale."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	[{"t": "no_adv", "who": 0, "x": "Churchill messo da parte dagli alleati: non può far avanzare temi (può dibattere)."},
	 {"t": "issue", "id": "do_ussr", "x": "Pressioni per la guerra al Giappone: l'Offensiva Diretta URSS va sul tavolo."},
	 {"t": "no_adv", "who": 1, "x": "Roosevelt in cattiva salute: non può far avanzare temi (può dibattere)."},
	 {"t": "res", "f": "swp", "n": 1, "x": "Difesa di Luzon: una riserva giapponese al Pacifico Sud-Occidentale."},
	 {"t": "exile", "x": "Governi in esilio: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si toglie l'Allineamento Politico da quei luoghi."}],
	[{"t": "mand", "who": 0, "n": 1, "k": "off", "th": "cbi", "x": "Riaperta la strada della Birmania: Churchill deve usare 1 Produzione per un supporto offensivo in Cina-Birmania-India."},
	 {"t": "issue", "id": "abomb", "track": 2, "d6": true, "x": "La rete di spie del Progetto Manhattan: la Ricerca Bomba A va sul tracciato sovietico, nello spazio indicato da 1d6."},
	 {"t": "fdr_dies", "x": "Muore Roosevelt: se non è già successo, lo sostituisce Truman."},
	 {"t": "res", "f": "cp", "n": 1, "x": "Iwo Jima: una riserva giapponese al Pacifico Centrale."},
	 {"t": "dispute", "x": "Contrasti fra partigiani: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si tolgono tutte le Reti da quei luoghi."}],
	# 10 Potsdam
	[{"t": "no_adv", "who": 0, "x": "Esito elettorale incerto: Churchill non può far avanzare temi (può dibattere)."},
	 {"t": "murmansk", "m": "north", "x": "Fianco settentrionale: con meno di 3 supporti navali nell'Artico 1d6, con 1-3 convoglio di Murmansk; con 3 o più il convoglio arriva (+1 Produzione URSS)."},
	 {"t": "fdr_dies", "x": "Muore Roosevelt: se non è già successo, lo sostituisce Truman."},
	 {"t": "prod_loss", "who": [1], "n": 1, "x": "Piano Morgenthau: gli USA perdono 1 Produzione per gli aiuti all'estero."},
	 {"t": "exile", "x": "Governi in esilio: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si toglie l'Allineamento Politico da quei luoghi."}],
	[{"t": "inactive", "who": 0, "x": "Attlee vince le elezioni: Churchill è inattivo in questa conferenza."},
	 {"t": "do_place", "id": "do_ussr", "f": "fe", "x": "Manciuria: l'Offensiva Diretta URSS va sullo spazio d'ingresso del Fronte dell'Estremo Oriente."},
	 {"t": "fdr_dies", "x": "Muore Roosevelt: se non è già successo, lo sostituisce Truman."},
	 {"t": "issue", "id": "pm11", "x": "Spartizione del Vietnam: il tema Pol-Mil 1/1 va sul tavolo."},
	 {"t": "exile", "x": "Governi in esilio: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si toglie l'Allineamento Politico da quei luoghi."}],
	[{"t": "issue", "id": "global", "track": 0, "d6": true, "x": "Churchill vince le elezioni: il tema Globale va sul tracciato britannico, nello spazio indicato da 1d6."},
	 {"t": "do_place", "id": "do_ussr", "f": "fe", "x": "Manciuria: l'Offensiva Diretta URSS va sullo spazio d'ingresso del Fronte dell'Estremo Oriente."},
	 {"t": "fdr_dies", "x": "Muore Roosevelt: se non è già successo, lo sostituisce Truman."},
	 {"t": "res", "f": "cp", "n": 1, "x": "Okinawa: una riserva giapponese al Pacifico Centrale."},
	 {"t": "exile", "x": "Governi in esilio: 1d6, con 1-3 si tira altrettante volte sulla tabella Pol-Mil e si toglie l'Allineamento Politico da quei luoghi."}],
]

## Le carte sono in ordine: conferenza n, variante v → indice (n−1)·3 + v.
static func conf_number(card: int) -> int:
	return card / 3 + 1

static func conf_variant(card: int) -> String:
	return ["A", "B", "C"][card % 3]

# ------------------------------------------------------------------ scenari
const SCENARIOS := [
	{"id": "training", "n": "Addestramento", "first": 8, "desc": "3 conferenze (Mosca, Jalta, Potsdam), circa un'ora.",
	 "fronts": {"west": 3, "med": 3, "east": 3, "cbi": -1, "fe": 0, "cp": 2, "swp": 2},
	 "naval": {"west": 5, "med": 3, "arctic": 1, "cbi": 1, "cp": 3, "swp": 3},
	 "net": [[1, "france", 1, true], [1, "czech", 1, true], [1, "siam", 1, true], [1, "dei", 1, false], [1, "vietnam", 1, false], [1, "cambodia", 1, true],
		[0, "netherlands", 1, true], [0, "belgium", 1, true], [0, "poland", 1, false], [0, "greece", 1, false], [0, "middleeast", 1, true], [0, "persia", 1, true],
		[2, "baltic", 1, true], [2, "yugoslavia", 1, true], [2, "hungary", 1, false], [2, "rumania", 1, true], [2, "bulgaria", 1, true], [2, "austria", 1, false]],
	 "lead": {"eu": 1, "pa": 1}, "abomb": 2, "spy": 0, "no_ita": true, "no_navy": true, "no_second": true},
	{"id": "tournament", "n": "Torneo", "first": 6, "desc": "5 conferenze (da Londra a Potsdam), 2-3 ore.",
	 "fronts": {"west": 0, "med": 2, "east": 1, "cbi": -1, "fe": 0, "cp": 1, "swp": 1},
	 "naval": {"west": 5, "med": 3, "arctic": 0, "cbi": 0, "cp": 3, "swp": 3},
	 "net": [[1, "france", 1, true], [1, "czech", 1, false], [1, "siam", 1, false], [1, "dei", 1, false], [1, "vietnam", 1, false], [1, "cambodia", 1, false],
		[0, "netherlands", 1, true], [0, "belgium", 1, false], [0, "poland", 1, false], [0, "greece", 1, false], [0, "middleeast", 1, false], [0, "persia", 1, false],
		[2, "baltic", 1, true], [2, "yugoslavia", 1, true], [2, "rumania", 1, false], [2, "bulgaria", 1, false]],
	 "lead": {"eu": 0, "pa": 1}, "abomb": 1, "spy": 0, "no_ita": true, "no_navy": true, "second_center": true},
	{"id": "campaign", "n": "Campagna", "first": 1, "desc": "10 conferenze (da Casablanca a Potsdam), 4-5 ore.",
	 "fronts": {"west": -1, "med": -1, "east": -1, "cbi": -1, "fe": -1, "cp": -1, "swp": -1},
	 "naval": {"west": 0, "med": 1, "arctic": 0, "cbi": 0, "cp": 1, "swp": 3},
	 "net": [], "lead": {"eu": 0, "pa": 1}, "abomb": 0, "spy": 0},
]

# ------------------------------------------------------------------ coordinate
# Tavolo della conferenza: coordinate nell'immagine assets/conference.jpg (frazioni 0..1).
const CONF_W := 890.0
const CONF_H := 850.0

static func conf_pos(owner: int, d: int) -> Vector2:
	## Posizione di uno spazio del tavolo: owner −1 = centro; d 1..6 tracciato; d ≥ 7 sedia.
	if owner < 0 or d <= 0:
		return Vector2(448, 478) / Vector2(CONF_W, CONF_H)
	var p := Vector2.ZERO
	var dd := mini(d, 7)
	match owner:
		0: p = Vector2(448, 464 - 44 * dd) if dd < 7 else Vector2(448, 128)
		1: p = Vector2(390 - 38 * (dd - 1), 520 + 22.4 * (dd - 1)) if dd < 7 else Vector2(132, 676)
		2: p = Vector2(508 + 37.4 * (dd - 1), 520 + 22.4 * (dd - 1)) if dd < 7 else Vector2(764, 676)
	return p / Vector2(CONF_W, CONF_H)

## Caselle dei temi disponibili, in alto a destra del tavolo.
const ISSUE_SLOTS := {
	"second": Vector2(563, 79), "global": Vector2(608, 79), "strat": Vector2(652, 79), "euro": Vector2(700, 82),
	"prod_us_a": Vector2(745, 80), "do_us_a": Vector2(790, 80), "pm11": Vector2(832, 82),
	"warjapan": Vector2(563, 126), "abomb": Vector2(608, 126), "pac": Vector2(700, 127),
	"prod_us_b": Vector2(745, 125), "do_us_b": Vector2(790, 125), "pm12": Vector2(832, 127),
	"prod_uk": Vector2(745, 170), "do_uk": Vector2(790, 170), "pm22": Vector2(832, 172),
	"do_ussr": Vector2(790, 215), "pm13": Vector2(832, 217),
}
## Temi Globali: posizione neutrale e dei due lati.
const GLOBAL_POS := [
	{-1: Vector2(300, 400), 0: Vector2(380, 296), 1: Vector2(250, 521)},
	{-1: Vector2(597, 393), 0: Vector2(518, 298), 2: Vector2(645, 515)},
	{-1: Vector2(448, 660), 1: Vector2(300, 638), 2: Vector2(588, 638)},
]
const CHAIR_POS := {0: Vector2(448, 100), 1: Vector2(126, 690), 2: Vector2(772, 690)}

# Mappa militare: coordinate nell'immagine assets/military.jpg (riferite a 1760 × 2100).
const MIL_W := 1760.0
const MIL_H := 2100.0
const MIL_POS := {
	"box:west": Vector2(90, 500), "uk": Vector2(216, 504), "normandy": Vector2(330, 510), "lowlands": Vector2(450, 510),
	"rhineland": Vector2(566, 504), "wgermany": Vector2(684, 504), "germany": Vector2(860, 490), "egermany": Vector2(1032, 504),
	"prussia": Vector2(1150, 504), "ukraine": Vector2(1264, 510), "belorussia": Vector2(1380, 510), "don": Vector2(1500, 510),
	"box:east": Vector2(1630, 524),
	"netherlands": Vector2(450, 286), "belgium": Vector2(450, 396), "denmark": Vector2(684, 396), "czech": Vector2(684, 620),
	"france": Vector2(330, 690), "norway": Vector2(836, 260), "finland": Vector2(952, 260), "baltic": Vector2(1264, 396),
	"austria": Vector2(1032, 620), "hungary": Vector2(1150, 620), "poland": Vector2(1264, 620), "yugoslavia": Vector2(1150, 734),
	"rumania": Vector2(1264, 734), "greece": Vector2(1150, 844), "bulgaria": Vector2(1264, 844),
	"box:med": Vector2(326, 880), "nafrica": Vector2(452, 880), "sicily": Vector2(568, 880), "sitaly": Vector2(686, 850),
	"citaly": Vector2(786, 770), "nitaly": Vector2(856, 684), "middleeast": Vector2(452, 994), "persia": Vector2(568, 1044),
	"box:arctic": Vector2(894, 130), "cmd:eu": Vector2(194, 290), "cmd:pa": Vector2(196, 1380),
	"ab0": Vector2(1424, 1080), "ab1": Vector2(1532, 1040), "ab2": Vector2(1640, 994), "ab3": Vector2(1640, 890), "ab4": Vector2(1640, 790),
	"box:fe": Vector2(450, 1320), "nomohon": Vector2(570, 1330), "manchuria": Vector2(680, 1340), "jehol": Vector2(790, 1410),
	"korea": Vector2(840, 1530), "japan": Vector2(850, 1690),
	"box:cbi": Vector2(96, 1684), "burma": Vector2(230, 1684), "kra": Vector2(344, 1684), "indochina": Vector2(458, 1684),
	"hongkong": Vector2(574, 1684), "formosa": Vector2(686, 1684),
	"box:cp": Vector2(1636, 1670), "marshall": Vector2(1500, 1684), "caroline": Vector2(1384, 1684), "marianas": Vector2(1270, 1684),
	"iwojima": Vector2(1154, 1684), "okinawa": Vector2(1040, 1684),
	"box:swp": Vector2(1410, 2010), "solomon": Vector2(1260, 2016), "papua": Vector2(1150, 2016), "vogelkop": Vector2(1030, 1990),
	"philippines": Vector2(930, 1936), "kyushu": Vector2(864, 1846),
	"siam": Vector2(344, 1570), "dei": Vector2(344, 1790), "malaya": Vector2(344, 1906), "vietnam": Vector2(458, 1790), "cambodia": Vector2(458, 1906),
}

static func mil_pos(key: String) -> Vector2:
	return MIL_POS.get(key, Vector2.ZERO) / Vector2(MIL_W, MIL_H)


static func front_index(id: String) -> int:
	for i in range(FRONTS.size()):
		if FRONTS[i]["id"] == id:
			return i
	return -1
