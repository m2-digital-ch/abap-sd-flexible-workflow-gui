"! Stub of the SAP standard BAdI interface IF_EX_SLS_HEAD_SCR_CUS.
"! Only used by abaplint in the CI pipeline, because the interface is not
"! part of the public abaplint dependency repository. Never install this
"! file in an SAP system.
INTERFACE if_ex_sls_head_scr_cus PUBLIC.

  INTERFACES if_badi_interface.

  METHODS activate_tab_page
    IMPORTING is_vbak         TYPE vbak
    CHANGING  ct_cus_head_tab TYPE sales_cust_tab_page_t.

  METHODS transfer_data_to_subscreen
    IMPORTING is_vbkd         TYPE vbkd OPTIONAL
              is_t180         TYPE t180
              is_rv45a        TYPE rv45a
              is_vbak         TYPE vbak
              is_cus_head_tab TYPE sales_cust_tab_page OPTIONAL.

  METHODS transfer_data_from_subscreen
    IMPORTING is_t180         TYPE t180
              is_cus_head_tab TYPE sales_cust_tab_page OPTIONAL
    EXPORTING ev_dataloss     TYPE dialog
    CHANGING  cs_vbkd         TYPE vbkd OPTIONAL
              cs_rv45a        TYPE rv45a
              cs_vbak         TYPE vbak
              cv_fcode        TYPE fcode.

  METHODS pass_fcode_to_subscreen
    IMPORTING iv_fcode_same_page TYPE fcode
              iv_fcode           TYPE fcode
              is_cus_head_tab    TYPE sales_cust_tab_page OPTIONAL.

ENDINTERFACE.
