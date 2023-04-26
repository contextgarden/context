/*
Author: S.H. Leong (Cerlane)

Copyright (c) 2018 Next Generation Arithmetic

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#ifndef INCLUDE_SOFTPOSIT_CPP_H_
#define INCLUDE_SOFTPOSIT_CPP_H_

#include <iostream>
#include "softposit.h"
#include "math.h"
//#include "positMath.h"

#ifdef __cplusplus

struct posit8{
	uint8_t value;

	posit8(double x=0) : value(castUI(convertDoubleToP8(x))) {
	}

	//Equal
	posit8& operator=(const double a) {
		value = castUI(convertDoubleToP8(a));
		return *this;
	}
	posit8& operator=(const int a) {
		value = castUI(i32_to_p8(a));
		return *this;
	}

	//Add
	posit8 operator+(const posit8 &a) const{
		posit8 ans;
		ans.value = castUI(p8_add(castP8(value), castP8(a.value)));
		return ans;
	}

	//Add equal
	posit8& operator+=(const posit8 &a) {
		value = castUI(p8_add(castP8(value), castP8(a.value)));
		return *this;
	}

	//Subtract
	posit8 operator-(const posit8 &a) const{
		posit8 ans;
		ans.value = castUI(p8_sub(castP8(value), castP8(a.value)));
		return ans;
	}

	//Subtract equal
	posit8& operator-=(const posit8 &a) {
		value = castUI(p8_sub(castP8(value), castP8(a.value)));
		return *this;
	}

	//Multiply
	posit8 operator*(const posit8 &a) const{
		posit8 ans;
		ans.value = castUI(p8_mul(castP8(value), castP8(a.value)));
		return ans;
	}

	//Multiply equal
	posit8& operator*=(const posit8 &a) {
		value = castUI(p8_mul(castP8(value), castP8(a.value)));
		return *this;
	}


	//Divide
	posit8 operator/(const posit8 &a) const{
		posit8 ans;
		ans.value = castUI(p8_div(castP8(value), castP8(a.value)));
		return ans;
	}

	//Divide equal
	posit8& operator/=(const posit8 &a) {
		value = castUI(p8_div(castP8(value), castP8(a.value)));
		return *this;
	}

	//less than
	bool operator<(const posit8 &a) const{
		return p8_lt(castP8(value), castP8(a.value));
	}

	//less than equal
	bool operator<=(const posit8 &a) const{
		return p8_le(castP8(value), castP8(a.value));
	}

	//equal
	bool operator==(const posit8 &a) const{
		return p8_eq(castP8(value), castP8(a.value));
	}


	//Not equalCPP
	bool operator!=(const posit8 &a) const{
		return !p8_eq(castP8(value), castP8(a.value));
	}

	//greater than
	bool operator>(const posit8 &a) const{
		return p8_lt(castP8(a.value), castP8(value));
	}

	//greater than equal
	bool operator>=(const posit8 &a) const{
		return p8_le(castP8(a.value), castP8(value));
	}

	//plus plus
	posit8& operator++() {
		value = castUI(p8_add(castP8(value), castP8(0x40)));
		return *this;
	}

	//minus minus
	posit8& operator--() {
		value = castUI(p8_sub(castP8(value), castP8(0x40)));
		return *this;
	}

	//Binary operators

	posit8 operator>>(const int &x) {
		posit8 ans;
		ans.value = value>>x;
		return ans;
	}

	posit8& operator>>=(const int &x) {
		value = value>>x;
		return *this;
	}

	posit8 operator<<(const int &x) {
		posit8 ans;
		ans.value = (value<<x)&0xFF;
		return ans;
	}

	posit8& operator<<=(const int &x) {
		value = (value<<x)&0xFF;
		return *this;
	}


	//Negate
	posit8 operator-() const{
		posit8 ans;
		ans.value = -value;
		return ans;
	}

	//NOT
	posit8 operator~() {
		posit8 ans;
		ans.value = ~value;
		return ans;
	}

	//AND
	posit8 operator&(const posit8 &a) const{
		posit8 ans;
		ans.value = (value & a.value);
		return *this;
	}

	//AND equal
	posit8& operator&=(const posit8 &a) {
		value = (value & a.value);
		return *this;
	}

	//OR
	posit8 operator|(const posit8 &a) const{
		posit8 ans;
		ans.value = (value | a.value);
		return ans;
	}


	//OR equal
	posit8& operator|=(const posit8 &a) {
		value = (value | a.value);
		return *this;
	}

	//XOR
	posit8 operator^(const posit8 &a) const{
		posit8 ans;
		ans.value = (value ^ a.value);
		return ans;
	}

	//XOR equal
	posit8& operator^=(const posit8 &a) {
		value = (value ^ a.value);
		return *this;
	}

	//Logical Operator
	//!
	bool operator!()const{
		return !value;
	}

	//&&
	bool operator&&(const posit8 &a) const{
		return (value && a.value);
	}

	//||
	bool operator||(const posit8 &a) const{
		return (value || a.value);
	}

	bool isNaR(){
		return isNaRP8UI(value);
	}

	double toDouble()const{
		return convertP8ToDouble(castP8(value));
	}

	long long int toInt()const{
		return p8_int(castP8(value));
	}

	long long int toRInt()const{
		return p8_to_i64(castP8(value));
	}
	posit8& sqrt(){
		value = castUI( p8_sqrt(castP8(value)) );
		return *this;
	}
	posit8& rint(){
		value = castUI( p8_roundToInt(castP8(value)) );
		return *this;
	}
	posit8 fma(posit8 a, posit8 b){ // + (a*b)
		posit8 ans;
		ans.value = castUI(p8_mulAdd(castP8(a.value), castP8(b.value), castP8(value)));
		return ans;
	}
	posit8& toNaR(){
		value = 0x80;
		return *this;
	}
};


struct posit16{
	uint16_t value;
	posit16(double x=0) : value(castUI(convertDoubleToP16(x))) {
	}

	//Equal
	posit16& operator=(const double a) {
		value = castUI(convertDoubleToP16(a));
		return *this;
	}
	posit16& operator=(const int a) {
		value = castUI(i32_to_p16(a));
		return *this;
	}

	//Add
	posit16 operator+(const posit16 &a) const{
		posit16 ans;
		ans.value = castUI(p16_add(castP16(value), castP16(a.value)));
		return ans;
	}

	//Add equal
	posit16& operator+=(const posit16 &a) {
		value = castUI(p16_add(castP16(value), castP16(a.value)));
		return *this;
	}

	//Subtract
	posit16 operator-(const posit16 &a) const{
		posit16 ans;
		ans.value = castUI(p16_sub(castP16(value), castP16(a.value)));
		return ans;
	}

	//Subtract equal
	posit16& operator-=(const posit16 &a) {
		value = castUI(p16_sub(castP16(value), castP16(a.value)));
		return *this;
	}

	//Multiply
	posit16 operator*(const posit16 &a) const{
		posit16 ans;
		ans.value = castUI(p16_mul(castP16(value), castP16(a.value)));
		return ans;
	}

	//Multiply equal
	posit16& operator*=(const posit16 &a) {
		value = castUI(p16_mul(castP16(value), castP16(a.value)));
		return *this;
	}


	//Divide
	posit16 operator/(const posit16 &a) const{
		posit16 ans;
		ans.value = castUI(p16_div(castP16(value), castP16(a.value)));
		return ans;
	}

	//Divide equal
	posit16& operator/=(const posit16 &a) {
		value = castUI(p16_div(castP16(value), castP16(a.value)));
		return *this;
	}

	//less than
	bool operator<(const posit16 &a) const{
		return p16_lt(castP16(value), castP16(a.value));
	}

	//less than equal
	bool operator<=(const posit16 &a) const{
		return p16_le(castP16(value), castP16(a.value));
	}

	//equal
	bool operator==(const posit16 &a) const{
		return p16_eq(castP16(value), castP16(a.value));
	}


	//Not equal
	bool operator!=(const posit16 &a) const{
		return !p16_eq(castP16(value), castP16(a.value));
	}

	//greater than
	bool operator>(const posit16 &a) const{
		return p16_lt(castP16(a.value), castP16(value));
	}

	//greater than equal
	bool operator>=(const posit16 &a) const{
		return p16_le(castP16(a.value), castP16(value));
	}

	//plus plus
	posit16& operator++() {
		value = castUI(p16_add(castP16(value), castP16(0x4000)));
		return *this;
	}

	//minus minus
	posit16& operator--() {
		value = castUI(p16_sub(castP16(value), castP16(0x4000)));
		return *this;
	}

	//Binary operators

	posit16 operator>>(const int &x) {
		posit16 ans;
		ans.value = value>>x;
		return ans;
	}

	posit16& operator>>=(const int &x) {
		value = value>>x;
		return *this;
	}

	posit16 operator<<(const int &x) {
		posit16 ans;
		ans.value = (value<<x)&0xFFFF;
		return ans;
	}

	posit16& operator<<=(const int &x) {
		value = (value<<x)&0xFFFF;
		return *this;
	}

	//Negate
	posit16 operator-() const{
		posit16 ans;
		ans.value = -value;
		return ans;
	}

	//Binary NOT
	posit16 operator~() {
		posit16 ans;
		ans.value = ~value;
		return ans;
	}

	//AND
	posit16 operator&(const posit16 &a) const{
		posit16 ans;
		ans.value = (value & a.value);
		return ans;
	}

	//AND equal
	posit16& operator&=(const posit16 &a) {
		value = (value & a.value);
		return *this;
	}

	//OR
	posit16 operator|(const posit16 &a) const{
		posit16 ans;
		ans.value = (value | a.value);
		return ans;
	}


	//OR equal
	posit16& operator|=(const posit16 &a) {
		value = (value | a.value);
		return *this;
	}

	//XOR
	posit16 operator^(const posit16 &a) const{
		posit16 ans;
		ans.value = (value ^ a.value);
		return ans;
	}

	//XOR equal
	posit16& operator^=(const posit16 &a) {
		value = (value ^ a.value);
		return *this;
	}

	//Logical operator
	//!
	bool operator!()const{
		return !value;
	}

	//&&
	bool operator&&(const posit16 &a) const{
		return (value && a.value);
	}

	//||
	bool operator||(const posit16 &a) const{
		return (value || a.value);
	}

	bool isNaR(){
		return isNaRP16UI(value);
	}

	double toDouble()const{
		return convertP16ToDouble(castP16(value));
	}

	long long int toInt()const{
		return p16_int(castP16(value));
	}

	long long int toRInt()const{
		return p16_to_i64(castP16(value));
	}
	posit16& sqrt(){
		value = castUI( p16_sqrt(castP16(value)) );
		return *this;
	}
	posit16& rint(){
		value = castUI( p16_roundToInt(castP16(value)) );
		return *this;
	}
	posit16 fma(posit16 a, posit16 b){ // + (a*b)
		posit16 ans;
		ans.value = castUI(p16_mulAdd(castP16(a.value), castP16(b.value), castP16(value)));
		return ans;
	}
	posit16& toNaR(){
		value = 0x8000;
		return *this;
	}


};

struct posit32{
	uint32_t value;
	posit32(double x=0) : value(castUI(convertDoubleToP32(x))) {
	}

	//Equal
	posit32& operator=(const double a) {
		value = castUI(convertDoubleToP32(a));
		return *this;
	}
	posit32& operator=(const int a) {
		value = castUI(i32_to_p32(a));
		return *this;
	}

	//Add
	posit32 operator+(const posit32 &a) const{
		posit32 ans;
		ans.value = castUI(p32_add(castP32(value), castP32(a.value)));
		return ans;
	}

	//Add equal
	posit32& operator+=(const posit32 &a) {
		value = castUI(p32_add(castP32(value), castP32(a.value)));
		return *this;
	}

	//Subtract
	posit32 operator-(const posit32 &a) const{
		posit32 ans;
		ans.value = castUI(p32_sub(castP32(value), castP32(a.value)));
		return ans;
	}

	//Subtract equal
	posit32& operator-=(const posit32 &a) {
		value = castUI(p32_sub(castP32(value), castP32(a.value)));
		return *this;
	}

	//Multiply
	posit32 operator*(const posit32 &a) const{
		posit32 ans;
		ans.value = castUI(p32_mul(castP32(value), castP32(a.value)));
		return ans;
	}

	//Multiply equal
	posit32& operator*=(const posit32 &a) {
		value = castUI(p32_mul(castP32(value), castP32(a.value)));
		return *this;
	}


	//Divide
	posit32 operator/(const posit32 &a) const{
		posit32 ans;
		ans.value = castUI(p32_div(castP32(value), castP32(a.value)));
		return ans;
	}

	//Divide equal
	posit32& operator/=(const posit32 &a) {
		value = castUI(p32_div(castP32(value), castP32(a.value)));
		return *this;
	}

	//less than
	bool operator<(const posit32 &a) const{
		return p32_lt(castP32(value), castP32(a.value));
	}

	//less than equal
	bool operator<=(const posit32 &a) const{
		return p32_le(castP32(value), castP32(a.value));
	}

	//equal
	bool operator==(const posit32 &a) const{
		return p32_eq(castP32(value), castP32(a.value));
	}


	//Not equalCPP
	bool operator!=(const posit32 &a) const{
		return !p32_eq(castP32(value), castP32(a.value));
	}

	//greater than
	bool operator>(const posit32 &a) const{
		return p32_lt(castP32(a.value), castP32(value));
	}

	//greater than equal
	bool operator>=(const posit32 &a) const{
		return p32_le(castP32(a.value), castP32(value));
	}

	//plus plus
	posit32& operator++() {
		value = castUI(p32_add(castP32(value), castP32(0x40000000)));
		return *this;
	}

	//minus minus
	posit32& operator--() {
		value = castUI(p32_sub(castP32(value), castP32(0x40000000)));
		return *this;
	}

	//Binary operators

	posit32 operator>>(const int &x) {
		posit32 ans;
		ans.value = value>>x;
		return ans;
	}

	posit32& operator>>=(const int &x) {
		value = value>>x;
		return *this;
	}

	posit32 operator<<(const int &x) {
		posit32 ans;
		ans.value = (value<<x)&0xFFFFFFFF;
		return ans;
	}

	posit32& operator<<=(const int &x) {
		value = (value<<x)&0xFFFFFFFF;
		return *this;
	}


	//Negate
	posit32 operator-() const{
		posit32 ans;
		ans.value = -value;
		return ans;
	}

	//NOT
	posit32 operator~() {
		posit32 ans;
		ans.value = ~value;
		return ans;
	}

	//AND
	posit32 operator&(const posit32 &a) const{
		posit32 ans;
		ans.value = (value & a.value);
		return *this;
	}

	//AND equal
	posit32& operator&=(const posit32 &a) {
		value = (value & a.value);
		return *this;
	}

	//OR
	posit32 operator|(const posit32 &a) const{
		posit32 ans;
		ans.value = (value | a.value);
		return ans;
	}


	//OR equal
	posit32& operator|=(const posit32 &a) {
		value = (value | a.value);
		return *this;
	}

	//XOR
	posit32 operator^(const posit32 &a) const{
		posit32 ans;
		ans.value = (value ^ a.value);
		return ans;
	}

	//XOR equal
	posit32& operator^=(const posit32 &a) {
		value = (value ^ a.value);
		return *this;
	}

	//Logical Operator
	//!
	bool operator!()const{
		return !value;
	}

	//&&
	bool operator&&(const posit32 &a) const{
		return (value && a.value);
	}

	//||
	bool operator||(const posit32 &a) const{
		return (value || a.value);
	}

	bool isNaR(){
		return isNaRP32UI(value);
	}

	double toDouble()const{
		return convertP32ToDouble(castP32(value));
	}

	long long int toInt()const{
		return p32_int(castP32(value));
	}

	long long int toRInt()const{
		return p32_to_i64(castP32(value));
	}
	posit32& sqrt(){
		value = castUI( p32_sqrt(castP32(value)) );
		return *this;
	}
	posit32& rint(){
		value = castUI( p32_roundToInt(castP32(value)) );
		return *this;
	}
	posit32 fma(posit32 a, posit32 b){ // + (a*b)
		posit32 ans;
		ans.value = castUI(p32_mulAdd(castP32(a.value), castP32(b.value), castP32(value)));
		return ans;
	}

	posit32& toNaR(){
		value = 0x80000000;
		return *this;
	}


};

struct posit_2{
	uint32_t value;
	int x;
	posit_2(double v=0, int x=32) : value(castUI(convertDoubleToPX2(v, x))), x(x) {
	}

	//Equal
	posit_2& operator=(const double a) {
		value = castUI(convertDoubleToPX2(a, x));
		return *this;
	}
	posit_2& operator=(const int a) {
		value = castUI(i32_to_pX2(a, x));
		return *this;
	}

	//Add
	posit_2 operator+(const posit_2 &a) const{
		posit_2 ans;
		ans.value = castUI(pX2_add(castPX2(value), castPX2(a.value), x));
		ans.x = x;
		return ans;
	}

	//Add equal
	posit_2& operator+=(const posit_2 &a) {
		value = castUI(pX2_add(castPX2(value), castPX2(a.value), x));
		return *this;
	}

	//Subtract
	posit_2 operator-(const posit_2 &a) const{
		posit_2 ans;
		ans.value = castUI(pX2_sub(castPX2(value), castPX2(a.value), x));
		ans.x = x;
		return ans;
	}

	//Subtract equal
	posit_2& operator-=(const posit_2 &a) {
		value = castUI(pX2_sub(castPX2(value), castPX2(a.value), x));
		return *this;
	}

	//Multiply
	posit_2 operator*(const posit_2 &a) const{
		posit_2 ans;
		ans.value = castUI(pX2_mul(castPX2(value), castPX2(a.value), x));
		ans.x = x;
		return ans;
	}

	//Multiply equal
	posit_2& operator*=(const posit_2 &a) {
		value = castUI(pX2_mul(castPX2(value), castPX2(a.value), x));
		return *this;
	}


	//Divide
	posit_2 operator/(const posit_2 &a) const{
		posit_2 ans;
		ans.value = castUI(pX2_div(castPX2(value), castPX2(a.value), x));
		ans.x = x;
		return ans;
	}

	//Divide equal
	posit_2& operator/=(const posit_2 &a) {
		value = castUI(pX2_div(castPX2(value), castPX2(a.value), x));
		return *this;
	}

	//less than
	bool operator<(const posit_2 &a) const{
		return pX2_lt(castPX2(value), castPX2(a.value));
	}

	//less than equal
	bool operator<=(const posit_2 &a) const{
		return pX2_le(castPX2(value), castPX2(a.value));
	}

	//equal
	bool operator==(const posit_2 &a) const{
		return pX2_eq(castPX2(value), castPX2(a.value));
	}


	//Not equalCPP
	bool operator!=(const posit_2 &a) const{
		return !pX2_eq(castPX2(value), castPX2(a.value));
	}

	//greater than
	bool operator>(const posit_2 &a) const{
		return pX2_lt(castPX2(a.value), castPX2(value));
	}

	//greater than equal
	bool operator>=(const posit_2 &a) const{
		return pX2_le(castPX2(a.value), castPX2(value));
	}

	//plus plus
	posit_2& operator++() {
		value = castUI(pX2_add(castPX2(value), castPX2(0x40000000), x));
		return *this;
	}

	//minus minus
	posit_2& operator--() {
		value = castUI(pX2_sub(castPX2(value), castPX2(0x40000000), x));
		return *this;
	}

	//Binary operators

	posit_2 operator>>(const int &x) {
		posit_2 ans;
		ans.value = (value>>x) & ((int32_t)0x80000000>>(x-1));
		ans.x = x;
		return ans;
	}

	posit_2& operator>>=(const int &x) {
		value = (value>>x) & ((int32_t)0x80000000>>(x-1));
		return *this;
	}

	posit_2 operator<<(const int &x) {
		posit_2 ans;
		ans.value = (value<<x)&0xFFFFFFFF;
		ans.x = x;
		return ans;
	}

	posit_2& operator<<=(const int &x) {
		value = (value<<x)&0xFFFFFFFF;
		return *this;
	}


	//Negate
	posit_2 operator-() const{
		posit_2 ans;
		ans.value = -value;
		ans.x = x;
		return ans;
	}

	//NOT
	posit_2 operator~() {
		posit_2 ans;
		ans.value = ~value;
		ans.x = x;
		return ans;
	}

	//AND
	posit_2 operator&(const posit_2 &a) const{
		posit_2 ans;
		ans.value = (value & a.value);
		return *this;
	}

	//AND equal
	posit_2& operator&=(const posit_2 &a) {
		value = (value & a.value);
		return *this;
	}

	//OR
	posit_2 operator|(const posit_2 &a) const{
		posit_2 ans;
		ans.value = (value | a.value);
		return ans;
	}


	//OR equal
	posit_2& operator|=(const posit_2 &a) {
		value = (value | a.value);
		return *this;
	}

	//XOR
	posit_2 operator^(const posit_2 &a) const{
		posit_2 ans;
		ans.value = (value ^ a.value);
		return ans;
	}

	//XOR equal
	posit_2& operator^=(const posit_2 &a) {
		value = (value ^ a.value);
		return *this;
	}

	//Logical Operator
	//!
	bool operator!()const{
		return !value;
	}

	//&&
	bool operator&&(const posit_2 &a) const{
		return (value && a.value);
	}

	//||
	bool operator||(const posit_2 &a) const{
		return (value || a.value);
	}

	bool isNaR(){
		return isNaRPX2UI(value);
	}

	double toDouble()const{
		return convertPX2ToDouble(castPX2(value));
	}

	long long int toInt()const{
		return pX2_int(castPX2(value));
	}

	long long int toRInt()const{
		return pX2_to_i64(castPX2(value));
	}
	posit_2& sqrt(){
		value = castUI( pX2_sqrt(castPX2(value), x) );
		return *this;
	}
	posit_2& rint(){
		value = castUI( pX2_roundToInt(castPX2(value), x) );
		return *this;
	}
	posit_2 fma(posit_2 a, posit_2 b){ // + (a*b)
		posit_2 ans;
		ans.value = castUI(pX2_mulAdd(castPX2(a.value), castPX2(b.value), castPX2(value), x));
		ans.x = x;
		return ans;
	}

	posit_2 toPositX2(int x){
		posit_2 ans;
		ans.value = pX2_to_pX2(castPX2(value), x).v;
		ans.x = x;
		return ans;
	}
	posit_2& toNaR(){
		value = 0x80000000;
		return *this;
	}


};

struct quire8{
	uint32_t value;

	quire8 (uint32_t value=0) : value(value){
	}

	quire8& clr(){
		value = 0;
		return *this;
	}

	bool isNaR(){
		return isNaRQ8(castQ8(value));
	}

	quire8& qma(posit8 a, posit8 b){ // q += a*b
		 quire8_t q = q8_fdp_add(castQ8(value), castP8(a.value), castP8(b.value));
		 value = q.v;
		 return *this;
	}
	quire8& qms(posit16 a, posit16 b){ // q -= a*b
		 quire8_t q = q8_fdp_sub(castQ8(value), castP8(a.value), castP8(b.value));
		 value = q.v;
		 return *this;
	}
	posit8 toPosit(){
		posit8 a;
		a.value = castUI(q8_to_p8(castQ8(value)));
		return a;
	}

};
struct quire16{
	uint64_t lvalue;
	uint64_t rvalue;

	quire16 (uint64_t lvalue=0, uint64_t rvalue=0) : lvalue(lvalue), rvalue(rvalue){
	}

	quire16& clr(){
		lvalue = 0;
		rvalue = 0;
		return *this;
	}

	bool isNaR(){
		return isNaRQ16(castQ16(lvalue, rvalue));
	}

	quire16& qma(posit16 a, posit16 b){ // q += a*b
		 quire16_t q = q16_fdp_add(castQ16(lvalue, rvalue), castP16(a.value), castP16(b.value));
		 lvalue = q.v[0];
		 rvalue = q.v[1];
		 return *this;
	}
	quire16& qms(posit16 a, posit16 b){ // q -= a*b
		 quire16_t q = q16_fdp_sub(castQ16(lvalue, rvalue), castP16(a.value), castP16(b.value));
		 lvalue = q.v[0];
		 rvalue = q.v[1];
		 return *this;
	}
	posit16 toPosit(){
		posit16 a;
		a.value = castUI(q16_to_p16(castQ16(lvalue, rvalue)));
		return a;
	}

};

struct quire32{
	uint64_t v0;
	uint64_t v1;
	uint64_t v2;
	uint64_t v3;
	uint64_t v4;
	uint64_t v5;
	uint64_t v6;
	uint64_t v7;

	quire32 (uint64_t v0=0, uint64_t v1=0, uint64_t v2=0, uint64_t v3=0, uint64_t v4=0, uint64_t v5=0, uint64_t v6=0, uint64_t v7=0) :
		v0(v0), v1(v1), v2(v2), v3(v3), v4(v4), v5(v5), v6(v6), v7(v7){
	}

	quire32& clr(){
		v0 = 0;
		v1 = 0;
		v2 = 0;
		v3 = 0;
		v4 = 0;
		v5 = 0;
		v6 = 0;
		v7 = 0;
		return *this;
	}

	bool isNaR(){
		return isNaRQ32(castQ32(v0, v1, v2, v3, v4, v5, v6, v7));
	}

	quire32& qma(posit32 a, posit32 b){ // q += a*b
		 quire32_t q = q32_fdp_add(castQ32(v0, v1, v2, v3, v4, v5, v6, v7),
				 	 	 	 castP32(a.value), castP32(b.value));
		 v0 = q.v[0];
		 v1 = q.v[1];
		 v2 = q.v[2];
		 v3 = q.v[3];
		 v4 = q.v[4];
		 v5 = q.v[5];
		 v6 = q.v[6];
		 v7 = q.v[7];
		 return *this;
	}
	quire32& qms(posit32 a, posit32 b){ // q -= a*b
		 quire32_t q = q32_fdp_sub(castQ32(v0, v1, v2, v3, v4, v5, v6, v7), castP32(a.value), castP32(b.value));
		 v0 = q.v[0];
		 v1 = q.v[1];
		 v2 = q.v[2];
		 v3 = q.v[3];
		 v4 = q.v[4];
		 v5 = q.v[5];
		 v6 = q.v[6];
		 v7 = q.v[7];
		 return *this;
	}
	posit32 toPosit(){
		posit32 a;
		a.value = castUI(q32_to_p32(castQ32(v0, v1, v2, v3, v4, v5, v6, v7)));
		return a;
	}

};

struct quire_2{
	uint64_t v0;
	uint64_t v1;
	uint64_t v2;
	uint64_t v3;
	uint64_t v4;
	uint64_t v5;
	uint64_t v6;
	uint64_t v7;
	int x;

	quire_2 (uint64_t v0=0, uint64_t v1=0, uint64_t v2=0, uint64_t v3=0, uint64_t v4=0, uint64_t v5=0, uint64_t v6=0, uint64_t v7=0, int x=32) :
		v0(v0), v1(v1), v2(v2), v3(v3), v4(v4), v5(v5), v6(v6), v7(v7), x(x){
	}

	quire_2& clr(){
		v0 = 0;
		v1 = 0;
		v2 = 0;
		v3 = 0;
		v4 = 0;
		v5 = 0;
		v6 = 0;
		v7 = 0;
		return *this;
	}

	bool isNaR(){
		return isNaRQX2(castQX2(v0, v1, v2, v3, v4, v5, v6, v7));
	}

	quire_2& qma(posit_2 a, posit_2 b){ // q += a*b
		 quire_2_t q = qX2_fdp_add(castQX2(v0, v1, v2, v3, v4, v5, v6, v7),
				 	 	 	 castPX2(a.value), castPX2(b.value));
		 v0 = q.v[0];
		 v1 = q.v[1];
		 v2 = q.v[2];
		 v3 = q.v[3];
		 v4 = q.v[4];
		 v5 = q.v[5];
		 v6 = q.v[6];
		 v7 = q.v[7];
		 return *this;
	}
	quire_2& qms(posit_2 a, posit_2 b){ // q -= a*b
		 quire_2_t q = qX2_fdp_sub(castQX2(v0, v1, v2, v3, v4, v5, v6, v7), castPX2(a.value), castPX2(b.value));
		 v0 = q.v[0];
		 v1 = q.v[1];
		 v2 = q.v[2];
		 v3 = q.v[3];
		 v4 = q.v[4];
		 v5 = q.v[5];
		 v6 = q.v[6];
		 v7 = q.v[7];
		 return *this;
	}
	posit_2 toPosit(){
		posit_2 a;
		a.value = castUI(qX2_to_pX2(castQX2(v0, v1, v2, v3, v4, v5, v6, v7), x));
		a.x = x;
		return a;
	}

};

inline posit8 operator+(int a, posit8 b){
	b.value = castUI(p8_add(i32_to_p8(a), castP8(b.value)));
	return b;
}
inline posit16 operator+(int a, posit16 b){
	b.value = castUI(p16_add(i32_to_p16(a), castP16(b.value)));
	return b;
}
inline posit32 operator+(int a, posit32 b){
	b.value = castUI(p32_add(i32_to_p32(a), castP32(b.value)));
	return b;
}
inline posit32 operator+(long long int a, posit32 b){
	b.value = castUI(p32_add(i64_to_p32(a), castP32(b.value)));
	return b;
}
inline posit_2 operator+(int a, posit_2 b){
	b.value = castUI(pX2_add(i32_to_pX2(a, b.x), castPX2(b.value), b.x));
	return b;
}
inline posit_2 operator+(long long int a, posit_2 b){
	b.value = castUI(pX2_add(i64_to_pX2(a, b.x), castPX2(b.value), b.x));
	return b;
}

inline posit8 operator+(double a, posit8 b){
	b.value = castUI(p8_add(convertDoubleToP8(a), castP8(b.value)));
	return b;
}
inline posit16 operator+(double a, posit16 b){
	b.value = castUI(p16_add(convertDoubleToP16(a), castP16(b.value)));
	return b;
}
inline posit32 operator+(double a, posit32 b){
	b.value = castUI(p32_add(convertDoubleToP32(a), castP32(b.value)));
	return b;
}
inline posit_2 operator+(double a, posit_2 b){
	b.value = castUI(pX2_add(convertDoubleToPX2(a, b.x), castPX2(b.value), b.x));
	return b;
}


inline posit8 operator-(int a, posit8 b){
	b.value = castUI(p8_sub(i32_to_p8(a), castP8(b.value)));
	return b;
}
inline posit16 operator-(int a, posit16 b){
	b.value = castUI(p16_sub(i32_to_p16(a), castP16(b.value)));
	return b;
}
inline posit32 operator-(int a, posit32 b){
	b.value = castUI(p32_sub(i32_to_p32(a), castP32(b.value)));
	return b;
}
inline posit32 operator-(long long int a, posit32 b){
	b.value = castUI(p32_sub(i64_to_p32(a), castP32(b.value)));
	return b;
}
inline posit_2 operator-(int a, posit_2 b){
	b.value = castUI(pX2_sub(i32_to_pX2(a, b.x), castPX2(b.value), b.x));
	return b;
}
inline posit_2 operator-(long long int a, posit_2 b){
	b.value = castUI(pX2_sub(i64_to_pX2(a, b.x), castPX2(b.value), b.x));
	return b;
}


inline posit8 operator-(double a, posit8 b){
	b.value = castUI(p8_sub(convertDoubleToP8(a), castP8(b.value)));
	return b;
}
inline posit16 operator-(double a, posit16 b){
	b.value = castUI(p16_sub(convertDoubleToP16(a), castP16(b.value)));
	return b;
}
inline posit32 operator-(double a, posit32 b){
	b.value = castUI(p32_sub(convertDoubleToP32(a), castP32(b.value)));
	return b;
}
inline posit_2 operator-(double a, posit_2 b){
	b.value = castUI(pX2_sub(convertDoubleToPX2(a, b.x), castPX2(b.value), b.x));
	return b;
}



inline posit8 operator/(int a, posit8 b){
	b.value = castUI(p8_div(i32_to_p8(a), castP8(b.value)));
	return b;
}
inline posit16 operator/(int a, posit16 b){
	b.value = castUI(p16_div(i32_to_p16(a), castP16(b.value)));
	return b;
}
inline posit32 operator/(int a, posit32 b){
	b.value = castUI(p32_div(i32_to_p32(a), castP32(b.value)));
	return b;
}
inline posit32 operator/(long long int a, posit32 b){
	b.value = castUI(p32_div(i64_to_p32(a), castP32(b.value)));
	return b;
}
inline posit_2 operator/(int a, posit_2 b){
	b.value = castUI(pX2_div(i32_to_pX2(a, b.x), castPX2(b.value), b.x));
	return b;
}
inline posit_2 operator/(long long int a, posit_2 b){
	b.value = castUI(pX2_div(i64_to_pX2(a, b.x), castPX2(b.value), b.x));
	return b;
}



inline posit8 operator/(double a, posit8 b){
	b.value = castUI(p8_div(convertDoubleToP8(a), castP8(b.value)));
	return b;
}
inline posit16 operator/(double a, posit16 b){
	b.value = castUI(p16_div(convertDoubleToP16(a), castP16(b.value)));
	return b;
}
inline posit32 operator/(double a, posit32 b){
	b.value = castUI(p32_div(convertDoubleToP32(a), castP32(b.value)));
	return b;
}
inline posit_2 operator/(double a, posit_2 b){
	b.value = castUI(pX2_div(convertDoubleToPX2(a, b.x), castPX2(b.value), b.x));
	return b;
}



inline posit8 operator*(int a, posit8 b){
	b.value = castUI(p8_mul(i32_to_p8(a), castP8(b.value)));
	return b;
}
inline posit16 operator*(int a, posit16 b){
	posit16 ans;
	ans.value = castUI(p16_mul(i32_to_p16(a), castP16(b.value)));
	return ans;
}
inline posit32 operator*(int a, posit32 b){
	b.value = castUI(p32_mul(i32_to_p32(a), castP32(b.value)));
	return b;
}
inline posit32 operator*(long long int a, posit32 b){
	b.value = castUI(p32_mul(i64_to_p32(a), castP32(b.value)));
	return b;
}
inline posit_2 operator*(int a, posit_2 b){
	b.value = castUI(pX2_mul(i32_to_pX2(a, b.x), castPX2(b.value), b.x));
	return b;
}
inline posit_2 operator*(long long int a, posit_2 b){
	b.value = castUI(pX2_mul(i64_to_pX2(a, b.x), castPX2(b.value), b.x));
	return b;
}


inline posit8 operator*(double a, posit8 b){
	b.value = castUI(p8_mul(convertDoubleToP8(a), castP8(b.value)));
	return b;
}
inline posit16 operator*(double a, posit16 b){
	posit16 ans;
	ans.value = castUI(p16_mul(convertDoubleToP16(a), castP16(b.value)));
	return ans;
}
inline posit32 operator*(double a, posit32 b){
	b.value = castUI(p32_mul(convertDoubleToP32(a), castP32(b.value)));
	return b;
}
inline posit_2 operator*(double a, posit_2 b){
	b.value = castUI(pX2_mul(convertDoubleToPX2(a, b.x), castPX2(b.value), b.x));
	return b;
}



//fused-multiply-add
inline posit8 fma(posit8 a, posit8 b, posit8 c){ // (a*b) + c
	posit8 ans;
	ans.value = castUI(p8_mulAdd(castP8(a.value), castP8(b.value), castP8(c.value)));
	return ans;
}
inline posit16 fma(posit16 a, posit16 b, posit16 c){ // (a*b) + c
	posit16 ans;
	ans.value = castUI(p16_mulAdd(castP16(a.value), castP16(b.value), castP16(c.value)));
	return ans;
}
inline posit32 fma(posit32 a, posit32 b, posit32 c){ // (a*b) + c
	posit32 ans;
	ans.value = castUI(p32_mulAdd(castP32(a.value), castP32(b.value), castP32(c.value)));
	return ans;
}
inline posit_2 fma(posit_2 a, posit_2 b, posit_2 c){ // (a*b) + c
	posit_2 ans;
	ans.value = castUI(pX2_mulAdd(castPX2(a.value), castPX2(b.value), castPX2(c.value), c.x));
	ans.x = c.x;
	return ans;
}


//Round to nearest integer
inline posit8 rint(posit8 a){
	posit8 ans;
	ans.value = castUI( p8_roundToInt(castP8(a.value)) );
	return ans;
}
inline posit16 rint(posit16 a){
	posit16 ans;
	ans.value = castUI( p16_roundToInt(castP16(a.value)) );
	return ans;
}
inline posit32 rint(posit32 a){
	posit32 ans;
	ans.value = castUI( p32_roundToInt(castP32(a.value)) );
	return ans;
}
inline posit_2 rint(posit_2 a){
	posit_2 ans;
	ans.value = castUI( pX2_roundToInt(castPX2(a.value), a.x) );
	ans.x = a.x;
	return ans;
}

//Square root
inline posit8 sqrt(posit8 a){
	posit8 ans;
	ans.value = castUI( p8_sqrt(castP8(a.value)) );
	return ans;
}
inline posit16 sqrt(posit16 a){
	posit16 ans;
	ans.value = castUI( p16_sqrt(castP16(a.value)) );
	return ans;
}
inline posit32 sqrt(posit32 a){
	posit32 ans;
	ans.value = castUI( p32_sqrt(castP32(a.value)) );
	return ans;
}
inline posit_2 sqrt(posit_2 a){
	posit_2 ans;
	ans.value = castUI( pX2_sqrt(castPX2(a.value), a.x) );
	ans.x = a.x;
	return ans;
}



// Convert to integer

inline uint32_t uint32 (posit8 a){
	return p8_to_ui32(castP8(a.value));
}
inline uint32_t uint32 (posit16 a){
	return p16_to_ui32(castP16(a.value));
}
inline uint32_t uint32 (posit32 a){
	return p32_to_ui32(castP32(a.value));
}
inline uint32_t uint32 (posit_2 a){
	return pX2_to_ui32(castPX2(a.value));
}



inline int32_t int32(posit8 a){
	return p8_to_i32(castP8(a.value));
}
inline int32_t int32(posit16 a){
	return p16_to_i32(castP16(a.value));
}
inline int32_t int32 (posit32 a){
	return p32_to_i32(castP32(a.value));
}
inline int32_t int32 (posit_2 a){
	return pX2_to_i32(castPX2(a.value));
}



inline uint64_t uint64(posit8 a){
	return p8_to_ui64(castP8(a.value));
}
inline uint64_t uint64(posit16 a){
	return p16_to_ui64(castP16(a.value));
}
inline uint64_t uint64 (posit32 a){
	return p32_to_ui64(castP32(a.value));
}
inline uint64_t uint64 (posit_2 a){
	return pX2_to_ui64(castPX2(a.value));
}



inline int64_t int64(posit8 a){
	return p8_to_i64(castP8(a.value));
}
inline int64_t int64(posit16 a){
	return p16_to_i64(castP16(a.value));
}
inline int64_t int64 (posit32 a){
	return p32_to_i64(castP32(a.value));
}
inline int64_t int64 (posit_2 a){
	return pX2_to_i64(castPX2(a.value));
}


//Convert To Posit
inline posit8 p8(posit16 a){
	posit8 b;
	b.value = castUI(p16_to_p8(castP16(a.value)));
	return b;
}
inline posit8 p8(posit32 a){
	posit8 b;
	b.value = castUI(p32_to_p8(castP32(a.value)));
	return b;
}
inline posit8 p8(posit_2 a){
	posit8 b;
	b.value = castUI(pX2_to_p8(castPX2(a.value)));
	return b;
}


inline posit16 p16(posit8 a){
	posit16 b;
	b.value = castUI(p8_to_p16(castP8(a.value)));
	return b;
}
inline posit16 p16(posit32 a){
	posit16 b;
	b.value = castUI(p32_to_p16(castP32(a.value)));
	return b;
}
inline posit16 p16(posit_2 a){
	posit16 b;
	b.value = castUI(pX2_to_p16(castPX2(a.value)));
	return b;
}


inline posit32 p32(posit8 a){
	posit32 b;
	b.value = castUI(p8_to_p32(castP8(a.value)));
	return b;
}
inline posit32 p32(posit16 a){
	posit32 b;
	b.value = castUI(p16_to_p32(castP16(a.value)));
	return b;
}
inline posit32 p32(posit_2 a){
	posit32 b;
	b.value = castUI(pX2_to_p32(castPX2(a.value)));
	return b;
}


inline posit_2 pX2(posit8 a, int x){
	posit_2 b;
	b.value = castUI(p8_to_pX2(castP8(a.value), x));
	b.x = x;
	return b;
}
inline posit_2 pX2(posit16 a, int x){
	posit_2 b;
	b.value = castUI(p16_to_pX2(castP16(a.value), x));
	b.x = x;
	return b;
}
inline posit_2 pX2(posit32 a, int x){
	posit_2 b;
	b.value = castUI(p32_to_pX2(castP32(a.value), x));
	b.x = x;
	return b;
}
inline posit_2 pX2(posit_2 a, int x){
	posit_2 b;
	b.value = castUI(pX2_to_pX2(castPX2(a.value), x));
	b.x = x;
	return b;
}



inline posit8 p8(uint32_t a){
	posit8 b;
	b.value = castUI(ui32_to_p8(a));
	return b;
}
inline posit16 p16(uint32_t a){
	posit16 b;
	b.value = castUI(ui32_to_p16(a));
	return b;
}
inline posit32 p32(uint32_t a){
	posit32 b;
	b.value = castUI(ui32_to_p32(a));
	return b;
}
inline posit_2 pX2(uint32_t a, int x){
	posit_2 b;
	b.value = castUI(ui32_to_pX2(a, x));
	b.x = x;
	return b;
}


inline posit8 p8(int32_t a){
	posit8 b;
	b.value = castUI(i32_to_p8(a));
	return b;
}
inline posit16 p16(int32_t a){
	posit16 b;
	b.value = castUI(i32_to_p16(a));
	return b;
}
inline posit32 p32(int32_t a){
	posit32 b;
	b.value = castUI(i32_to_p32(a));
	return b;
}
inline posit_2 pX2(int32_t a, int x){
	posit_2 b;
	b.value = castUI(i32_to_pX2(a, x));
	b.x = x;
	return b;
}



inline posit8 p8(uint64_t a){
	posit8 b;
	b.value = castUI(ui64_to_p8(a));
	return b;
}
inline posit16 p16(uint64_t a){
	posit16 b;
	b.value = castUI(ui64_to_p16(a));
	return b;
}
inline posit32 p32(uint64_t a){
	posit32 b;
	b.value = castUI(ui64_to_p32(a));
	return b;
}
inline posit_2 pX2(uint64_t a, int x){
	posit_2 b;
	b.value = castUI(ui64_to_pX2(a, x));
	b.x = x;
	return b;
}


inline posit8 p8(int64_t a){
	posit8 b;
	b.value = castUI(i64_to_p8(a));
	return b;
}
inline posit16 p16(int64_t a){
	posit16 b;
	b.value = castUI(i64_to_p16(a));
	return b;
}
inline posit32 p32(int64_t a){
	posit32 b;
	b.value = castUI(i64_to_p32(a));
	return b;
}
inline posit_2 p32(int64_t a, int x){
	posit_2 b;
	b.value = castUI(i64_to_pX2(a, x));
	b.x = x;
	return b;
}


inline posit8 p8(double a){
	posit8 b;
	b.value = castUI(convertDoubleToP8(a));
	return b;
}
inline posit16 p16(double a){
	posit16 b;
	b.value = castUI(convertDoubleToP16(a));
	return b;
}
inline posit32 p32(double a){
	posit32 b;
	b.value = castUI(convertDoubleToP32(a));
	return b;
}
inline posit_2 pX2(double a, int x){
	posit_2 b;
	b.value = castUI(convertDoubleToPX2(a, x));
	b.x = x;
	return b;
}



inline posit8 p8(quire8 a){
	posit8 b;
	b.value = castUI(q8_to_p8(castQ8(a.value)));
	return b;
}
inline posit16 p16(quire16 a){
	posit16 b;
	b.value = castUI(q16_to_p16(castQ16(a.lvalue, a.rvalue)));
	return b;
}
inline posit32 p32(quire32 a){
	posit32 b;
	b.value = castUI(q32_to_p32(castQ32(a.v0, a.v1, a.v2, a.v3, a.v4, a.v5, a.v6, a.v7)));
	return b;
}
inline posit_2 pX2(quire_2 a){
	posit_2 b;
	b.value = castUI(qX2_to_pX2(castQX2(a.v0, a.v1, a.v2, a.v3, a.v4, a.v5, a.v6, a.v7), a.x));
	b.x = a.x;
	return b;
}
inline posit_2 pX2(quire_2 a, int x){
	posit_2 b;
	b.value = castUI(qX2_to_pX2(castQX2(a.v0, a.v1, a.v2, a.v3, a.v4, a.v5, a.v6, a.v7), x));
	b.x = x;
	return b;
}


//cout helper functions

inline std::ostream& operator<<(std::ostream& os, const posit8& p) {
    os << p.toDouble();
    return os;
}

inline std::ostream& operator<<(std::ostream& os, const posit16& p) {
    os << p.toDouble();
    return os;
}

inline std::ostream& operator<<(std::ostream& os, const posit32& p) {
    os << p.toDouble();
    return os;
}

inline std::ostream& operator<<(std::ostream& os, const posit_2& p) {
    os << p.toDouble();
    return os;
}

//Math lib

/*inline posit8 abs(posit8 a){
	a.value = castUI(p8_abs(castP8(a.value)));
	return a;
}

inline posit16 abs(posit16 a){
	a.value = castUI(p16_abs(castP16(a.value)));
	return a;
}


inline posit32 abs(posit32 a){
	a.value = castUI(p32_abs(castP32(a.value)));
	return a;
}


inline posit8 ceil(posit8 a){
	a.value = castUI(p8_ceil(castP8(a.value)));
	return a;
}

inline posit16 ceil(posit16 a){
	a.value = castUI(p16_ceil(castP16(a.value)));
	return a;
}

inline posit32 ceil(posit32 a){
	a.value = castUI(p32_ceil(castP32(a.value)));
	return a;
}


inline posit8 floor(posit8 a){
	a.value = castUI(p8_floor(castP8(a.value)));
	return a;
}
inline posit16 floor(posit16 a){
	a.value = castUI(p16_floor(castP16(a.value)));
	return a;
}
inline posit32 floor(posit32 a){
	a.value = castUI(p32_floor(castP32(a.value)));
	return a;
}


inline posit8 exp(posit8 a){
	a.value = castUI(p8_exp(castP8(a.value)));
	return a;
}
inline posit16 exp(posit16 a){
	a.value = castUI(p16_exp(castP16(a.value)));
	return a;
}
inline posit32 exp(posit32 a){
	a.value = castUI(convertDoubleToP32(exp(convertP32ToDouble(castP32(a.value)))));
	return a;
}



inline posit8 pow(posit8 a, posit8 b){
	a.value = castUI(convertDoubleToP8(pow(convertP8ToDouble(castP8(a.value)), convertP8ToDouble(castP8(b.value)))));
	return a;
}
inline posit16 pow(posit16 a, posit16 b){
	a.value = castUI(convertDoubleToP16(pow(convertP16ToDouble(castP16(a.value)), convertP16ToDouble(castP16(b.value)))));
	return a;
}
inline posit32 pow(posit32 a, posit32 b){
	a.value = castUI(convertDoubleToP32(pow(convertP32ToDouble(castP32(a.value)), convertP32ToDouble(castP32(b.value)))));
	return a;
}


inline posit8 log(posit8 a){
	a.value = castUI(convertDoubleToP8(log(convertP8ToDouble(castP8(a.value)))));
	return a;
}
inline posit16 log(posit16 a){
	a.value = castUI(convertDoubleToP16(log(convertP16ToDouble(castP16(a.value)))));
	return a;
}
inline posit32 log(posit32 a){
	a.value = castUI(convertDoubleToP32(log(convertP32ToDouble(castP32(a.value)))));
	return a;
}


inline posit8 log2(posit8 a){
	a.value = castUI(convertDoubleToP8(log2(convertP8ToDouble(castP8(a.value)))));
	return a;
}
inline posit16 log2(posit16 a){
	a.value = castUI(convertDoubleToP16(log2(convertP16ToDouble(castP16(a.value)))));
	return a;
}
inline posit32 log2(posit32 a){
	a.value = castUI(convertDoubleToP32(log2(convertP32ToDouble(castP32(a.value)))));
	return a;
}


inline posit8 cos(posit8 a){
	a.value = castUI(convertDoubleToP8(cos(convertP8ToDouble(castP8(a.value)))));
	return a;
}
inline posit16 cos(posit16 a){
	a.value = castUI(convertDoubleToP16(cos(convertP16ToDouble(castP16(a.value)))));
	return a;
}
inline posit32 cos(posit32 a){
	a.value = castUI(convertDoubleToP32(cos(convertP32ToDouble(castP32(a.value)))));
	return a;
}


inline posit8 sin(posit8 a){
	a.value = castUI(convertDoubleToP8(sin(convertP8ToDouble(castP8(a.value)))));
	return a;
}
inline posit16 sin(posit16 a){
	a.value = castUI(convertDoubleToP16(sin(convertP16ToDouble(castP16(a.value)))));
	return a;
}
inline posit32 sin(posit32 a){
	a.value = castUI(convertDoubleToP32(sin(convertP32ToDouble(castP32(a.value)))));
	return a;
}


inline posit8 acos(posit8 a){
	a.value = castUI(convertDoubleToP8(acos(convertP8ToDouble(castP8(a.value)))));
	return a;
}
inline posit16 acos(posit16 a){
	a.value = castUI(convertDoubleToP16(acos(convertP16ToDouble(castP16(a.value)))));
	return a;
}
inline posit32 acos(posit32 a){
	a.value = castUI(convertDoubleToP32(acos(convertP32ToDouble(castP32(a.value)))));
	return a;
}*/


#endif //CPLUSPLUS

#endif /* INCLUDE_SOFTPOSIT_CPP_H_ */
