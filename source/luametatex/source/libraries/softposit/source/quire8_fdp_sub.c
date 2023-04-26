/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017, 2018 A*STAR.  All rights reserved.

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

#include <inttypes.h>

#include "platform.h"
#include "internals.h"


//q - (pA*pB)
quire8_t q8_fdp_sub( quire8_t q, posit8_t pA, posit8_t pB ){

	union ui8_p8 uA, uB;
	union ui32_q8 uqZ, uqZ1, uqZ2;
	uint_fast8_t uiA, uiB;
	uint_fast8_t fracA, tmp;
	bool signA, signB, signZ2, regSA, regSB, rcarry;
	int_fast8_t kA=0, shiftRight=0;
	uint_fast32_t frac32Z;

	uqZ1.q = q;

	uA.p = pA;
	uiA = uA.ui;
	uB.p = pB;
	uiB = uB.ui;

	//NaR
	if (isNaRQ8(q) || isNaRP8UI(uA.ui) || isNaRP8UI(uB.ui)){
		uqZ2.ui=0x80000000;
		return uqZ2.q;
	}
	else if (uiA==0 || uiB==0)
		return q;


	//max pos (sign plus and minus)
	signA = signP8UI( uiA );
	signB = signP8UI( uiB );
	signZ2 = signA ^ signB;

	if(signA) uiA = (-uiA & 0xFF);
	if(signB) uiB = (-uiB & 0xFF);

	regSA = signregP8UI(uiA);
	regSB = signregP8UI(uiB);

	tmp = (uiA<<2) & 0xFF;
	if (regSA){
		while (tmp>>7){
			kA++;
			tmp= (tmp<<1) & 0xFF;
		}
	}
	else{
		kA=-1;
		while (!(tmp>>7)){
			kA--;
			tmp= (tmp<<1) & 0xFF;
		}
		tmp&=0x7F;
	}
	fracA = (0x80 | tmp);

	tmp = (uiB<<2) & 0xFF;
	if (regSB){
		while (tmp>>7){
			kA++;
			tmp= (tmp<<1) & 0xFF;
		}
	}
	else{
		kA--;
		while (!(tmp>>7)){
			kA--;
			tmp= (tmp<<1) & 0xFF;
		}
		tmp&=0x7F;
	}
	frac32Z = (uint_fast32_t)( fracA * (0x80 | tmp) ) <<16;

	rcarry = frac32Z>>31;//1st bit (position 2) of frac32Z, hidden bit is 4th bit (position 3)
	if (rcarry){
		kA ++;
		frac32Z>>=1;
	}

	//default dot is between bit 19 and 20, extreme left bit is bit 0. Last right bit is bit 31.
	//Scale = 2^es * k + e  => 2k + e // firstPost = 19-kA, shift = firstPos -1 (because frac32Z start from 2nd bit)
	//int firstPos = 19 - kA;
	shiftRight = 18-kA;

	uqZ2.ui = frac32Z>> shiftRight;

	//This is the only difference from ADD (signZ2) and (!signZ2)
	if (!signZ2) uqZ2.ui  = -uqZ2.ui & 0xFFFFFFFF;

	//Addition
	uqZ.ui = uqZ2.ui + uqZ1.ui;

	//Exception handling
	if (isNaRQ8(uqZ.q) ) uqZ.q.v=0;

	return uqZ.q;
}
