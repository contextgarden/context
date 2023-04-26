/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017 A*STAR.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions, and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors may
    be used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/

#include "platform.h"
#include "internals.h"


void printBinary(uint64_t * s, int size) {
	int i;

	uint64_t number = *s;
	int bitSize = size -1;
	for(i = 0; i < size; ++i) {
		if(i%8 == 0)
			putchar(' ');
		printf("%llu", (number >> (bitSize-i))&1);
	}
	printf("\n");

}
void printBinaryQuire32(quire32_t * s){
	int size = 512;
	int dotPos = 272;
	int bitSize = 63;

	int n = 0;
	uint64_t number =  s->v[n];
	for(int i = 0; i < size; ++i) {
		if (i!=0 && i%64==0){
			printf("\n");
			n++;
			number =  s->v[n];
		}
		if(i%8 == 0)
			putchar(' ');
		if (i==dotPos)
			putchar('.');
		printf("%llu", (number >> (bitSize-i))&1);
	}
	printf("\n");
}

void printBinaryQuire16(quire16_t * s){
	int size = 128;
	int dotPos = 72;
	int bitSize = 63;

	int n = 0;
	uint64_t number =  s->v[n];
	for(int i = 0; i < size; ++i) {
		if (i!=0 && i%64==0){
			printf("\n");
			n++;
			number =  s->v[n];
		}
		if(i%8 == 0)
			putchar(' ');
		if (i==dotPos)
			putchar('.');
		printf("%llu", (number >> (bitSize-i))&1);
	}
	printf("\n");
}

void printBinaryQuire8(quire8_t * s){
	int size = 32;
	uint32_t number = s->v;
	int dotPos = 20;

	int bitSize = size -1;
	for(int i = 0; i < size; ++i) {
		if(i%8 == 0)
			putchar(' ');
		if (i==dotPos)
					putchar('.');
		printf("%u", (number >> (bitSize-i))&1);
	}
	printf("\n");
}

void printBinaryPX(uint32_t * s, int size) {
	int i;
	uint32_t number = *s;
	number >>= (32-size);
	int bitSize = size -1;
	for(i = 0; i < size; ++i){
		if(i%8 == 0)
			putchar(' ');
		printf("%u", (number >> (bitSize-i))&1);
	}
	printf("\n");

}
void printHex64(uint64_t s) {
	printf("%016llx\n", s);

}
void printHex(uint64_t s) {
	printf("0x%llx\n", s);

}
void printHexPX(uint32_t s, int size) {
	s>>=(32-size);
	printf("0x%x\n", s);

}
quire16_t q16_TwosComplement(quire16_t q){
	if (!isQ16Zero(q) && !isNaRQ16(q)){
		if (q.v[1]==0){
			q.v[0] = -q.v[0];
		}
		else{
			q.v[1] = - q.v[1];
			q.v[0] = ~q.v[0];
		}
	}
	return q;

}

quire32_t q32_TwosComplement(quire32_t q){
	if (!isQ32Zero(q) && !isNaRQ32(q)){
		int i=7;
		bool found = false;
		while(i){
			if (found){
				q.v[i] = ~q.v[i];
			}
			else{
				if (q.v[i]!=0){
					q.v[i] = -q.v[i];
					found = true;
				}
			}
			i--;
		}
	}
	return q;

}

quire_2_t qX2_TwosComplement(quire_2_t q){
	if (!isQX2Zero(q) && !isNaRQX2(q)){
		int i=7;
		bool found = false;
		while(i){
			if (found){
				q.v[i] = ~q.v[i];
			}
			else{
				if (q.v[i]!=0){
					q.v[i] = -q.v[i];
					found = true;
				}
			}
			i--;
		}
	}
	return q;

}


