# Architecture

Deutsche Version: [ARCHITECTURE.de.md](ARCHITECTURE.de.md)

The solution has a **core module** (header tab, BAdI based, no change to the SAP standard) and
an **optional module** (status button, based on two implicit enhancements in SAPMV45A).

## Core module: the header tab

```
BADI_SLS_HEAD_SCR_CUS (enhancement spot BADI_SD_SALES_BASIC)
  implementation ZSD_APM_HEAD_TAB → class ZCL_SD_APM_HEAD_TAB
    ├─ ACTIVATE_TAB_PAGE            registers subscreen SAPLZSD_APM_INFO 0100, caption from message 020,
    │                               remembers the K_CUS_BADI_n function code of the tab
    ├─ TRANSFER_DATA_TO_SUBSCREEN   remembers VBELN (context for the PBO of the subscreen)
    ├─ TRANSFER_DATA_FROM_SUBSCREEN consumes ZREFRESH → Z_SD_APM_WF_REFRESH, replaces it by ENT1
    └─ PASS_FCODE_TO_SUBSCREEN      empty
```

The tab only appears when `ZCL_SD_APM_WF_SCOPE=>IS_RELEVANT` agrees (transaction VA03, document
category credit memo request). Users reach it via Goto → Header.

### Subscreen 0100 (function group ZSD_APM_INFO)

- push button BTN_REFRESH (ICON_REFRESH, function code ZREFRESH), row 1
- custom control GO_CONT_STEPS, row 2, resizable
- PBO module `pbo_0100` → `LCL_TREE_VIEW=>PROCESS_BEFORE_OUTPUT`
  1. VBELN from `ZCL_SD_APM_HEAD_TAB=>GET_CURRENT_VBELN`
  2. check whether the frontend container still exists (`IS_VALID`), otherwise drop the ABAP references
  3. `ZCL_SD_APM_WF_READER=>GET_INFO` (without cache after a manual refresh)
  4. rebuild when: first display, other document, manual refresh, or the reader delivered fresh data
  5. free the container and build the SALV tree from scratch (an incremental refresh proved unstable
     inside the embedded VA03 subscreen)

### SALV tree

- level 1: one node per workflow run ("Run n - submitter") with status, result and time stamps
- level 2: one node per step ("Approval" or "Rework") with processor, status, decision, note icon
  and time stamps; open steps are emphasized; only the latest run is expanded
- double-click on a step with a note icon opens the note as HTML popup (`CL_ABAP_BROWSER`)

### Reading a note

1. `SAP_WAPI_GET_ATTACHMENTS`, first only decision comments (`COMMENT_SEMANTIC_ONLY`), otherwise all attachments
2. attachments are inherited along the workflow: the attachments of the predecessor step in the same run
   are removed, what remains was entered at this step (safety net: all attachments if nothing remains)
3. SOFM key from the BOR object key (offset 20, 34 characters) → `SO_DOCUMENT_READ_API1`
4. render escaped HTML and show it modally

### Refresh cycle

PAI must not touch the frontend controls. Therefore:

```
PAI: ZREFRESH → BAdI consumes it → Z_SD_APM_WF_REFRESH sets a flag → fcode becomes ENT1
PBO: flag set → reader without cache → container free + flush → tree rebuilt
```

## Optional module: the status button

```
SAPMV45A sets the GUI status of the overview screen (FORM cua_setzen)
  └─ plug-in ZSD_APM_WF_GUI_STATUS (implicit enhancement at the end of the FORM)
       ├─ only VA03 in display mode and only documents in scope
       │  (ZCL_SD_APM_WF_SCOPE=>IS_RELEVANT)
       ├─ CALL FUNCTION 'Z_SD_APM_WF_BUTTON_PREPARE'
       │    → LCL_STATUS_BUTTON=>PREPARE fills GS_WF_BUTTON (icon, text, quick info)
       └─ SET PF-STATUS 'ZU' EXCLUDING cua_exclude OF PROGRAM 'SAPLZSD_APM_INFO'
            ZU = copy of SAPMV45B status U + function ZWF with dynamic text <GS_WF_BUTTON>
```

A dynamic text of a GUI status must be a global variable of the program that owns the status.
That is why `GS_WF_BUTTON` lives in the TOP include of function group ZSD_APM_INFO and is filled
through a function module.

