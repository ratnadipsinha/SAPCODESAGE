FUNCTION z_validate_vendor_payterms.
*"----------------------------------------------------------------------
*" Function Module : Z_VALIDATE_VENDOR_PAYTERMS
*" Function Group  : ZFM_VENDOR_TOOLS
*" Author          : FI_TEAM
*" Date            : 2025-08-15
*" Description     : Validates that a payment term key is configured
*"                   in T052 and is compatible with the vendor's
*"                   company code settings in LFB1.
*"                   Used by invoice entry and PO creation.
*"----------------------------------------------------------------------
*"  IMPORTING
*"    VALUE(IV_LIFNR)   TYPE  LIFNR     Vendor account number
*"    VALUE(IV_BUKRS)   TYPE  BUKRS     Company code
*"    VALUE(IV_ZTERM)   TYPE  DZTERM    Payment term key to validate
*"  EXPORTING
*"    VALUE(EV_VALID)   TYPE  BOOLE_D   X = valid, space = invalid
*"    VALUE(EV_MESSAGE) TYPE  STRING    Validation result message
*"  EXCEPTIONS
*"    VENDOR_NOT_FOUND  = 1
*"    OTHERS            = 2
*"----------------------------------------------------------------------
  DATA: ls_lfa1  TYPE lfa1,
        ls_lfb1  TYPE lfb1,
        ls_t052  TYPE t052.

  CLEAR: ev_valid, ev_message.

  " --- Step 1: Check vendor exists and is not deleted ---
  SELECT SINGLE lifnr, loevm, sperr
    FROM lfa1 INTO CORRESPONDING FIELDS OF ls_lfa1
    WHERE lifnr = iv_lifnr.

  IF sy-subrc <> 0 OR ls_lfa1-loevm = 'X'.
    RAISE vendor_not_found.
  ENDIF.

  " --- Step 2: Check vendor has company code data ---
  SELECT SINGLE lifnr, bukrs, zterm
    FROM lfb1 INTO CORRESPONDING FIELDS OF ls_lfb1
    WHERE lifnr = iv_lifnr AND bukrs = iv_bukrs.

  IF sy-subrc <> 0.
    ev_valid   = abap_false.
    ev_message = |Vendor { iv_lifnr } has no data for company code { iv_bukrs }|.
    RETURN.
  ENDIF.

  " --- Step 3: Validate the payment term key exists in T052 (FI config) ---
  SELECT SINGLE zterm, ztagg, ztag1, zpro1, ztag2, zpro2
    FROM t052 INTO CORRESPONDING FIELDS OF ls_t052
    WHERE zterm = iv_zterm.

  IF sy-subrc <> 0.
    ev_valid   = abap_false.
    ev_message = |Payment term '{ iv_zterm }' not found in T052 \u2014 contact FI team to configure|.
    RETURN.
  ENDIF.

  " --- Step 4: Warn if different from vendor master default ---
  IF ls_lfb1-zterm <> iv_zterm AND ls_lfb1-zterm IS NOT INITIAL.
    ev_valid   = abap_true.   " Still valid, but informational
    ev_message = |Payment term { iv_zterm } is valid but differs from vendor | &&
                 |master default ({ ls_lfb1-zterm })|.
    RETURN.
  ENDIF.

  ev_valid   = abap_true.
  ev_message = |Payment term { iv_zterm } validated OK for vendor { iv_lifnr }|.

ENDFUNCTION.
