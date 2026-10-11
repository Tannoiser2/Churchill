# Churchill – adattamento digitale (Godot 4)

Versione digitale per uso personale di **Churchill: Big Three Struggle for Peace** di Mark Herman
(GMT Games, 2ª edizione con l'errata del settembre 2015). Mappa, carte e regole © dei rispettivi autori:
le immagini vengono dal modulo Tabletop Simulator e non vanno distribuite pubblicamente.

**Gioca nel browser:** https://tannoiser2.github.io/Churchill/

## Avvio
1. Apri Godot 4 (testato su 4.7) → *Importa* → seleziona `project.godot`.
2. Premi **F5**. F11 alterna schermo intero e finestra.

## Cosa c'è
- **Tre potenze**: Churchill (Regno Unito), Roosevelt (poi Truman, Stati Uniti) e Stalin (URSS), ognuna
  Umana o IA. Si gioca da soli contro due IA, in due, in tre sullo stesso dispositivo (una schermata
  «passa il dispositivo» nasconde le carte in mano) oppure online.
- **Tre scenari**: Addestramento (Mosca, Jalta, Potsdam), Torneo (da Londra a Potsdam) e Campagna
  (dieci conferenze da Casablanca), con le loro posizioni di partenza.
- **Regole complete**: le 30 carte Conferenza con le cinque fasce, i 63 membri dello staff con tutti
  gli attributi (bonus, salute, purghe, Capi di Stato Maggiore, Hopkins, King, Noble, Tovey…), i quattro
  Leader (salute di Churchill e Roosevelt, morte di Roosevelt e Truman, paranoia di Stalin), i caratteri
  nazionali, Agenda, Riunione con avanzamenti, dibattiti, catture, passaggi e temi condizionali, spareggi
  con i Leader e l'Arsenale della Democrazia, le sette attività delle Decisioni (offensive dirette,
  produzione e sua assegnazione, comando dei teatri, Bomba A e spie, temi Globali), reti clandestine e
  allineamenti politici con le restrizioni dei temi Globali e dell'Artico, tabella Pol-Mil, riserve
  dell'Asse con tutte le priorità, fronti, sfondamenti, kamikaze, «dietro il fronte», crollo militare,
  resa di Germania, Italia e Giappone (anche con le condizioni dell'Imperatore), punteggio finale con le
  tre situazioni di vittoria e lo spareggio finale.
- **Le due metà della mappa in viste separate**: il *tavolo della Conferenza* (Agenda e Riunione) e la
  *mappa dei fronti* (Decisioni e guerra). La vista cambia da sola con la fase; il pulsante in alto
  (MAPPA DEI FRONTI / TAVOLO) permette di passare a mano dall'una all'altra. La **fascia in alto** resta
  sempre visibile: conferenza, fase, punti di ognuno (passa il mouse per il dettaglio), conferenze vinte,
  temi sul proprio lato o vinti, Bomba A e spie, temi Globali, Germania e Giappone, comandi dei teatri.
- **IA** su tre livelli (Facile / Normale / Difficile): stima in punti vittoria il valore di ogni tema
  per ogni esito (vinto da sé, da un altro, al centro), la probabilità che la conferenza vada a buon fine,
  il rischio di essere contestata, il valore di ogni passo dei fronti e di ogni supporto (con la
  concentrazione della produzione), dove servono reti e allineamenti. Non guarda mai le carte degli altri.
- **Variante Agenda segreta** (regola 10.0, scelta nel menu): ognuno pesca a caso 3 dei 36 segnalini
  (alcuni paesi sono doppi, com'è previsto) e li tiene nascosti. Il proprio si vede sotto le carte in mano
  (passa il mouse per ingrandirlo). A fine partita, prima di stabilire il vincitore, ogni segnalino vale
  5 PV se in quel paese c'è un proprio Allineamento Politico. Il punteggio in alto resta quello pubblico,
  senza le agende. L'IA cura soltanto la propria agenda e non conosce quella degli altri.
- **Regole in breve** (menu e pulsante REGOLE), **diario** della partita (DIARIO), riepiloghi a fine
  Agenda, fine Riunione e fine fase militare, fine partita con il dettaglio dei punti.

## Comandi
- **Tavolo**: clic su una carta della mano, poi sul tema evidenziato. Per il Leader premi USA IL LEADER e
  scegli la carta da scartare. Nei dibattiti scegli la carta e premi DIBATTI. Tasto destro: annulla.
- **Agenda**: si sceglie la carta coperta; il vincitore e poi tutti scelgono i temi fra le caselle
  evidenziate in alto a destra del tavolo.
- **Mappa**: clic sui riquadri dorati (spazi d'ingresso, riquadri dei teatri, paesi) oppure sui pulsanti
  del pannello in basso a destra.
- Passa il mouse su carte, temi, paesi, fronti e sulle schede dei giocatori per i dettagli.

## Gioco online
Dal menu, **GIOCA ONLINE** (anche dalla versione web). Usa lo stesso progetto Firebase degli altri giochi
(Realtime Database, piano gratuito), con le stanze sotto `churchill/rooms`.

- **Chi crea la stanza** sceglie prima nel menu le potenze, lo scenario e il livello dell'IA: le potenze
  su UMANO diventano i posti per gli amici (la prima è la sua). Scrive il nome, preme *Crea una stanza* e
  comunica il codice di 4 lettere. Quando ci sono tutti preme *Inizia online*: i posti liberi li gioca
  l'IA.
- **Gli amici** scrivono il nome e il codice e premono *Entra*.
- Ognuno vede soltanto le proprie carte (anche quella giocata coperta nell'Agenda, fino alla rivelazione)
  e la propria Agenda segreta, se la variante è attiva (la sceglie chi crea la stanza).
- Ogni decisione è una mossa numerata nel database (`acts/0`, `acts/1`, …): tutti i dispositivi fanno
  girare lo stesso motore con lo stesso seme e applicano le stesse mosse, quindi la partita è identica
  ovunque. Le potenze dell'IA le gioca il dispositivo di chi ha creato la stanza.
- **Se cade la linea** si rientra con lo stesso codice e *Entra*. Se un giocatore tace per un minuto, al
  suo posto gioca l'IA finché non rientra.
- Nota: come negli altri giochi online fra amici senza server, le carte degli altri sono nascoste
  dall'interfaccia, non dalla rete.

**Configurazione Firebase.** Le regole sono in `firebase/database.rules.json` e comprendono anche quelle
degli altri giochi (Ultimo chilometro, Snow Tails, STATUS, World Order, Kingsburg) più la nuova sezione
`churchill`: vanno pubblicate nella console di Firebase (Realtime Database → Regole) al posto delle
precedenti. Senza questo passaggio la creazione della stanza risponde "Permission denied".

**Prove senza Firebase.** `tests/firebase_mock.py` è un finto Firebase locale. Con `CH_DB_URL`,
`CH_AUTH_URL` e `CH_REFRESH_URL` che puntano lì, `tests/online_play.gd` fa giocare una partita intera a
due istanze (`CH_ROLE=host` con Churchill e `guest` con Stalin, Roosevelt all'IA; con `CH_PHASE=drop` e
poi `back` l'ospite esce a metà e rientra). Alla fine ognuna stampa l'impronta della partita, che deve
coincidere, e controlla che si vedano solo le proprie carte.

## Struttura
```
scripts/data/ch_data.gd      carte dello staff e dei Leader, carte Conferenza, temi, fronti, paesi, scenari, coordinate
scripts/core/engine.gd       motore delle regole (nessuna dipendenza dalla UI)
scripts/core/ai.gd           IA
scripts/net/                 Firebase (REST) e partita online in lockstep
scripts/ui/                  menu, vista di gioco (tavolo e mappa), regole
tests/sim.gd                 godot --headless -s res://tests/sim.gd -- 20 1 1 1 1   (partite IA contro IA: partite, scenario, livelli)
tests/shot.gd                xvfb-run godot -s res://tests/shot.gd -- game 1         (screenshot, partita intera dall'interfaccia)
tests/online_play.gd         prova online con tests/firebase_mock.py
assets/                      mappa divisa in tavolo e fronti, fogli delle carte, gettoni dei temi (dal modulo TTS), font OFL
```

## Scelte da verificare
- **IA**: le tabelle dei 'Bot sono sulle schede d'aiuto, che non fanno parte del modulo TTS. L'IA segue la
  logica descritta in 11.3 (sfruttare le combinazioni fra attributi delle carte e temi) ma con valutazioni
  proprie, non con le priorità delle schede.
- La carta giocata nell'Agenda è spesa: nella Riunione restano sei carte (come nell'esempio illustrato).
- Gli attributi delle carte valgono anche nei dibattiti (Kuznecov, Novikov, Vasilevskij…); «se il tema è sul
  tracciato X» si valuta nel momento in cui la carta viene giocata.
- Il Leader usato per dibattere applica attributi e prove di salute come quando avanza. Usato per uno
  spareggio non scarta carte e non fa prove (errata).
- Hopkins sui Materiali Strategici con Roosevelt vivo (anche inattivo) prende un valore da 1 a 6 al posto
  di 5; con Truman presidente vale sempre 3 in meno.
- King, «prima il Pacifico»: si guarda la posizione attuale dei fronti; i due supporti vanno subito sullo
  spazio d'ingresso del Pacifico Centrale o Sud-Occidentale scelto.
- Anderson e Knox: i supporti guadagnati si piazzano nell'assegnazione della produzione, in qualsiasi teatro.
- Il bonus di comando del teatro va a chi lo comanda all'inizio delle Decisioni (prima del cambio deciso
  da chi ha vinto il tema). Tutti i supporti dei comandi si piazzano durante l'assegnazione.
- La produzione per la Bomba A si può investire solo se il tema è stato vinto in questa conferenza.
- I supporti navali non si mettono nel Teatro Orientale (non ha spazi anfibi).
- Con il tema Globale neutrale (o con le sfere/colonialismo) nei paesi vietati non si può né mettere né
  togliere un Allineamento Politico.
- Parità nell'ordine di piazzamento di reti e allineamenti: gli USA si mettono per ultimi.
- Riserve messe dalle carte Conferenza: vengono dal totale dell'Asse e si oppongono al fronte indicato; le
  sortite della flotta giapponese delle carte tolgono un supporto navale, tirano per la sorte della
  flotta e sostituiscono la sortita della priorità 4.
- «Manciuria» (Potsdam B e C): l'Offensiva Diretta sovietica va sullo spazio d'ingresso dell'Estremo
  Oriente e l'URSS la paga con 2 Produzione; il tema non è disponibile in quella conferenza.
- Sfondamento: il secondo spazio deve essere di terra e rispettare le condizioni di Normandia e Manciuria.
- Il Fronte dell'Estremo Oriente in Corea o in Giappone dà 8 PV all'URSS, non cumulabili.
- Quando tutti i temi sono catturati, chi ha ancora carte le scarta senza effetto.
- Agenda segreta: i segnalini si pescano con lo stesso seme della partita (così online coincidono su tutti
  i dispositivi). In hotseat restano nascosti con la mano, dietro la schermata «passa il dispositivo».
  L'aggiustamento finale e le soglie dei 20 PV usano il punteggio con le agende, come chiede la regola 10.3.
