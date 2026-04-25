FUNCTION z_check_restricted_material.
*"----------------------------------------------------------------------
*" Function Module : Z_CHECK_RESTRICTED_MATERIAL
*" Function Group  : ZFM_MM_TOOLS
*" Author          : MM_TEAM
*" Date            : 2025-09-01
*" Description     : Checks whether a material is flagged as restricted
*"                   for a given plant. Reads ZMM_RESTRICTED_MATS config
*"                   table maintained by MM master data team.
*"                   Used by GR BAdI, PO creation, and transfer order.
*"----------------------------------------------------------------------
*"  IMPORTING
*"    VALUE(IV_MATNR)      TYPE  MATNR    Material number
*"    VALUE(IV_WERKS)      TYPE  WERKS_D  Plant
*"  EXPORTING
*"    VALUE(EV_RESTRICTED) TYPE  BOOLE_D  X = restricted
*"    VALUE(EV_REASON)     TYPE  STRING   Restriction reason text
*"    VALUE(EV_VALID_FROM) TYPE  DATUM    Restriction start date
*"    VALUE(EV_VALID_TO)   TYPE  DATUM    Restriction end date (99991231 = permanent)
*"  EXCEPTIONS
*"    MATERIAL_ERROR       = 1
*"    OTHERS               = 2
*"----------------------------------------------------------------------
  DATA: ls_mara      TYPE mara,
        ls_restricted TYPE zmm_restricted_mats.

  CLEAR: ev_restricted, ev_reason, ev_valid_from, ev_valid_to.

  " --- Validate material exists in MARA ---
  SELECT SINGLE matnr, mtart, mstae
    FROM mara INTO CORRESPONDING FIELDS OF ls_mara
    WHERE matnr = iv_matnr.

  IF sy-subrc <> 0.
    RAISE material_error.
  ENDIF.

  " Material flagged for deletion in MARA \u2014 treat as restricted
  IF ls_mara-mstae IS NOT INITIAL.
    ev_restricted = abap_true.
    ev_reason     = |Material { iv_matnr } is flagged for deletion (MARA-MSTAE = { ls_mara-mstae })|.
    ev_valid_from = sy-datum.
    ev_valid_to   = '99991231'.
    RETURN.
  ENDIF.

  " --- Check organisation restriction config table ---
  SELECT SINGLE matnr, werks, reason, valid_from, valid_to, active
    FROM zmm_restricted_mats
    INTO CORRESPONDING FIELDS OF ls_restricted
    WHERE matnr = iv_matnr
      AND ( werks = iv_werks OR werks = '*' )   " * = all plants
      AND active = abap_true
      AND valid_from <= sy-datum
      AND valid_to   >= sy-datum
    ORDER BY werks DESCENDING.  " plant-specific takes priority over *

  IF sy-subrc = 0.
    ev_restricted = abap_true.
    ev_reason     = ls_restricted-reason.
    ev_valid_from = ls_restricted-valid_from.
    ev_valid_to   = ls_restricted-valid_to.
  ELSE.
    ev_restricted = abap_false.
  ENDIF.

ENDFUNCTION.
