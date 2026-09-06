"! <p class="shorttext">Scope of the approval status GUI integration</p>
"! Central place that decides for which transaction and sales document
"! categories the approval status button and the "Approval" header tab are
"! shown in SAP GUI.
"! <p>All other components (BAdI implementation, source code plug-ins in
"! SAPMV45A, function group ZSD_APM_INFO) delegate to this class so that the
"! scope is defined exactly once.</p>
CLASS zcl_sd_apm_wf_scope DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Function code of the approval status button (GUI status ZU, function ZWF).
    "! Used by the source code plug-in ZSD_APM_WF_FCODE in SAPMV45A.
    CONSTANTS gc_fcode_status_button TYPE fcode VALUE 'ZWF' ##NEEDED.
    "! Function code of the refresh button on subscreen 0100
    CONSTANTS gc_fcode_refresh TYPE fcode VALUE 'ZREFRESH'.
    "! Function code that SAPMV45A treats as plain "Enter"
    CONSTANTS gc_fcode_enter TYPE fcode VALUE 'ENT1'.
    "! Prefix of the function codes SAPMV45A uses to navigate to the n-th
    "! custom header tab registered via BADI_SLS_HEAD_SCR_CUS (K_CUS_BADI_n)
    CONSTANTS gc_fcode_tab_prefix TYPE string VALUE 'K_CUS_BADI_'.
    "! Position of the approval tab among the custom header tabs.
    "! Used by the status button before the BAdI has registered the tab
    "! (the overview screen is shown first, the header tabs are built
    "! later). Adjust when other implementations of BADI_SLS_HEAD_SCR_CUS
    "! register tabs before this one.
    CONSTANTS gc_tab_position TYPE i VALUE 1.
    "! Transaction in which the integration is active
    CONSTANTS gc_tcode_display TYPE sytcode VALUE 'VA03'.

    "! Checks whether the approval status integration applies to the given
    "! sales document in the current transaction.
    "! @parameter is_vbak | Sales document header as available in SAPMV45A
    "! @parameter rv_relevant | abap_true if button and tab shall be shown
    CLASS-METHODS is_relevant
      IMPORTING is_vbak            TYPE vbak
      RETURNING VALUE(rv_relevant) TYPE abap_bool.

  PRIVATE SECTION.
    TYPES ty_doc_categories TYPE RANGE OF vbak-vbtyp.

    "! Sales document categories that are covered by the integration
    CLASS-METHODS get_doc_categories
      RETURNING VALUE(rt_categories) TYPE ty_doc_categories.

ENDCLASS.


CLASS zcl_sd_apm_wf_scope IMPLEMENTATION.

  METHOD is_relevant.
    DATA(lt_categories) = get_doc_categories( ).

    rv_relevant = xsdbool( sy-tcode = gc_tcode_display
                       AND is_vbak-vbtyp IN lt_categories ).
  ENDMETHOD.


  METHOD get_doc_categories.
    " Document categories for which SAP provides a flexible workflow.
    " Extend this list (or replace it by a customizing table) when further
    " categories such as sales orders shall be covered.
    rt_categories = VALUE #( sign   = 'I'
                             option = 'EQ'
                             ( low = if_sd_doc_category=>credit_memo_req ) ).
  ENDMETHOD.

ENDCLASS.
