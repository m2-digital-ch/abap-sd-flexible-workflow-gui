# Installation

English version: [INSTALLATION.md](INSTALLATION.md)

Getestet auf SAP S/4HANA 2023 (S4CORE 108, SAP_BASIS 758).

## Module

| Modul | Was es liefert | Eingriff in den SAP-Standard? |
|---|---|---|
| **Kern** (Pflicht) | Kopfreiter "Freigabe" in VA03 mit dem Workflow-Baum, Notiz-Popup, Prüfreport | Nein. Nur das freigegebene BAdI BADI_SLS_HEAD_SCR_CUS und eigene Objekte. |
| **Statusbutton** (optional) | Icon-Button in der VA03-Drucktastenleiste mit dem Freigabestatus, Klick öffnet den Reiter | Ja. Zwei implizite Erweiterungen in SAPMV45A und eine Kopie eines Standard-GUI-Status. |

Ohne den Statusbutton erreichen die Anwender den Reiter über den Belegkopf
(VA03 → Springen → Kopf → Reiter "Freigabe").

Objektliste

| Objekt | Typ | Modul | Bereitstellung |
|---|---|---|---|
| ZSD_APM | Paket | Kern | abapGit / manuell |
| ZSD_APM | Nachrichtenklasse | Kern | abapGit / manuell (MESSAGES.md) |
| ZCL_SD_APM_WF_SCOPE | Klasse | Kern | Quelltext |
| ZCL_SD_APM_WF_READER | Klasse | Kern | Quelltext |
| ZCL_SD_APM_HEAD_TAB | Klasse | Kern | Quelltext |
| ZSD_APM_INFO | Funktionsgruppe mit Includes, 2 Funktionsbausteine | Kern | Quelltext |
| ZSD_APM_INFO Dynpro 0100 | Subscreen | Kern | abapGit / manuell (Teil B1) |
| ZSD_APM_HEAD_TAB | BAdI-Implementierung | Kern | abapGit / manuell (Teil B2) |
| ZSD_APM / WF_DISPLAY | Application-Log-Objekt | Kern | manuell (Teil B3) |
| ZSD_APM_WF_DISPLAY | Report | Kern | Quelltext |
| ZSD_APM_INFO Status ZU | GUI-Status | Statusbutton | abapGit / manuell (Teil C1) |
| ZSD_APM_WF_FCODE, ZSD_APM_WF_GUI_STATUS | Erweiterungsimplementierungen | Statusbutton | abapGit / manuell (Teil C2) |

Mit abapGit wird alles außer dem Application-Log-Objekt automatisch angelegt. Die manuellen
Schritte in B1, B2, C1 und C2 braucht nur, wer ohne abapGit installiert.

## Teil A: Quelltexte ins System bringen

### A1. Mit abapGit (empfohlen)

