FUNCTION z_sd_apm_wf_button_prepare.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_VBELN) TYPE  VBELN_VA
*"----------------------------------------------------------------------

  " Called by the source code plug-in ZSD_APM_WF_GUI_STATUS in SAPMV45A
  " right before SET PF-STATUS 'ZU' so that the dynamic text of function
  " ZWF (icon and quick info) reflects the current approval status.
  gs_wf_button = lcl_status_button=>prepare( iv_vbeln ).

ENDFUNCTION.
