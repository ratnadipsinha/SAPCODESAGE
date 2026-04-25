FUNCTION Z_VENDOR_MASTER_READ.
*"----------------------------------------------------------------------
*"  IMPORTING
*"     VALUE(IV_LIFNR)    TYPE  LFA1-LIFNR
*"     VALUE(IV_BUKRS)    TYPE  LFB1-BUKRS  OPTIONAL
*"     VALUE(IV_EKORG)    TYPE  LFM1-EKORG  OPTIONAL
*"  EXPORTING
*"     ES_LFA1            TYPE  LFA1
*"     ES_LFB1            TYPE  LFB1
*"     ES_LFM1            TYPE  LFM1
*"  EXCEPTIONS
*"     VENDOR_NOT_FOUND   = 1
*"     COMPANY_DATA_MISSING = 2
*"     SYSTEM_ERROR       = 3
*"----------------------------------------------------------------------

  DATA: ls_lfa1 TYPE lfa1,
        ls_lfb1 TYPE lfb1,
        ls_lfm1 TYPE lfm1.

  " Validate input
  IF iv_lifnr IS INITIAL.
    RAISE system_error.
  ENDIF.

  " Read general vendor master (client-independent)
  SELECT SINGLE *
    FROM lfa1
    INTO ls_lfa1
   WHERE lifnr = iv_lifnr.

  IF sy-subrc <> 0.
    RAISE vendor_not_found.
  ENDIF.

  " Read company code data if requested
  IF iv_bukrs IS NOT INITIAL.
    SELECT SINGLE *
      FROM lfb1
      INTO ls_lfb1
     WHERE lifnr = iv_lifnr
       AND bukrs = iv_bukrs.

    IF sy-subrc <> 0.
      RAISE company_data_missing.
    ENDIF.
  ENDIF.

  " Read purchasing organisation data if requested
  IF iv_ekorg IS NOT INITIAL.
    SELECT SINGLE *
      FROM lfm1
      INTO ls_lfm1
     WHERE lifnr = iv_lifnr
       AND ekorg = iv_ekorg.
    " Purchasing org data absence is not an error — vendor may not be set up for purchasing
  ENDIF.

  " Export results
  es_lfa1 = ls_lfa1.
  es_lfb1 = ls_lfb1.
  es_lfm1 = ls_lfm1.

ENDFUNCTION.
