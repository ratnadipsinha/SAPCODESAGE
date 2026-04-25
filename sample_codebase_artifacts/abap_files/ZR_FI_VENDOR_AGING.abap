*&---------------------------------------------------------------------*
*& Report         ZR_FI_VENDOR_AGING
*& Package        ZFI_REPORTS
*& Author         FI_TEAM
*& Date           2025-03-10
*& Desc           Vendor accounts payable aging report.
*&                Groups open items into buckets:
*&                  Not Due / 0-30 / 31-60 / 61-90 / 90+ days overdue.
*&                Used by the AP team for month-end reconciliation.
*&---------------------------------------------------------------------*
REPORT zr_fi_vendor_aging.

TYPES: BEGIN OF ty_aging_line,
         lifnr    TYPE lifnr,
         vname    TYPE name1,
         bukrs    TYPE bukrs,
         belnr    TYPE belnr_d,
         bldat    TYPE bldat,
         faedt    TYPE faedt,     " Due date
         wrbtr    TYPE wrbtr,
         waers    TYPE waers,
         days_od  TYPE i,         " Days overdue (negative = not yet due)
         bucket   TYPE char10,    " NOT_DUE / 0_30 / 31_60 / 61_90 / 90PLUS
       END OF ty_aging_line.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_bukrs FOR ( TYPE bukrs ) OBLIGATORY,
                  s_lifnr FOR ( TYPE lifnr ).
  PARAMETERS:     p_keydate TYPE datum DEFAULT sy-datum.
SELECTION-SCREEN END OF BLOCK b1.

DATA: gt_aging   TYPE STANDARD TABLE OF ty_aging_line,
      go_alv     TYPE REF TO cl_salv_table.

START-OF-SELECTION.
  PERFORM fetch_open_items.
  PERFORM calculate_aging.
  PERFORM display_alv.

*&---------------------------------------------------------------------*
FORM fetch_open_items.
  " BSIK = open vendor line items (cleared items in BSAK)
  SELECT
      k~lifnr, k~bukrs, k~belnr, k~bldat,
      k~wrbtr, k~waers,
      k~zfbdt, k~zbd1t, k~zbd2t  " baseline date + payment terms days
    FROM bsik AS k
    INTO TABLE @DATA(lt_bsik)
    WHERE k~bukrs IN @s_bukrs
      AND k~lifnr IN @s_lifnr
      AND k~bldat <= @p_keydate.  " posted on or before key date

  LOOP AT lt_bsik ASSIGNING FIELD-SYMBOL(<ls>).
    APPEND VALUE ty_aging_line(
      lifnr = <ls>-lifnr
      bukrs = <ls>-bukrs
      belnr = <ls>-belnr
      bldat = <ls>-bldat
      wrbtr = <ls>-wrbtr
      waers = <ls>-waers
      " Calculate due date: baseline date + net payment days
      faedt = <ls>-zfbdt + <ls>-zbd1t ) TO gt_aging.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
FORM calculate_aging.
  LOOP AT gt_aging ASSIGNING FIELD-SYMBOL(<ls>).
    " Days overdue = key date - due date (positive = overdue)
    <ls>-days_od = p_keydate - <ls>-faedt.

    <ls>-bucket = SWITCH #( <ls>-days_od
      WHEN IS BETWEEN -9999 AND -1 THEN 'NOT_DUE'
      WHEN IS BETWEEN 0     AND 30 THEN '0_30'
      WHEN IS BETWEEN 31    AND 60 THEN '31_60'
      WHEN IS BETWEEN 61    AND 90 THEN '61_90'
      ELSE                              '90PLUS' ).

    " Enrich vendor name
    CALL FUNCTION 'Z_VENDOR_MASTER_READ'
      EXPORTING  iv_lifnr   = <ls>-lifnr
                 iv_bukrs   = <ls>-bukrs
      IMPORTING  es_vendor  = DATA(ls_vend)
      EXCEPTIONS OTHERS     = 1.
    IF sy-subrc = 0. <ls>-vname = ls_vend-name1. ENDIF.
  ENDLOOP.

  SORT gt_aging BY lifnr bukrs days_od DESCENDING.
ENDFORM.

*&---------------------------------------------------------------------*
FORM display_alv.
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = go_alv
        CHANGING  t_table      = gt_aging ).
      go_alv->get_columns( )->set_optimize( abap_true ).
      go_alv->get_display_settings( )->set_striped_pattern( cl_salv_display_settings=>true ).
      go_alv->display( ).
    CATCH cx_salv_msg INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.
