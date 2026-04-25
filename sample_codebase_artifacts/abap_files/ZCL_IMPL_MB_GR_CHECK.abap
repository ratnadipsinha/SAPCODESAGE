*&---------------------------------------------------------------------*
*& Class          ZCL_IMPL_MB_GR_CHECK
*& Package        ZMM_BADI_IMPL
*& Author         MM_TEAM
*& Date           2025-07-20
*& Description    BAdI implementation for MB_MIGO_BADI.
*&                Runs custom checks before goods receipt posting in MIGO.
*&                Checks: material restriction, plant quarantine flag,
*&                        and storage location capacity limit.
*&                Set CH_MSG_PROT = 'E' to block the GR posting.
*&---------------------------------------------------------------------*
CLASS zcl_impl_mb_gr_check DEFINITION
  PUBLIC FINAL
  INHERITING FROM cl_badi_impl.

  PUBLIC SECTION.
    INTERFACES if_ex_mb_migo_badi.

ENDCLASS.


CLASS zcl_impl_mb_gr_check IMPLEMENTATION.

  METHOD if_ex_mb_migo_badi~mb_migo_hold_check.
  *----------------------------------------------------------------
  * Called once per GR line item before MIGO posts the document.
  * Parameters (provided by SAP framework):
  *   IS_MSEG  - movement segment (material, plant, sloc, quantity)
  *   IS_MKPF  - document header (movement type, posting date)
  *   CH_MSG_PROT - set to 'E' to block; 'W' for warning only
  *----------------------------------------------------------------

    DATA: lv_restricted TYPE boole_d,
          lv_reason     TYPE string,
          lv_capacity   TYPE p DECIMALS 3.

    " Only run checks for GR-relevant movement types (101, 103, 105)
    CHECK is_mkpf-blart = 'WE' AND is_mseg-bwart IN ('101', '103', '105').

    " --- Check 1: Material restriction ---
    CALL FUNCTION 'Z_CHECK_RESTRICTED_MATERIAL'
      EXPORTING
        iv_matnr       = is_mseg-matnr
        iv_werks       = is_mseg-werks
      IMPORTING
        ev_restricted  = lv_restricted
        ev_reason      = lv_reason
      EXCEPTIONS
        material_error = 1
        OTHERS         = 2.

    IF sy-subrc = 0 AND lv_restricted = abap_true.
      ch_msg_prot = 'E'.
      MESSAGE e010(zmm_badi)
        WITH is_mseg-matnr lv_reason
        INTO DATA(lv_dummy).
      RETURN.
    ENDIF.

    " --- Check 2: Plant quarantine flag (ZMM_PLANT_STATUS config) ---
    SELECT SINGLE quarantine
      FROM zmm_plant_status
      INTO @DATA(lv_quarantine)
      WHERE werks  = @is_mseg-werks
        AND active = @abap_true.

    IF sy-subrc = 0 AND lv_quarantine = abap_true.
      ch_msg_prot = 'E'.
      MESSAGE e011(zmm_badi)
        WITH is_mseg-werks
        INTO lv_dummy.
      RETURN.
    ENDIF.

    " --- Check 3: Storage location capacity (warning only) ---
    SELECT SUM( labst ) + SUM( einme )
      FROM mard
      INTO @lv_capacity
      WHERE werks = @is_mseg-werks
        AND lgort = @is_mseg-lgort.

    SELECT SINGLE max_capacity
      FROM zmm_sloc_capacity
      INTO @DATA(lv_max)
      WHERE werks = @is_mseg-werks
        AND lgort = @is_mseg-lgort.

    IF sy-subrc = 0 AND lv_max > 0.
      IF ( lv_capacity + is_mseg-menge ) > lv_max * '1.10'.  " 10% over = hard block
        ch_msg_prot = 'E'.
        MESSAGE e012(zmm_badi)
          WITH is_mseg-lgort lv_max lv_capacity
          INTO lv_dummy.
      ELSEIF ( lv_capacity + is_mseg-menge ) > lv_max * '0.90'. " 90% = warning
        ch_msg_prot = 'W'.
        MESSAGE w013(zmm_badi)
          WITH is_mseg-lgort lv_max
          INTO lv_dummy.
      ENDIF.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
