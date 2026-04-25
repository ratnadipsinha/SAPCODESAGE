*&---------------------------------------------------------------------*
*& Class          ZCL_INVOICE_PROCESSOR
*& Package        ZFI_INVOICE
*& Author         FI_TEAM
*& Date           2025-11-15
*& Description    Handles invoice validation and posting for S/4HANA.
*&                Validates: amount vs PO value, payment terms, duplicate
*&                invoices, and tax codes before calling BAPI_INCOMINGINVOICE_CREATE.
*&---------------------------------------------------------------------*
CLASS zcl_invoice_processor DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_invoice_item,
        po_number   TYPE ebeln,
        po_item     TYPE ebelp,
        quantity    TYPE menge_d,
        amount      TYPE wrbtr,
        tax_code    TYPE mwskz,
      END OF ty_invoice_item,
      tt_invoice_items TYPE STANDARD TABLE OF ty_invoice_item WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_posting_result,
        doc_number  TYPE belnr_d,
        fiscal_year TYPE gjahr,
        company_code TYPE bukrs,
        success     TYPE boole_d,
        message     TYPE string,
      END OF ty_posting_result.

    METHODS constructor
      IMPORTING
        iv_bukrs    TYPE bukrs
        iv_lifnr    TYPE lifnr
      RAISING
        zcx_base_error.

    METHODS validate_invoice
      IMPORTING
        iv_gross_amount  TYPE wrbtr
        iv_currency      TYPE waers
        iv_invoice_date  TYPE bldat
        iv_reference     TYPE xblnr
        it_items         TYPE tt_invoice_items
      RAISING
        zcx_base_error.

    METHODS post_invoice
      IMPORTING
        iv_gross_amount  TYPE wrbtr
        iv_currency      TYPE waers
        iv_invoice_date  TYPE bldat
        iv_reference     TYPE xblnr
        it_items         TYPE tt_invoice_items
      RETURNING
        VALUE(rs_result)  TYPE ty_posting_result
      RAISING
        zcx_base_error.

  PRIVATE SECTION.

    DATA mv_bukrs  TYPE bukrs.
    DATA mv_lifnr  TYPE lifnr.
    DATA ms_vendor TYPE zs_vendor_master.

    CONSTANTS c_tolerance_pct TYPE p DECIMALS 2 VALUE '5.00'.

    METHODS check_duplicate_invoice
      IMPORTING
        iv_reference    TYPE xblnr
        iv_invoice_date TYPE bldat
      RAISING
        zcx_base_error.

    METHODS validate_item_against_po
      IMPORTING
        is_item TYPE ty_invoice_item
      RAISING
        zcx_base_error.

ENDCLASS.


