"Name: \PR:SAPMV45A\FO:CUA_SETZEN\SE:END\EI
ENHANCEMENT 0 ZSD_APM_WF_GUI_STATUS.
  " Optional module "status button" (see docs/INSTALLATION.md, part C).
  " Replaces the standard overview status U of SAPMV45B by its copy ZU in
  " function group ZSD_APM_INFO, which additionally carries the approval
  " status button (function ZWF with dynamic text <GS_WF_BUTTON>). The
  " dynamic text is filled by Z_SD_APM_WF_BUTTON_PREPARE right before the
  " status is set. Only the overview status of the display transaction
  " is replaced.
  IF t185v-status = 'U'
     AND modul-pool = 'SAPMV45B'
     AND t180-trtyp = chara
     AND zcl_sd_apm_wf_scope=>is_relevant( vbak ) = abap_true.

    CALL FUNCTION 'Z_SD_APM_WF_BUTTON_PREPARE'
      EXPORTING
        iv_vbeln = vbak-vbeln.

    SET PF-STATUS 'ZU'
        EXCLUDING cua_exclude
        OF PROGRAM 'SAPLZSD_APM_INFO'.

  ENDIF.
ENDENHANCEMENT.
