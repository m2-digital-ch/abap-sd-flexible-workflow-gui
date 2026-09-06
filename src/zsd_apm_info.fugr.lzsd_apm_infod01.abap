*----------------------------------------------------------------------*
* LZSD_APM_INFOD01 - local class definitions
* Implementations: LZSD_APM_INFOP01
*----------------------------------------------------------------------*

*----------------------------------------------------------------------*
* LCL_TEXT - UI texts
*
* All texts shown to the user come from message class ZSD_APM so that
* the whole solution can be translated with transaction SE63.
*----------------------------------------------------------------------*
CLASS lcl_text DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CONSTANTS gc_msgid TYPE symsgid VALUE 'ZSD_APM'.

    " Message numbers of ZSD_APM that are read as texts, named for
    " readability. Messages 002 to 004 are issued directly (MESSAGE sNNN).
    CONSTANTS:
      BEGIN OF gc_msg,
        no_workflow    TYPE symsgno VALUE '001',
        status_generic TYPE symsgno VALUE '010',
        pending        TYPE symsgno VALUE '011',
        pending_with   TYPE symsgno VALUE '012',
        rework_pending TYPE symsgno VALUE '013',
        approved       TYPE symsgno VALUE '014',
        rejected       TYPE symsgno VALUE '015',
        cancelled      TYPE symsgno VALUE '016',
        approval       TYPE symsgno VALUE '020',
        tree_header    TYPE symsgno VALUE '021',
        run            TYPE symsgno VALUE '022',
        step_approval  TYPE symsgno VALUE '023',
        step_rework    TYPE symsgno VALUE '024',
        note_title     TYPE symsgno VALUE '025',
        col_agent      TYPE symsgno VALUE '030',
        col_status     TYPE symsgno VALUE '031',
        col_decision   TYPE symsgno VALUE '032',
        col_note       TYPE symsgno VALUE '033',
        col_created    TYPE symsgno VALUE '034',
        col_completed  TYPE symsgno VALUE '035',
        col_note_tip   TYPE symsgno VALUE '036',
      END OF gc_msg.

    " Returns the text of message ZSD_APM iv_msgno with up to two
    " placeholders (&1, &2) replaced.
    CLASS-METHODS get
      IMPORTING iv_msgno       TYPE symsgno
                iv_v1          TYPE string OPTIONAL
                iv_v2          TYPE string OPTIONAL
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.


*----------------------------------------------------------------------*
* LCL_STATUS_BUTTON - approval status button in the VA03 toolbar
*----------------------------------------------------------------------*
CLASS lcl_status_button DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    " Determines icon, text and quick info of function ZWF (GUI status
    " ZU) for the given sales document.
    CLASS-METHODS prepare
      IMPORTING iv_vbeln         TYPE vbeln_va
      RETURNING VALUE(rs_button) TYPE smp_dyntxt.

  PRIVATE SECTION.
    " abap_true if the given run still has an open rework step
    CLASS-METHODS has_open_rework_step
      IMPORTING it_steps       TYPE zcl_sd_apm_wf_reader=>ty_steps
                iv_run         TYPE i
      RETURNING VALUE(rv_open) TYPE abap_bool.
ENDCLASS.


