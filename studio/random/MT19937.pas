unit MT19937;
{$R-} {range checking off}
{$Q-} {overflow checking off}

{----------------------------------------------------------------------
   Mersenne Twister: A 623-Dimensionally Equidistributed Uniform
   Pseudo-Random Number Generator.

   What is Mersenne Twister?
   Mersenne Twister(MT) is a pseudorandom number generator developped by
   Makoto Matsumoto and Takuji Nishimura (alphabetical order) during
   1996-1997. MT has the following merits:
   It is designed with consideration on the flaws of various existing
   generators.
   Far longer period and far higher order of equidistribution than any
   other implemented generators. (It is proved that the period is 2^19937-1,
   and 623-dimensional equidistribution property is assured.)
   Fast generation. (Although it depends on the system, it is reported that
   MT is sometimes faster than the standard ANSI-C library in a system
   with pipeline and cache memory.)
   Efficient use of the memory. (The implemented C-code mt19937.c
   consumes only 624 words of working area.)

   home page
     http://www.math.keio.ac.jp/~matumoto/emt.html
   original c source
     http://www.math.keio.ac.jp/~nisimura/random/int/mt19937int.c

   Coded by Takuji Nishimura, considering the suggestions by
   Topher Cooper and Marc Rieffel in July-Aug. 1997.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later
   version.
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
   See the GNU Library General Public License for more details.
   You should have received a copy of the GNU Library General
   Public License along with this library; if not, write to the
   Free Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
   02111-1307  USA

   Copyright (C) 1997, 1999 Makoto Matsumoto and Takuji Nishimura.
   When you use this, send an email to: matumoto@math.keio.ac.jp
   with an appropriate reference to your work.

   REFERENCE
   M. Matsumoto and T. Nishimura,
   "Mersenne Twister: A 623-Dimensionally Equidistributed Uniform
   Pseudo-Random Number Generator",
   ACM Transactions on Modeling and Computer Simulation,
   Vol. 8, No. 1, January 1998, pp 3--30.


  Translated to OP and Delphi interface added by Roman Krejci (6.12.1999)

  http://www.rksolution.cz/delphi/tips.htm

  Revised 21.6.2000: Bug in the function RandInt_MT19937 fixed
 ----------------------------------------------------------------------}




interface

{ Period parameter }
Const
  MT19937N=624;

Type
  tMT19937StateArray = array [0..MT19937N-1] of longint; // the array for the state vector

procedure sgenrand_MT19937(seed: longint);         // Initialization by seed
procedure lsgenrand_MT19937(const seed_array: tMT19937StateArray); // Initialization by array of seeds
procedure randomize_MT19937;                       // randomization
function  randInt_MT19937(Range: longint):longint; // integer RANDOM with positive range
function  genrand_MT19937: longint;                // random longint (full range);
function  randFloat_MT19937: Double;               // float RANDOM on 0..1 interval

procedure FillBuffer_MT19937(Buffer : PChar; Length : Integer); // Fills a buffer.  Written by John Newbigin
type PLongInt = ^LongInt;

implementation

{ Period parameters }
const
  MT19937M=397;
  MT19937MATRIX_A  =$9908b0df;  // constant vector a
  MT19937UPPER_MASK=$80000000;  // most significant w-r bits
  MT19937LOWER_MASK=$7fffffff;  // least significant r bits

{ Tempering parameters }
  TEMPERING_MASK_B=$9d2c5680;
  TEMPERING_MASK_C=$efc60000;


VAR
  mt : tMT19937StateArray;
  mti: integer=MT19937N+1; // mti=MT19937N+1 means mt[] is not initialized

{ Initializing the array with a seed }
procedure sgenrand_MT19937(seed: longint);
var
  i: integer;
begin
  for i := 0 to MT19937N-1 do begin
    mt[i] := seed and $ffff0000;
    seed := 69069 * seed + 1;
    mt[i] := mt[i] or ((seed and $ffff0000) shr 16);
    seed := 69069 * seed + 1;
  end;
  mti := MT19937N;
end;

