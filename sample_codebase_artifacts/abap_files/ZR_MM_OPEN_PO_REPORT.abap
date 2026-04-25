*&---------------------------------------------------------------------*
*& Report         ZR_MM_OPEN_PO_REPORT
*& Package        ZMM_REPORTS
*& Author         MM_TEAM
*& Date           2025-05-01
*& Desc           Displays all open purchase orders with outstanding
*&                delivery quantities. Supports plant and vendor filters.
*&                Output: ALV grid with drill-down to ME23N.
*&---------------------------------------------------------------------*
REPORT zr_mm_open_po_report.

"--- Types -----------------------------------------------------------
TYPES: BEGIN OF ty_po_line,
         ebeln   TYPE ebeln,         " PO number
         ebelp   TYPE ebelp,         " PO item
         lifnr   TYPE lifnr,         " Vendor
         vname   TYPE name1,         " Vendor name
         werks   TYPE werks_d,       " Plant
         matnr   TYPE matnr,         " Material
         maktx   TYPE maktx,         " Material description
         menge   TYPE menge_d,       " Ordered quantity
         wemng   TYPE menge_d,       " Goods-received quantity
         remng   TYPE menge_d,       " Remaining open quantity
         netpr   TYPE bprei,         " Net price
         waers   TYPE waers,         " Currency
         eindt   TYPE eindt,         " Delivery date
         overdue TYPE boole_d,       " X = delivery date passed
       END OF ty_po_line.

"--- Selection screen ------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_werks FOR  ( TYPE werks_d ),
                  s_lifnr FOR  ( TYPE lifnr ),
                  s_eindt FOR  ( TYPE eindt ) DEFAULT sy-datum.
  PARAMETERS:     p_overdue AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b1.

"--- Global data -----------------------------------------------------
DATA: gt_result  TYPE STANDARD TABLE OF ty_po_line,
      go_alv     TYPE REF TO cl_salv_table.

"--- Main ------------------------------------------------------------
START-OF-SELECTION.
  PERFORM fetch_data.
  PERFORM display_alv.

*&---------------------------------------------------------------------*
FORM fetch_data.
  DATA lt_raw TYPE STANDARD TABLE OF ty_po_line.

  " Join PO header (EKKO), item (EKPO), and GR history (EKBE)
  SELECT
      h~ebeln,  i~ebelp,
      h~lifnr,  i~werks,
      i~matnr,  i~menge,
      i~wemng,  i~netpr,
      h~waers,  i~eindt
    FROM ekko AS h
    INNER JOIN ekpo AS i ON i~ebeln = h~ebeln
    INTO TABLE @lt_raw
    WHERE h~loekz  = space          " not deleted
      AND h~bstyp  = 'F'            " standard PO
      AND i~loekz  = space          " item not deleted
      AND i~elikz  = space          " not fully delivered
      AND i~wemng  < i~menge        " open quantity exists
      AND i~werks  IN @s_werks
      AND h~lifnr  IN @s_lifnr
      AND i~eindt  IN @s_eindt.

  IF sy-subrc <> 0 OR lt_raw IS INITIAL.
    MESSAGE 'No open purchase orders found for the selected criteria' TYPE 'I'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " Enrich with vendor name and material description
  LOOP AT lt_raw ASSIGNING FIELD-SYMBOL(<ls>).
    <ls>-remng = <ls>-menge - <ls>-wemng.
    <ls>-overdue = xsdbool( <ls>-eindt < sy-datum ).

    IF p_overdue = abap_true AND <ls>-overdue = abap_false.
      DELETE lt_raw.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'Z_VENDOR_MASTER_READ'
      EXPORTING  iv_lifnr   = <ls>-lifnr
      IMPORTING  es_vendor  = DATA(ls_vend)
      EXCEPTIONS OTHERS     = 1.
    IF sy-subrc = 0. <ls>-vname = ls_vend-name1. ENDIF.

    SELECT SINGLE maktx FROM makt
      INTO @<ls>-maktx
      WHERE matnr  = @<ls>-matnr
        AND spras  = @sy-langu.
  ENDLOOP.

  gt_result = lt_raw.
ENDFORM.

*&---------------------------------------------------------------------*
FORM display_alv.
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = go_alv
        CHANGING  t_table      = gt_result ).

      " Configure columns
      DATA(lo_cols) = go_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      " Colour overdue rows red
      DATA(lo_disp) = go_alv->get_display_settings( ).
      lo_disp->set_striped_pattern( cl_salv_display_settings=>true ).

      " Add double-click navigation to ME23N
      DATA(lo_events) = go_alv->get_event( ).
      SET HANDLER lcl_alv_events=>on_double_click FOR lo_events.

      go_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.

"--- ALV event handler -----------------------------------------------
CLASS lcl_alv_events DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
ENDCLASS.

CLASS lcl_alv_events IMPLEMENTATION.
  METHOD on_double_click.
    READ TABLE gt_result ASSIGNING FIELD-SYMBOL(<ls>) INDEX row.
    CHECK sy-subrc = 0.
    " Open PO in ME23N
    CALL FUNCTION 'CALL_TRANSACTION_USING'
      EXPORTING tcode   = 'ME23N'
                skip_SCREEN = ' '
      TABLES   using   = VALUE rsparameters_tt(
        ( selname = 'P_EBELN' kind = 'P' sign = 'I'
          option = 'EQ' low = <ls>-ebeln ) ).
  ENDMETHOD.
ENDCLASS.