*----------------------------------------------------------------------*
* LCL_TREE_VIEW - SALV tree of workflow runs and steps (subscreen 0100)
*
* Display
* - CL_SALV_TREE inside custom control GO_CONT_STEPS
* - workflow runs as top level nodes, workflow steps as child nodes
* - processor, status, decision, note icon and time stamps per row
* - double-click on a step with a note opens the note as HTML popup
*
* Refresh cycle
* - the user triggers function code ZREFRESH on subscreen 0100 (PAI)
* - ZCL_SD_APM_HEAD_TAB consumes it and calls Z_SD_APM_WF_REFRESH
* - REQUEST_REFRESH only sets a flag: no frontend access during PAI
* - the next PBO re-reads the workflow without cache and rebuilds the
*   tree from scratch (an incremental SALV refresh proved unstable in
*   the embedded VA03 subscreen)
*
* Control lifecycle
* - VA03 -> back -> other document -> approval tab: the ABAP reference
*   may still be bound although the frontend control is already gone.
*   The container is therefore checked with IS_VALID before it is
*   reused or freed. Dead controls are only dropped on the ABAP side.
* - the SALV tree is never freed separately, it is destroyed together
*   with its container
*----------------------------------------------------------------------*
CLASS lcl_tree_view DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    " Flags that the workflow shall be re-read without cache and the
    " tree rebuilt during the next PBO.
    CLASS-METHODS request_refresh.

    " PBO of subscreen 0100: reads the workflow data and (re)builds the
    " tree when necessary.
    CLASS-METHODS process_before_output
      IMPORTING iv_vbeln TYPE vbeln_va.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_tree_row,
        agent       TYPE c LENGTH 60,
        status_text TYPE c LENGTH 30,
        decision    TYPE c LENGTH 30,
        note        TYPE salv_de_tree_image,
        created     TYPE c LENGTH 19,
        completed   TYPE c LENGTH 19,
      END OF ty_tree_row,
      ty_tree_rows TYPE STANDARD TABLE OF ty_tree_row WITH EMPTY KEY.

    " Maps a SALV node key to the index of the step in GS_INFO-STEPS
    TYPES:
      BEGIN OF ty_node_map,
        node_key   TYPE salv_de_node_key,
        step_index TYPE i,
      END OF ty_node_map,
      ty_node_maps TYPE STANDARD TABLE OF ty_node_map WITH EMPTY KEY.

    " Name of the custom control on subscreen 0100
    CONSTANTS gc_container_name TYPE c LENGTH 30 VALUE 'GO_CONT_STEPS'.
    " Column that carries the note icon
    CONSTANTS gc_column_note TYPE lvc_fname VALUE 'NOTE'.
    " Width of the hierarchy column (characters)
    CONSTANTS gc_hierarchy_width TYPE i VALUE 50.

    CLASS-DATA go_container     TYPE REF TO cl_gui_custom_container.
    CLASS-DATA go_tree          TYPE REF TO cl_salv_tree.
    CLASS-DATA gt_tree_data     TYPE ty_tree_rows.
    CLASS-DATA gt_node_map      TYPE ty_node_maps.
    CLASS-DATA gs_info          TYPE zcl_sd_apm_wf_reader=>ty_info.
    CLASS-DATA gv_vbeln_shown   TYPE vbeln_va.
    CLASS-DATA gv_force_refresh TYPE abap_bool.

    " abap_true if GO_CONTAINER is bound and its frontend control exists
    CLASS-METHODS is_container_alive
      RETURNING VALUE(rv_alive) TYPE abap_bool.

    " Frees the container on the frontend (if alive) and drops all
    " ABAP references and display state
    CLASS-METHODS destroy_tree.

    " Drops ABAP references and display state without frontend access
    CLASS-METHODS discard_references.

    " Creates container and SALV tree and fills it from GS_INFO
    CLASS-METHODS create_tree
      RAISING cx_salv_error.

    CLASS-METHODS configure_columns
      RAISING cx_salv_error.

    CLASS-METHODS configure_column
      IMPORTING io_columns TYPE REF TO cl_salv_columns_tree
                iv_name    TYPE lvc_fname
                iv_msgno   TYPE symsgno
                iv_width   TYPE lvc_outlen
      RAISING   cx_salv_error.

    " Adds the run and step nodes from GS_INFO to the tree
    CLASS-METHODS fill_tree
      RAISING cx_salv_error.

    " Date and time in the user's format, empty if the date is initial
    CLASS-METHODS format_timestamp
      IMPORTING iv_date        TYPE d
                iv_time        TYPE t
      RETURNING VALUE(rv_text) TYPE string.

    " Shows the note(s) of the step in a modal HTML popup
    CLASS-METHODS show_note
      IMPORTING iv_step_index TYPE i.

    " Attachments that were added at exactly this step (inherited
    " attachments of the predecessor step are removed)
    CLASS-METHODS read_note_attachments
      IMPORTING iv_step_index         TYPE i
      RETURNING VALUE(rt_attachments) TYPE swrtobject.

    " Attachments of a work item: decision comments first, otherwise all
    CLASS-METHODS read_attachments
      IMPORTING iv_wi_id              TYPE sww_wiid
      RETURNING VALUE(rt_attachments) TYPE swrtobject.

    " Renders the SOFM documents behind the attachments as HTML.
    " Returns an empty string if no document could be read.
    CLASS-METHODS render_note_html
      IMPORTING is_step        TYPE zcl_sd_apm_wf_reader=>ty_step
                it_attachments TYPE swrtobject
      RETURNING VALUE(rv_html) TYPE string.

    CLASS-METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_tree
      IMPORTING node_key.
ENDCLASS.