{
   Initialization by "sgenrand_MT19937()" is an example. Theoretically,
   there are 2^19937-1 possible states as an intial state.
   This function (lsgenrand_MT19937) allows to choose any of 2^19937-1 ones.
   Essential bits in "seed_array[]" is following 19937 bits:
    (seed_array[0]&MT19937UPPER_MASK), seed_array[1], ..., seed_array[MT19937-1].
    (seed_array[0]&MT19937LOWER_MASK) is discarded.
   Theoretically,
    (seed_array[0]&MT19937UPPER_MASK), seed_array[1], ..., seed_array[MT19937N-1]
   can take any values except all zeros.
}
procedure lsgenrand_MT19937(const seed_array: tMT19937StateArray);
VAR
  i: integer;
begin
  for i := 0 to MT19937N-1 do mt[i] := seed_array[i];
  mti := MT19937N;
end;

function genrand_MT19937: longint;
const
  mag01 : array [0..1] of longint =(0, MT19937MATRIX_A);
var
  y: longint;
  kk: integer;
begin
  if mti >= MT19937N { generate MT19937N longints at one time }
  then begin
     if mti = (MT19937N+1) then  // if sgenrand_MT19937() has not been called,
       sgenrand_MT19937(4357);   // default initial seed is used
     for kk:=0 to MT19937N-MT19937M-1 do begin
        y := (mt[kk] and MT19937UPPER_MASK) or (mt[kk+1] and MT19937LOWER_MASK);
        mt[kk] := mt[kk+MT19937M] xor (y shr 1) xor mag01[y and $00000001];
     end;
     for kk:= MT19937N-MT19937M to MT19937N-2 do begin
       y := (mt[kk] and MT19937UPPER_MASK) or (mt[kk+1] and MT19937LOWER_MASK);
       mt[kk] := mt[kk+(MT19937M-MT19937N)] xor (y shr 1) xor mag01[y and $00000001];
     end;
     y := (mt[MT19937N-1] and MT19937UPPER_MASK) or (mt[0] and MT19937LOWER_MASK);
     mt[MT19937N-1] := mt[MT19937M-1] xor (y shr 1) xor mag01[y and $00000001];
     mti := 0;
  end;
  y := mt[mti]; inc(mti);
  y := y xor (y shr 11);
  y := y xor (y shl 7)  and TEMPERING_MASK_B;
  y := y xor (y shl 15) and TEMPERING_MASK_C;
  y := y xor (y shr 18);
  Result := y;
end;

{ Delphi interface }

procedure Randomize_MT19937;
Var OldRandSeed: longint;
begin
  OldRandSeed := System.randseed;     // save system RandSeed value
  System.randomize;                   // randseed value based on system time is generated
  sgenrand_MT19937(System.randSeed);  // initialize generator state array
  System.randseed := OldRandSeed;     // restore system RandSeed
end;

// bug fixed 21.6.2000. 
Function  RandInt_MT19937(Range: longint):longint;
// EAX <- Range
// Result -> EAX
asm
  PUSH  EAX
  CALL  genrand_MT19937
  POP   EDX
  MUL   EDX
  MOV   EAX,EDX
end;

function RandFloat_MT19937: Double;
const   Minus32: double = -32.0;
asm
  CALL    genrand_MT19937
  PUSH    0
  PUSH    EAX
  FLD     Minus32
  FILD    qword ptr [ESP]
  ADD     ESP,8
  FSCALE
  FSTP    ST(1)
end;

procedure FillBuffer_MT19937(Buffer : PChar; Length : Integer); // Fills a buffer.  Written by John Newbigin
var
   RandomValue : LongInt;
   Data  : PLongInt;
   i     : Integer;
begin
   i := 0;
   while i + 3 < Length do
   begin
      PLongInt(@Buffer[i])^ := genrand_MT19937;
      i := i + sizeof(LongInt);
   end;
   while i < Length do
   begin
      // byte at a time
      RandomValue := genrand_MT19937;
      Buffer[i] := Char(RandomValue);
      i := i + 1;
   end;
end;

end.



