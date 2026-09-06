FUNCTION-POOL zsd_apm_info MESSAGE-ID zsd_apm.

*----------------------------------------------------------------------*
* Function group ZSD_APM_INFO
* Flexible workflow approval status in SAP GUI (VA03)
*
* The function group owns
* - subscreen 0100: header tab "Approval" (SALV tree of workflow runs
*   and steps), registered in VA03 via BADI_SLS_HEAD_SCR_CUS
*   (core module)
* - GUI status ZU: copy of the VA03 overview status extended by the
*   approval status button (function ZWF with dynamic text)
*   (optional module "status button", needs the source code plug-ins
*   in SAPMV45A; without it users reach the tab via the header detail)
* - the function modules that the source code plug-ins in SAPMV45A
*   and the BAdI implementation ZCL_SD_APM_HEAD_TAB call
*
* The logic lives in local classes (include LZSD_APM_INFOD01 / P01):
* - LCL_TEXT           UI texts from message class ZSD_APM
* - LCL_STATUS_BUTTON  icon and quick info of the status button
* - LCL_TREE_VIEW      SALV tree on subscreen 0100 incl. note popup
*----------------------------------------------------------------------*

* Dynamic text of function ZWF in GUI status ZU.
* SAPMV45A sets the status with
*   SET PF-STATUS 'ZU' EXCLUDING ... OF PROGRAM 'SAPLZSD_APM_INFO'
* so the dynamic text has to be a global variable of this program.
DATA gs_wf_button TYPE smp_dyntxt.

* Local class definitions have to be known before the function modules
* (include LZSD_APM_INFOUXX) that use them.
INCLUDE lzsd_apm_infod01.
