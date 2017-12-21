// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#include "firmware.h"
#include "stdlib.h"

#include <stdarg.h>
#include <stdint.h>

char heap_memory[1024];
int heap_memory_used = 0;

long time(){
	int cycles;
	asm("rdcycle %0" : "=r"(cycles));
	return cycles;
}

long insn(){
	int insns;
	asm("rdinstret %0" : "=r"(insns));
	return insns;
}

char *malloc(int size){
	char *p = heap_memory + heap_memory_used;
	// printf("[malloc(%d) -> %d (%d..%d)]", size, (int)p, heap_memory_used, heap_memory_used + size);
	heap_memory_used += size;
	if (heap_memory_used > 1024)
		asm("ebreak");
	return p;
}

void printf_c(int c){
	volatile char* serial_base = (char*) OUTPORT;
	*serial_base = c;
}

void printf_s(char *s){
	while(*s) printf_c(*(s++));
}

void printf_d(int val){
	char buffer[32];
	char *p = buffer;
	if (val < 0) {
		printf_c('-');
		val = -val;
	}
	while (val || p == buffer) {
		*(p++) = '0' + val % 10;
		val = val / 10;
	}
	while (p != buffer)
		printf_c(*(--p));
}

void printf_h(unsigned int val, int digits){
	for (int i = (4*digits)-4; i >= 0; i -= 4)
		printf_c("0123456789ABCDEF"[(val >> i) % 16]);
}

void printf(const char *format, ...){
	int i;
	va_list ap;
	va_start(ap, format);
	for (i = 0; format[i]; i++)
		if (format[i] == '%') {
			while (format[++i]) {
				if (format[i] == 'c') {
					printf_c(va_arg(ap, int));
					break;
				}
				if (format[i] == 's') {
					printf_s(va_arg(ap,char*));
					break;
				}
				if (format[i] == 'd') {
					printf_d(va_arg(ap,int));
					break;
				}
				//own imp bgn
				if (format[i] == 'u') {
					printf_d(va_arg(ap,unsigned int));
					break;
				}
				if (format[i] == 'l') {
					if(format[i+1] == 'u'){
						i++;
						printf_d(va_arg(ap,unsigned long));
					}
					else{
						printf_d(va_arg(ap,long));
					}
					break;
				}
				if (format[i] == '0') {
					printf_h(va_arg(ap,unsigned int),(int)(format[i+1]-'0'));
					i+=2;
					break;
				}
				/*if (format[i] == 'f') {
					float flt=va_arg(ap,double);
					printf_d((int)flt);
					printf_c('.');
					printf_d((int)(((float)flt-(int)flt)*1000));
					break;
				}*/
				//own imp end
			}
		} else
			printf_c(format[i]);
	va_end(ap);
}

void *memcpy(void *aa, const void *bb, long n){
	char *a = aa;
	const char *b = bb;
	while (n--) *(a++) = *(b++);
	return aa;
}

char *strcpy(char* dst, const char* src){
	char *r = dst;

	while ((((uint32_t)dst | (uint32_t)src) & 3) != 0)
	{
		char c = *(src++);
		*(dst++) = c;
		if (!c) return r;
	}

	while (1)
	{
		uint32_t v = *(uint32_t*)src;

		if (__builtin_expect((((v) - 0x01010101UL) & ~(v) & 0x80808080UL), 0))
		{
			dst[0] = v & 0xff;
			if ((v & 0xff) == 0)
				return r;
			v = v >> 8;

			dst[1] = v & 0xff;
			if ((v & 0xff) == 0)
				return r;
			v = v >> 8;

			dst[2] = v & 0xff;
			if ((v & 0xff) == 0)
				return r;
			v = v >> 8;

			dst[3] = v & 0xff;
			return r;
		}

		*(uint32_t*)dst = v;
		src += 4;
		dst += 4;
	}
}

int strcmp(const char *s1, const char *s2){
	while ((((uint32_t)s1 | (uint32_t)s2) & 3) != 0)
	{
		char c1 = *(s1++);
		char c2 = *(s2++);

		if (c1 != c2)
			return c1 < c2 ? -1 : +1;
		else if (!c1)
			return 0;
	}

	while (1)
	{
		uint32_t v1 = *(uint32_t*)s1;
		uint32_t v2 = *(uint32_t*)s2;

		if (__builtin_expect(v1 != v2, 0))
		{
			char c1, c2;

			c1 = v1 & 0xff, c2 = v2 & 0xff;
			if (c1 != c2) return c1 < c2 ? -1 : +1;
			if (!c1) return 0;
			v1 = v1 >> 8, v2 = v2 >> 8;

			c1 = v1 & 0xff, c2 = v2 & 0xff;
			if (c1 != c2) return c1 < c2 ? -1 : +1;
			if (!c1) return 0;
			v1 = v1 >> 8, v2 = v2 >> 8;

			c1 = v1 & 0xff, c2 = v2 & 0xff;
			if (c1 != c2) return c1 < c2 ? -1 : +1;
			if (!c1) return 0;
			v1 = v1 >> 8, v2 = v2 >> 8;

			c1 = v1 & 0xff, c2 = v2 & 0xff;
			if (c1 != c2) return c1 < c2 ? -1 : +1;
			return 0;
		}

		if (__builtin_expect((((v1) - 0x01010101UL) & ~(v1) & 0x80808080UL), 0))
			return 0;

		s1 += 4;
		s2 += 4;
	}
}

