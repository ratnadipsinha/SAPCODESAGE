FUNCTION z_vendor_master_read.
*"----------------------------------------------------------------------
*" Function Module : Z_VENDOR_MASTER_READ
*" Function Group  : ZFM_VENDOR_TOOLS
*" Author          : MM_TEAM
*" Date            : 2025-06-01
*" Description     : Reads vendor master data from LFA1/LFB1/LFM1.
*"                   Central FM for all vendor lookups \u2014 do not read
*"                   LFA1 directly in programs; always use this FM.
*"----------------------------------------------------------------------
*"  IMPORTING
*"    VALUE(IV_LIFNR)   TYPE  LIFNR          Vendor account number
*"    VALUE(IV_BUKRS)   TYPE  BUKRS          Company code (optional)
*"    VALUE(IV_EKORG)   TYPE  EKORG          Purchasing org (optional)
*"  EXPORTING
*"    VALUE(ES_VENDOR)  TYPE  ZS_VENDOR_MASTER   Vendor master data
*"  EXCEPTIONS
*"    VENDOR_NOT_FOUND  = 1
*"    COMPANY_DATA_MISSING = 2
*"    OTHERS            = 3
*"----------------------------------------------------------------------
  DATA: ls_lfa1  TYPE lfa1,
        ls_lfb1  TYPE lfb1,
        ls_lfm1  TYPE lfm1.

  CLEAR es_vendor.

  " --- General data (client-independent) ---
  SELECT SINGLE lifnr, name1, name2, stras, ort01,
                land1, regio, telf1, telfx, stcd1,
                loevm, sperr, sperm
    FROM lfa1
    INTO CORRESPONDING FIELDS OF ls_lfa1
    WHERE lifnr = iv_lifnr.

  IF sy-subrc <> 0.
    RAISE vendor_not_found.
  ENDIF.

  " Reject if vendor is flagged for deletion
  IF ls_lfa1-loevm = 'X'.
    RAISE vendor_not_found.
  ENDIF.

  es_vendor-lifnr = ls_lfa1-lifnr.
  es_vendor-name1 = ls_lfa1-name1.
  es_vendor-name2 = ls_lfa1-name2.
  es_vendor-street= ls_lfa1-stras.
  es_vendor-city  = ls_lfa1-ort01.
  es_vendor-country = ls_lfa1-land1.
  es_vendor-phone = ls_lfa1-telf1.
  es_vendor-tax_id= ls_lfa1-stcd1.
  es_vendor-blocked = ls_lfa1-sperr.

  " --- Company code data (accounting) ---
  IF iv_bukrs IS NOT INITIAL.
    SELECT SINGLE lifnr, bukrs, zterm, zwels, akont, reprf
      FROM lfb1
      INTO CORRESPONDING FIELDS OF ls_lfb1
      WHERE lifnr = iv_lifnr
        AND bukrs = iv_bukrs.

    IF sy-subrc <> 0.
      RAISE company_data_missing.
    ENDIF.

    es_vendor-bukrs      = ls_lfb1-bukrs.
    es_vendor-pay_terms  = ls_lfb1-zterm.
    es_vendor-pay_method = ls_lfb1-zwels.
    es_vendor-recon_acct = ls_lfb1-akont.
    es_vendor-inv_verify = ls_lfb1-reprf.
  ENDIF.

  " --- Purchasing org data ---
  IF iv_ekorg IS NOT INITIAL.
    SELECT SINGLE lifnr, ekorg, zterm, waers, inco1, inco2
      FROM lfm1
      INTO CORRESPONDING FIELDS OF ls_lfm1
      WHERE lifnr = iv_lifnr
        AND ekorg = iv_ekorg.

    IF sy-subrc = 0.
      es_vendor-ekorg      = ls_lfm1-ekorg.
      es_vendor-purch_terms= ls_lfm1-zterm.
      es_vendor-currency   = ls_lfm1-waers.
      es_vendor-incoterms  = ls_lfm1-inco1.
    ENDIF.
  ENDIF.

ENDFUNCTION.
