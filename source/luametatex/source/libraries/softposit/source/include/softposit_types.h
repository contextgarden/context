
/*============================================================================

This C header file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017, 2018 A*STAR.  All rights reserved.

This C header file was based on SoftFloat IEEE Floating-Point Arithmetic
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

#ifndef softposit_types_h
#define softposit_types_h 1

#include <stdint.h>

/*----------------------------------------------------------------------------
| Types used to pass 16-bit, 32-bit, 64-bit, and 128-bit floating-point
| arguments and results to/from functions.  These types must be exactly
| 16 bits, 32 bits, 64 bits, and 128 bits in size, respectively.  Where a
| platform has "native" support for IEEE-Standard floating-point formats,
| the types below may, if desired, be defined as aliases for the native types
| (typically 'float' and 'double', and possibly 'long double').
*----------------------------------------------------------------------------*/

#ifdef SOFTPOSIT_EXACT
	typedef struct { uint8_t v; bool exact; } posit8_t;
	typedef struct { uint_fast16_t v; bool exact; } posit16_t;
	typedef struct { uint32_t v; bool exact; } posit32_t;
	typedef struct { uint64_t v; bool exact; } posit64_t;
	typedef struct { uint64_t v[2]; bool exact; } posit128_t;

	typedef struct { uint64_t v[2]; bool exact; } quire16_t;
#else
	typedef struct { uint8_t v; } posit8_t;
	typedef struct { uint16_t v; } posit16_t;
	typedef struct { uint32_t v; } posit32_t;
	typedef struct { uint64_t v; } posit64_t;
	typedef struct { uint64_t v[2]; } posit128_t;

	typedef struct { uint32_t v; } quire8_t;
	typedef struct { uint64_t v[2]; } quire16_t;
	typedef struct { uint64_t v[8]; } quire32_t;

	typedef struct { uint32_t v; } posit_2_t;
	typedef struct { uint32_t v; } posit_1_t;
	typedef struct { uint32_t v; } posit_0_t;

	typedef struct { uint64_t v[8]; } quire_2_t;
	typedef struct { uint64_t v[8]; } quire_1_t;
	typedef struct { uint64_t v[8]; } quire_0_t;

#endif


#ifdef SOFTPOSIT_EXACT
	typedef struct { uint8_t v; bool exact; } uint8e_t;
	typedef struct { uint16_t v; bool exact; } uint16e_t;
	typedef struct { uint32_t v; bool exact; } uint32e_t;
	typedef struct { uint64_t v; bool exact; } uint64e_t;
	typedef struct { uint64_t v[2]; bool exact; } uint128e_t;

	union ui8_p8   { uint8e_t ui; posit8_t p; };
	union ui16_p16 { uint16e_t ui; posit16_t p; };
	union ui32_p32 { uint32e_t ui; posit32_t p; };
	union ui64_p64 { uint64e_t ui; posit64_t p; };

	union ui128_q16 { uint64_t ui[2]; quire16_t q; };
#else
	union ui8_p8   { uint8_t ui; posit8_t p; };
	union ui16_p16 { uint16_t ui; posit16_t p; };
	union ui32_p32 { uint32_t ui; posit32_t p; };
	union ui64_p64 { uint64_t ui; posit64_t p; };
	union ui128_p128c {uint64_t ui[2]; posit128_t p;}; //c to differentiate from original implementation

	union ui32_pX2 { uint32_t ui; posit_2_t p; };
	union ui32_pX1 { uint32_t ui; posit_1_t p; };
	union ui32_pX0 { uint32_t ui; posit_1_t p; };

	union ui64_double   { uint64_t ui; double d; };

	union ui32_q8 {
		uint32_t ui;    // =0;                  // patched by HH because the compilers don't like this 
		quire8_t q;
	};
	union ui128_q16 {
		uint64_t ui[2]; // ={0,0};              // idem 
		quire16_t q;
	};

	union ui512_q32 {
		uint64_t ui[8]; // ={0,0,0,0, 0,0,0,0}; // idme 
		quire32_t q;
	};

	union ui512_qX2 {
		uint64_t ui[8]; // ={0,0,0,0, 0,0,0,0}; // idem
		quire_2_t q;
	};

	union ui512_qX1 {
		uint64_t ui[8]; // ={0,0,0,0, 0,0,0,0}; // idem 
		quire_1_t q;
	};
#endif


#endif

