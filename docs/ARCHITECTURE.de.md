# Architektur

English version: [ARCHITECTURE.md](ARCHITECTURE.md)

## Kernmodul: der Kopfreiter

```
BADI_SLS_HEAD_SCR_CUS (Erweiterungsspot BADI_SD_SALES_BASIC)
  Implementierung ZSD_APM_HEAD_TAB → Klasse ZCL_SD_APM_HEAD_TAB
    ├─ ACTIVATE_TAB_PAGE            registriert Subscreen SAPLZSD_APM_INFO 0100, Caption aus Nachricht 020,
    │                               merkt sich den Funktionscode K_CUS_BADI_n des Reiters
    ├─ TRANSFER_DATA_TO_SUBSCREEN   merkt sich VBELN (Kontext für das PBO des Subscreens)
    ├─ TRANSFER_DATA_FROM_SUBSCREEN konsumiert ZREFRESH → Z_SD_APM_WF_REFRESH, ersetzt ihn durch ENT1
    └─ PASS_FCODE_TO_SUBSCREEN      leer
```

Der Reiter erscheint nur, wenn `ZCL_SD_APM_WF_SCOPE=>IS_RELEVANT` zustimmt (Transaktion VA03,
Belegart Gutschriftsanforderung). Anwender erreichen ihn über Springen → Kopf.

### Subscreen 0100 (Funktionsgruppe ZSD_APM_INFO)

- Drucktaste BTN_REFRESH (ICON_REFRESH, Funktionscode ZREFRESH), Zeile 1
- Custom Control GO_CONT_STEPS, Zeile 2, größenveränderbar
- PBO-Modul `pbo_0100` → `LCL_TREE_VIEW=>PROCESS_BEFORE_OUTPUT`
  1. VBELN aus `ZCL_SD_APM_HEAD_TAB=>GET_CURRENT_VBELN`
  2. prüfen, ob der Frontend-Container noch existiert (`IS_VALID`), sonst ABAP-Referenzen verwerfen
  3. `ZCL_SD_APM_WF_READER=>GET_INFO` (ohne Cache nach manuellem Refresh)
  4. Neuaufbau bei: erster Anzeige, anderem Beleg, manuellem Refresh oder frischen Daten des Readers
  5. Container freigeben und SALV-Tree komplett neu aufbauen (ein inkrementeller Refresh war im
     eingebetteten VA03-Subscreen instabil)

### SALV-Tree

- Ebene 1: ein Knoten pro Workflow-Lauf ("Lauf n – Einreicher") mit Status, Ergebnis und Zeitstempeln
- Ebene 2: ein Knoten pro Schritt ("Freigabe" oder "Nachbearbeitung") mit Bearbeiter, Status,
  Entscheid, Notiz-Icon und Zeitstempeln; offene Schritte sind hervorgehoben; nur der neueste Lauf
  ist aufgeklappt
- Doppelklick auf einen Schritt mit Notiz-Icon öffnet die Notiz als HTML-Popup (`CL_ABAP_BROWSER`)

### Notiz lesen

1. `SAP_WAPI_GET_ATTACHMENTS`, zuerst nur Entscheidungskommentare (`COMMENT_SEMANTIC_ONLY`), sonst alle Anhänge
2. Anhänge werden im Workflow vererbt: Die Anhänge des Vorgängerschritts im selben Lauf werden abgezogen,
   übrig bleibt, was an diesem Schritt erfasst wurde (Sicherheitsnetz: alle Anhänge, falls nichts übrig bleibt)
3. SOFM-Schlüssel aus dem BOR-Objektschlüssel (Offset 20, 34 Zeichen) → `SO_DOCUMENT_READ_API1`
4. HTML escaped rendern und modal anzeigen

### Refresh-Zyklus

Im PAI darf das Frontend nicht angefasst werden. Deshalb:

```
PAI: ZREFRESH → BAdI konsumiert → Z_SD_APM_WF_REFRESH setzt ein Flag → Fcode wird ENT1
PBO: Flag gesetzt → Reader ohne Cache → Container free + flush → Tree neu
```

## Optionales Modul: der Statusbutton

```
SAPMV45A setzt den GUI-Status des Übersichtsbilds (FORM cua_setzen)
  └─ Plug-in ZSD_APM_WF_GUI_STATUS (implizite Erweiterung am Ende der FORM)
       ├─ nur VA03 im Anzeigemodus und nur Belege im Scope
       │  (ZCL_SD_APM_WF_SCOPE=>IS_RELEVANT)
       ├─ CALL FUNCTION 'Z_SD_APM_WF_BUTTON_PREPARE'
       │    → LCL_STATUS_BUTTON=>PREPARE füllt GS_WF_BUTTON (Icon, Text, Quickinfo)
       └─ SET PF-STATUS 'ZU' EXCLUDING cua_exclude OF PROGRAM 'SAPLZSD_APM_INFO'
            ZU = Kopie von SAPMV45B Status U + Funktion ZWF mit dynamischem Text <GS_WF_BUTTON>
```

Ein dynamischer Text eines GUI-Status muss eine globale Variable des Programms sein, dem der
Status gehört. Deshalb liegt `GS_WF_BUTTON` im TOP-Include der Funktionsgruppe und wird über einen
Funktionsbaustein gefüllt.

| Situation des neuesten Laufs | Icon | Quickinfo (Nachricht) |
|---|---|---|
| kein Workflow | ICON_LED_INACTIVE | 001 |
| läuft, Nachbearbeitung offen | ICON_SYSTEM_UNDO | 013 |
| läuft, Genehmiger bekannt | ICON_TIME | 012 mit Name |
| läuft, Genehmiger unbekannt | ICON_TIME | 011 |
| erledigt, genehmigt | ICON_OKAY | 014 |
| erledigt, abgelehnt | ICON_CANCEL | 015 |
| abgebrochen | ICON_LED_INACTIVE | 016 |
| sonst | ICON_LED_INACTIVE | 010 |

