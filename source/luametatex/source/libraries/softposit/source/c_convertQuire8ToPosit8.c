
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


#include <stdint.h>
#include <math.h>

#include "platform.h"
#include "internals.h"


posit8_t q8_to_p8(quire8_t qA){

	union ui32_q8 uZ;
	union ui8_p8 uA;
	uint_fast8_t regA, fracA = 0, shift=0, regime;
	uint_fast32_t frac32A;
	bool sign=0, regSA=0, bitNPlusOne=0, bitsMore=0;

	if (isQ8Zero(qA)){
		uA.ui=0;
		return uA.p;
	}
	//handle NaR
	else if (isNaRQ8(qA)){
		uA.ui=0x80;
		return uA.p;
	}

	uZ.q = qA;

	sign = uZ.ui>>31;

	if(sign){
		uZ.ui = -uZ.ui & 0xFFFFFFFF;
	}

	int noLZ =0;

	uint_fast32_t tmp = uZ.ui;

	while (!(tmp>>31)){//==0
		noLZ++;
		tmp<<=1;
	}
	frac32A = tmp;

	//default dot is between bit 19 and 20, extreme left bit is bit 0. Last right bit is bit 31.
	//Scale =  k
	int kA=(19-noLZ);

	if(kA<0){
		regA = (-kA & 0xFF);
		regSA = 0;
		regime = 0x40>>regA;
	}
	else{
		regA = kA+1;
		regSA=1;
		regime = 0x7F-(0x7F>>regA);
	}

	if(regA>6){
		//max or min pos. exp and frac does not matter.
		(regSA) ? (uA.ui= 0x7F): (uA.ui=0x1);
	}
	else{
		//remove hidden bit
		frac32A&=0x7FFFFFFF;
		shift = regA+25; // 1 sign bit and 1 r terminating bit , 16+7+2
		fracA = frac32A>>shift;

		bitNPlusOne = (frac32A>>(shift-1))&0x1 ;

		uA.ui = packToP8UI(regime, fracA);

		if (bitNPlusOne){
			( (frac32A <<(33-shift)) & 0xFFFFFFFF ) ? (bitsMore=1) : (bitsMore=0);
			uA.ui += (uA.ui&1) |  bitsMore;
		}
	}

	if (sign) uA.ui = -uA.ui & 0xFF;

	return uA.p;


}