**Was abapGit ist.** abapGit ist der kostenlose Open-Source-Git-Client für ABAP, gepflegt von der
abapGit-Community unter MIT-Lizenz. Es ist weder Teil des SAP-Standards noch ein Produkt von
M2 Digital. Website und Download: [abapgit.org](https://abapgit.org), Quellcode und Releases:
[github.com/abapGit/abapGit](https://github.com/abapGit/abapGit), Dokumentation:
[docs.abapgit.org](https://docs.abapgit.org). Die folgenden Schritte sind nur eine
Gedächtnisstütze; maßgeblich ist die abapGit-Dokumentation, weil sich Installationsdetails ohne
unser Zutun ändern können.

**Falls abapGit noch nicht im System ist.** Der schnellste Weg ist die Standalone-Version: Die
Datei `zabapgit_standalone.prog.abap` von der abapGit-Website herunterladen, in SE38 einen Report
mit diesem Namen anlegen (Typ ausführbares Programm, lokales Objekt `$TMP` genügt), Inhalt
einfügen und aktivieren. Für Online-Repositories braucht das SAP-System zusätzlich die
SSL-Zertifikate von github.com in STRUST; die abapGit-Dokumentation beschreibt das unter
"Installation".

**Wie man es startet.** SE38 → `ZABAPGIT_STANDALONE` → Ausführen. Falls die Basis eine Transaktion
dafür angelegt hat, heißt sie meist `ZABAPGIT`. Wenn das SAP-System GitHub nicht erreicht,
stattdessen ein Offline-Repository verwenden: dieses Repository auf GitHub als ZIP herunterladen
und per abapGit → New Offline importieren.

**Auf Deutsch anmelden.** Die Hauptsprache dieses Repositories ist Deutsch; die englischen
Texte stehen in [MESSAGES.md](MESSAGES.md) für die Transaktion SE63. abapGit verweigert den
Pull, wenn die Anmeldesprache von der Hauptsprache abweicht
("Current login language 'EN' does not match main language 'DE'"). Für die Installation deshalb
in Deutsch am SAP-System anmelden.

**Vor dem Pull entscheiden: mit oder ohne Statusbutton.** Das Repository enthält beide Module.
abapGit legt alles an, was es findet, sofern man im Pull-Dialog nichts abwählt. Der Pull-Dialog
listet jedes Objekt mit einem Ankreuzfeld in der Spalte "Change?". Wer nur das Kernmodul
möchte, **entfernt vor dem Bestätigen die Haken bei den zwei Objekten vom Typ ENHO namens
`ZSD_APM_WF_FCODE` und `ZSD_APM_WF_GUI_STATUS`**. Alles andere bleibt markiert; der GUI-Status ZU
in der Funktionsgruppe ist ohne die Plug-ins wirkungslos. Wer die Plug-ins versehentlich
gepullt hat, deaktiviert oder löscht die beiden Erweiterungsimplementierungen in SE19 und pullt
erneut ohne die Haken.

**Dieses Repository holen.**

1. abapGit starten und **New Online** wählen (Schaltfläche in der Symbolleiste der
   Repository-Liste).
2. Den Dialog "New Online Repository" ausfüllen (Feldnamen Stand abapGit 1.13x):
   - **Git Repository URL**: `https://github.com/m2-digital-ch/abap-sd-flexible-workflow-gui.git`
   - **Package**: `ZSD_APM`. Das Paket muss noch nicht existieren. Zwei Möglichkeiten:
     - *Von abapGit anlegen lassen*: Auf die Schaltfläche **Create Package** am unteren Rand des
       Dialogs klicken. Es öffnet sich ein Popup. Dort Paket `ZSD_APM`, eine Beschreibung wie
       "Flexible-Workflow-Freigabestatus in der SAP GUI (VA03)", Softwarekomponente `HOME` und
       die Transportschicht des Entwicklungssystems eintragen (im Zweifel bei der Basis
       nachfragen; für einen ersten Test geht auch ein lokales Paket `$ZSD_APM` ohne
       Transportschicht, lokale Objekte lassen sich später aber nicht transportieren).
       Bestätigen; abapGit legt das Paket an und füllt das Feld.
     - *Selbst anlegen*: SE80 → Repository Browser → Paket → `ZSD_APM` eingeben → Anlegen, mit
       denselben Werten wie oben. Danach `ZSD_APM` im abapGit-Dialog eintragen (die
       Schaltfläche `...` neben dem Feld bietet eine Suchhilfe).
   - **Branch**: leer lassen ("Autodetect default branch").
   - **Folder Logic**: `Prefix` (Vorgabe, passt zur `.abapgit.xml`).
   - **Display Name**: optional, zum Beispiel "SD Freigabestatus GUI".
   - **Labels**, die Ankreuzfelder und **ABAP Language Version** (`Any`): so lassen.
   - Mit **Create Online Repo** bestätigen. abapGit zeigt nun das Repository mit allen Objekten
     als neu markiert (Status "A").

   ![Dialog New Online Repository](images/abapgit_new_online_repository.png)

   ![Repository-Ansicht vor dem Pull](images/abapgit_repository_before_pull.png)

3. Auf **Pull** klicken. abapGit listet die Objekte auf, die es anlegen wird, jedes mit
   Ankreuzfeld. **Ohne Statusbutton: jetzt die zwei ENHO-Objekte abwählen** (siehe oben).
   Bestätigen. Ist das Paket transportierbar, fragt abapGit nach einem Transportauftrag: neuen
   Workbench-Auftrag anlegen oder einen bestehenden auswählen. Danach legt abapGit die Objekte
   an und aktiviert sie.

   ![Pull-Dialog, nur Kernmodul](images/abapgit_pull_dialog_core_only.png)
4. In SE80 prüfen, dass das Paket `ZSD_APM` die drei Klassen, die Nachrichtenklasse, die
   Funktionsgruppe mit Dynpro 0100, GUI-Status ZU, Includes und Funktionsbausteinen, den Report
   und die Erweiterungsimplementierungen enthält. Weiter mit Teil B3 (Application-Log-Objekt)
   und B4; B1, B2, C1 und C2 sind damit erledigt.

### A2. Ohne abapGit (manuell)

Alle Quelltexte sind reine Textdateien in `/src/`. Die Objekte in dieser Reihenfolge anlegen,
weil jeder Schritt die vorherigen benötigt. Die unten genannten Objekttexte sind die deutschen
Originaltexte der ausgelieferten Objekte (Hauptsprache Deutsch); in Deutsch anmelden, damit die
Texte in der Hauptsprache landen.

1. **Paket** `ZSD_APM` (SE80 → Paket → Anlegen). Beschreibung: "Flexible-Workflow-Freigabestatus
   in der SAP GUI (VA03)". Transportschicht nach Wahl.

2. **Nachrichtenklasse** `ZSD_APM` (SE91 → Anlegen, in Deutsch angemeldet). Kurztext:
   "Freigabe-Workflow-Status in der SAP GUI". Alle Nachrichten aus [MESSAGES.md](MESSAGES.md)
   mit Nummer und deutschem Text erfassen. Englische Texte: per SE63 oder in Englisch anmelden
   und als Übersetzung erfassen.

3. **Klassen** (ADT empfohlen, sonst SE24 → quelltextbasiert). Jede Klasse als globale,
   öffentliche, finale Klasse anlegen und dann den kompletten Quelltext durch den Inhalt der Datei
   ersetzen. Aktivieren in dieser Reihenfolge:
   1. `zcl_sd_apm_wf_scope.clas.abap` → ZCL_SD_APM_WF_SCOPE
   2. `zcl_sd_apm_wf_reader.clas.abap` → ZCL_SD_APM_WF_READER
   3. `zcl_sd_apm_head_tab.clas.abap` → ZCL_SD_APM_HEAD_TAB

   In SE24 muss der quelltextbasierte Modus eingeschaltet sein (Schaltfläche in der
   Symbolleiste); die Klassenköpfe enthalten bereits die ABAP-Doc-Kommentare (`"!`).

4. **Funktionsgruppe** `ZSD_APM_INFO` (SE80 → Funktionsgruppe → Anlegen). Kurztext:
   "Freigabe-Workflow-Status in der SAP GUI".
   1. Include `LZSD_APM_INFOTOP` öffnen und den Inhalt durch
      `zsd_apm_info.fugr.lzsd_apm_infotop.abap` ersetzen.
   2. Die Includes `LZSD_APM_INFOD01`, `LZSD_APM_INFOP01` und `LZSD_APM_INFOO01` anlegen
      (Rechtsklick auf die Funktionsgruppe → Anlegen → Include) und die jeweiligen Dateien
      einfügen. D01 wird aus dem TOP-Include inkludiert; P01 und O01 im Rahmenprogramm
      `SAPLZSD_APM_INFO` unter `INCLUDE lzsd_apm_infouxx.` eintragen, wie in
      `zsd_apm_info.fugr.saplzsd_apm_info.abap`.
   3. Funktionsbaustein `Z_SD_APM_WF_REFRESH` anlegen (Kurztext "Freigabe-Reiter: Neuaufbau im
      naechsten PBO vormerken"): keine Parameter, Ablaufart "Normal". Rumpf aus
      `zsd_apm_info.fugr.z_sd_apm_wf_refresh.abap` einfügen (zwischen FUNCTION und ENDFUNCTION).
   4. Funktionsbaustein `Z_SD_APM_WF_BUTTON_PREPARE` anlegen (Kurztext "Freigabestatus-Button:
      dynamischen Text vorbereiten"): Import-Parameter `IV_VBELN` Typ `VBELN_VA`,
      Wertübergabe. Rumpf aus
      `zsd_apm_info.fugr.z_sd_apm_wf_button_prepare.abap` einfügen.
   5. Die ganze Funktionsgruppe aktivieren (das Dynpro aus Teil B1 kann vorher oder nachher
      angelegt werden).

5. **Report** `ZSD_APM_WF_DISPLAY` (SE38 → Anlegen, Typ Ausführbares Programm).
   `zsd_apm_wf_display.prog.abap` einfügen. Titel: "Freigabe-Workflow eines Verkaufsbelegs
   anzeigen". Selektionstext für `P_VBELN`: "Verkaufsbeleg". Aktivieren.

## Teil B: Kernmodul

B1 und B2 sind nur nach einer manuellen Installation (Teil A2) nötig; abapGit liefert beides mit.

### B1. Subscreen 0100 der Funktionsgruppe ZSD_APM_INFO

Screen Painter (SE51), Programm SAPLZSD_APM_INFO, Dynpro 0100.

Dynpro-Eigenschaften

| Attribut | Wert |
|---|---|
| Kurzbeschreibung | Subscreen Kopfreiter Freigabe (Status + Schritte) |
| Dynprotyp | Subscreen |
| Folgedynpro | 0 |
| Zeilen / Spalten (belegt) | 30 / 171 |
| Zeilen / Spalten (Pflege) | 30 / 172 |
| Einstellungen | keine |

Elementliste

| Element | Typ | Attribute |
|---|---|---|
| BTN_REFRESH | Drucktaste | Zeile 1, Spalte 1, defLänge 4, visLänge 1, Höhe 1, Icon ICON_REFRESH (`@42@`), Quickinfo "Auffrischen", Funktionscode ZREFRESH, Funktionstyp leer |
| GO_CONT_STEPS | Custom Control | Zeile 2, Spalte 1, Länge 171, Höhe 29, Resizing vertikal und horizontal, Minimum 8 Zeilen / 59 Spalten |

![Dynpro 0100, Custom Control](images/screen_0100_custom_control.png)

![Dynpro 0100, Refresh-Button](images/screen_0100_refresh_button.png)

Ablauflogik

```abap
PROCESS BEFORE OUTPUT.
  MODULE pbo_0100.

PROCESS AFTER INPUT.
```

Es gibt kein PAI-Modul: Der Funktionscode ZREFRESH wird von der BAdI-Implementierung konsumiert
(`TRANSFER_DATA_FROM_SUBSCREEN`).

### B2. BAdI-Implementierung ZSD_APM_HEAD_TAB

1. SE19, Erweiterungsspot BADI_SD_SALES_BASIC, BAdI-Definition BADI_SLS_HEAD_SCR_CUS.
2. Erweiterungsimplementierung `ZSD_APM_HEAD_TAB`, BAdI-Implementierung `ZSD_APM_HEAD_TAB`,
   implementierende Klasse `ZCL_SD_APM_HEAD_TAB` (vorhandene Klasse aus Teil A).
3. Keine Filterwerte. Aktivieren.

### B3. Application-Log-Objekt (empfohlen)

Technische Fehler des Readers landen im Application Log. In Transaktion SLG0 anlegen:

| Objekt | Subobjekt | Text |
|---|---|---|
| ZSD_APM | WF_DISPLAY | Approval workflow display in SAP GUI |

Ohne das Objekt überspringt der Reader das Protokollieren stillschweigend; die Anzeige ist
nicht betroffen.

### B4. Workflow-Konstanten prüfen

`ZCL_SD_APM_WF_READER` ist für das SAP-Standard-Workflow-Szenario **WS02000029** (Flexible
Workflow für Gutschriftsanforderungen) ausgeliefert. SAP liefert dieses Szenario mit genau zwei
Dialogaufgaben aus, und genau diese werden hier ausgewertet:

| Konstante | Wert | Bedeutung |
|---|---|---|
| GC_TYPEID | CL_SD_CMR_WORKFLOW | Workflow-Objekttyp am Beleg (SWW_WI2OBJ) |
| GC_TASK-APPROVE | TS02000054 | Dialogaufgabe "Gutschriftsanforderung freigeben" |
| GC_TASK-REWORK | TS02000055 | Dialogaufgabe "Gutschriftsanforderung nachbearbeiten" |

Die Task-IDs vor dem Go-live im eigenen System prüfen: Transaktion SWDD, Szenario WS02000029,
oder das Workflow-Protokoll (SWI1) einer bestehenden Gutschriftsanforderung.

### B5. Kernmodul testen

1. Report `ZSD_APM_WF_DISPLAY` für eine Gutschriftsanforderung mit Workflow ausführen. Die
   Liste zeigt Läufe und Schritte. Bleibt sie leer, B4 prüfen.
2. Denselben Beleg in VA03 öffnen → Springen → Kopf. Der Reiter "Freigabe" zeigt den Baum.
3. In der Fiori-App "Mein Eingang" eine Entscheidung treffen, im Reiter den Refresh-Button drücken.
4. Doppelklick auf einen Schritt mit Notiz-Icon: Der Entscheidungskommentar öffnet sich im Popup.

## Teil C: Optionales Modul "Statusbutton"

Diesen Teil überspringen, wenn Erweiterungen von SAPMV45A im System nicht gewünscht sind. C1 und
C2 sind nur nach einer manuellen Installation (Teil A2) nötig; abapGit liefert beides mit.

Der mitgelieferte Status ZU ist eine Kopie des Status U von SAPMV45B aus S/4HANA 2023. Auf einem
anderen Release kann der Standardstatus andere Funktionen enthalten; dann den eigenen Status U
wie in C1 beschrieben kopieren und die Funktion ZWF erneut ergänzen, damit die
Drucktastenleiste zum Release passt.

### C1. GUI-Status ZU der Funktionsgruppe ZSD_APM_INFO

1. Menu Painter (SE41): Status `U` des Programms **SAPMV45B** nach Programm SAPLZSD_APM_INFO als
   Status `ZU` kopieren. Der Status muss eine Kopie bleiben, damit alle Standardfunktionen von
   VA03 weiter funktionieren; `EXCLUDING cua_exclude` im Plug-in entfernt die Funktionen, die
   SAPMV45A selbst ausschließt.
2. Funktion `ZWF` auf Funktionstaste Strg+Umsch+F11 legen und in die Drucktastenleiste aufnehmen.
3. Funktion ZWF: Funktionstexttyp "Dynamischer Text", Feldname `GS_WF_BUTTON` (Struktur
   SMP_DYNTXT im TOP-Include der Funktionsgruppe).

### C2. Source-Code-Plug-ins in SAPMV45A

Beides implizite Erweiterungen (SE38 → SAPMV45A → Erweitern → Bearbeiten → Erweiterungsoperationen →
Implizite Erweiterungsoptionen anzeigen). Quelltexte: `src/zsd_apm_wf_fcode.enho.*.abap` und
`src/zsd_apm_wf_gui_status.enho.*.abap` (die Anweisungen zwischen ENHANCEMENT und
ENDENHANCEMENT einfügen).

| Implementierung | Fundort |
|---|---|
| ZSD_APM_WF_FCODE | Include MV45AF0F_FCODE_BEARBEITEN, FORM `fcode_bearbeiten`, implizite Option am Anfang der FORM |
| ZSD_APM_WF_GUI_STATUS | Include MV45AF0C_CUA_SETZEN, FORM `cua_setzen`, implizite Option am **Ende** der FORM (`\PR:SAPMV45A\FO:CUA_SETZEN\SE:END\EI`) |

![Plug-in ZSD_APM_WF_GUI_STATUS](images/plugin_zsd_apm_wf_gui_status_location.png)

### C3. Statusbutton testen

**Der erste Aufruf nach der Aktivierung dauert länger.** Das Aktivieren der zwei Plug-ins macht
den generierten Ladelauf von SAPMV45A ungültig. Der erste Aufruf von VA01, VA02 oder VA03 danach
zeigt ein Fortschrittsfenster "Compiling SAPMV45A in separate task" und kann eine Minute oder
länger dauern, weil das Programm mit seinen mehreren hundert Includes neu generiert wird. Das
passiert einmal pro System und Mandant und erneut nach dem Import des Transports ins nächste
System. Um den ersten Anwender zu verschonen, nach dem Import einmal selbst VA03 aufrufen oder
SAPMV45A mit Transaktion SGEN neu generieren.

1. Gutschriftsanforderung in VA03 öffnen. Die Drucktastenleiste zeigt den Button "Freigabe" mit Status-Icon.
2. Mauszeiger darauf: Die Quickinfo nennt den aktuellen Genehmiger.
3. Klick: Der Reiter "Freigabe" öffnet sich.

Endet der Klick mit der Meldung "Die angeforderte Funktion ZWF ist hier nicht vorgesehen", ist
das Plug-in ZSD_APM_WF_FCODE nicht aktiv (SE19 prüfen) oder der Freigabe-Reiter ist im System
nicht der erste kundeneigene Kopfreiter. Der Button spricht den Reiter über seine Position unter
den kundeneigenen Reitern von BADI_SLS_HEAD_SCR_CUS an; Vorgabe ist 1 (Konstante
`GC_TAB_POSITION` in ZCL_SD_APM_WF_SCOPE). Registrieren andere BAdI-Implementierungen Reiter vor
diesem, die Konstante auf die tatsächliche Position setzen.

## Übersetzung

Alle Texte sind Nachrichten der Klasse ZSD_APM. Übersetzung mit Transaktion SE63 (Kurztexte →
Nachrichten). Die deutschen Texte stehen in [MESSAGES.md](MESSAGES.md).
