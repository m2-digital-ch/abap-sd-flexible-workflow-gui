*----------------------------------------------------------------------*
* LZSD_APM_INFOP01 - local class implementations
* Definitions: LZSD_APM_INFOD01
*----------------------------------------------------------------------*

CLASS lcl_text IMPLEMENTATION.

  METHOD get.
    MESSAGE ID gc_msgid TYPE 'I' NUMBER iv_msgno
            WITH iv_v1 iv_v2 INTO rv_text.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_status_button IMPLEMENTATION.

  METHOD prepare.
    " TEXT has to be filled even though an icon is shown, otherwise the
    " function is not rendered in the toolbar.
    rs_button-text      = lcl_text=>get( lcl_text=>gc_msg-approval ).
    rs_button-icon_id   = icon_led_inactive.
    rs_button-quickinfo = lcl_text=>get( lcl_text=>gc_msg-no_workflow ).

    IF iv_vbeln IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_info) = zcl_sd_apm_wf_reader=>get_info( iv_vbeln ).

    IF ls_info-wf_found = abap_false OR ls_info-runs IS INITIAL.
      RETURN.
    ENDIF.

    " Only the latest run determines the button.
    DATA(ls_run) = ls_info-runs[ lines( ls_info-runs ) ].

    IF ls_run-status = zcl_sd_apm_wf_reader=>gc_run_status-running.

      IF has_open_rework_step( it_steps = ls_info-steps
                               iv_run   = ls_run-run ) = abap_true.
        rs_button-icon_id   = icon_system_undo.
        rs_button-quickinfo = lcl_text=>get( lcl_text=>gc_msg-rework_pending ).
      ELSEIF ls_info-current_approver IS NOT INITIAL.
        rs_button-icon_id   = icon_time.
        rs_button-quickinfo = lcl_text=>get( iv_msgno = lcl_text=>gc_msg-pending_with
                                             iv_v1    = ls_info-current_approver ).
      ELSE.
        rs_button-icon_id   = icon_time.
        rs_button-quickinfo = lcl_text=>get( lcl_text=>gc_msg-pending ).
      ENDIF.

      RETURN.
    ENDIF.

    CASE ls_run-result.
      WHEN zcl_sd_apm_wf_reader=>gc_decision-approved.
        rs_button-icon_id   = icon_okay.
        rs_button-quickinfo = lcl_text=>get( lcl_text=>gc_msg-approved ).

      WHEN zcl_sd_apm_wf_reader=>gc_decision-rejected.
        rs_button-icon_id   = icon_cancel.
        rs_button-quickinfo = lcl_text=>get( lcl_text=>gc_msg-rejected ).

      WHEN OTHERS.
        rs_button-icon_id   = icon_led_inactive.
        rs_button-quickinfo = COND #(
          WHEN ls_run-status = zcl_sd_apm_wf_reader=>gc_run_status-cancelled
          THEN lcl_text=>get( lcl_text=>gc_msg-cancelled )
          ELSE lcl_text=>get( lcl_text=>gc_msg-status_generic ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD has_open_rework_step.
    rv_open = xsdbool( line_exists(
      it_steps[ run     = iv_run
                is_open = abap_true
                task    = zcl_sd_apm_wf_reader=>gc_task-rework ] ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lcl_tree_view IMPLEMENTATION.

  METHOD request_refresh.
    gv_force_refresh = abap_true.
  ENDMETHOD.


  METHOD process_before_output.
    IF iv_vbeln IS INITIAL.
      RETURN.
    ENDIF.

    " The frontend control may already be gone while the ABAP reference
    " is still bound. Never call FREE on a dead control.
    IF go_container IS BOUND AND is_container_alive( ) = abap_false.
      discard_references( ).
    ENDIF.

    DATA(lv_force_refresh) = gv_force_refresh.
    CLEAR gv_force_refresh.

    DATA(ls_info) = zcl_sd_apm_wf_reader=>get_info( iv_vbeln    = iv_vbeln
                                                    iv_no_cache = lv_force_refresh ).

    " Rebuild on first display, document change, manual refresh or when
    " the reader delivered fresh data (cache expired).
    DATA(lv_rebuild) = xsdbool( go_tree IS NOT BOUND
                             OR iv_vbeln <> gv_vbeln_shown
                             OR lv_force_refresh = abap_true
                             OR ls_info-read_at <> gs_info-read_at ).
    IF lv_rebuild = abap_false.
      RETURN.
    ENDIF.

    destroy_tree( ).

    gs_info        = ls_info.
    gv_vbeln_shown = iv_vbeln.

    TRY.
        create_tree( ).
      CATCH cx_salv_error INTO DATA(lx_salv).
        destroy_tree( ).
        DATA(lv_message) = lx_salv->get_text( ).
        MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'W'.
    ENDTRY.
  ENDMETHOD.


  METHOD is_container_alive.
    DATA lv_valid TYPE i.

    rv_alive = abap_false.

    IF go_container IS NOT BOUND.
      RETURN.
    ENDIF.

    go_container->is_valid( IMPORTING result = lv_valid ).

    rv_alive = xsdbool( lv_valid = 1 ).
  ENDMETHOD.


  METHOD destroy_tree.
    IF is_container_alive( ) = abap_true.
      " Freeing the container destroys the tree inside it as well.
      go_container->free(
        EXCEPTIONS
          cntl_error        = 1
          cntl_system_error = 2
          OTHERS            = 3 ).

      IF sy-subrc = 0.
        cl_gui_cfw=>flush(
          EXCEPTIONS
            cntl_system_error = 1
            cntl_error        = 2
            OTHERS            = 3 ).
      ENDIF.
    ENDIF.

    discard_references( ).
  ENDMETHOD.


  METHOD discard_references.
    " GO_TREE is intentionally not freed separately: it lives inside the
    " container and is destroyed together with it.
    FREE: go_tree,
          go_container.

    CLEAR: gt_tree_data,
           gt_node_map,
           gs_info,
           gv_vbeln_shown.
  ENDMETHOD.


  METHOD create_tree.
    CREATE OBJECT go_container
      EXPORTING
        container_name = gc_container_name
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc <> 0.
      discard_references( ).
      MESSAGE s004 DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    CLEAR gt_tree_data.

    cl_salv_tree=>factory(
      EXPORTING
        r_container = go_container
      IMPORTING
        r_salv_tree = go_tree
      CHANGING
        t_table     = gt_tree_data ).

    go_tree->get_tree_settings( )->set_hierarchy_size( gc_hierarchy_width ).

    configure_columns( ).

    SET HANDLER on_double_click FOR go_tree->get_event( ).

    fill_tree( ).

    go_tree->display( ).
  ENDMETHOD.


  METHOD configure_columns.
    DATA(lo_columns) = go_tree->get_columns( ).

    configure_column( io_columns = lo_columns
                      iv_name    = 'AGENT'
                      iv_msgno   = lcl_text=>gc_msg-col_agent
                      iv_width   = 32 ).
    configure_column( io_columns = lo_columns
                      iv_name    = 'STATUS_TEXT'
                      iv_msgno   = lcl_text=>gc_msg-col_status
                      iv_width   = 30 ).
    configure_column( io_columns = lo_columns
                      iv_name    = 'DECISION'
                      iv_msgno   = lcl_text=>gc_msg-col_decision
                      iv_width   = 30 ).
    configure_column( io_columns = lo_columns
                      iv_name    = gc_column_note
                      iv_msgno   = lcl_text=>gc_msg-col_note
                      iv_width   = 9 ).
    configure_column( io_columns = lo_columns
                      iv_name    = 'CREATED'
                      iv_msgno   = lcl_text=>gc_msg-col_created
                      iv_width   = 25 ).
    configure_column( io_columns = lo_columns
                      iv_name    = 'COMPLETED'
                      iv_msgno   = lcl_text=>gc_msg-col_completed
                      iv_width   = 25 ).

    lo_columns->get_column( gc_column_note )->set_tooltip(
      CONV #( lcl_text=>get( lcl_text=>gc_msg-col_note_tip ) ) ).
  ENDMETHOD.


  METHOD configure_column.
    DATA(lo_column) = io_columns->get_column( iv_name ).
    DATA(lv_text)   = lcl_text=>get( iv_msgno ).

    lo_column->set_short_text( CONV #( lv_text ) ).
    lo_column->set_medium_text( CONV #( lv_text ) ).
    lo_column->set_long_text( CONV #( lv_text ) ).
    lo_column->set_output_length( iv_width ).
  ENDMETHOD.


  METHOD fill_tree.
    DATA ls_row TYPE ty_tree_row.

    DATA(lo_nodes) = go_tree->get_nodes( ).

    go_tree->get_tree_settings( )->set_hierarchy_header(
      CONV #( lcl_text=>get( iv_msgno = lcl_text=>gc_msg-tree_header
                             iv_v1    = |{ gs_info-read_on_date DATE = USER }|
                             iv_v2    = |{ gs_info-read_on_time TIME = USER }| ) ) ).

    " SALV keeps the node data in the table handed over to FACTORY:
    " clear data and node model together.
    CLEAR: gt_tree_data,
           gt_node_map.
    lo_nodes->delete_all( ).

    IF gs_info-runs IS INITIAL.
      CLEAR ls_row.
      lo_nodes->add_node(
        related_node = space
        relationship = cl_gui_column_tree=>relat_last_child
        data_row     = ls_row
        text         = CONV #( lcl_text=>get( lcl_text=>gc_msg-no_workflow ) ) ).
      RETURN.
    ENDIF.

    DATA(lv_latest_run_index) = lines( gs_info-runs ).

    LOOP AT gs_info-runs INTO DATA(ls_run).
      DATA(lv_run_index) = sy-tabix.

      ls_row = VALUE #( status_text = ls_run-status_text
                        decision    = ls_run-result_text
                        created     = format_timestamp( iv_date = ls_run-started_on
                                                        iv_time = ls_run-started_at )
                        completed   = format_timestamp( iv_date = ls_run-ended_on
                                                        iv_time = ls_run-ended_at ) ).

      DATA(lo_run_node) = lo_nodes->add_node(
        related_node   = space
        relationship   = cl_gui_column_tree=>relat_last_child
        data_row       = ls_row
        collapsed_icon = CONV #( ls_run-icon )
        expanded_icon  = CONV #( ls_run-icon )
        text           = CONV #( lcl_text=>get( iv_msgno = lcl_text=>gc_msg-run
                                                iv_v1    = |{ ls_run-run }|
                                                iv_v2    = ls_run-submitter ) ) ).

      LOOP AT gs_info-steps INTO DATA(ls_step) WHERE run = ls_run-run.
        DATA(lv_step_index) = sy-tabix.

        ls_row = VALUE #( agent       = ls_step-agent
                          status_text = ls_step-status_text
                          decision    = ls_step-decision_text
                          created     = format_timestamp( iv_date = ls_step-created_on
                                                          iv_time = ls_step-created_at )
                          completed   = format_timestamp( iv_date = ls_step-completed_on
                                                          iv_time = ls_step-completed_at ) ).

        DATA(lv_step_msgno) = COND symsgno(
          WHEN ls_step-task = zcl_sd_apm_wf_reader=>gc_task-rework
          THEN lcl_text=>gc_msg-step_rework
          ELSE lcl_text=>gc_msg-step_approval ).

        DATA(lo_step_node) = lo_nodes->add_node(
          related_node   = lo_run_node->get_key( )
          relationship   = cl_gui_column_tree=>relat_last_child
          data_row       = ls_row
          collapsed_icon = CONV #( ls_step-icon )
          text           = CONV #( lcl_text=>get( lv_step_msgno ) ) ).

        IF ls_step-is_open = abap_true.
          lo_step_node->set_row_style( if_salv_c_tree_style=>emphasized_b ).
        ENDIF.

        IF ls_step-has_note = abap_true.
          lo_step_node->get_item( gc_column_note )->set_icon( CONV #( icon_annotation ) ).
        ENDIF.

        APPEND VALUE #( node_key   = lo_step_node->get_key( )
                        step_index = lv_step_index ) TO gt_node_map.
      ENDLOOP.

      " Only the latest run is expanded automatically.
      IF lv_run_index = lv_latest_run_index.
        lo_run_node->expand( ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD format_timestamp.
    rv_text = COND #( WHEN iv_date IS NOT INITIAL
                      THEN |{ iv_date DATE = USER } { iv_time TIME = USER }| ).
  ENDMETHOD.


  METHOD show_note.
    DATA lv_title TYPE cl_abap_browser=>title.

    DATA(ls_step) = VALUE #( gs_info-steps[ iv_step_index ] OPTIONAL ).
    IF ls_step IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_attachments) = read_note_attachments( iv_step_index ).
    IF lt_attachments IS INITIAL.
      MESSAGE s002.
      RETURN.
    ENDIF.

    DATA(lv_html) = render_note_html( is_step        = ls_step
                                      it_attachments = lt_attachments ).
    IF lv_html IS INITIAL.
      MESSAGE s003 DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " TITLE is typed with a fixed length; a functional method result of
    " type string cannot be passed directly.
    lv_title = lcl_text=>get( lcl_text=>gc_msg-note_title ).

    cl_abap_browser=>show_html(
      title       = lv_title
      html_string = lv_html
      size        = cl_abap_browser=>medium
      modal       = abap_true ).
  ENDMETHOD.


  METHOD read_note_attachments.
    DATA(ls_step) = gs_info-steps[ iv_step_index ].

    rt_attachments = read_attachments( ls_step-wi_id ).

    " Attachments are inherited along the workflow. Remove those that
    " already existed at the previous step of the same run so that only
    " the notes entered at THIS step remain.
    DATA(lv_prev_index) = iv_step_index - 1.

    WHILE lv_prev_index >= 1.
      DATA(ls_prev) = gs_info-steps[ lv_prev_index ].
      IF ls_prev-run <> ls_step-run.
        EXIT.
      ENDIF.

      DATA(lt_prev) = read_attachments( ls_prev-wi_id ).
      IF lt_prev IS NOT INITIAL.
        LOOP AT lt_prev INTO DATA(ls_prev_attachment).
          DELETE rt_attachments WHERE object_id = ls_prev_attachment-object_id.
        ENDLOOP.
        " The nearest predecessor with attachments is a sufficient reference.
        EXIT.
      ENDIF.

      lv_prev_index = lv_prev_index - 1.
    ENDWHILE.

    " Safety net: never show an empty popup when the note icon was set.
    IF rt_attachments IS INITIAL.
      rt_attachments = read_attachments( ls_step-wi_id ).
    ENDIF.
  ENDMETHOD.


  METHOD read_attachments.
    CLEAR rt_attachments.

    " Decision comments (semantic attachments) first ...
    CALL FUNCTION 'SAP_WAPI_GET_ATTACHMENTS'
      EXPORTING
        workitem_id           = iv_wi_id
        comment_semantic_only = abap_true
      TABLES
        attachments           = rt_attachments.

    " ... otherwise all attachments of the work item.
    IF rt_attachments IS INITIAL.
      CALL FUNCTION 'SAP_WAPI_GET_ATTACHMENTS'
        EXPORTING
          workitem_id = iv_wi_id
        TABLES
          attachments = rt_attachments.
    ENDIF.
  ENDMETHOD.


  METHOD render_note_html.
    DATA ls_document TYPE sofolenti1.
    DATA lt_content  TYPE STANDARD TABLE OF solisti1.

    CLEAR rv_html.

    DATA(lv_body) = ``.

    LOOP AT it_attachments INTO DATA(ls_attachment).
      " BOR object key of a SOFM attachment: folder id (17) + document
      " id (17), starting at offset 20 of the object id.
      DATA(lv_doc_id) = CONV sofolenti1-doc_id( ls_attachment-object_id+20(34) ).

      CLEAR: ls_document,
             lt_content.

      CALL FUNCTION 'SO_DOCUMENT_READ_API1'
        EXPORTING
          document_id    = lv_doc_id
        IMPORTING
          document_data  = ls_document
        TABLES
          object_content = lt_content
        EXCEPTIONS
          OTHERS         = 1.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      lv_body = lv_body
        && `<div class="t">`
        && escape( val = ls_document-obj_descr format = cl_abap_format=>e_html_text )
        && `</div>`.

      LOOP AT lt_content INTO DATA(ls_line).
        lv_body = lv_body
          && escape( val = ls_line-line format = cl_abap_format=>e_html_text )
          && `<br>`.
      ENDLOOP.
    ENDLOOP.

    IF lv_body IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_when) = COND #( WHEN is_step-completed_on IS NOT INITIAL
                            THEN format_timestamp( iv_date = is_step-completed_on
                                                   iv_time = is_step-completed_at )
                            ELSE format_timestamp( iv_date = is_step-created_on
                                                   iv_time = is_step-created_at ) ).

    DATA(lv_header) = lcl_text=>get( iv_msgno = lcl_text=>gc_msg-run
                                     iv_v1    = |{ is_step-run }|
                                     iv_v2    = is_step-agent )
                   && ` &middot; ` && lv_when.

    rv_html = `<html><head><style>`
      && `body{font-family:Arial,sans-serif;font-size:13px;color:#222;margin:12px}`
      && `.h{color:#666;font-size:12px;margin-bottom:6px}`
      && `.t{font-weight:bold;margin:10px 0 4px 0}`
      && `</style></head><body>`
      && `<div class="h">`
      && escape( val = lv_header format = cl_abap_format=>e_html_text )
      && `</div>`
      && lv_body
      && `</body></html>`.
  ENDMETHOD.


  METHOD on_double_click.
    DATA(ls_map) = VALUE #( gt_node_map[ node_key = node_key ] OPTIONAL ).
    IF ls_map IS INITIAL.
      " Double-click on a run node: nothing to show.
      RETURN.
    ENDIF.

    DATA(ls_step) = VALUE #( gs_info-steps[ ls_map-step_index ] OPTIONAL ).
    IF ls_step-has_note = abap_false.
      RETURN.
    ENDIF.

    show_note( ls_map-step_index ).
  ENDMETHOD.

ENDCLASS.
