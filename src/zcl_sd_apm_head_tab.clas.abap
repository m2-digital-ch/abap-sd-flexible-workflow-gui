"! <p class="shorttext">BAdI BADI_SLS_HEAD_SCR_CUS: header tab "Approval" in VA03</p>
"! Implementing class of the enhancement implementation ZSD_APM_HEAD_TAB
"! (enhancement spot BADI_SD_SALES_BASIC, BAdI BADI_SLS_HEAD_SCR_CUS).
"! <ul>
"! <li>Registers subscreen 0100 of function group ZSD_APM_INFO as an
"! additional header tab for the documents in scope, see
"! {@link zcl_sd_apm_wf_scope}.</li>
"! <li>Provides the current document number to the subscreen.</li>
"! <li>Consumes the refresh function code of the subscreen before the SD
"! screen sequence control (table T185) processes it.</li>
"! </ul>
CLASS zcl_sd_apm_head_tab DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_badi_interface.
    INTERFACES if_ex_sls_head_scr_cus.

    "! Program that owns the subscreen of the header tab
    CONSTANTS gc_tab_program TYPE syrepid VALUE 'SAPLZSD_APM_INFO'.
    "! Subscreen number of the header tab
    CONSTANTS gc_tab_dynpro TYPE sydynnr VALUE '0100'.

    "! Sales document currently displayed in VA03.
    "! Initial if the document is not in scope.
    CLASS-METHODS get_current_vbeln
      RETURNING VALUE(rv_vbeln) TYPE vbeln_va.

    "! Function code (K_CUS_BADI_n) that navigates to the approval tab.
    "! As long as the tab has not been registered in the current session
    "! (the BAdI runs when the header detail is built, not on the overview
    "! screen), the configured position from ZCL_SD_APM_WF_SCOPE is used.
    CLASS-METHODS get_tab_fcode
      RETURNING VALUE(rv_fcode) TYPE fcode.

  PRIVATE SECTION.
    CLASS-DATA gv_current_vbeln TYPE vbeln_va.
    CLASS-DATA gv_tab_fcode     TYPE fcode.

ENDCLASS.


CLASS zcl_sd_apm_head_tab IMPLEMENTATION.

  METHOD get_current_vbeln.
    rv_vbeln = gv_current_vbeln.
  ENDMETHOD.


  METHOD get_tab_fcode.
    IF gv_tab_fcode IS NOT INITIAL.
      rv_fcode = gv_tab_fcode.
    ELSE.
      rv_fcode = |{ zcl_sd_apm_wf_scope=>gc_fcode_tab_prefix }{ zcl_sd_apm_wf_scope=>gc_tab_position }|.
    ENDIF.
  ENDMETHOD.


  METHOD if_ex_sls_head_scr_cus~activate_tab_page.
    IF zcl_sd_apm_wf_scope=>is_relevant( is_vbak ) = abap_false.
      CLEAR gv_current_vbeln.
      RETURN.
    ENDIF.

    gv_current_vbeln = is_vbak-vbeln.

    " The method may be called more than once per document.
    " Register the tab only once and remember its position.
    DATA(lv_index) = line_index( ct_cus_head_tab[ head_program = gc_tab_program
                                                  head_dynpro  = gc_tab_dynpro ] ).
    IF lv_index = 0.
      MESSAGE i020(zsd_apm) INTO DATA(lv_caption).

      APPEND VALUE #( head_caption = lv_caption
                      head_program = gc_tab_program
                      head_dynpro  = gc_tab_dynpro ) TO ct_cus_head_tab.

      lv_index = lines( ct_cus_head_tab ).
    ENDIF.

    " SAPMV45A addresses custom header tabs by their position in
    " CT_CUS_HEAD_TAB (K_CUS_BADI_1, K_CUS_BADI_2, ...). The source code
    " plug-in ZSD_APM_WF_FCODE uses this value to jump to the tab; the
    " real position overrides the configured default from now on.
    gv_tab_fcode = |{ zcl_sd_apm_wf_scope=>gc_fcode_tab_prefix }{ lv_index }|.
  ENDMETHOD.


  METHOD if_ex_sls_head_scr_cus~transfer_data_to_subscreen.
    " Use the document data officially handed over by the BAdI as the
    " context for the PBO of subscreen 0100.
    gv_current_vbeln = is_vbak-vbeln.
  ENDMETHOD.


  METHOD if_ex_sls_head_scr_cus~transfer_data_from_subscreen.
    " Consume the refresh function code of the subscreen before the SD
    " screen sequence control (T185) sees it. This runs during PAI, so the
    " frontend must not be touched here: the function module only flags the
    " refresh and the tree is rebuilt during the next PBO.
    IF cv_fcode = zcl_sd_apm_wf_scope=>gc_fcode_refresh.
      CALL FUNCTION 'Z_SD_APM_WF_REFRESH'.
      cv_fcode = zcl_sd_apm_wf_scope=>gc_fcode_enter.
    ENDIF.
  ENDMETHOD.


  METHOD if_ex_sls_head_scr_cus~pass_fcode_to_subscreen.
    " Nothing to do: subscreen 0100 has no PAI logic of its own.
  ENDMETHOD.

ENDCLASS.
