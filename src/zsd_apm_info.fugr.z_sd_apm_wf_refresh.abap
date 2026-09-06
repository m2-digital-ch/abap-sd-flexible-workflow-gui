FUNCTION z_sd_apm_wf_refresh.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"----------------------------------------------------------------------

  " Called by the BAdI implementation ZCL_SD_APM_HEAD_TAB during PAI when
  " the user pressed the refresh button on subscreen 0100.
  " No frontend access here: only flag the refresh, the tree is rebuilt
  " during the next PBO of the subscreen.
  lcl_tree_view=>request_refresh( ).

ENDFUNCTION.
