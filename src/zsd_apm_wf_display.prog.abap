*&---------------------------------------------------------------------*
*& Report ZSD_APM_WF_DISPLAY
*&---------------------------------------------------------------------*
*& Displays the approval workflow of one sales document (runs and their
*& steps) as a full screen ALV list, independent of VA03.
*&
*& Use it to
*& - verify the installation and the workflow constants of
*&   ZCL_SD_APM_WF_READER
*& - give support and key users a quick look at the workflow history
*&
*& The workflow is always read without cache.
*&---------------------------------------------------------------------*
REPORT zsd_apm_wf_display.

PARAMETERS p_vbeln TYPE vbeln_va OBLIGATORY.


*----------------------------------------------------------------------*
* LCL_REPORT
*----------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS run
      IMPORTING iv_vbeln TYPE vbeln_va.

  PRIVATE SECTION.
    " One ALV row: either a run (LEVEL "Run") or a step (LEVEL "Step")
    TYPES:
      BEGIN OF ty_row,
        run          TYPE i,
        level        TYPE c LENGTH 10,
        icon         TYPE icon_d,
        text         TYPE c LENGTH 60,   " run: submitter, step: work item text
        agent        TYPE c LENGTH 60,
        status_text  TYPE c LENGTH 30,
        decision     TYPE c LENGTH 30,
        has_note     TYPE abap_bool,
        created_on   TYPE d,
        created_at   TYPE t,
        completed_on TYPE d,
        completed_at TYPE t,
        wi_id        TYPE sww_wiid,
        task         TYPE sww_task,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    CONSTANTS gc_msgid TYPE symsgid VALUE 'ZSD_APM'.

    " Message numbers of ZSD_APM that are read as texts (message 001 is
    " issued directly)
    CONSTANTS:
      BEGIN OF gc_msg,
        col_agent        TYPE symsgno VALUE '030',
        col_status       TYPE symsgno VALUE '031',
        col_decision     TYPE symsgno VALUE '032',
        col_note         TYPE symsgno VALUE '033',
        col_created      TYPE symsgno VALUE '034',
        col_completed    TYPE symsgno VALUE '035',
        run              TYPE symsgno VALUE '060',
        step             TYPE symsgno VALUE '061',
        col_level        TYPE symsgno VALUE '062',
        col_text         TYPE symsgno VALUE '063',
        col_work_item    TYPE symsgno VALUE '064',
        col_task         TYPE symsgno VALUE '065',
        hdr_document     TYPE symsgno VALUE '066',
        hdr_status       TYPE symsgno VALUE '067',
        hdr_reason       TYPE symsgno VALUE '068',
        hdr_current_step TYPE symsgno VALUE '069',
        hdr_approver     TYPE symsgno VALUE '070',
        hdr_runs         TYPE symsgno VALUE '071',
        hdr_read_at      TYPE symsgno VALUE '072',
      END OF gc_msg.

    " The ALV keeps a reference to this table, therefore class data.
    CLASS-DATA gt_rows TYPE ty_rows.

    CLASS-METHODS build_rows
      IMPORTING is_info        TYPE zcl_sd_apm_wf_reader=>ty_info
      RETURNING VALUE(rt_rows) TYPE ty_rows.

    CLASS-METHODS build_header
      IMPORTING is_info          TYPE zcl_sd_apm_wf_reader=>ty_info
      RETURNING VALUE(ro_header) TYPE REF TO cl_salv_form_layout_grid.

    CLASS-METHODS display
      IMPORTING is_info TYPE zcl_sd_apm_wf_reader=>ty_info
      RAISING   cx_salv_error.

    CLASS-METHODS set_column_text
      IMPORTING io_columns TYPE REF TO cl_salv_columns_table
                iv_name    TYPE lvc_fname
                iv_msgno   TYPE symsgno
      RAISING   cx_salv_not_found.

    CLASS-METHODS text
      IMPORTING iv_msgno       TYPE symsgno
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.


CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    DATA(ls_info) = zcl_sd_apm_wf_reader=>get_info( iv_vbeln    = iv_vbeln
                                                    iv_no_cache = abap_true ).

    IF ls_info-wf_found = abap_false.
      MESSAGE s001(zsd_apm) DISPLAY LIKE 'W'.
    ENDIF.

    gt_rows = build_rows( ls_info ).

    TRY.
        display( ls_info ).
      CATCH cx_salv_error INTO DATA(lx_salv).
        DATA(lv_message) = lx_salv->get_text( ).
        MESSAGE lv_message TYPE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD build_rows.
    LOOP AT is_info-runs INTO DATA(ls_run).
      APPEND VALUE #( run          = ls_run-run
                      level        = text( gc_msg-run )
                      icon         = ls_run-icon
                      text         = ls_run-submitter
                      status_text  = ls_run-status_text
                      decision     = ls_run-result_text
                      created_on   = ls_run-started_on
                      created_at   = ls_run-started_at
                      completed_on = ls_run-ended_on
                      completed_at = ls_run-ended_at ) TO rt_rows.

      LOOP AT is_info-steps INTO DATA(ls_step) WHERE run = ls_run-run.
        APPEND VALUE #( run          = ls_step-run
                        level        = text( gc_msg-step )
                        icon         = ls_step-icon
                        text         = ls_step-step_text
                        agent        = ls_step-agent
                        status_text  = ls_step-status_text
                        decision     = ls_step-decision_text
                        has_note     = ls_step-has_note
                        created_on   = ls_step-created_on
                        created_at   = ls_step-created_at
                        completed_on = ls_step-completed_on
                        completed_at = ls_step-completed_at
                        wi_id        = ls_step-wi_id
                        task         = ls_step-task ) TO rt_rows.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD build_header.
    ro_header = NEW cl_salv_form_layout_grid( ).

    ro_header->create_label( row = 1 column = 1 text = text( gc_msg-hdr_document ) ).
    ro_header->create_text( row = 1 column = 2 text = |{ is_info-vbeln ALPHA = OUT }| ).

    ro_header->create_label( row = 2 column = 1 text = text( gc_msg-hdr_status ) ).
    ro_header->create_text( row    = 2
                            column = 2
                            text   = |{ is_info-approval_status } { is_info-approval_status_text }| ).

    ro_header->create_label( row = 3 column = 1 text = text( gc_msg-hdr_reason ) ).
    ro_header->create_text( row    = 3
                            column = 2
                            text   = |{ is_info-approval_reason } { is_info-approval_reason_text }| ).

    ro_header->create_label( row = 4 column = 1 text = text( gc_msg-hdr_runs ) ).
    ro_header->create_text( row = 4 column = 2 text = |{ lines( is_info-runs ) }| ).

    ro_header->create_label( row = 5 column = 1 text = text( gc_msg-hdr_current_step ) ).
    ro_header->create_text( row = 5 column = 2 text = is_info-current_step ).

    ro_header->create_label( row = 6 column = 1 text = text( gc_msg-hdr_approver ) ).
    ro_header->create_text( row = 6 column = 2 text = is_info-current_approver ).

    ro_header->create_label( row = 7 column = 1 text = text( gc_msg-hdr_read_at ) ).
    ro_header->create_text( row    = 7
                            column = 2
                            text   = |{ is_info-read_on_date DATE = USER } { is_info-read_on_time TIME = USER }| ).
  ENDMETHOD.


  METHOD display.
    cl_salv_table=>factory(
      IMPORTING
        r_salv_table = DATA(lo_alv)
      CHANGING
        t_table      = gt_rows ).

    lo_alv->get_functions( )->set_all( ).
    lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).

    DATA(lo_columns) = lo_alv->get_columns( ).
    lo_columns->set_optimize( ).

    set_column_text( io_columns = lo_columns iv_name = 'RUN'          iv_msgno = gc_msg-run ).
    set_column_text( io_columns = lo_columns iv_name = 'LEVEL'        iv_msgno = gc_msg-col_level ).
    set_column_text( io_columns = lo_columns iv_name = 'TEXT'         iv_msgno = gc_msg-col_text ).
    set_column_text( io_columns = lo_columns iv_name = 'AGENT'        iv_msgno = gc_msg-col_agent ).
    set_column_text( io_columns = lo_columns iv_name = 'STATUS_TEXT'  iv_msgno = gc_msg-col_status ).
    set_column_text( io_columns = lo_columns iv_name = 'DECISION'     iv_msgno = gc_msg-col_decision ).
    set_column_text( io_columns = lo_columns iv_name = 'HAS_NOTE'     iv_msgno = gc_msg-col_note ).
    set_column_text( io_columns = lo_columns iv_name = 'CREATED_ON'   iv_msgno = gc_msg-col_created ).
    set_column_text( io_columns = lo_columns iv_name = 'COMPLETED_ON' iv_msgno = gc_msg-col_completed ).
    set_column_text( io_columns = lo_columns iv_name = 'WI_ID'        iv_msgno = gc_msg-col_work_item ).
    set_column_text( io_columns = lo_columns iv_name = 'TASK'         iv_msgno = gc_msg-col_task ).

    DATA(lo_icon) = CAST cl_salv_column_table( lo_columns->get_column( 'ICON' ) ).
    lo_icon->set_icon( abap_true ).
    lo_icon->set_short_text( '' ).
    lo_icon->set_medium_text( '' ).
    lo_icon->set_long_text( '' ).

    CAST cl_salv_column_table( lo_columns->get_column( 'HAS_NOTE' )
      )->set_cell_type( if_salv_c_cell_type=>checkbox ).

    lo_alv->set_top_of_list( build_header( is_info ) ).

    lo_alv->display( ).
  ENDMETHOD.


  METHOD set_column_text.
    DATA(lo_column) = io_columns->get_column( iv_name ).
    DATA(lv_text)   = text( iv_msgno ).

    lo_column->set_short_text( CONV #( lv_text ) ).
    lo_column->set_medium_text( CONV #( lv_text ) ).
    lo_column->set_long_text( CONV #( lv_text ) ).
  ENDMETHOD.


  METHOD text.
    MESSAGE ID gc_msgid TYPE 'I' NUMBER iv_msgno INTO rv_text.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  lcl_report=>run( p_vbeln ).
