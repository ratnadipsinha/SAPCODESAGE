FUNCTION Z_VALIDATE_VENDOR_PAYTERMS.
*"----------------------------------------------------------------------
*"  IMPORTING
*"     VALUE(IV_LIFNR)    TYPE  LFB1-LIFNR
*"     VALUE(IV_BUKRS)    TYPE  LFB1-BUKRS
*"     VALUE(IV_ZTERM)    TYPE  LFB1-ZTERM
*"  EXPORTING
*"     EV_VALID           TYPE  ABAP_BOOL
*"     EV_MESSAGE         TYPE  BAPI_MSG
*"  EXCEPTIONS
*"     VENDOR_NOT_FOUND   = 1
*"     INVALID_PAYTERMS   = 2
*"     SYSTEM_ERROR       = 3
*"----------------------------------------------------------------------

  DATA: ls_lfb1  TYPE lfb1,
        ls_t052  TYPE t052,
        lv_zterm TYPE t052-zterm.

  " Default to invalid
  ev_valid = abap_false.

  " 1. Check vendor exists in this company code
  SELECT SINGLE zterm
    FROM lfb1
    INTO ls_lfb1-zterm
   WHERE lifnr = iv_lifnr
     AND bukrs = iv_bukrs.

  IF sy-subrc <> 0.
    ev_message = |Vendor { iv_lifnr } not found in company code { iv_bukrs }|.
    RAISE vendor_not_found.
  ENDIF.

  " 2. Determine which payment terms to validate
  " If caller passes a specific term use that, otherwise use the vendor default
  IF iv_zterm IS NOT INITIAL.
    lv_zterm = iv_zterm.
  ELSE.
    lv_zterm = ls_lfb1-zterm.
  ENDIF.

  " 3. Check payment terms exist in T052 (payment terms table)
  SELECT SINGLE *
    FROM t052
    INTO ls_t052
   WHERE zterm = lv_zterm
     AND spras = sy-langu.

  IF sy-subrc <> 0.
    ev_message = |Payment terms { lv_zterm } not found in T052 for language { sy-langu }|.
    RAISE invalid_payterms.
  ENDIF.

  " 4. Validate that the payment terms are not blocked
  " Custom config table ZMM_BLOCKED_PAYTERMS holds org-specific exclusions
  SELECT SINGLE zterm
    FROM zmm_blocked_payterms
    INTO lv_zterm
   WHERE zterm  = lv_zterm
     AND bukrs  = iv_bukrs
     AND active = abap_true.

  IF sy-subrc = 0.
    ev_message = |Payment terms { lv_zterm } are blocked for company code { iv_bukrs }|.
    RAISE invalid_payterms.
  ENDIF.

  " All checks passed
  ev_valid   = abap_true.
  ev_message = |Payment terms { lv_zterm } are valid for vendor { iv_lifnr }|.

ENDFUNCTION.
