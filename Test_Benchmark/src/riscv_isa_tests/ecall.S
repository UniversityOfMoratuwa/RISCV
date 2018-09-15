# See LICENSE for license details.

#*****************************************************************************
# ecall.S
#-----------------------------------------------------------------------------
#
# Test syscall trap.
#

#define __MACHINE_MODE

#define TEST_FUNC_NAME ecall
#define TEST_FUNC_TXT "ecall \t"
#define TEST_FUNC_RET amoaddw

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64S
RVTEST_CODE_BEGIN

setup_stvec:
  lui t0,%hi(Mtvec_handler)
  addi t0,t0,%lo(Mtvec_handler)
  csrw mtvec, t0

do_ecall:
  scall
  j fail

TEST_PASSFAIL

Mtvec_handler:
  csrr t0, mcause
  li t1, CAUSE_MACHINE_ECALL
  bne t0, t1, fail
  la t2, do_ecall
  csrr t0, mepc
  bne t0, t2, fail
  j pass

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
