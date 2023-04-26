
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

#include "platform.h"
#include "internals.h"

//softposit_mulAdd_subC => (uiA*uiB)-uiC
//softposit_mulAdd_subProd => uiC - (uiA*uiB)
//Default is always op==0
posit8_t softposit_mulAddP8( uint_fast8_t uiA, uint_fast8_t uiB, uint_fast8_t uiC, uint_fast8_t op ){


	union ui8_p8 uZ;
	uint_fast8_t regZ, fracA, fracZ, regime, tmp;
	bool signA, signB, signC, signZ, regSA, regSB, regSC, regSZ, bitNPlusOne=0, bitsMore=0, rcarry;
	int_fast8_t kA=0, kC=0, kZ=0, shiftRight;
	uint_fast16_t frac16C, frac16Z;

	//NaR
	if ( uiA==0x80 || uiB==0x80  || uiC==0x80 ){
		uZ.ui = 0x80;
		return uZ.p;
	}
	else if (uiA==0 || uiB==0){
		if (op == softposit_mulAdd_subC)
			uZ.ui = -uiC;
		else
			uZ.ui = uiC;
		return uZ.p;
	}

	signA = signP8UI( uiA );
	signB = signP8UI( uiB );
	signC = signP8UI( uiC );//^ (op == softposit_mulAdd_subC);
	signZ = signA ^ signB;// ^ (op == softposit_mulAdd_subProd);

	if(signA) uiA = (-uiA & 0xFF);
	if(signB) uiB = (-uiB & 0xFF);
	if(signC) uiC = (-uiC & 0xFF);

	regSA = signregP8UI(uiA);
	regSB = signregP8UI(uiB);
	regSC = signregP8UI(uiC);

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
	fracA = (0x80 | tmp); //use first bit here for hidden bit to get more bits

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
	frac16Z = (uint_fast16_t) fracA * (0x80 | tmp);

	rcarry = frac16Z>>15;//1st bit of frac16Z
	if (rcarry){
		kA++;
		frac16Z>>=1;
	}

	if (uiC!=0){
		tmp = (uiC<<2) & 0xFF;
		if (regSC){
			while (tmp>>7){
				kC++;
				tmp= (tmp<<1) & 0xFF;
			}
		}
		else{
			kC=-1;
			while (!(tmp>>7)){
				kC--;
				tmp= (tmp<<1) & 0xFF;
			}
			tmp&=0x7F;
		}
		frac16C = (0x80 | tmp) <<7 ;
		shiftRight = (kA-kC);

		if (shiftRight<0){ // |uiC| > |Prod|
			if (shiftRight<=-15) {
				bitsMore = 1;
				frac16Z=0;
			}
			else if (((frac16Z<<(16+shiftRight))&0xFFFF)!=0) bitsMore = 1;
			if (signZ==signC)
				frac16Z = frac16C + (frac16Z>>-shiftRight);
			else {//different signs
				frac16Z = frac16C - (frac16Z>>-shiftRight) ;
				signZ=signC;
				if (bitsMore) frac16Z-=1;
			}
			kZ = kC;

		}
		else if (shiftRight>0){// |uiC| < |Prod|

			if(shiftRight>=15){
				bitsMore = 1;
				frac16C = 0;
			}
			else if (((frac16C<<(16-shiftRight))&0xFFFF)!=0) bitsMore = 1;
			if (signZ==signC)
				frac16Z += (frac16C>>shiftRight);
			else{
				frac16Z -= (frac16C>>shiftRight);
				if (bitsMore) frac16Z-=1;
			}
			kZ = kA;
		}
		else{
			if(frac16C==frac16Z && signZ!=signC ){ //check if same number
					uZ.ui = 0;
					return uZ.p;
			}
			else{
				if (signZ==signC)
					frac16Z += frac16C;
				else{
					if (frac16Z<frac16C){
						frac16Z = frac16C - frac16Z;
						signZ = signC;
					}
					else{
						frac16Z -= frac16C;
					}
				}
			}
			kZ = kA;// actually can be kC too, no diff
		}

		rcarry = 0x8000 & frac16Z; //first left bit
		if(rcarry){
			kZ ++;
			frac16Z=(frac16Z>>1)&0x7FFF;
		}
		else {

			//for subtract cases
			if (frac16Z!=0){
				while((frac16Z>>14)==0){
					kZ--;
					frac16Z<<=1;
				}
			}
		}

	}
	else{
		kZ = kA;
	}

	if(kZ<0){
		regZ = (-kZ & 0xFF);
		regSZ = 0;
		regime = 0x40>>regZ;
	}
	else{
		regZ = kZ+1;
		regSZ=1;
		regime = 0x7F - (0x7F>>regZ);
	}

	if(regZ>6){
		//max or min pos. exp and frac does not matter.
		(regSZ) ? (uZ.ui= 0x7F): (uZ.ui=0x1);
	}
	else{
		//remove hidden bits
		frac16Z &= 0x3FFF;

		fracZ = (frac16Z >> regZ) >> 8;

		bitNPlusOne = ((frac16Z>>regZ) & 0x80);
		uZ.ui = packToP8UI(regime, fracZ);

		if (bitNPlusOne){
			if ( (frac16Z<<(9-regZ)) &0xFFFF  ) bitsMore =1;
			uZ.ui += (uZ.ui&1) | bitsMore;
		}
	}

	if (signZ) uZ.ui = -uZ.ui & 0xFF;
	return uZ.p;

}

