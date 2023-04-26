
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

//a*b+c
posit_2_t
  softposit_mulAddPX2(
     uint_fast32_t uiA, uint_fast32_t uiB, uint_fast32_t uiC, uint_fast32_t op, int x ){

	union ui32_pX2 uZ;
	int regZ;
	uint_fast32_t fracA, fracZ, regime, tmp;
	bool signA, signB, signC, signZ, regSA, regSB, regSC, regSZ, bitNPlusOne=0, bitsMore=0, rcarry;
	int_fast32_t expA, expC, expZ;
	int_fast16_t kA=0, kC=0, kZ=0, shiftRight;
	uint_fast64_t frac64C, frac64Z;

    if (x<2 || x>32){
    	uZ.ui = 0x80000000;
    	return uZ.p;
    }

	//NaR
	if ( uiA==0x80000000 || uiB==0x80000000  || uiC==0x80000000 ){
		uZ.ui = 0x80000000;
		return uZ.p;
	}
	else if (uiA==0 || uiB==0){
		if (op == softposit_mulAdd_subC)
			uZ.ui = -uiC;
		else
			uZ.ui = uiC;
		return uZ.p;
	}

	signA = signP32UI( uiA );
	signB = signP32UI( uiB );
	signC = signP32UI( uiC );//^ (op == softposit_mulAdd_subC);
	signZ = signA ^ signB;// ^ (op == softposit_mulAdd_subProd);

	if(signA) uiA = (-uiA & 0xFFFFFFFF);
	if(signB) uiB = (-uiB & 0xFFFFFFFF);
	if(signC) uiC = (-uiC & 0xFFFFFFFF);

	regSA = signregP32UI(uiA);
	regSB = signregP32UI(uiB);
	regSC = signregP32UI(uiC);

    if (x==2){
    	uZ.ui = (regSA&regSB) ? (0x40000000) : (0x0);
    	if (signZ){// i.e. negative prod
    		if (signC){
    			uZ.ui |= uiC;
    			uZ.ui = -uZ.ui & 0xFFFFFFFF;
    		}
    		else{//prod is negative
    			if (uiC==uZ.ui) uZ.ui = 0;
    			else uZ.ui =(uZ.ui>0)?( 0xC0000000):(0x40000000);
    		}
    	}
    	else{ //prod : same sign signZ=0
    		if (signC){
    			if (uiC==uZ.ui)  uZ.ui = 0;
    			else uZ.ui = (uZ.ui>0) ? (0x40000000) : (0xC0000000);
    		}
    		else{//C is positive
    			uZ.ui |= uiC;
    		}
    	}
    	return uZ.p;
    }
    else{
    	tmp = (uiA<<2)&0xFFFFFFFF;
		if (regSA){
			while (tmp>>31){
				kA++;
				tmp= (tmp<<1) & 0xFFFFFFFF;
			}
		}
		else{
			kA=-1;
			while (!(tmp>>31)){
				kA--;
				tmp= (tmp<<1) & 0xFFFFFFFF;
			}
			tmp&=0x7FFFFFFF;
		}
		expA = tmp>>29; //to get 2 bits
		fracA = ((tmp<<2) | 0x80000000) & 0xFFFFFFFF;

		tmp = (uiB<<2)&0xFFFFFFFF;
		if (regSB){
			while (tmp>>31){
				kA++;
				tmp= (tmp<<1) & 0xFFFFFFFF;
			}
		}
		else{
			kA--;
			while (!(tmp>>31)){
				kA--;
				tmp= (tmp<<1) & 0xFFFFFFFF;
			}
			tmp&=0x7FFFFFFF;
		}
		expA += tmp>>29;
		frac64Z = (uint_fast64_t) fracA * (((tmp<<2) | 0x80000000) & 0xFFFFFFFF);

		if (expA>3){
			kA++;
			expA&=0x3; // -=4
		}

		rcarry = frac64Z>>63;//1st bit of frac64Z
		if (rcarry){
			expA++;
			if (expA>3){
				kA ++;
				expA&=0x3;
			}
			frac64Z>>=1;
		}

		if (uiC!=0){
			tmp = (uiC<<2)&0xFFFFFFFF;
			if (regSC){
				while (tmp>>31){
					kC++;
					tmp= (tmp<<1) & 0xFFFFFFFF;
				}
			}
			else{
				kC=-1;
				while (!(tmp>>31)){
					kC--;
					tmp= (tmp<<1) & 0xFFFFFFFF;
				}
				tmp&=0x7FFFFFFF;
			}

			expC = tmp>>29; //to get 2 bits
			frac64C = (((tmp<<1) | 0x40000000ULL) & 0x7FFFFFFFULL)<<32;
			shiftRight = ((kA-kC)<<2) + (expA-expC);

			if (shiftRight<0){ // |uiC| > |Prod|
				if (shiftRight<=-63){
					bitsMore = 1;
					frac64Z = 0;
					//set bitsMore to one?
				}
				else if ((frac64Z<<(64+shiftRight))!=0) bitsMore = 1;

				if (signZ==signC)
					frac64Z = frac64C + (frac64Z>>-shiftRight);
				else {//different signs
					frac64Z = frac64C - (frac64Z>>-shiftRight) ;
					signZ=signC;
					if (bitsMore) frac64Z-=1;
				}
				kZ = kC;
				expZ = expC;
			}
			else if (shiftRight>0){// |uiC| < |Prod|
				//if (frac32C&((1<<shiftRight)-1)) bitsMore = 1;
				if(shiftRight>=63) {
					bitsMore = 1;
					frac64C = 0;
				}
				else if ((frac64C<<(64-shiftRight))!=0) bitsMore = 1;
				if (signZ==signC)
					frac64Z = frac64Z + (frac64C>>shiftRight);
				else{
					frac64Z = frac64Z - (frac64C>>shiftRight);
					if (bitsMore) frac64Z-=1;
				}
				kZ = kA;
				expZ = expA;

			}
			else{
				if(frac64C==frac64Z && signZ!=signC ){ //check if same number
						uZ.ui = 0;
						return uZ.p;
				}
				else{
					if (signZ==signC)
						frac64Z += frac64C;
					else{
						if (frac64Z<frac64C){
							frac64Z = frac64C - frac64Z;
							signZ = signC;
						}
						else{
							frac64Z -= frac64C;
						}
					}
				}
				kZ = kA;// actually can be kC too, no diff
				expZ = expA; //same here
			}
			rcarry = (uint64_t)frac64Z>>63; //first left bit

			if(rcarry){
				expZ++;
				if (expZ>3){
					kZ++;
					expZ&=0x3;
				}
				frac64Z=(frac64Z>>1)&0x7FFFFFFFFFFFFFFF;
			}
			else {
				//for subtract cases
				if (frac64Z!=0){
					while((frac64Z>>59)==0){
						kZ--;
						frac64Z<<=4;
					}
					while((frac64Z>>62)==0){
						expZ--;
						frac64Z<<=1;
						if (expZ<0){
							kZ--;
							expZ=3;
						}
					}
				}

			}

		}
		else{
			kZ = kA;
			expZ=expA;
		}

		if(kZ<0){
			regZ = -kZ;
			regSZ = 0;
			regime = 0x40000000>>regZ;
		}
		else{
			regZ = kZ+1;
			regSZ=1;
			regime = 0x7FFFFFFF - (0x7FFFFFFF>>regZ);
		}

		if(regZ>(x-2)){
			//max or min pos. exp and frac does not matter.
			uZ.ui=(regSZ) ? (0x7FFFFFFF & ((int32_t)0x80000000>>(x-1)) ): (0x1 << (32-x));
		}
		else{

			if (regZ<x){
				//remove hidden bits
				frac64Z &= 0x3FFFFFFFFFFFFFFF;
				fracZ = frac64Z >> (regZ + 34);//frac32Z>>16;

				if (regZ<=(x-4)){
					bitNPlusOne |= (((uint64_t)0x8000000000000000>>(x-regZ-2)) & frac64Z) ;
					bitsMore = (((uint64_t)0x7FFFFFFFFFFFFFFF>>(x-regZ-2)) & frac64Z) ;
					fracZ &=((int32_t)0x80000000>>(x-1));
				}
				else {

					if (regZ==(x-2)){

						bitNPlusOne = expZ&0x2;
						bitsMore = (expZ&0x1);
						expZ = 0;
					}
					else if (regZ==(x-3)){

						bitNPlusOne = expZ&0x1;
						expZ &=0x2;

					}
					if (frac64Z>0){
						fracZ=0;
						bitsMore =1;

					}
				}
			}
			else{
				regime=(regSZ) ? (regime & ((int32_t)0x80000000>>(x-1)) ): (regime << (32-x));
				expZ=0;
				fracZ=0;
			}

			expZ <<= (28-regZ);

			uZ.ui = packToP32UI(regime, expZ, fracZ);

			if (bitNPlusOne){
				uZ.ui += (uint32_t)(((uZ.ui>>(32-x))&1) | bitsMore) << (32-x) ;
			}

		}
		if (signZ) uZ.ui = -uZ.ui & 0xFFFFFFFF;
		return uZ.p;
    }


}

