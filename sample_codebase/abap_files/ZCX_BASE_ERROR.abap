*&---------------------------------------------------------------------*
*& Exception Class  ZCX_BASE_ERROR
*& Author : CodeSage Sample Codebase
*& Date   : 2026-01-01
*& Desc   : Organisation-wide base exception class.
*&          All custom exceptions inherit from this class.
*&          Carries a free-text message and optional technical detail.
*&---------------------------------------------------------------------*
CLASS zcx_base_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_dyn_msg.

    ALIASES:
      msgid FOR if_t100_dyn_msg~msgid,
      msgno FOR if_t100_dyn_msg~msgno,
      msgv1 FOR if_t100_dyn_msg~msgv1,
      msgv2 FOR if_t100_dyn_msg~msgv2,
      msgv3 FOR if_t100_dyn_msg~msgv3,
      msgv4 FOR if_t100_dyn_msg~msgv4.

    DATA mv_message       TYPE string READ-ONLY.
    DATA mv_technical_msg TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        iv_message       TYPE string       OPTIONAL
        iv_technical_msg TYPE string       OPTIONAL
        previous         TYPE REF TO cx_root OPTIONAL.

    METHODS get_text
      REDEFINITION.

ENDCLASS.

CLASS zcx_base_error IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    mv_message       = iv_message.
    mv_technical_msg = iv_technical_msg.
  ENDMETHOD.

  METHOD get_text.
    result = COND #(
      WHEN mv_message IS NOT INITIAL THEN mv_message
      ELSE 'An unexpected error occurred. Check technical details.' ).
  ENDMETHOD.

ENDCLASS.
