# Message class ZSD_APM

Main language: German (delivered in `src/zsd_apm.msag.xml`). English is the translation; enter
it with transaction SE63 or, when installing manually, log on in English and maintain the texts
as translation.

| No. | Used for | English | Deutsch |
|---|---|---|---|
| 000 | generic | &1&2&3&4 | &1&2&3&4 |
| 001 | tree, button quick info | No approval workflow exists for this document | Kein Freigabe-Workflow vorhanden |
| 002 | note popup | No note exists for this approval step | Keine Notiz zum Schritt vorhanden |
| 003 | note popup | The note could not be read | Notiz konnte nicht gelesen werden |
| 004 | subscreen | The approval steps cannot be displayed (control error) | Die Freigabeschritte können nicht angezeigt werden (Control-Fehler) |
| 010 | button quick info | Approval status - click for details | Freigabestatus - Klick für Details |
| 011 | button quick info | Approval pending - click for details | Freigabe offen - Klick für Details |
| 012 | button quick info | Approval pending with &1 - click for details | Freigabe offen bei &1 - Klick für Details |
| 013 | button quick info | Rework pending - click for details | Nachbearbeitung offen - Klick für Details |
| 014 | button quick info | Approved - click for details | Freigabe genehmigt - Klick für Details |
| 015 | button quick info | Rejected - click for details | Freigabe abgelehnt - Klick für Details |
| 016 | button quick info | Approval cancelled - click for details | Freigabe abgebrochen - Klick für Details |
| 020 | tab caption, button text | Approval | Freigabe |
| 021 | tree header | Approval - status as of &1 &2 | Freigabe - Stand &1 &2 |
| 022 | run node, note popup | Run &1 - &2 | Lauf &1 - &2 |
| 023 | step node | Approval | Freigabe |
| 024 | step node | Rework | Nachbearbeitung |
| 025 | note popup title | Note for approval step | Notiz zum Genehmigungsschritt |
| 030 | column | Processor | Bearbeiter |
| 031 | column | Status | Status |
| 032 | column | Decision | Entscheid |
| 033 | column | Note | Notiz |
| 034 | column | Created | Angelegt |
| 035 | column | Completed | Erledigt |
| 036 | column tooltip | Note / comment of the step (double-click to open) | Notiz / Kommentar zum Schritt (Doppelklick öffnet) |
| 040 | work item status READY | Open | Offen |
| 041 | work item status SELECTED | Reserved | Reserviert |
| 042 | work item status STARTED | In process | In Bearbeitung |
| 043 | work item status COMPLETED, run status | Completed | Erledigt |
| 044 | work item status CANCELLED, run status | Cancelled | Abgebrochen |
| 045 | work item status ERROR | Error | Fehler |
| 046 | work item status WAITING | Waiting | Wartet |
| 047 | open rework step, reserved or started | In rework | In Nachbearbeitung |
| 048 | open rework step, ready | Rework open | Nachbearbeitung offen |
| 050 | run status | Running | Läuft |
| 051 | decision | Approved | genehmigt |
| 052 | decision | Rejected | abgelehnt |
| 053 | decision | Sent back for rework | zur Nachbearbeitung |
| 054 | decision | Resubmitted | neu eingereicht |
| 060 | report: level / column | Run | Lauf |
| 061 | report: level | Step | Schritt |
| 062 | report: column | Level | Ebene |
| 063 | report: column | Submitter / step | Einreicher / Schritt |
| 064 | report: column | Work item | Workitem |
| 065 | report: column | Task | Aufgabe |
| 066 | report: header | Sales document | Verkaufsbeleg |
| 067 | report: header | Approval status | Genehmigungsstatus |
| 068 | report: header | Approval reason | Genehmigungsgrund |
| 069 | report: header | Current step | Aktueller Schritt |
| 070 | report: header | Current approver | Aktueller Genehmiger |
| 071 | report: header | Workflow runs | Workflow-Läufe |
| 072 | report: header | Read at | Gelesen am |

Messages that are read as texts are referenced by name: `LCL_TEXT=>GC_MSG` (include
LZSD_APM_INFOD01, messages 001 and 010 to 036), `ZCL_SD_APM_WF_READER=>GC_MSG` (messages 040 to
054) and `LCL_REPORT=>GC_MSG` in report ZSD_APM_WF_DISPLAY (messages 030 to 035 and 060 to 072).
Messages 001 to 004 and 020 are also issued or read directly with `MESSAGE` statements (report,
subscreen and BAdI class).

When installing manually (SE91), create all messages of this table with the German text while
logged on in German; the English column is the translation for SE63.
