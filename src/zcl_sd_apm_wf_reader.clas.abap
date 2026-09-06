"! <p class="shorttext">Reads the flexible approval workflow of a sales document</p>
"! Reads all runs (workflow instances) and their dialog steps (work items) of
"! the SAP flexible workflow that belong to one sales document and condenses
"! them into a display-oriented structure (TY_INFO).
"! <p>Data sources</p>
"! <ul>
"! <li>VBAK: approval status and approval reason of the document</li>
"! <li>SAP Business Workflow runtime (SWW_WI2OBJ, SWWWIHEAD, SAP_WAPI_*):
"! runs, work items, agents, decisions</li>
"! <li>Change documents (CDHDR): submitter of follow-up runs</li>
"! <li>User master (BAPI_USER_GET_DETAIL): display names</li>
"! </ul>
"! <p>The class is the single data source of the GUI integration. It has no
"! persistence of its own and never modifies workflow data.</p>
"! <p><strong>Caching:</strong> results are cached per document within the
"! internal session for GC_CACHE_MAX_AGE seconds, because the status button is
"! prepared on every PBO of VA03. A manual refresh bypasses the cache.</p>
"! <p><strong>Error handling:</strong> technical errors are caught so that the
"! display in VA03 is never blocked by this add-on. They are written to the
"! application log, object ZSD_APM, subobject WF_DISPLAY (transaction SLG1).</p>
CLASS zcl_sd_apm_wf_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Status of a workflow run, see GC_RUN_STATUS
    TYPES ty_run_status TYPE c LENGTH 1.
    "! Decision of a step or result of a run, see GC_DECISION
    TYPES ty_decision TYPE c LENGTH 1.

    "! One dialog step (work item) of a run
    TYPES:
      BEGIN OF ty_step,
        run           TYPE i,                  " number of the run the step belongs to (1 = oldest)
        wi_id         TYPE sww_wiid,           " work item id
        task          TYPE sww_task,           " standard task of the step, see GC_TASK
        step_text     TYPE string,             " work item text
        agent         TYPE string,             " processor (completed) or current recipients (open)
        wi_status     TYPE sww_wistat,         " technical work item status (READY, COMPLETED, ...)
        status_text   TYPE string,             " work item status, language dependent
        decision      TYPE ty_decision,        " see GC_DECISION
        decision_text TYPE string,             " language dependent
        is_open       TYPE abap_bool,          " step still waits for processing
        has_note      TYPE abap_bool,          " a note / decision comment was entered at this step
        icon          TYPE icon_d,             " icon representing the step status
        created_on    TYPE d,
        created_at    TYPE t,
        completed_on  TYPE d,
        completed_at  TYPE t,
      END OF ty_step,
      ty_steps TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.

    "! One workflow run (workflow instance) of the document
    TYPES:
      BEGIN OF ty_run,
        run         TYPE i,                    " sequential number (1 = oldest)
        submitter   TYPE string,               " display name of the user who started the run
        status      TYPE ty_run_status,        " see GC_RUN_STATUS
        status_text TYPE string,               " language dependent
        result      TYPE ty_decision,          " final decision of the run, see GC_DECISION
        result_text TYPE string,               " language dependent
        icon        TYPE icon_d,               " icon representing the run status
        started_on  TYPE d,
        started_at  TYPE t,
        ended_on    TYPE d,
        ended_at    TYPE t,
      END OF ty_run,
      ty_runs TYPE STANDARD TABLE OF ty_run WITH EMPTY KEY.

    "! Complete workflow information of one sales document
    TYPES:
      BEGIN OF ty_info,
        vbeln                TYPE vbeln_va,
        approval_status      TYPE c LENGTH 10, " VBAK-APM_APPROVAL_STATUS
        approval_status_text TYPE string,
        approval_reason      TYPE c LENGTH 10, " VBAK-APM_APPROVAL_REASON
        approval_reason_text TYPE string,
        wf_found             TYPE abap_bool,   " at least one run exists
        current_step         TYPE string,      " text(s) of the open step(s) of the latest run
        current_approver     TYPE string,      " agent(s) of the open step(s) of the latest run
        runs                 TYPE ty_runs,     " sorted ascending by RUN
        steps                TYPE ty_steps,    " sorted by RUN, then chronologically
        read_at              TYPE timestampl,  " time stamp of the read; changes on every real read
        read_on_date         TYPE d,           " READ_AT in the user's time zone
        read_on_time         TYPE t,
      END OF ty_info.

    "! Status of a workflow run
    CONSTANTS:
      BEGIN OF gc_run_status,
        running   TYPE ty_run_status VALUE 'R',
        completed TYPE ty_run_status VALUE 'C',
        cancelled TYPE ty_run_status VALUE 'X',
      END OF gc_run_status.

    "! Decision of a step / result of a run
    CONSTANTS:
      BEGIN OF gc_decision,
        none        TYPE ty_decision VALUE space,
        approved    TYPE ty_decision VALUE 'A',
        rejected    TYPE ty_decision VALUE 'R',
        rework      TYPE ty_decision VALUE 'W', " sent back for rework
        resubmitted TYPE ty_decision VALUE 'S', " rework done, document resubmitted
      END OF gc_decision.

    "! Dialog tasks of the SAP standard workflow scenario WS02000029
    "! (flexible workflow for credit memo requests) whose steps are
    "! displayed. The scenario contains exactly these two tasks.
    CONSTANTS:
      BEGIN OF gc_task,
        approve TYPE sww_task VALUE 'TS02000054',
        rework  TYPE sww_task VALUE 'TS02000055',
      END OF gc_task.

    "! Returns the workflow information of a sales document.
    "! @parameter iv_vbeln | Sales document number
    "! @parameter iv_no_cache | abap_true forces a fresh read of the workflow
    "! @parameter rs_info | Runs and steps of the document; WF_FOUND is
    "!                      abap_false when no workflow exists
    CLASS-METHODS get_info
      IMPORTING iv_vbeln       TYPE vbeln_va
                iv_no_cache    TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_info) TYPE ty_info.

  PRIVATE SECTION.
    " Top level work item (flow item) of a run
    TYPES:
      BEGIN OF ty_run_head,
        wi_id      TYPE swwwihead-wi_id,
        wi_stat    TYPE swwwihead-wi_stat,
        wi_cd      TYPE swwwihead-wi_cd,
        wi_ct      TYPE swwwihead-wi_ct,
        wi_creator TYPE swwwihead-wi_creator,
        wi_cruser  TYPE swwwihead-wi_cruser,
      END OF ty_run_head,
      ty_run_heads TYPE STANDARD TABLE OF ty_run_head WITH EMPTY KEY.

    " Change document header of the sales document
    TYPES:
      BEGIN OF ty_change,
        udate    TYPE cdhdr-udate,
        utime    TYPE cdhdr-utime,
        username TYPE cdhdr-username,
      END OF ty_change,
      ty_changes TYPE STANDARD TABLE OF ty_change WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_user_cache,
        uname TYPE syuname,
        name  TYPE string,
      END OF ty_user_cache.

    " Workflow object type of the flexible workflow for credit memo requests
    CONSTANTS gc_typeid TYPE sibftypeid VALUE 'CL_SD_CMR_WORKFLOW'.
    CONSTANTS gc_catid TYPE sibfcatid VALUE 'CL'.
    " VBAK field with the approval status (its domain delivers the texts)
    CONSTANTS gc_field_status TYPE fieldname VALUE 'APM_APPROVAL_STATUS'.
    " Container element that carries the decision of a dialog step
    CONSTANTS gc_decision_element TYPE swc_elem VALUE '_WI_RESULT'.
    " Object class of the sales document change documents
    CONSTANTS gc_change_object_class TYPE cdobjectcl VALUE 'VERKBELEG'.
    " Object type of the note attachments
    CONSTANTS gc_note_typeid TYPE sibftypeid VALUE 'SOFM'.

    CONSTANTS:
      BEGIN OF gc_wi_status,
        ready     TYPE sww_wistat VALUE 'READY',
        selected  TYPE sww_wistat VALUE 'SELECTED',
        started   TYPE sww_wistat VALUE 'STARTED',
        completed TYPE sww_wistat VALUE 'COMPLETED',
        cancelled TYPE sww_wistat VALUE 'CANCELLED',
        error     TYPE sww_wistat VALUE 'ERROR',
        waiting   TYPE sww_wistat VALUE 'WAITING',
      END OF gc_wi_status.

    CONSTANTS:
      BEGIN OF gc_wi_type,
        flow   TYPE sww_witype VALUE 'F',
        dialog TYPE sww_witype VALUE 'W',
      END OF gc_wi_type.

    " Decision keys of the approval task (work item result / _WI_RESULT)
    CONSTANTS:
      BEGIN OF gc_result_key,
        approved TYPE swr_result VALUE '0001',
        rejected TYPE swr_result VALUE '0002',
        rework   TYPE swr_result VALUE '0003',
      END OF gc_result_key.

    " Technical users that never count as the submitter of a run
    CONSTANTS gc_user_wfrt TYPE syuname VALUE 'SAP_WFRT'.
    CONSTANTS gc_user_wf_batch TYPE syuname VALUE 'WF-BATCH'.
    CONSTANTS gc_agent_type_user TYPE otype VALUE 'US'.

    " Application log (transaction SLG0 / SLG1)
    CONSTANTS gc_log_object TYPE balobj_d VALUE 'ZSD_APM'.
    CONSTANTS gc_log_subobject TYPE balsubobj VALUE 'WF_DISPLAY'.

    " Message class and numbers of the language dependent texts
    CONSTANTS gc_msgid TYPE symsgid VALUE 'ZSD_APM'.
    CONSTANTS:
      BEGIN OF gc_msg,
        wi_open         TYPE symsgno VALUE '040',
        wi_reserved     TYPE symsgno VALUE '041',
        wi_in_process   TYPE symsgno VALUE '042',
        wi_completed    TYPE symsgno VALUE '043',
        wi_cancelled    TYPE symsgno VALUE '044',
        wi_error        TYPE symsgno VALUE '045',
        wi_waiting      TYPE symsgno VALUE '046',
        in_rework       TYPE symsgno VALUE '047',
        rework_open     TYPE symsgno VALUE '048',
        run_running     TYPE symsgno VALUE '050',
        dec_approved    TYPE symsgno VALUE '051',
        dec_rejected    TYPE symsgno VALUE '052',
        dec_rework      TYPE symsgno VALUE '053',
        dec_resubmitted TYPE symsgno VALUE '054',
      END OF gc_msg.

    "! Seconds after which a cached result is considered stale
    CONSTANTS gc_cache_max_age TYPE i VALUE 60.

    CLASS-DATA gt_cache TYPE HASHED TABLE OF ty_info WITH UNIQUE KEY vbeln.
    CLASS-DATA gt_user_cache TYPE HASHED TABLE OF ty_user_cache WITH UNIQUE KEY uname.
    CLASS-DATA gt_logged_errors TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    "! abap_true if the cached entry is younger than GC_CACHE_MAX_AGE
    CLASS-METHODS is_cache_entry_fresh
      IMPORTING is_cached       TYPE ty_info
      RETURNING VALUE(rv_fresh) TYPE abap_bool.

    "! Approval status and reason from VBAK
    CLASS-METHODS read_header_status
      CHANGING cs_info TYPE ty_info.

    "! Runs and steps from SAP Business Workflow
    CLASS-METHODS read_workflow
      CHANGING cs_info TYPE ty_info.

    "! Top level work items of all runs of the document, oldest first
    CLASS-METHODS read_run_heads
      IMPORTING iv_vbeln            TYPE vbeln_va
      RETURNING VALUE(rt_run_heads) TYPE ty_run_heads.

    "! Dialog steps of all runs (unsorted)
    CLASS-METHODS read_steps
      IMPORTING it_run_heads TYPE ty_run_heads
      CHANGING  cs_info      TYPE ty_info.

    "! Reads one dialog work item and appends it to CS_INFO-STEPS
    CLASS-METHODS append_step
      IMPORTING iv_run   TYPE i
                is_child TYPE swr_wihdr
      CHANGING  cs_info  TYPE ty_info.

    "! Decision from the work item container element _WI_RESULT
    CLASS-METHODS read_decision_from_container
      IMPORTING iv_vbeln           TYPE vbeln_va
                iv_wi_id           TYPE sww_wiid
      RETURNING VALUE(rv_decision) TYPE ty_decision.

    "! Current recipients of an open work item as comma separated names
    CLASS-METHODS read_recipients
      IMPORTING iv_vbeln        TYPE vbeln_va
                iv_wi_id        TYPE sww_wiid
      RETURNING VALUE(rv_names) TYPE string.

    "! Fallback for completed steps without a stored decision: derive it
    "! from the step that followed
    CLASS-METHODS infer_missing_decisions
      CHANGING ct_steps TYPE ty_steps.

    "! Change document headers of the document since the first run,
    "! newest first (only read when follow-up runs or withdrawn rework
    "! steps exist)
    CLASS-METHODS read_change_documents
      IMPORTING iv_vbeln          TYPE vbeln_va
                it_run_heads      TYPE ty_run_heads
                it_steps          TYPE ty_steps
      RETURNING VALUE(rt_changes) TYPE ty_changes.

    "! A withdrawn (cancelled) rework step followed by another step means
    "! the document was changed and resubmitted directly
    CLASS-METHODS reinterpret_cancelled_rework
      IMPORTING it_changes TYPE ty_changes
      CHANGING  ct_steps   TYPE ty_steps.

    "! Marks the steps at which a note (SOFM attachment) was entered
    CLASS-METHODS flag_notes
      CHANGING ct_steps TYPE ty_steps.

    "! Decision texts and status icons of all steps
    CLASS-METHODS finalize_steps
      CHANGING ct_steps TYPE ty_steps.

    "! CURRENT_STEP and CURRENT_APPROVER from the open steps of the latest run
    CLASS-METHODS set_current_step
      IMPORTING iv_latest_run TYPE i
      CHANGING  cs_info       TYPE ty_info.

    "! Run header data (status, result, submitter, icon) from heads and steps
    CLASS-METHODS build_runs
      IMPORTING it_run_heads TYPE ty_run_heads
                it_changes   TYPE ty_changes
      CHANGING  cs_info      TYPE ty_info.

    "! Display name of the user who started a run
    CLASS-METHODS determine_submitter
      IMPORTING is_head        TYPE ty_run_head
                iv_run         TYPE i
                iv_creator     TYPE syuname
                it_changes     TYPE ty_changes
      RETURNING VALUE(rv_name) TYPE string.

    "! Maps a decision key of the approval task to GC_DECISION
    CLASS-METHODS map_decision
      IMPORTING iv_key             TYPE csequence
      RETURNING VALUE(rv_decision) TYPE ty_decision.

    CLASS-METHODS get_decision_text
      IMPORTING iv_decision    TYPE ty_decision
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS get_wi_status_text
      IMPORTING iv_status      TYPE sww_wistat
      RETURNING VALUE(rv_text) TYPE string.

    "! Display name of a user (SU01 address), cached per session
    CLASS-METHODS resolve_user
      IMPORTING iv_uname       TYPE syuname
      RETURNING VALUE(rv_name) TYPE string.

    "! Fixed value text of a VBAK field from its domain
    CLASS-METHODS get_domain_text
      IMPORTING iv_fieldname   TYPE fieldname
                iv_value       TYPE clike
      RETURNING VALUE(rv_text) TYPE string.

    "! Text of an approval reason (customizing text table)
    CLASS-METHODS get_reason_text
      IMPORTING iv_reason      TYPE clike
      RETURNING VALUE(rv_text) TYPE string.

    "! Appends a value to a comma separated list
    CLASS-METHODS append_to_list
      IMPORTING iv_value TYPE string
      CHANGING  cv_list  TYPE string.

    "! Text of message class ZSD_APM
    CLASS-METHODS text
      IMPORTING iv_msgno       TYPE symsgno
      RETURNING VALUE(rv_text) TYPE string.

    "! Writes a technical error to the application log (once per session
    "! and error) without triggering a COMMIT WORK in the VA03 LUW
    CLASS-METHODS log_error
      IMPORTING iv_vbeln   TYPE vbeln_va
                iv_context TYPE string
                iv_text    TYPE string.

