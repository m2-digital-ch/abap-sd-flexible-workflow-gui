"Name: \PR:SAPMV45A\FO:FCODE_BEARBEITEN\SE:BEGIN\EI
ENHANCEMENT 0 ZSD_APM_WF_FCODE.
  " Optional module "status button" (see docs/INSTALLATION.md, part C).
  " The approval status button (function ZWF of GUI status ZU) navigates
  " to the custom header tab that ZCL_SD_APM_HEAD_TAB registers via
  " BADI_SLS_HEAD_SCR_CUS. SAPMV45A addresses custom tabs with
  " K_CUS_BADI_n; the position comes from ZCL_SD_APM_WF_SCOPE until the
  " BAdI has registered the tab and knows the real one.
  IF fcode = zcl_sd_apm_wf_scope=>gc_fcode_status_button
     AND zcl_sd_apm_wf_scope=>is_relevant( vbak ) = abap_true.

    fcode = zcl_sd_apm_head_tab=>get_tab_fcode( ).

  ENDIF.
ENDENHANCEMENT.
