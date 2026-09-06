# Enhancement implementations

The BAdI implementation (core module) and the two source code plug-ins in SAPMV45A (optional
module "status button") are delivered as abapGit objects in `/src/`; this folder only documents
them:

| File(s) | Object | Module |
|---|---|---|
| `zsd_apm_head_tab.enho.xml` | BAdI implementation ZSD_APM_HEAD_TAB (BADI_SLS_HEAD_SCR_CUS) | core |
| `zsd_apm_wf_fcode.enho.xml`, `zsd_apm_wf_fcode.enho.f213fd76.abap` | Plug-in at the beginning of FORM `fcode_bearbeiten` (MV45AF0F_FCODE_BEARBEITEN) | status button |
| `zsd_apm_wf_gui_status.enho.xml`, `zsd_apm_wf_gui_status.enho.d3f1fe05.abap` | Plug-in at the end of FORM `cua_setzen` (MV45AF0C_CUA_SETZEN) | status button |

With abapGit the objects are created on pull. Companies that do not want to enhance SAPMV45A
simply **uncheck ZSD_APM_WF_FCODE and ZSD_APM_WF_GUI_STATUS in the pull dialog**; the header tab
(core module) works without them, users open it through the header detail of the document.

For manual installation the `*.abap` files above contain the source of each plug-in; see
`docs/INSTALLATION.md`, part C.

Both plug-ins are guarded by `zcl_sd_apm_wf_scope=>is_relevant( )`, so they have no effect
outside VA03 and outside the configured document categories.