Klick auf den Button:

```
Benutzer drückt ZWF
  └─ FORM fcode_bearbeiten (MV45AF0F_FCODE_BEARBEITEN)
       └─ Plug-in ZSD_APM_WF_FCODE: fcode 'ZWF' → ZCL_SD_APM_HEAD_TAB=>GET_TAB_FCODE( )
            (K_CUS_BADI_n, n = Position des Reiters in CT_CUS_HEAD_TAB, Standardnavigation)
```

## Datenquelle: ZCL_SD_APM_WF_READER

Es gibt keine eigenen Tabellen. Alles liest `ZCL_SD_APM_WF_READER=>GET_INFO` zur Laufzeit.
Der Reader cacht das Ergebnis pro Beleg 60 Sekunden, weil der Statusbutton bei jedem PBO von VA03
vorbereitet wird; ein manueller Refresh umgeht den Cache.

Leseschritte (Methode `READ_WORKFLOW`):

1. **Läufe**: Top-Level-Flow-Items zum Beleg in SWW_WI2OBJ (Kategorie CL, Typ CL_SD_CMR_WORKFLOW,
   Instanz = Belegnummer), verknüpft mit SWWWIHEAD, älteste zuerst.
2. **Schritte**: abhängige Dialog-Workitems jedes Laufs (`SAP_WAPI_GET_DEPENDENT_WIS`), gefiltert
   auf die Freigabeaufgabe TS02000054 und die Nachbearbeitungsaufgabe TS02000055 des
   SAP-Standard-Szenarios WS02000029. Pro Schritt
   liefert `SAP_WAPI_GET_WORKITEM_DETAIL` Status, Bearbeiter, Zeitstempel und Workitem-Ergebnis.
3. **Entscheid** eines erledigten Schritts: Workitem-Ergebnis, sonst Containerelement `_WI_RESULT`
   (`SAP_WAPI_READ_CONTAINER`), sonst aus dem Folgeschritt im selben Lauf abgeleitet
   (Nachbearbeitung nach Freigabe heißt "zur Nachbearbeitung", ein späterer Schritt nach einer
   Nachbearbeitung heißt "neu eingereicht").
4. **Bearbeiter** eines offenen Schritts: tatsächlicher Bearbeiter eines reservierten oder
   gestarteten Workitems, sonst die Empfänger (`SAP_WAPI_WORKITEM_RECIPIENTS`), aufgelöst zu
   Anzeigenamen über `BAPI_USER_GET_DETAIL`.
5. **Zurückgezogene Nachbearbeitungen** (abgebrochenes Nachbearbeitungs-Workitem mit Folgeschritt)
   werden als "neu eingereicht" gezeigt; als Bearbeiter gilt, wer den Beleg dazwischen geändert
   hat (Änderungsbelege VERKBELEG).
6. **Notizen**: SOFM-Relationen der Workitems in SWW_WI2OBJ. Weil der Workflow Notizen an
   Folge-Workitems weiterreicht, bekommt nur das Workitem mit der kleinsten ID pro Notiz das Kennzeichen.
7. **Läufe zusammenfassen**: Status aus dem Flow-Item, Ergebnis aus dem letzten erledigten
   Freigabeschritt, Einreicher aus dem Workflow-Kopf (Fallback: Beleganleger bei Lauf 1,
   Änderungsbeleg-Benutzer bei späteren Läufen).

Kopfinformationen aus VBAK (Genehmigungsstatus und -grund mit Texten) werden ebenfalls gelesen.

Technische Fehler landen einmal pro Session und Fehler im Application Log (Objekt ZSD_APM,
Subobjekt WF_DISPLAY), gesichert über eine zweite DB-Verbindung, damit kein COMMIT WORK in der
VA03-LUW ausgelöst wird.

Stellen für weitere Belegarten: `GC_TYPEID`, `GC_TASK` und `GC_RESULT_KEY` im Reader,
`GET_DOC_CATEGORIES` in der Scope-Klasse.

## Designentscheidungen

- **Eine Scope-Definition.** Transaktion und Belegarten werden nur in `ZCL_SD_APM_WF_SCOPE`
  geprüft. BAdI-Implementierung und beide Plug-ins rufen sie.
- **Keine sprachabhängigen Vergleiche.** Laufstatus, Entscheid und Laufergebnis sind Konstanten des
  Readers (`GC_RUN_STATUS`, `GC_DECISION`), Texte dienen nur der Anzeige.
- **Übersetzbare Texte.** Jeder Oberflächentext ist eine Nachricht der Klasse ZSD_APM.
- **Lokale Klassen statt FORM-Routinen** in der Funktionsgruppe; die Funktionsbausteine sind dünne
  Hüllen, die es nur gibt, weil SAPMV45A und das BAdI eine aufrufbare Schnittstelle in die
  Funktionsgruppe brauchen.
- **Kern und Statusbutton getrennt.** Der Kern kommt ohne Eingriff in SAPMV45A aus; der Button
  ist ein Zusatz für Unternehmen, die den Komfort wollen und implizite Erweiterungen akzeptieren.
- **Report ZSD_APM_WF_DISPLAY** zeigt das Reader-Ergebnis als Vollbild-ALV-Liste (kein Popup), damit
  die Installation ohne VA03 geprüft werden kann und der Support schnell auf einen Beleg schauen kann.
