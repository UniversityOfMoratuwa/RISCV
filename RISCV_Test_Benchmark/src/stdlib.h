/*
 * stdlib.c
 *
 *  Created on: Nov 4, 2017
 *      Author: ijaz
 */

#ifndef STDLIB_H
#define STDLIB_H

long time();
long insn();

void printf_c(int c);
void printf_s(char *s);
void printf_d(int val);
void printf_h(unsigned int val, int digits);
void printf(const char *format, ...);

void *memcpy(void *aa, const void *bb, long n);
char *strcpy(char* dst, const char* src);
int strcmp(const char *s1, const char *s2);


#endif
