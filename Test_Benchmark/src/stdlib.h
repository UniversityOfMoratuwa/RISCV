/*
 * stdlib.c
 *
 *  Created on: Nov 4, 2017
 *      Author: ijaz
 */

#ifndef STDLIB_H
#define STDLIB_H

#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_MAGENTA "\x1b[35m"
#define ANSI_COLOR_CYAN    "\x1b[36m"
#define ANSI_COLOR_RESET   "\x1b[0m"

long time();
long insn();

void enableIntr();
void enableExternalIntr();
void enableTimerIntr();
void disableIntr();
void disableExternalIntr();
void disableTimerIntr();
unsigned long readMtime();
long readMtimeCmp();
void writeMtimeCmp(int cmp);

void printf_c(int c);
void printf_s(char *s);
void printf_d(int val);
void printf_h(unsigned int val, int digits);
void printf(const char *format, ...);

char scanf_c();
char* scanf();

void *memcpy(void *aa, const void *bb, long n);
char *strcpy(char* dst, const char* src);
int strcmp(const char *s1, const char *s2);


#endif