| Situation of the latest run | Icon | Quick info (message) |
|---|---|---|
| no workflow | ICON_LED_INACTIVE | 001 |
| running, open rework step | ICON_SYSTEM_UNDO | 013 |
| running, approver known | ICON_TIME | 012 with name |
| running, approver unknown | ICON_TIME | 011 |
| completed, approved | ICON_OKAY | 014 |
| completed, rejected | ICON_CANCEL | 015 |
| cancelled | ICON_LED_INACTIVE | 016 |
| other | ICON_LED_INACTIVE | 010 |

Clicking the button:

```
user presses ZWF
  └─ FORM fcode_bearbeiten (MV45AF0F_FCODE_BEARBEITEN)
       └─ plug-in ZSD_APM_WF_FCODE: fcode 'ZWF' → ZCL_SD_APM_HEAD_TAB=>GET_TAB_FCODE( )
            (K_CUS_BADI_n, n = position of the tab in CT_CUS_HEAD_TAB, standard navigation)
```

## Data source: ZCL_SD_APM_WF_READER

There are no customer tables. Everything is read at runtime by `ZCL_SD_APM_WF_READER=>GET_INFO`.
The reader caches the result per document for 60 seconds because the status button is prepared
on every PBO of VA03; a manual refresh bypasses the cache.

Reading steps (method `READ_WORKFLOW`):

1. **Runs**: top level flow items linked to the document in SWW_WI2OBJ (category CL, type
   CL_SD_CMR_WORKFLOW, instance = document number) joined with SWWWIHEAD, oldest first.
2. **Steps**: dependent dialog work items of each run (`SAP_WAPI_GET_DEPENDENT_WIS`), filtered to
   the approval task TS02000054 and the rework task TS02000055 of the SAP standard scenario
   WS02000029. Per step
   `SAP_WAPI_GET_WORKITEM_DETAIL` delivers status, agent, time stamps and the work item result.
3. **Decision** of a completed step: work item result, otherwise container element `_WI_RESULT`
   (`SAP_WAPI_READ_CONTAINER`), otherwise inferred from the following step in the same run
   (a rework step after an approval step means "sent back for rework", any later step after a
   rework step means "resubmitted").
4. **Agent** of an open step: actual agent of a reserved or started work item, otherwise the
   recipients (`SAP_WAPI_WORKITEM_RECIPIENTS`), resolved to display names via
   `BAPI_USER_GET_DETAIL`.
5. **Withdrawn rework steps** (cancelled rework work item followed by another step) are shown as
   "resubmitted"; the user who changed the document in between (change documents VERKBELEG) is
   shown as agent.
6. **Notes**: SOFM relations of the work items in SWW_WI2OBJ. Because the workflow passes notes on
   to follow-up work items, only the work item with the smallest id per note gets the flag.
7. **Runs are summarized**: status from the flow item, result from the last completed approval
   step, submitter from the workflow header (fallback: document creator for run 1, change
   document user for later runs).

Header information from VBAK (approval status and reason with their texts) is read as well and
is available to callers that need it.

Technical errors are logged to the application log (object ZSD_APM, subobject WF_DISPLAY) once
per session and error, saved on a secondary DB connection so that no COMMIT WORK is triggered in
the VA03 LUW.

Places to extend for other document categories: `GC_TYPEID`, `GC_TASK` and `GC_RESULT_KEY` in
the reader, `GET_DOC_CATEGORIES` in the scope class.

## Design decisions

- **One scope definition.** Transaction and document categories are checked in
  `ZCL_SD_APM_WF_SCOPE` only. The BAdI implementation and both plug-ins call it.
- **No language dependent comparisons.** Run status, step decision and run result are constants
  of the reader (`GC_RUN_STATUS`, `GC_DECISION`), texts are only used for display.
- **Translatable texts.** Every UI text is a message of class ZSD_APM.
- **Local classes instead of FORM routines** in the function group; the function modules are thin
  wrappers that exist only because SAPMV45A and the BAdI need a callable interface into the
  function group.
- **Core and status button are separated.** The core works without touching SAPMV45A; the
  button is an add-on for companies that want the convenience and accept implicit enhancements.
- **Report ZSD_APM_WF_DISPLAY** shows the reader result as a full screen ALV list (no popup), so
  the installation can be verified without VA03 and support can look at a document quickly.
