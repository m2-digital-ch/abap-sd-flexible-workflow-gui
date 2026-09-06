*----------------------------------------------------------------------*
* LZSD_APM_INFOO01 - PBO modules
*----------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Module PBO_0100 OUTPUT
*&---------------------------------------------------------------------*
*& Subscreen 0100 is embedded in the VA03 header tab strip via
*& BADI_SLS_HEAD_SCR_CUS. The document context is provided by the BAdI
*& implementation ZCL_SD_APM_HEAD_TAB.
*&---------------------------------------------------------------------*
MODULE pbo_0100 OUTPUT.
  lcl_tree_view=>process_before_output( zcl_sd_apm_head_tab=>get_current_vbeln( ) ).
ENDMODULE.
