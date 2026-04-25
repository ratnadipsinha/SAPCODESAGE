*&---------------------------------------------------------------------*
*& Class          ZCL_PO_STATUS_HANDLER
*& Package        ZMM_PO_PROCESSING
*& Author         MM_TEAM
*& Date           2025-10-01
*& Description    Manages Purchase Order status transitions.
*&                Enforces the allowed workflow:
*&                  OP (Open) -> SN (Sent) -> LS (Partially Delivered)
*&                  -> GR (Goods Received) -> IV (Invoice Verified)
*&                  -> CL (Closed)
*&                Raises ZCX_BASE_ERROR for invalid transitions.
*&---------------------------------------------------------------------*
CLASS zcl_po_status_handler DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_status_entry,
        ebeln      TYPE ebeln,
        old_status TYPE char2,
        new_status TYPE char2,
        changed_by TYPE uname,
        changed_at TYPE timestamp,
        reason     TYPE string,
      END OF ty_status_entry.

    CLASS-DATA gt_audit_log TYPE STANDARD TABLE OF ty_status_entry.

    METHODS constructor
      IMPORTING
        iv_ebeln TYPE ebeln
      RAISING
        zcx_base_error.

    METHODS get_current_status
      RETURNING VALUE(rv_status) TYPE char2.

    METHODS get_po_header
      RETURNING VALUE(rs_header) TYPE ekko.

    METHODS apply_status_change
      IMPORTING
        iv_new_status TYPE char2
        iv_reason     TYPE string OPTIONAL
      RAISING
        zcx_base_error.

    METHODS close_po
      IMPORTING
        iv_reason TYPE string DEFAULT 'Manually closed'
      RAISING
        zcx_base_error.

    CLASS-METHODS get_status_text
      IMPORTING iv_status        TYPE char2
      RETURNING VALUE(rv_text)   TYPE string.

  PRIVATE SECTION.

    DATA mv_ebeln   TYPE ebeln.
    DATA ms_header  TYPE ekko.

    " Allowed transitions: from -> to
    CLASS-DATA gt_transitions TYPE SORTED TABLE OF string
      WITH NON-UNIQUE KEY table_line.

    CLASS-METHODS class_constructor.

    METHODS validate_transition
      IMPORTING
        iv_from          TYPE char2
        iv_to            TYPE char2
      RETURNING
        VALUE(rv_allowed) TYPE boole_d.

    METHODS write_audit_entry
      IMPORTING
        iv_old_status TYPE char2
        iv_new_status TYPE char2
        iv_reason     TYPE string.

ENDCLASS.


CLASS zcl_po_status_handler IMPLEMENTATION.

  METHOD class_constructor.
    " Define all permitted status transitions
    gt_transitions = VALUE #(
      ( |OP-SN| )   " Open -> Sent to vendor
      ( |SN-LS| )   " Sent -> Partially delivered
      ( |SN-GR| )   " Sent -> Fully goods-received (skip partial)
      ( |LS-GR| )   " Partial -> Fully goods-received
      ( |GR-IV| )   " GR -> Invoice verified
      ( |IV-CL| )   " Invoice verified -> Closed
      ( |OP-CL| )   " Open -> Closed (cancelled without delivery)
      ( |SN-CL| ) ).
  ENDMETHOD.

  METHOD constructor.
    mv_ebeln = iv_ebeln.

    SELECT SINGLE *
      FROM ekko
      INTO ms_header
      WHERE ebeln = mv_ebeln.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message = |Purchase order { iv_ebeln } not found in EKKO|.
    ENDIF.
  ENDMETHOD.

  METHOD get_current_status.
    rv_status = ms_header-statu.
  ENDMETHOD.

  METHOD get_po_header.
    rs_header = ms_header.
  ENDMETHOD.

  METHOD apply_status_change.
    DATA(lv_old_status) = ms_header-statu.

    " Validate the transition is allowed
    IF validate_transition( iv_from = lv_old_status iv_to = iv_new_status ) = abap_false.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message =
          |Invalid status transition for PO { mv_ebeln }: | &&
          |{ get_status_text( lv_old_status ) } -> { get_status_text( iv_new_status ) }. | &&
          |Allowed transitions from { lv_old_status }: | &&
          |{ REDUCE string( INIT s = `` FOR t IN gt_transitions
               WHERE ( table_line CP |{ lv_old_status }-*| )
               NEXT s = COND #( WHEN s = `` THEN t+3 ELSE s && `, ` && t+3 ) ) }|.
    ENDIF.

    " Update EKKO status
    UPDATE ekko
      SET statu = iv_new_status
      WHERE ebeln = mv_ebeln.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message = |Failed to update status for PO { mv_ebeln }|
                  iv_technical_msg = |UPDATE ekko returned SY-SUBRC { sy-subrc }|.
    ENDIF.

    ms_header-statu = iv_new_status.
    write_audit_entry( iv_old_status = lv_old_status
                       iv_new_status = iv_new_status
                       iv_reason     = iv_reason ).
  ENDMETHOD.

  METHOD close_po.
    apply_status_change( iv_new_status = 'CL' iv_reason = iv_reason ).
  ENDMETHOD.

  METHOD validate_transition.
    rv_allowed = xsdbool( |{ iv_from }-{ iv_to }| IN gt_transitions ).
  ENDMETHOD.

  METHOD get_status_text.
    rv_text = SWITCH #( iv_status
      WHEN 'OP' THEN 'Open'
      WHEN 'SN' THEN 'Sent to Vendor'
      WHEN 'LS' THEN 'Partially Delivered'
      WHEN 'GR' THEN 'Goods Received'
      WHEN 'IV' THEN 'Invoice Verified'
      WHEN 'CL' THEN 'Closed'
      ELSE            |Unknown ({ iv_status })| ).
  ENDMETHOD.

  METHOD write_audit_entry.
    DATA(ls_entry) = VALUE ty_status_entry(
      ebeln      = mv_ebeln
      old_status = iv_old_status
      new_status = iv_new_status
      changed_by = sy-uname
      reason     = iv_reason ).
    GET TIME STAMP FIELD ls_entry-changed_at.
    APPEND ls_entry TO gt_audit_log.
  ENDMETHOD.

ENDCLASS.