ENDCLASS.


CLASS zcl_sd_apm_wf_reader IMPLEMENTATION.

  METHOD get_info.
    IF iv_no_cache = abap_false.
      DATA(ls_cached) = VALUE #( gt_cache[ vbeln = iv_vbeln ] OPTIONAL ).
      IF is_cache_entry_fresh( ls_cached ) = abap_true.
        rs_info = ls_cached.
        RETURN.
      ENDIF.
    ENDIF.

    rs_info-vbeln = iv_vbeln.

    GET TIME STAMP FIELD rs_info-read_at.
    CONVERT TIME STAMP rs_info-read_at TIME ZONE sy-zonlo
            INTO DATE rs_info-read_on_date TIME rs_info-read_on_time.

    read_header_status( CHANGING cs_info = rs_info ).
    read_workflow( CHANGING cs_info = rs_info ).

    DELETE TABLE gt_cache WITH TABLE KEY vbeln = iv_vbeln.
    INSERT rs_info INTO TABLE gt_cache.
  ENDMETHOD.


  METHOD is_cache_entry_fresh.
    DATA lv_now TYPE timestampl.

    rv_fresh = abap_false.

    IF is_cached-read_at IS INITIAL.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD lv_now.

    TRY.
        DATA(lv_age) = cl_abap_tstmp=>subtract( tstmp1 = lv_now
                                                tstmp2 = is_cached-read_at ).
        rv_fresh = xsdbool( lv_age >= 0 AND lv_age < gc_cache_max_age ).
      CATCH cx_parameter_invalid.
        " Unexpected time stamp values: treat the entry as stale.
        rv_fresh = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD read_header_status.
    SELECT SINGLE apm_approval_status, apm_approval_reason
      FROM vbak
      WHERE vbeln = @cs_info-vbeln
      INTO ( @DATA(lv_status), @DATA(lv_reason) ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    cs_info-approval_status      = lv_status.
    cs_info-approval_status_text = get_domain_text( iv_fieldname = gc_field_status
                                                    iv_value     = lv_status ).
    cs_info-approval_reason      = lv_reason.
    cs_info-approval_reason_text = get_reason_text( lv_reason ).
  ENDMETHOD.


  METHOD read_workflow.
    DATA(lt_run_heads) = read_run_heads( cs_info-vbeln ).
    IF lt_run_heads IS INITIAL.
      RETURN.
    ENDIF.

    cs_info-wf_found = abap_true.

    read_steps( EXPORTING it_run_heads = lt_run_heads
                CHANGING  cs_info      = cs_info ).

    SORT cs_info-steps BY run        ASCENDING
                          created_on ASCENDING
                          created_at ASCENDING
                          wi_id      ASCENDING.

    infer_missing_decisions( CHANGING ct_steps = cs_info-steps ).

    DATA(lt_changes) = read_change_documents( iv_vbeln     = cs_info-vbeln
                                              it_run_heads = lt_run_heads
                                              it_steps     = cs_info-steps ).

    reinterpret_cancelled_rework( EXPORTING it_changes = lt_changes
                                  CHANGING  ct_steps   = cs_info-steps ).

    flag_notes( CHANGING ct_steps = cs_info-steps ).

    finalize_steps( CHANGING ct_steps = cs_info-steps ).

    set_current_step( EXPORTING iv_latest_run = lines( lt_run_heads )
                      CHANGING  cs_info       = cs_info ).

    build_runs( EXPORTING it_run_heads = lt_run_heads
                          it_changes   = lt_changes
                CHANGING  cs_info      = cs_info ).
  ENDMETHOD.


  METHOD read_run_heads.
    " SWW_WI2OBJ-INSTID is CHAR 90. Assigning the document number directly
    " would apply the ALPHA conversion to the target length, so pad to the
    " VBELN length first and then move it left-aligned.
    DATA lv_vbeln  TYPE vbeln_va.
    DATA lv_instid TYPE sww_wi2obj-instid.

    lv_vbeln  = |{ iv_vbeln ALPHA = IN }|.
    lv_instid = lv_vbeln.

    " All runs (top level flow items) of the document, oldest first
    SELECT o~wi_id, h~wi_stat, h~wi_cd, h~wi_ct, h~wi_creator, h~wi_cruser
      FROM sww_wi2obj AS o
      INNER JOIN swwwihead AS h ON h~wi_id = o~wi_id
      WHERE o~catid   = @gc_catid
        AND o~typeid  = @gc_typeid
        AND o~instid  = @lv_instid
        AND h~wi_type = @gc_wi_type-flow
      ORDER BY h~wi_cd ASCENDING, h~wi_ct ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_run_heads.
  ENDMETHOD.


  METHOD read_steps.
    DATA lt_children TYPE STANDARD TABLE OF swr_wihdr.
    DATA lv_rc       TYPE sy-subrc.

    LOOP AT it_run_heads INTO DATA(ls_head).
      DATA(lv_run) = sy-tabix.

      CLEAR: lt_children,
             lv_rc.

      CALL FUNCTION 'SAP_WAPI_GET_DEPENDENT_WIS'
        EXPORTING
          workitem_id = ls_head-wi_id
        IMPORTING
          return_code = lv_rc
        TABLES
          items       = lt_children.

      IF lv_rc <> 0.
        log_error( iv_vbeln   = cs_info-vbeln
                   iv_context = 'SAP_WAPI_GET_DEPENDENT_WIS'
                   iv_text    = |Workflow { ls_head-wi_id }, RC { lv_rc }| ).
        CONTINUE.
      ENDIF.

      LOOP AT lt_children INTO DATA(ls_child) WHERE wi_type = gc_wi_type-dialog.
        append_step( EXPORTING iv_run   = lv_run
                               is_child = ls_child
                     CHANGING  cs_info  = cs_info ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD append_step.
    DATA ls_detail TYPE swr_widtl.
    DATA lv_result TYPE swr_result.
    DATA lv_rc     TYPE sy-subrc.

    CALL FUNCTION 'SAP_WAPI_GET_WORKITEM_DETAIL'
      EXPORTING
        workitem_id     = is_child-wi_id
      IMPORTING
        workitem_detail = ls_detail
        workitem_result = lv_result
        return_code     = lv_rc.

    IF lv_rc <> 0.
      log_error( iv_vbeln   = cs_info-vbeln
                 iv_context = 'SAP_WAPI_GET_WORKITEM_DETAIL'
                 iv_text    = |WI { is_child-wi_id }, RC { lv_rc }| ).
      RETURN.
    ENDIF.

    " Only the dialog steps of the known tasks are displayed.
    IF ls_detail-wi_rh_task <> gc_task-approve AND ls_detail-wi_rh_task <> gc_task-rework.
      RETURN.
    ENDIF.

    DATA(ls_step) = VALUE ty_step(
      run         = iv_run
      wi_id       = is_child-wi_id
      task        = ls_detail-wi_rh_task
      step_text   = ls_detail-wi_text
      wi_status   = ls_detail-wi_stat
      status_text = get_wi_status_text( ls_detail-wi_stat )
      is_open     = xsdbool( ls_detail-wi_stat <> gc_wi_status-completed
                         AND ls_detail-wi_stat <> gc_wi_status-cancelled )
      created_on  = ls_detail-wi_cd
      created_at  = ls_detail-wi_ct ).

    CASE ls_detail-wi_stat.
      WHEN gc_wi_status-completed.
        ls_step-completed_on = ls_detail-wi_aed.
        ls_step-completed_at = ls_detail-wi_aet.
        ls_step-agent        = resolve_user( ls_detail-wi_aagent ).

        " Primary source 1: the work item result.
        ls_step-decision = map_decision( lv_result ).

        " Primary source 2: element _WI_RESULT of the work item container.
        IF ls_step-decision = gc_decision-none.
          ls_step-decision = read_decision_from_container( iv_vbeln = cs_info-vbeln
                                                           iv_wi_id = is_child-wi_id ).
        ENDIF.

      WHEN gc_wi_status-cancelled.
        " A cancelled work item has a technical end as well, but no
        " processor: the actual agent is not necessarily the one who
        " cancelled it.
        ls_step-completed_on = ls_detail-wi_aed.
        ls_step-completed_at = ls_detail-wi_aet.

      WHEN OTHERS.
        IF ls_step-task = gc_task-rework.
          ls_step-status_text = COND #(
            WHEN ls_detail-wi_stat = gc_wi_status-selected OR ls_detail-wi_stat = gc_wi_status-started
            THEN text( gc_msg-in_rework )
            ELSE text( gc_msg-rework_open ) ).
        ENDIF.

        " Prefer the actual agent of a reserved / started work item; read
        " the recipients only for READY work items or without actual agent.
        IF ( ls_detail-wi_stat = gc_wi_status-selected OR ls_detail-wi_stat = gc_wi_status-started )
            AND ls_detail-wi_aagent IS NOT INITIAL.
          ls_step-agent = resolve_user( ls_detail-wi_aagent ).
        ELSE.
          ls_step-agent = read_recipients( iv_vbeln = cs_info-vbeln
                                           iv_wi_id = is_child-wi_id ).
        ENDIF.
    ENDCASE.

    APPEND ls_step TO cs_info-steps.
  ENDMETHOD.


  METHOD read_decision_from_container.
    DATA lt_container TYPE STANDARD TABLE OF swr_cont.
    DATA lv_rc        TYPE sy-subrc.

    rv_decision = gc_decision-none.

    CALL FUNCTION 'SAP_WAPI_READ_CONTAINER'
      EXPORTING
        workitem_id      = iv_wi_id
      IMPORTING
        return_code      = lv_rc
      TABLES
        simple_container = lt_container.

    IF lv_rc <> 0.
      log_error( iv_vbeln   = iv_vbeln
                 iv_context = 'SAP_WAPI_READ_CONTAINER'
                 iv_text    = |WI { iv_wi_id }, RC { lv_rc }| ).
      RETURN.
    ENDIF.

    LOOP AT lt_container INTO DATA(ls_element).
      IF to_upper( ls_element-element ) = gc_decision_element.
        rv_decision = map_decision( ls_element-value ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_recipients.
    DATA lt_recipients TYPE STANDARD TABLE OF swragent.
    DATA lv_rc         TYPE sy-subrc.

    CLEAR rv_names.

    CALL FUNCTION 'SAP_WAPI_WORKITEM_RECIPIENTS'
      EXPORTING
        workitem_id = iv_wi_id
      IMPORTING
        return_code = lv_rc
      TABLES
        recipients  = lt_recipients.

    IF lv_rc <> 0.
      log_error( iv_vbeln   = iv_vbeln
                 iv_context = 'SAP_WAPI_WORKITEM_RECIPIENTS'
                 iv_text    = |WI { iv_wi_id }, RC { lv_rc }| ).
      RETURN.
    ENDIF.

    LOOP AT lt_recipients INTO DATA(ls_recipient) WHERE otype = gc_agent_type_user.
      append_to_list( EXPORTING iv_value = resolve_user( CONV #( ls_recipient-objid ) )
                      CHANGING  cv_list  = rv_names ).
    ENDLOOP.
  ENDMETHOD.


  METHOD infer_missing_decisions.
    " Primary sources (work item result, container) are evaluated in
    " APPEND_STEP. This pattern based fallback only applies to completed
    " steps without a stored decision. A rework step is never a rejection.
    LOOP AT ct_steps ASSIGNING FIELD-SYMBOL(<ls_step>)
         WHERE wi_status = gc_wi_status-completed AND decision = gc_decision-none.
      DATA(lv_from) = sy-tabix + 1.

      " First step that really followed this one.
      LOOP AT ct_steps INTO DATA(ls_next) FROM lv_from.
        CHECK ls_next-created_on > <ls_step>-completed_on
          OR ( ls_next-created_on = <ls_step>-completed_on
               AND ls_next-created_at >= <ls_step>-completed_at ).

        CASE <ls_step>-task.
          WHEN gc_task-rework.
            " A later known step (also in a follow-up run) is reliable
            " evidence that the document was resubmitted.
            <ls_step>-decision = gc_decision-resubmitted.

          WHEN gc_task-approve.
            " For approvals only infer within the same run: a new run may
            " also have been caused by a change of the document.
            IF ls_next-run <> <ls_step>-run.
              EXIT.
            ENDIF.
            <ls_step>-decision = COND #( WHEN ls_next-task = gc_task-rework
                                         THEN gc_decision-rework
                                         ELSE gc_decision-approved ).
        ENDCASE.
        EXIT.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_change_documents.
    CLEAR rt_changes.

    IF lines( it_run_heads ) <= 1
        AND NOT line_exists( it_steps[ wi_status = gc_wi_status-cancelled
                                       task      = gc_task-rework ] ).
      RETURN.
    ENDIF.

    DATA(lv_objectid)       = CONV cdobjectv( |{ iv_vbeln ALPHA = IN }| ).
    DATA(lv_first_run_date) = it_run_heads[ 1 ]-wi_cd.

    SELECT udate, utime, username
      FROM cdhdr
      WHERE objectclas = @gc_change_object_class
        AND objectid   = @lv_objectid
        AND udate      >= @lv_first_run_date
      ORDER BY udate DESCENDING, utime DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_changes.
  ENDMETHOD.


  METHOD reinterpret_cancelled_rework.
    LOOP AT ct_steps ASSIGNING FIELD-SYMBOL(<ls_cancelled>)
         WHERE wi_status = gc_wi_status-cancelled AND task = gc_task-rework.
      DATA(lv_next_index) = sy-tabix + 1.

      " Only interpret as resubmitted when another step really followed.
      IF lv_next_index > lines( ct_steps ).
        CONTINUE.
      ENDIF.
      DATA(ls_after) = ct_steps[ lv_next_index ].

      <ls_cancelled>-status_text = text( gc_msg-wi_completed ).
      <ls_cancelled>-decision    = gc_decision-resubmitted.

      " The user who changed the document between the creation of the
      " rework step and the creation of the next step did the resubmission
      " (newest change document in that time window).
      LOOP AT it_changes INTO DATA(ls_change).
        IF ls_change-udate < ls_after-created_on
            OR ( ls_change-udate = ls_after-created_on AND ls_change-utime <= ls_after-created_at ).
          IF ls_change-udate > <ls_cancelled>-created_on
              OR ( ls_change-udate = <ls_cancelled>-created_on AND ls_change-utime >= <ls_cancelled>-created_at ).
            <ls_cancelled>-agent = resolve_user( ls_change-username ).
          ENDIF.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD flag_notes.
    IF ct_steps IS INITIAL.
      RETURN.
    ENDIF.

    " The workflow passes notes on to the follow-up work items. The icon
    " shall only appear at the step where the note was entered: per note
    " document (INSTID) the work item with the smallest id counts.
    SELECT wi_id, instid
      FROM sww_wi2obj
      FOR ALL ENTRIES IN @ct_steps
      WHERE wi_id  = @ct_steps-wi_id
        AND typeid = @gc_note_typeid
      INTO TABLE @DATA(lt_note_relations).

    SORT lt_note_relations BY instid ASCENDING wi_id ASCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_note_relations COMPARING instid.

    LOOP AT ct_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
      <ls_step>-has_note = xsdbool( line_exists( lt_note_relations[ wi_id = <ls_step>-wi_id ] ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD finalize_steps.
    " Cancelled approval steps stay visible on purpose. Without clear
    " evidence they are interpreted neither as rejection nor as approval.
    LOOP AT ct_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
      <ls_step>-decision_text = get_decision_text( <ls_step>-decision ).

      <ls_step>-icon = COND #(
        WHEN <ls_step>-decision  = gc_decision-resubmitted  THEN icon_change
        WHEN <ls_step>-wi_status = gc_wi_status-cancelled   THEN icon_led_inactive
        WHEN <ls_step>-is_open = abap_true
         AND <ls_step>-task = gc_task-rework                THEN icon_change
        WHEN <ls_step>-is_open = abap_true                  THEN icon_time
        WHEN <ls_step>-decision = gc_decision-rejected      THEN icon_cancel
        WHEN <ls_step>-decision = gc_decision-rework        THEN icon_system_undo
        ELSE icon_okay ).
    ENDLOOP.
  ENDMETHOD.


  METHOD set_current_step.
    CLEAR: cs_info-current_step,
           cs_info-current_approver.

    LOOP AT cs_info-steps INTO DATA(ls_open)
         WHERE run = iv_latest_run AND is_open = abap_true.
      append_to_list( EXPORTING iv_value = ls_open-step_text
                      CHANGING  cv_list  = cs_info-current_step ).
      append_to_list( EXPORTING iv_value = ls_open-agent
                      CHANGING  cv_list  = cs_info-current_approver ).
    ENDLOOP.
  ENDMETHOD.


  METHOD build_runs.
    SELECT SINGLE ernam
      FROM vbak
      WHERE vbeln = @cs_info-vbeln
      INTO @DATA(lv_creator).

    LOOP AT it_run_heads INTO DATA(ls_head).
      DATA(lv_run) = sy-tabix.

      DATA(ls_run) = VALUE ty_run(
        run        = lv_run
        started_on = ls_head-wi_cd
        started_at = ls_head-wi_ct
        status     = SWITCH #( ls_head-wi_stat
                               WHEN gc_wi_status-completed THEN gc_run_status-completed
                               WHEN gc_wi_status-cancelled THEN gc_run_status-cancelled
                               ELSE gc_run_status-running ) ).

      ls_run-status_text = SWITCH #( ls_run-status
                                     WHEN gc_run_status-completed THEN text( gc_msg-wi_completed )
                                     WHEN gc_run_status-cancelled THEN text( gc_msg-wi_cancelled )
                                     ELSE text( gc_msg-run_running ) ).

      " Result and end of the run come from the steps (SWWWIHEAD carries
      " no end time): the decision of the last completed approval step.
      LOOP AT cs_info-steps INTO DATA(ls_step)
           WHERE run = lv_run AND wi_status = gc_wi_status-completed.
        ls_run-ended_on = ls_step-completed_on.
        ls_run-ended_at = ls_step-completed_at.
        IF ls_step-task = gc_task-approve.
          ls_run-result = ls_step-decision.
        ENDIF.
      ENDLOOP.

      " Only final decisions count as the result of a run.
      IF ls_run-result <> gc_decision-approved
          AND ls_run-result <> gc_decision-rejected
          AND ls_run-result <> gc_decision-rework.
        CLEAR ls_run-result.
      ENDIF.
      ls_run-result_text = get_decision_text( ls_run-result ).

      IF ls_run-status = gc_run_status-running.
        CLEAR: ls_run-ended_on,
               ls_run-ended_at.
      ENDIF.

      ls_run-icon = COND #(
        WHEN ls_run-status = gc_run_status-running    THEN icon_time
        WHEN ls_run-result = gc_decision-rejected     THEN icon_cancel
        WHEN ls_run-result = gc_decision-approved     THEN icon_okay
        WHEN ls_run-result = gc_decision-rework       THEN icon_system_undo
        ELSE icon_led_inactive ).

      ls_run-submitter = determine_submitter( is_head    = ls_head
                                              iv_run     = lv_run
                                              iv_creator = lv_creator
                                              it_changes = it_changes ).

      APPEND ls_run TO cs_info-runs.
    ENDLOOP.
  ENDMETHOD.


  METHOD determine_submitter.
    DATA lv_initiator TYPE syuname.

    CLEAR rv_name.

    " Preferably the initiator from the workflow header.
    IF is_head-wi_creator(2) = gc_agent_type_user.
      lv_initiator = is_head-wi_creator+2.
    ELSEIF is_head-wi_cruser IS NOT INITIAL
        AND is_head-wi_cruser <> gc_user_wfrt
        AND is_head-wi_cruser <> gc_user_wf_batch.
      lv_initiator = is_head-wi_cruser.
    ENDIF.

    IF lv_initiator IS NOT INITIAL.
      rv_name = resolve_user( lv_initiator ).
      RETURN.
    ENDIF.

    " Fallback for technically started workflows: run 1 was submitted by
    " the creator of the document, follow-up runs by the user of the newest
    " change document before the run started.
    IF iv_run = 1.
      rv_name = resolve_user( iv_creator ).
      RETURN.
    ENDIF.

    LOOP AT it_changes INTO DATA(ls_change).
      IF ls_change-udate < is_head-wi_cd
          OR ( ls_change-udate = is_head-wi_cd AND ls_change-utime <= is_head-wi_ct ).
        rv_name = resolve_user( ls_change-username ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD map_decision.
    CASE iv_key.
      WHEN gc_result_key-approved.
        rv_decision = gc_decision-approved.
      WHEN gc_result_key-rejected.
        rv_decision = gc_decision-rejected.
      WHEN gc_result_key-rework.
        rv_decision = gc_decision-rework.
      WHEN OTHERS.
        rv_decision = gc_decision-none.
    ENDCASE.
  ENDMETHOD.


  METHOD get_decision_text.
    rv_text = SWITCH #( iv_decision
                        WHEN gc_decision-approved    THEN text( gc_msg-dec_approved )
                        WHEN gc_decision-rejected    THEN text( gc_msg-dec_rejected )
                        WHEN gc_decision-rework      THEN text( gc_msg-dec_rework )
                        WHEN gc_decision-resubmitted THEN text( gc_msg-dec_resubmitted )
                        ELSE `` ).
  ENDMETHOD.


  METHOD get_wi_status_text.
    rv_text = SWITCH #( iv_status
                        WHEN gc_wi_status-ready     THEN text( gc_msg-wi_open )
                        WHEN gc_wi_status-selected  THEN text( gc_msg-wi_reserved )
                        WHEN gc_wi_status-started   THEN text( gc_msg-wi_in_process )
                        WHEN gc_wi_status-completed THEN text( gc_msg-wi_completed )
                        WHEN gc_wi_status-cancelled THEN text( gc_msg-wi_cancelled )
                        WHEN gc_wi_status-error     THEN text( gc_msg-wi_error )
                        WHEN gc_wi_status-waiting   THEN text( gc_msg-wi_waiting )
                        ELSE |{ iv_status }| ).
  ENDMETHOD.


  METHOD resolve_user.
    DATA ls_address TYPE bapiaddr3.
    DATA lt_return  TYPE STANDARD TABLE OF bapiret2.

    CLEAR rv_name.

    IF iv_uname IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_cached) = VALUE #( gt_user_cache[ uname = iv_uname ] OPTIONAL ).
    IF ls_cached-uname IS NOT INITIAL.
      rv_name = ls_cached-name.
      RETURN.
    ENDIF.

    " USER_ADDR is empty for users maintained via business partner
    " (SU01 with BP assignment), therefore the SU01 read logic of the BAPI.
    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username = iv_uname
      IMPORTING
        address  = ls_address
      TABLES
        return   = lt_return.

    rv_name = COND #( WHEN ls_address-fullname IS NOT INITIAL
                      THEN |{ ls_address-fullname }|
                      ELSE |{ iv_uname }| ).

    INSERT VALUE #( uname = iv_uname
                    name  = rv_name ) INTO TABLE gt_user_cache.
  ENDMETHOD.


  METHOD get_domain_text.
    DATA lt_dfies TYPE STANDARD TABLE OF dfies.
    DATA lt_dd07v TYPE STANDARD TABLE OF dd07v.

    " Fixed value text from the domain of the VBAK field: release
    " independent, no hard coded status values.
    CALL FUNCTION 'DDIF_FIELDINFO_GET'
      EXPORTING
        tabname   = 'VBAK'
        fieldname = iv_fieldname
        langu     = sy-langu
      TABLES
        dfies_tab = lt_dfies
      EXCEPTIONS
        OTHERS    = 1.

    DATA(ls_dfies) = VALUE #( lt_dfies[ 1 ] OPTIONAL ).
    IF ls_dfies-domname IS INITIAL.
      rv_text = iv_value.
      RETURN.
    ENDIF.

    CALL FUNCTION 'DD_DOMVALUES_GET'
      EXPORTING
        domname   = ls_dfies-domname
        text      = abap_true
        langu     = sy-langu
      TABLES
        dd07v_tab = lt_dd07v
      EXCEPTIONS
        OTHERS    = 1.

    DATA(ls_dd07v) = VALUE #( lt_dd07v[ domvalue_l = iv_value ] OPTIONAL ).
    rv_text = COND #( WHEN ls_dd07v-ddtext IS NOT INITIAL
                      THEN ls_dd07v-ddtext
                      ELSE iv_value ).
  ENDMETHOD.


  METHOD get_reason_text.
    CLEAR rv_text.

    IF iv_reason IS INITIAL.
      RETURN.
    ENDIF.

    " Text table of the approval reason customizing (view V_SDAPMAPRR).
    SELECT SINGLE description
      FROM sdapmaprr_t
      WHERE language            = @sy-langu
        AND apm_approval_reason = @iv_reason
      INTO @DATA(lv_text).

    rv_text = COND #( WHEN sy-subrc = 0 AND lv_text IS NOT INITIAL
                      THEN lv_text
                      ELSE |{ iv_reason }| ).
  ENDMETHOD.


  METHOD append_to_list.
    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.

    cv_list = COND #( WHEN cv_list IS INITIAL
                      THEN iv_value
                      ELSE |{ cv_list }, { iv_value }| ).
  ENDMETHOD.


  METHOD text.
    MESSAGE ID gc_msgid TYPE 'I' NUMBER iv_msgno INTO rv_text.
  ENDMETHOD.


  METHOD log_error.
    DATA ls_log    TYPE bal_s_log.
    DATA lv_handle TYPE balloghndl.
    DATA lt_handle TYPE bal_t_logh.

    " Each distinct error is logged once per session.
    DATA(lv_log_key) = |{ iv_vbeln }#{ iv_context }#{ iv_text }|.
    IF line_exists( gt_logged_errors[ table_line = lv_log_key ] ).
      RETURN.
    ENDIF.
    INSERT lv_log_key INTO TABLE gt_logged_errors.

    ls_log-object    = gc_log_object.
    ls_log-subobject = gc_log_subobject.
    ls_log-extnumber = |VBELN { iv_vbeln }|.
    ls_log-aluser    = sy-uname.
    ls_log-alprog    = sy-repid.

    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log      = ls_log
      IMPORTING
        e_log_handle = lv_handle
      EXCEPTIONS
        OTHERS       = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CALL FUNCTION 'BAL_LOG_MSG_ADD_FREE_TEXT'
      EXPORTING
        i_log_handle = lv_handle
        i_msgty      = 'E'
        i_text       = |{ iv_context }: { iv_text }|
      EXCEPTIONS
        OTHERS       = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Save on a secondary DB connection so that the log is persisted at
    " once without a COMMIT WORK in the LUW of VA03.
    APPEND lv_handle TO lt_handle.
    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle       = lt_handle
        i_2th_connection     = abap_true
        i_2th_connect_commit = abap_true
      EXCEPTIONS
        OTHERS               = 0.
  ENDMETHOD.

ENDCLASS.
