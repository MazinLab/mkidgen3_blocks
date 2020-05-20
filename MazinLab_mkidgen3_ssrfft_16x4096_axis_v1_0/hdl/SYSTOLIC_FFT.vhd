-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- ? Copyright 2018 Xilinx, Inc. All rights reserved.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-----------------------------------------------------------------------------------------------
--
-- Disclaimer:
--         This disclaimer is not a license and does not grant any rights to the materials
--         distributed herewith. Except as otherwise provided in a valid license issued to you
--         by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--         ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--         WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--         TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--         PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--         negligence, or under any other theory of liability) for any loss or damage of any
--         kind or nature related to, arising under or in connection with these materials,
--         including for any direct, or any indirect, special, incidental, or consequential
--         loss or damage (including loss of data, profits, goodwill, or any type of loss or
--         damage suffered as a result of any action brought by a third party) even if such
--         damage or loss was reasonably foreseeable or Xilinx had been advised of the
--         possibility of the same.
--
-- CRITICAL APPLICATIONS
--         Xilinx products are not designed or intended to be fail-safe, or for use in any
--         application requiring fail-safe performance, such as life-support or safety devices
--         or systems, Class III medical devices, nuclear facilities, applications related to
--         the deployment of airbags, or any other applications that could lead to death,
--         personal injury, or severe property or environmental damage (individually and
--         collectively, "Critical Applications"). Customer assumes the sole risk and
--         liability of any use of Xilinx products in Critical Applications, subject only to
--         applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             SYSTOLIC_FFT.vhd
--  /   /                  Date Last Modified:   9 Mar 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     SYSTOLIC_FFT
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-Mar-09 Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Arbitrary Size, Systolic FFT Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity SYSTOLIC_FFT is
  generic(N:INTEGER;
          SSR:INTEGER; --93
          W_high:INTEGER:=1;
          W_low:INTEGER:=-17;
          ROUNDING:BOOLEAN:=TRUE;
          BRAM_THRESHOLD:INTEGER:=256;
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end SYSTOLIC_FFT;

architecture TEST of SYSTOLIC_FFT is
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute keep_hierarchy:STRING;
  attribute keep_hierarchy of all:architecture is "yes";
  
--2008  constant RADIX:INTEGER:=I'length;      -- this is the Systolic FFT RADIX or SSR
  constant RADIX:INTEGER:=SSR;           -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  constant F:INTEGER:=L2N mod L2R;       -- if F is not zero there will be a partial last stage
  constant G:INTEGER:=2**F;              -- size of each CB and PARFFT in last stage
  constant H:INTEGER:=RADIX/G;           -- number of CBs and PARFFTsin last stage
  constant SIZE:INTEGER:=(L2N-1)/L2R;    -- ceil(LOG2(N)/LOG2(RADIX)), number of stages
--2008  constant BIT_GROWTH:INTEGER:=MAX(O(O'low).RE'high,O(O'low).IM'high)-MAX(I(I'low).RE'high,I(I'low).IM'high);
  constant BIT_GROWTH:INTEGER:=(O'high+1)/2/SSR-(I'high+1)/2/SSR;

--  constant XL:INTEGER:=work.COMPLEX_FIXED_PKG.MIN((SIZE-1)*L2R,BIT_GROWTH);
  constant XL:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(SIZE*L2R,BIT_GROWTH);
--2008  signal D:CFIXED_MATRIX(0 to SIZE)(I'range)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
  type CFIXED_MATRIX is array(INTEGER range <>) of CFIXED_VECTOR(O'range); -- unconstrained array of CFIXED_VECTOR
  signal D:CFIXED_MATRIX(0 to SIZE);
  signal V:BOOLEAN_VECTOR(0 to SIZE);
--2008  signal S:UNSIGNED_VECTOR(0 to SIZE)(SI'range);
  type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(SI'range); --93
  signal S:UNSIGNED_VECTOR(0 to SIZE);

--  constant XI:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(SIZE*L2R,BIT_GROWTH);
  constant XI:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(L2N,BIT_GROWTH);
--2008  signal DI:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'high+XI downto I(I'low).RE'low),IM(I(I'low).IM'high+XI downto I(I'low).IM'low));
--2008  signal OO:CFIXED_VECTOR(O'range)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
  signal DI:CFIXED_VECTOR(I'high+2*SSR*XI downto I'low);
  signal OO:CFIXED_VECTOR(O'range);
begin
--2008  lj:for J in I'range generate
--2008       D(D'low)(J)<=RESIZE(I(J),D(D'low)(J));
  lj:for J in 0 to SSR-1 generate
       D(D'low)(O'length/SSR*(J+1)-1+O'low downto O'length/SSR*J+O'low)<=CFIXED_VECTOR(RESIZE(ELEMENT(I,J,SSR),(O'high+1)/2/SSR-1,O'low/2/SSR));
     end generate;
  V(V'low)<=VI;
  S(S'low)<=SI;
  lk:for K in 0 to SIZE-1 generate
       constant XI:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(K*L2R,BIT_GROWTH);
       constant XO:INTEGER:=work.COMPLEX_FIXED_PKG.MIN((K+1)*L2R,BIT_GROWTH);
--2008       signal DI:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'high+XI downto I(I'low).RE'low),IM(I(I'low).IM'high+XI downto I(I'low).IM'low));
--2008       signal DM,DB,DO:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'high+XO downto I(I'low).RE'low),IM(I(I'low).IM'high+XO downto I(I'low).IM'low));
       signal DI:CFIXED_VECTOR(I'high+2*SSR*XI downto I'low);
       signal DM,DB,DO:CFIXED_VECTOR(I'high+2*SSR*XO downto I'low);
       signal VM,VB:BOOLEAN;
       signal SM,SB:UNSIGNED(SI'range);
     begin
--2008       li:for J in 0 to I'length-1 generate
--2008            DI(DI'low+J)<=RESIZE(D(K)(J),DI(DI'low+J));
       li:for J in 0 to SSR-1 generate
            DI(DI'length/SSR*(J+1)-1+DI'low downto DI'length/SSR*J+DI'low)<=CFIXED_VECTOR(RESIZE(ELEMENT(D(K),J,SSR),(DI'high+1)/2/SSR-1,DI'low/2/SSR));
          end generate;
       pf:entity work.PARFFT generic map(N=>RADIX, --93
                                         INV_FFT=>FALSE,
                                         ROUNDING=>ROUNDING,
                                         W_high=>W_high,
                                         W_low=>W_low,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                         DSP48E=>DSP48E)
                                     port map(CLK=>CLK,
                                              I=>DI,
                                              VI=>V(K),
                                              SI=>S(K),
                                              O=>DM,
                                              VO=>VM,
                                              SO=>SM);
       cm:entity work.CM3FFT generic map(N=>N/(RADIX**K),
                                         RADIX=>RADIX, --93
                                         INV_FFT=>FALSE,
                                         W_high=>W_high,
                                         W_low=>W_low,
                                         ROUNDING=>ROUNDING,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                         DSP48E=>DSP48E)
                            port map(CLK=>CLK,
                                      I=>DM,
                                      VI=>VM,
                                      SI=>SM,
                                      O=>DB,
                                      VO=>VB,
                                      SO=>SB);
     
       bc:entity work.CB generic map(SSR=>RADIX, --93
                                     F=>F*BOOLEAN'pos(K=SIZE-1),
                                     PACKING_FACTOR=>N/(RADIX**(K+2))*BOOLEAN'pos(K<SIZE-1)+BOOLEAN'pos(K=SIZE-1),
                                     BRAM_THRESHOLD=>BRAM_THRESHOLD)
                         port map(CLK=>CLK,
                                  I=>DB,
                                  VI=>VB,
                                  SI=>SB,
                                  O=>DO,
                                  VO=>V(K+1),
                                  SO=>S(K+1));
--2008       lo:for J in 0 to I'length-1 generate
--2008            D(K+1)(J)<=RESIZE(DO(DO'low+J),D(K+1)(J));
       lo:for J in 0 to SSR-1 generate
            D(K+1)(O'length/SSR*(J+1)-1+O'low downto O'length/SSR*J+O'low)<=CFIXED_VECTOR(RESIZE(ELEMENT(DO,J,SSR),(O'high+1)/2/SSR-1,O'low/2/SSR));
          end generate;
     end generate;
--last PARFFT stage
--2008  li:for J in 0 to I'length-1 generate
--2008       DI(DI'low+J)<=RESIZE(D(D'high)(J),DI(DI'low+J));
  li:for J in 0 to SSR-1 generate
       DI(DI'length/SSR*(J+1)-1+DI'low downto DI'length/SSR*J+DI'low)<=CFIXED_VECTOR(RESIZE(ELEMENT(D(D'high),J,SSR),(DI'high+1)/2/SSR-1,DI'low/2/SSR));
     end generate;
  pf:entity work.PARFFT generic map(N=>RADIX,
                                    F=>F,
                                    INV_FFT=>FALSE,
                                    ROUNDING=>ROUNDING,
                                    W_high=>W_high,
                                    W_low=>W_low,
                                    BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                    DSP48E=>DSP48E)
                        port map(CLK=>CLK,
                                 I=>DI,
                                 VI=>V(V'high),
                                 SI=>S(S'high),
                                 O=>OO,
                                 VO=>VO,
                                 SO=>SO);
  lo:for J in 0 to H-1 generate
       lk:for K in 0 to G-1 generate
--2008            O(O'low+J+H*K)<=OO(OO'low+K+G*J);
            O(O'length/SSR*(J+H*K+1)-1+O'low downto O'length/SSR*(J+H*K)+O'low)<=OO(O'length/SSR*(K+G*J+1)-1+OO'low downto O'length/SSR*(K+G*J)+OO'low);
          end generate;
     end generate;
end TEST;
