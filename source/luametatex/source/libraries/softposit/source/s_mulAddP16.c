
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017, 2018 A*STAR.  All rights reserved.

This C source file was based on SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3d, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017 The Regents of the
University of California.  All rights reserved.

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
posit16_t softposit_mulAddP16( uint_fast16_t uiA, uint_fast16_t uiB, uint_fast16_t uiC, uint_fast16_t op ){


	union ui16_p16 uZ;
	uint_fast16_t regZ, fracA, fracZ, regime, tmp;
	bool signA, signB, signC, signZ, regSA, regSB, regSC, regSZ, bitNPlusOne=0, bitsMore=0, rcarry;
	int_fast8_t expA, expC, expZ;
	int_fast16_t kA=0, kC=0, kZ=0, shiftRight;
	uint_fast32_t frac32C=0, frac32Z=0;

	//NaR
	if ( uiA==0x8000 || uiB==0x8000  || uiC==0x8000 ){
		uZ.ui = 0x8000;
		return uZ.p;
	}
	else if (uiA==0 || uiB==0){
		if (op == softposit_mulAdd_subC)
			uZ.ui = -uiC;
		else
			uZ.ui = uiC;
		return uZ.p;
	}

	signA = signP16UI( uiA );
	signB = signP16UI( uiB );
	signC = signP16UI( uiC );//^ (op == softposit_mulAdd_subC);
	signZ = signA ^ signB;// ^ (op == softposit_mulAdd_subProd);

	if(signA) uiA = (-uiA & 0xFFFF);
	if(signB) uiB = (-uiB & 0xFFFF);
	if(signC) uiC = (-uiC & 0xFFFF);

	regSA = signregP16UI(uiA);
	regSB = signregP16UI(uiB);
	regSC = signregP16UI(uiC);

	tmp = (uiA<<2) & 0xFFFF;
	if (regSA){
		while (tmp>>15){
			kA++;
			tmp= (tmp<<1) & 0xFFFF;
		}
	}
	else{
		kA=-1;
		while (!(tmp>>15)){
			kA--;
			tmp= (tmp<<1) & 0xFFFF;
		}
		tmp&=0x7FFF;
	}
	expA = tmp>>14;
	fracA = (0x8000 | (tmp<<1)); //use first bit here for hidden bit to get more bits

	tmp = (uiB<<2) & 0xFFFF;
	if (regSB){
		while (tmp>>15){
			kA++;
			tmp= (tmp<<1) & 0xFFFF;
		}
	}
	else{
		kA--;
		while (!(tmp>>15)){
			kA--;
			tmp= (tmp<<1) & 0xFFFF;
		}
		tmp&=0x7FFF;
	}
	expA += tmp>>14;
	frac32Z = (uint_fast32_t) fracA * (0x8000 | (tmp <<1)); // first bit hidden bit

	if (expA>1){
		kA++;
		expA ^=0x2;
	}

	rcarry = frac32Z>>31;//1st bit of frac32Z
	if (rcarry){
		if (expA) kA ++;
		expA^=1;
		frac32Z>>=1;
	}

	//Add
	if (uiC!=0){
		tmp = (uiC<<2) & 0xFFFF;
		if (regSC){
			while (tmp>>15){
				kC++;
				tmp= (tmp<<1) & 0xFFFF;
			}
		}
		else{
			kC=-1;
			while (!(tmp>>15)){
				kC--;
				tmp= (tmp<<1) & 0xFFFF;
			}
			tmp&=0x7FFF;
		}
		expC = tmp>>14;
		frac32C = (0x4000 | tmp) << 16;
		shiftRight = ((kA-kC)<<1) + (expA-expC); //actually this is the scale

		if (shiftRight<0){ // |uiC| > |Prod Z|
			if (shiftRight<=-31){
				bitsMore = 1;
				frac32Z = 0;
			}
			else if (((frac32Z<<(32+shiftRight))&0xFFFFFFFF)!=0) bitsMore = 1;
			if (signZ==signC)
				frac32Z = frac32C + (frac32Z>>-shiftRight);
			else {//different signs
				frac32Z = frac32C - (frac32Z>>-shiftRight) ;
				signZ=signC;
				if (bitsMore) frac32Z-=1;
			}
			kZ = kC;
			expZ = expC;

		}
		else if (shiftRight>0){// |uiC| < |Prod|
			//if (frac32C&((1<<shiftRight)-1)) bitsMore = 1;
			if(shiftRight>=31){
				bitsMore = 1;
				frac32C = 0;
			}
			else if (((frac32C<<(32-shiftRight))&0xFFFFFFFF)!=0) bitsMore = 1;
			if (signZ==signC)
				frac32Z = frac32Z + (frac32C>>shiftRight);
			else{
				frac32Z = frac32Z - (frac32C>>shiftRight);
				if (bitsMore) frac32Z-=1;
			}
			kZ = kA;
			expZ = expA;

		}
		else{
			if(frac32C==frac32Z && signZ!=signC ){ //check if same number
					uZ.ui = 0;
					return uZ.p;
			}
			else{
				if (signZ==signC)
					frac32Z += frac32C;
				else{
					if (frac32Z<frac32C){
						frac32Z = frac32C - frac32Z;
						signZ = signC;
					}
					else{
						frac32Z -= frac32C;
					}
				}
			}
			kZ = kA;// actually can be kC too, no diff
			expZ = expA; //same here
		}

		rcarry = 0x80000000 & frac32Z; //first left bit
		if(rcarry){
			if (expZ) kZ ++;
			expZ^=1;
			if (frac32Z&0x1) bitsMore = 1;
			frac32Z=(frac32Z>>1)&0x7FFFFFFF;
		}
		else {
			//for subtract cases
			if (frac32Z!=0){
				while((frac32Z>>29)==0){
					kZ--;
					frac32Z<<=2;
				}
			}
			bool ecarry = (0x40000000 & frac32Z)>>30;

			if(!ecarry){
				if (expZ==0) kZ--;
				expZ^=1;
				frac32Z<<=1;
			}
		}
	}
	else{
		kZ = kA;
		expZ=expA;
	}

	if(kZ<0){
		regZ = (-kZ & 0xFFFF);
		regSZ = 0;
		regime = 0x4000>>regZ;
	}
	else{
		regZ = kZ+1;
		regSZ=1;
		regime = 0x7FFF - (0x7FFF>>regZ);
	}

	if(regZ>14){
		//max or min pos. exp and frac does not matter.
		(regSZ) ? (uZ.ui= 0x7FFF): (uZ.ui=0x1);
	}
	else{
		//remove hidden bits
		frac32Z &= 0x3FFFFFFF;
		fracZ = frac32Z >> (regZ + 17);

		if (regZ!=14) bitNPlusOne = (frac32Z>>regZ) & 0x10000;
		else if (frac32Z>0){
			fracZ=0;
			bitsMore =1;
		}
		if (regZ==14 && expZ) bitNPlusOne = 1;
		uZ.ui = packToP16UI(regime, regZ, expZ, fracZ);
		if (bitNPlusOne){
			if ( (frac32Z<<(16-regZ)) &0xFFFFFFFF  ) bitsMore =1;
			uZ.ui += (uZ.ui&1) | bitsMore;
		}
	}

	if (signZ) uZ.ui = -uZ.ui & 0xFFFF;
	return uZ.p;

}