CLASS zcl_invoice_processor IMPLEMENTATION.

  METHOD constructor.
    mv_bukrs = iv_bukrs.
    mv_lifnr = iv_lifnr.

    " Load vendor master using central FM
    CALL FUNCTION 'Z_VENDOR_MASTER_READ'
      EXPORTING
        iv_lifnr = iv_lifnr
        iv_bukrs = iv_bukrs
      IMPORTING
        es_vendor = ms_vendor
      EXCEPTIONS
        vendor_not_found     = 1
        company_data_missing = 2
        OTHERS               = 3.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message = |Vendor { iv_lifnr } not found or has no data for company code { iv_bukrs }|.
    ENDIF.

    " Reject if vendor is payment-blocked
    IF ms_vendor-blocked = 'Z'.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message = |Vendor { iv_lifnr } is blocked for payment. Release in XK05 first.|.
    ENDIF.
  ENDMETHOD.

  METHOD validate_invoice.

    " --- Validate reference number not blank ---
    IF iv_reference IS INITIAL.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message = 'Invoice reference (external document number) is required'.
    ENDIF.

    " --- Check for duplicate invoice ---
    check_duplicate_invoice( iv_reference    = iv_reference
                             iv_invoice_date = iv_invoice_date ).

    " --- Validate payment terms ---
    CALL FUNCTION 'Z_VALIDATE_VENDOR_PAYTERMS'
      EXPORTING
        iv_lifnr = mv_lifnr
        iv_bukrs = mv_bukrs
        iv_zterm = ms_vendor-pay_terms
      IMPORTING
        ev_valid   = DATA(lv_valid)
        ev_message = DATA(lv_msg)
      EXCEPTIONS
        vendor_not_found = 1
        OTHERS           = 2.

    IF sy-subrc <> 0 OR lv_valid = abap_false.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message = |Payment terms validation failed: { lv_msg }|.
    ENDIF.

    " --- Validate each item against its PO ---
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      validate_item_against_po( <ls_item> ).
    ENDLOOP.

  ENDMETHOD.

  METHOD post_invoice.
    validate_invoice( iv_gross_amount = iv_gross_amount
                      iv_currency     = iv_currency
                      iv_invoice_date = iv_invoice_date
                      iv_reference    = iv_reference
                      it_items        = it_items ).

    " --- Build BAPI header ---
    DATA(ls_header) = VALUE bapi_incinv_create_header(
      invoice_ind  = abap_true
      comp_code    = mv_bukrs
      doc_date     = iv_invoice_date
      pstng_date   = sy-datum
      ref_doc_no   = iv_reference
      gross_amount = iv_gross_amount
      currency     = iv_currency
      pmnttrms     = ms_vendor-pay_terms ).

    " --- Build BAPI item table ---
    DATA lt_bapi_items TYPE STANDARD TABLE OF bapi_incinv_create_item.
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      APPEND VALUE #(
        invoice_doc_item = sy-tabix
        po_number        = <ls_item>-po_number
        po_item          = <ls_item>-po_item
        quantity         = <ls_item>-quantity
        po_unit          = 'EA'
        item_amount      = <ls_item>-amount
        tax_code         = <ls_item>-tax_code )
      TO lt_bapi_items.
    ENDLOOP.

    " --- Call standard BAPI ---
    DATA lt_return TYPE STANDARD TABLE OF bapiret2.
    CALL FUNCTION 'BAPI_INCOMINGINVOICE_CREATE'
      EXPORTING headerdata  = ls_header
      IMPORTING invoicedocnumber = rs_result-doc_number
                fiscalyear       = rs_result-fiscal_year
      TABLES    itemdata    = lt_bapi_items
                return      = lt_return.

    " --- Evaluate BAPI return ---
    READ TABLE lt_return ASSIGNING FIELD-SYMBOL(<ls_ret>)
      WITH KEY type = 'E'.
    IF sy-subrc = 0.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message = |Invoice posting failed: { <ls_ret>-message }|.
    ENDIF.

    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = abap_true.

    rs_result-company_code = mv_bukrs.
    rs_result-success      = abap_true.
    rs_result-message      = |Invoice { rs_result-doc_number } / { rs_result-fiscal_year } posted|.
  ENDMETHOD.

  METHOD check_duplicate_invoice.
    " Check RBKP for existing invoice with same reference + vendor + company code
    SELECT SINGLE belnr FROM rbkp
      INTO @DATA(lv_existing)
      WHERE lifnr  = @mv_lifnr
        AND bukrs  = @mv_bukrs
        AND xblnr  = @iv_reference
        AND bldat  = @iv_invoice_date
        AND stblg  = space.  " not reversed

    IF sy-subrc = 0.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message =
          |Duplicate invoice: reference { iv_reference } already posted as { lv_existing }|.
    ENDIF.
  ENDMETHOD.

  METHOD validate_item_against_po.
    " Read PO item net value for tolerance check
    SELECT SINGLE netwr, menge, meins
      FROM ekpo
      INTO @DATA(ls_ekpo)
      WHERE ebeln = @is_item-po_number
        AND ebelp = @is_item-po_item.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_base_error
        EXPORTING iv_message =
          |PO { is_item-po_number } item { is_item-po_item } not found in EKPO|.
    ENDIF.

    " Check amount within tolerance
    IF ls_ekpo-netwr > 0.
      DATA(lv_variance_pct) =
        abs( ( is_item-amount - ls_ekpo-netwr ) / ls_ekpo-netwr * 100 ).

      IF lv_variance_pct > c_tolerance_pct.
        RAISE EXCEPTION TYPE zcx_base_error
          EXPORTING iv_message =
            |Invoice amount { is_item-amount } for PO { is_item-po_number } item { is_item-po_item } | &&
            |exceeds PO value { ls_ekpo-netwr } by { lv_variance_pct }% | &&
            |(tolerance: { c_tolerance_pct }%)|.
      ENDIF.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
