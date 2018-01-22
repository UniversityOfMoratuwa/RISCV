
#include "../firmware.h"

#ifndef _ENV_RV32_TEST_H
#define _ENV_RV32_TEST_H


#include "../encoding.h"

//-----------------------------------------------------------------------
// Begin Macro
//-----------------------------------------------------------------------

#define RVTEST_RV64U                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_RV64UF                                                   \
  .macro init;                                                          \
  RVTEST_FP_ENABLE;                                                     \
  .endm

#define RVTEST_RV32U                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_RV32UF                                                   \
  .macro init;                                                          \
  RVTEST_FP_ENABLE;                                                     \
  .endm

#define RVTEST_RV64M                                                    \
  .macro init;                                                          \
  RVTEST_ENABLE_MACHINE;                                                \
  .endm

#define RVTEST_RV64S                                                    \
  .macro init;                                                          \
  RVTEST_ENABLE_SUPERVISOR;                                             \
  .endm

#define RVTEST_RV32M                                                    \
  .macro init;                                                          \
  RVTEST_ENABLE_MACHINE;                                                \
  .endm

#define RVTEST_RV32S                                                    \
  .macro init;                                                          \
  RVTEST_ENABLE_SUPERVISOR;                                             \
  .endm

#if __riscv_xlen == 64
# define CHECK_XLEN li a0, 1; slli a0, a0, 31; bgez a0, 1f; RVTEST_PASS; 1:
#else
# define CHECK_XLEN li a0, 1; slli a0, a0, 31; bltz a0, 1f; RVTEST_PASS; 1:
#endif

#define INIT_PMP                                                        \
  la t0, 1f;                                                            \
  csrw mtvec, t0;                                                       \
  li t0, -1;        /* Set up a PMP to permit all accesses */           \
  csrw pmpaddr0, t0;                                                    \
  li t0, PMP_NAPOT | PMP_R | PMP_W | PMP_X;                             \
  csrw pmpcfg0, t0;                                                     \
  .align 2;                                                             \
1:

#define INIT_SATP                                                       \
  la t0, 1f;                                                            \
  csrw mtvec, t0;                                                       \
  csrwi sptbr, 0;                                                       \
  .align 2;                                                             \
1:

#define DELEGATE_NO_TRAPS                                               \
  la t0, 1f;                                                            \
  csrw mtvec, t0;                                                       \
  csrwi medeleg, 0;                                                     \
  csrwi mideleg, 0;                                                     \
  csrwi mie, 0;                                                         \
  .align 2;                                                             \
1:

#define RVTEST_ENABLE_SUPERVISOR                                        \
  li a0, MSTATUS_MPP & (MSTATUS_MPP >> 1);                              \
  csrs mstatus, a0;                                                     \
  li a0, SIP_SSIP | SIP_STIP;                                           \
  csrs mideleg, a0;                                                     \

#define RVTEST_ENABLE_MACHINE                                           \
  li a0, MSTATUS_MPP;                                                   \
  csrs mstatus, a0;                                                     \

#define RVTEST_FP_ENABLE                                                \
  li a0, MSTATUS_FS & (MSTATUS_FS >> 1);                                \
  csrs mstatus, a0;                                                     \
  csrwi fcsr, 0

#define RISCV_MULTICORE_DISABLE                                         \
  csrr a0, mhartid;                                                     \
  1: bnez a0, 1b

#define EXTRA_TVEC_USER
#define EXTRA_TVEC_MACHINE
#define EXTRA_INIT
#define EXTRA_INIT_TIMER

#define INTERRUPT_HANDLER j other_exception /* No interrupts should occur */

//-----------------------------------------------------------------------
// End Macro
//-----------------------------------------------------------------------


#ifndef TEST_FUNC_NAME
#  define TEST_FUNC_NAME mytest
#  define TEST_FUNC_TXT "mytest"
#  define TEST_FUNC_RET mytest_ret
#endif

#define TESTNUM x28

#define RVTEST_CODE_BEGIN		\
	.text;				\
	.global TEST_FUNC_NAME;		\
	.global TEST_FUNC_RET;		\
TEST_FUNC_NAME:				\
	lui	a0,%hi(.test_name);	\
	addi	a0,a0,%lo(.test_name);	\
.prname_next:				\
	li sp, STACK_POINTER; \
	jal ra, printf_s
.test_name:				\
	.ascii TEST_FUNC_TXT;		\
	.byte 0x00;			\
	.balign 4;

#define RVTEST_PASS			\
	addi	a0,zero,'O';		\
	li sp, STACK_POINTER; \
	jal ra, printf_c	;	\
	addi	a0,zero,'K';		\
	li sp, STACK_POINTER; \
	jal ra, printf_c	;	\
	addi	a0,zero,'\n';		\
	li sp, STACK_POINTER; \
	jal ra, printf_c	;	\
	jal	zero,TEST_FUNC_RET;

#define RVTEST_FAIL			\
	addi	a0,zero,'E';		\
	li sp, STACK_POINTER; \
	jal ra, printf_c	;	\
	addi	a0,zero,'R';		\
	li sp, STACK_POINTER; \
	jal ra, printf_c	;	\
	li sp, STACK_POINTER; \
	jal ra, printf_c	;	\
	addi	a0,zero,'O';		\
	li sp, STACK_POINTER; \
	jal ra, printf_c	;	\
	li sp, STACK_POINTER; \
	addi	a0,zero,'R';		\
	li sp, STACK_POINTER; \
	jal ra, printf_c	;	\
	addi	a0,zero,'\n';		\
	li sp, STACK_POINTER; \
	jal ra, printf_c	;	\
	jal	zero,TEST_FUNC_RET;

#define RVTEST_CODE_END
#define RVTEST_DATA_BEGIN .balign 4;
#define RVTEST_DATA_END

#endif
