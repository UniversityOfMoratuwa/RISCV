/*
 * start.S
 *
 *  Created on: Nov 4, 2017
 *      Author: ijaz
 */

#include "firmware.h"

	.section .text.boot
	.global _start
	.global isaTest
	.global dhrystoneBenchmark
	.global coremarkBenchmark
	.global isaTestEnd

/* Main program
 **********************************/
_start:
	jal ra,init
	/* trap */
	ebreak

initReg:
	/* initialize all registers */
	li x2, STACK_POINTER
	li x3, GLOBAL_POINTER
	addi x4, zero, 0
	addi x5, zero, 0
	addi x6, zero, 0
	addi x7, zero, 0
	addi x8, zero, 0
	addi x9, zero, 0
	addi x10, zero, 0
	addi x11, zero, 0
	addi x12, zero, 0
	addi x13, zero, 0
	addi x14, zero, 0
	addi x15, zero, 0
	addi x16, zero, 0
	addi x17, zero, 0
	addi x18, zero, 0
	addi x19, zero, 0
	addi x20, zero, 0
	addi x21, zero, 0
	addi x22, zero, 0
	addi x23, zero, 0
	addi x24, zero, 0
	addi x25, zero, 0
	addi x26, zero, 0
	addi x27, zero, 0
	addi x28, zero, 0
	addi x29, zero, 0
	addi x30, zero, 0
	addi x31, zero, 0
	ret

isaTest:
	jal ra,risvISATestStartMsg
	jal ra,initReg
	jal ra,add

isaTestEnd:
	jal ra,initReg
	jal ra,init

dhrystoneBenchmark:
	jal ra,risvDhrystoneStartMsg
	jal ra,initReg
	jal ra,DHRYSTONE
	jal ra,init

coremarkBenchmark:
	jal ra,risvCoremarkStartMsg
	jal ra,initReg
	jal ra,COREMARK
	jal ra,init

