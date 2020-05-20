-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- © Copyright 2018 Xilinx, Inc. All rights reserved.
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
--  \   \                  Filename:             PARFFT.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     PARFFT
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Arbitrary Size, Parallel FFT Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;
use ieee.math_complex.all;

use work.COMPLEX_FIXED_PKG.all;

entity PARFFT is
  generic(N:INTEGER:=4;
          F:INTEGER:=0;
          INV_FFT:BOOLEAN:=FALSE;
          ROUNDING:BOOLEAN:=FALSE;
          W_high:INTEGER:=1;
          W_low:INTEGER:=-16;
          BRAM_THRESHOLD:INTEGER:=256;
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end PARFFT;

architecture TEST of PARFFT is
  constant I_low:INTEGER:=I'low/2/N;
  constant I_high:INTEGER:=I'length/2/N-1+I_low;
  constant O_low:INTEGER:=O'low/2/N;
  constant O_high:INTEGER:=O'length/2/N-1+O_low;

  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute keep_hierarchy:STRING;
  attribute keep_hierarchy of all:architecture is "yes";

  constant L2N:INTEGER:=LOG2(N);
begin
--2008  assert I'length=O'length report "Ports I and O must have the same length!" severity warning;
  assert SI'length=SO'length report "Ports SI and SO must have the same length!" severity warning;

  f0:if F=0 generate
     begin
       l2:if N=2 generate -- FFT2 case
            signal I0,I1:CFIXED(2*I_high+1 downto 2*I_low);
            signal O0,O1:CFIXED(2*O_high+1 downto 2*O_low);
            signal iSO:UNSIGNED(SO'high-1 downto SO'low):=(others=>'0');
          begin
-- unpack CFIXED_VECTOR I
            I0<=ELEMENT(I,0,2);     
            I1<=ELEMENT(I,1,2);     
-- complex add/sub butterfly with scaling and overflow detection
            bf:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                         I0=>I0,
                                         I1=>I1,
                                         SCALE=>SI(SI'low),
                                         O0=>O0,
                                         O1=>O1,
                                         OVR=>SO(SO'high));
-- pack CFIXED_VECTOR O
            O((0+1)*O'length/2-1+O'low downto 0*O'length/2+O'low)<=CFIXED_VECTOR(O0);
            O((1+1)*O'length/2-1+O'low downto 1*O'length/2+O'low)<=CFIXED_VECTOR(O1);
       
            process(CLK)
            begin
              if rising_edge(CLK) then
                iSO<=SI(SI'high downto SI'low+1);
              end if;
            end process;
            SO(SO'high-1 downto SO'low)<=iSO;
            
            bd:entity work.BDELAY generic map(SIZE=>1)
                                  port map(CLK=>CLK,
                                           I=>VI,
                                           O=>VO);
--          end;
          end generate;
--       elsif N=4 generate -- FFT4 case
       l4:if N=4 generate -- FFT4 case
            signal I0,I1,I2,I3:CFIXED(2*I_high+1 downto 2*I_low);
            signal P0,P1,P2,P3,P3S:CFIXED(2*I_high+3 downto 2*I_low);
            signal O0,O1,O2,O3,O1S,O3S:CFIXED(2*O_high+1 downto 2*O_low);
            signal S:UNSIGNED(SI'range):=(others=>'0');
            signal OVR1,OVR2:UNSIGNED(1 downto 0);
            signal iSO:UNSIGNED(SO'high-1 downto SO'low):=(others=>'0');
          begin
-- unpack CFIXED_VECTOR I
            I0<=ELEMENT(I,0,4);     
            I1<=ELEMENT(I,1,4);     
            I2<=ELEMENT(I,2,4);     
            I3<=ELEMENT(I,3,4);    
-- complex add/sub butterflies with scaling and overflow detection
            u0:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                         I0=>I0,
                                         I1=>I2,
                                         SCALE=>SI(SI'low),
                                         O0=>P0,
                                         O1=>P1,
                                         OVR=>OVR1(0));
       
            u1:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                          I0=>I1,
                                          I1=>I3,
                                          SCALE=>SI(SI'low),
                                          O0=>P2,
                                          O1=>P3,
                                          OVR=>OVR1(1));
       
            process(CLK)
            begin
              if rising_edge(CLK) then
                S<=(OVR1(0) or OVR1(1))&SI(SI'high downto SI'low+1);
              end if;
            end process;
          
            u2:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                         I0=>P0,
                                         I1=>P2,
                                         SCALE=>S(S'low),
                                         O0=>O0,
                                         O1=>O2,
                                         OVR=>OVR2(0));
       
            P3S<=SWAP(P3);
            u3:entity work.CBFS generic map(DSP48E=>DSP48E)
                                port map(CLK=>CLK,
                                         I0=>P1,
                                         I1=>P3S,
                                         SCALE=>S(S'low),
                                         O0=>O1S,
                                         O1=>O3S,
                                         OVR=>OVR2(1));
            O1<=TO_CFIXED(RE(O1S),IM(O3S));
            O3<=TO_CFIXED(RE(O3S),IM(O1S));
-- pack CFIXED_VECTOR O
            O((0+1)*O'length/4-1+O'low downto 0*O'length/4+O'low)<=CFIXED_VECTOR(O0);
            O((1+1)*O'length/4-1+O'low downto 1*O'length/4+O'low)<=CFIXED_VECTOR(O1);
            O((2+1)*O'length/4-1+O'low downto 2*O'length/4+O'low)<=CFIXED_VECTOR(O2);
            O((3+1)*O'length/4-1+O'low downto 3*O'length/4+O'low)<=CFIXED_VECTOR(O3);
       
            SO(SO'high)<=(OVR2(0) or OVR2(1));
            process(CLK)
            begin
              if rising_edge(CLK) then
                iSO<=S(S'high downto S'low+1);
              end if;
            end process;
            SO(SO'high-1 downto SO'low)<=iSO;
            
            bd:entity work.BDELAY generic map(SIZE=>2)
                                  port map(CLK=>CLK,
                                           I=>VI,
                                           O=>VO);
--          end;
          end generate;
--       elsif N=8 generate -- FFT8 case
       l8:if N=8 generate -- FFT8 case
--2008            constant BIT_GROWTH:INTEGER:=MAX(O(O'low).RE'high,O(O'low).IM'high)-MAX(I(I'low).RE'high,I(I'low).IM'high);
            constant BIT_GROWTH:INTEGER:=(O'high+1)/8/2-(I'high+1)/8/2;
            constant X:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(BIT_GROWTH,1); -- ModelSim workaround
            signal iV:BOOLEAN_VECTOR(0 to 3);
--2008            signal S:UNSIGNED_VECTOR(0 to 3)(SI'range);
            type TUV is array(NATURAL range <>) of UNSIGNED(SI'range);
            signal S:TUV(0 to 3);
            signal SS:UNSIGNED(SI'range);
            signal P:CFIXED_VECTOR(I'high+8*2*X downto I'low);
            signal VP:BOOLEAN;
            signal SP:UNSIGNED(SI'range);
            signal oV:BOOLEAN_VECTOR(0 to 1);
--2008            signal oS:UNSIGNED_VECTOR(0 to 1)(SO'range);
            signal oS:TUV(0 to 1);
          begin  
            s1:for K in 0 to 3 generate
--2008                 signal II:CFIXED_VECTOR(0 to 1)(RE(I(0).RE'high downto I(0).RE'low),IM(I(0).IM'high downto I(0).IM'low));
--2008                 signal OO:CFIXED_VECTOR(0 to 1)(RE(P(0).RE'high downto P(0).RE'low),IM(P(0).IM'high downto P(0).IM'low));
                 signal II:CFIXED_VECTOR(4*(I_high+1)-1 downto 4*I_low);
                 signal OO:CFIXED_VECTOR(4*(I_high+1+2*X)-1 downto 4*I_low);
                 signal OO0,OO1:CFIXED(2*(I_high+1+2*X)-1 downto 2*I_low);
                 signal P0,P1:CFIXED(I'length/8+2*X-1+I'low/8 downto I'low/8);
                 signal SS:UNSIGNED(SI'range);
               begin
--2008                 II(0)<=I(K);
--2008                 II(1)<=I(K+4);
                 II((0+1)*II'length/2-1+II'low downto 0*II'length/2+II'low)<=CFIXED_VECTOR(ELEMENT(I,K,8));
                 II((1+1)*II'length/2-1+II'low downto 1*II'length/2+II'low)<=CFIXED_VECTOR(ELEMENT(I,K+4,8));
                 p2:entity work.PARFFT generic map(N=>2,
                                                   INV_FFT=>INV_FFT,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>II,
                                                VI=>VI,
                                                SI=>SI,
                                                O=>OO,
                                                VO=>iV(K),
                                                SO=>S(K));
                 OO0<=ELEMENT(OO,0,2);
                 OO1<=ELEMENT(OO,1,2);
                 cd:entity work.CDELAY generic map(SIZE=>3)
                                       port map(CLK=>CLK,
--2008                                                I=>OO(0),
--2008                                                O=>P(2*K+0));
                                                I=>OO0,
                                                O=>P0);
                 ck:entity work.CKCM generic map(DSP48E=>DSP48E,
                                                 M=>K,
                                                 ROUNDING=>ROUNDING,
                                                 CONJUGATE=>INV_FFT)
                                     port map(CLK=>CLK,
--2008                                              I=>OO(1),
--2008                                              O=>P(2*K+1));
                                              I=>OO1,
                                              O=>P1);
                 P((2*K+1)*P'length/8-1+P'low downto (2*K+0)*P'length/8+P'low)<=CFIXED_VECTOR(P0);
                 P((2*K+2)*P'length/8-1+P'low downto (2*K+1)*P'length/8+P'low)<=CFIXED_VECTOR(P1);
               end generate;
            SS(SI'high)<=S(0)(SI'high) or S(1)(SI'high) or S(2)(SI'high) or S(3)(SI'high) when iV(0) else '0';
            SS(SI'high-1 downto SI'low)<=S(0)(SI'high-1 downto SI'low);
            ud:entity work.UDELAY generic map(SIZE=>3)
                                  port map(CLK=>CLK,
                                           I=>SS,
                                           O=>SP);
            bd:entity work.BDELAY generic map(SIZE=>3)
                                  port map(CLK=>CLK,
                                           I=>iV(0),
                                           O=>VP);
            s2:for K in 0 to 1 generate
--2008                 signal II:CFIXED_VECTOR(0 to 3)(RE(P(0).RE'high downto P(0).RE'low),IM(P(0).IM'high downto P(0).IM'low));
--2008                 signal OO:CFIXED_VECTOR(0 to 3)(RE(O(0).RE'high downto O(0).RE'low),IM(O(0).IM'high downto O(0).IM'low));
                 signal II:CFIXED_VECTOR((P'high+1)/2-1 downto P'low/2);
                 signal OO:CFIXED_VECTOR((O'high+1)/2-1 downto O'low/2);
                 signal SS:UNSIGNED(SI'range);
               begin
--2008                 II(0)<=P(K+0);
--2008                 II(1)<=P(K+2);
--2008                 II(2)<=P(K+4);
--2008                 II(3)<=P(K+6);
                 II((0+1)*II'length/4-1+II'low downto 0*II'length/4+II'low)<=CFIXED_VECTOR(ELEMENT(P,K+0,8));     
                 II((1+1)*II'length/4-1+II'low downto 1*II'length/4+II'low)<=CFIXED_VECTOR(ELEMENT(P,K+2,8));     
                 II((2+1)*II'length/4-1+II'low downto 2*II'length/4+II'low)<=CFIXED_VECTOR(ELEMENT(P,K+4,8));     
                 II((3+1)*II'length/4-1+II'low downto 3*II'length/4+II'low)<=CFIXED_VECTOR(ELEMENT(P,K+6,8));     
                 p2:entity work.PARFFT generic map(N=>4,
                                                   INV_FFT=>INV_FFT,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>II,
                                                VI=>VP,
                                                SI=>SP,
                                                O=>OO,
                                                VO=>oV(K),
                                                SO=>oS(K));
--2008                 O(K+0)<=OO(0);
--2008                 O(K+2)<=OO(1);
--2008                 O(K+4)<=OO(2);
--2008                 O(K+6)<=OO(3);
                 O((K+0+1)*O'length/8-1+O'low downto (K+0)*O'length/8+O'low)<=CFIXED_VECTOR(ELEMENT(OO,0,4));
                 O((K+2+1)*O'length/8-1+O'low downto (K+2)*O'length/8+O'low)<=CFIXED_VECTOR(ELEMENT(OO,1,4));
                 O((K+4+1)*O'length/8-1+O'low downto (K+4)*O'length/8+O'low)<=CFIXED_VECTOR(ELEMENT(OO,2,4));
                 O((K+6+1)*O'length/8-1+O'low downto (K+6)*O'length/8+O'low)<=CFIXED_VECTOR(ELEMENT(OO,3,4));
               end generate;
            VO<=oV(0);
            SO(SO'high downto SO'high-1)<=oS(0)(SO'high downto SO'high-1) or oS(1)(SO'high downto SO'high-1) when oV(0) else "00";
            SO(SO'high-2 downto SO'low)<=oS(0)(SO'high-2 downto SO'low);
--          end;
          end generate;
--       elsif N=2**L2N generate -- FFT2**n case using Split Radix decomposition, uses recursive PARFFT instantiation
       ln:if (N>8) and (N=2**L2N) generate -- FFT2**n  case using Split Radix decomposition, uses recursive PARFFT instantiation
--2008            constant BIT_GROWTH:INTEGER:=MAX(O(O'low).RE'high,O(O'low).IM'high)-MAX(I(I'low).RE'high,I(I'low).IM'high);
            constant BIT_GROWTH:INTEGER:=(O'high+1)/N/2-(I'high+1)/N/2;
            constant X1:INTEGER:=work.COMPLEX_FIXED_PKG.MAX(0,work.COMPLEX_FIXED_PKG.MIN(BIT_GROWTH,L2N)-2); -- ModelSim workaround
            constant X2:INTEGER:=work.COMPLEX_FIXED_PKG.MAX(0,work.COMPLEX_FIXED_PKG.MIN(BIT_GROWTH,L2N)-1); -- ModelSim workaround
            function MUL_LATENCY(N:INTEGER) return INTEGER is
            begin
              return 6;
            end;
            function LATENCY(N:INTEGER) return INTEGER is
            begin
              return LOG2(N)*4-6;
            end;
--2008            signal IU:CFIXED_VECTOR(0 to N/2-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
--2008            signal U,UD:CFIXED_VECTOR(0 to N/2-1)(RE(I(I'low).RE'high+X2 downto I(I'low).RE'low),IM(I(I'low).IM'high+X2 downto I(I'low).IM'low));
            signal IU:CFIXED_VECTOR((I'high+1)/2-1 downto I'low/2);
            signal U,UD:CFIXED_VECTOR((I'high+1)/2-1+N/2*2*X2 downto I'low/2);
            signal SU,SUD:UNSIGNED(SI'range);
            signal VU,VU4D:BOOLEAN;
--2008            signal ZO:CFIXED_MATRIX(0 to N/4-1)(0 to 1)(RE(I(I'low).RE'high+X1 downto I(I'low).RE'low),IM(I(I'low).IM'high+X1 downto I(I'low).IM'low));
            type CFIXED_MATRIX is array(INTEGER range <>) of CFIXED_VECTOR(2*2*(I_high+X1+1)-1 downto 2*2*I_low); -- unconstrained array of CFIXED_VECTOR
            signal ZO:CFIXED_MATRIX(0 to N/4-1);
            type TUV is array(NATURAL range <>) of UNSIGNED(SI'range);
--2008            signal S1:UNSIGNED_VECTOR(0 to 1)(SI'range);
            signal S1:TUV(0 to 1);
            signal S1I:UNSIGNED(SI'range);
--2008            signal S2:UNSIGNED_VECTOR(0 to N/4-1)(SI'range);
            signal S2:TUV(0 to N/4-1);
            signal S2I:UNSIGNED(SI'range):=(others=>'0');
--2008            signal S:UNSIGNED_VECTOR(0 to N/2-1)(SI'range);
            signal S:TUV(0 to N/2-1);
          begin
            lk:for K in 0 to N/2-1 generate
--2008                 IU(K)<=I(I'low+2*K);
                 IU((K+1)*IU'length/N*2-1+IU'low downto K*IU'length/N*2+IU'low)<=CFIXED_VECTOR(ELEMENT(I,2*K,N));
               end generate;
            pu:entity work.PARFFT generic map(N=>N/2,
                                              ROUNDING=>ROUNDING,
                                              W_high=>W_high,
                                              W_low=>W_low,
                                              INV_FFT=>INV_FFT,
                                              BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                              DSP48E=>DSP48E)
                                  port map(CLK=>CLK,
                                           I=>IU,
                                           VI=>VI,
                                           SI=>SI,
                                           O=>U,
                                           VO=>VU,
                                           SO=>SU);
            du:for K in 0 to N/2-1 generate
                 signal UK,UDK:CFIXED((UD'high+1)/N*2-1 downto UD'low/N*2);
               begin
                 UK<=ELEMENT(U,K,N/2);
                 cd:entity work.CDELAY generic map(SIZE=>LATENCY(N/4)+MUL_LATENCY(N)+1-LATENCY(N/2))--3) -- when CMUL latency is 6
                                     port map(CLK=>CLK,
--2008                                              I=>U(K),
--2008                                              O=>UD(K));
                                              I=>UK,
                                              O=>UDK);
                 UD((K+1)*UD'length/N*2-1+UD'low downto K*UD'length/N*2+UD'low)<=CFIXED_VECTOR(UDK);
               end generate;
            u4:entity work.UDELAY generic map(SIZE=>LATENCY(N/4)+MUL_LATENCY(N)+2-LATENCY(N/2))--4) -- when CMUL latency is 6
                                  port map(CLK=>CLK,
                                           I=>SU,
                                           O=>SUD);
            b5:entity work.BDELAY generic map(SIZE=>LATENCY(N/4)+MUL_LATENCY(N)+2-LATENCY(N/2))--4) -- when CMUL latency is 6
                                  port map(CLK=>CLK,
                                           I=>VU,
                                           O=>VO);
            ll:for L in 0 to 1 generate
--2008                 signal IZ:CFIXED_VECTOR(0 to N/4-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
--2008                 signal Z,OZ:CFIXED_VECTOR(0 to N/4-1)(RE(I(I'low).RE'high+X1 downto I(I'low).RE'low),IM(I(I'low).IM'high+X1 downto I(I'low).IM'low));
                 signal IZ:CFIXED_VECTOR((I'high+1)/4-1 downto I'low/4);
                 signal Z,OZ:CFIXED_VECTOR((I'high+1)/4-1+N/4*2*X1 downto I'low/4);
                 signal SZ:UNSIGNED(SI'range);
                 signal SM:UNSIGNED(SI'range);
                 signal VZ:BOOLEAN;
               begin
                 li:for J in 0 to N/4-1 generate
--2008                      IZ(J)<=I(I'low+4*J+2*L+1);
                      IZ(2*(J+1)*(I_high-I_low+1)-1+IZ'low downto 2*J*(I_high-I_low+1)+IZ'low)<=CFIXED_VECTOR(ELEMENT(I,4*J+2*L+1,N));
                    end generate;
                 pe:entity work.PARFFT generic map(N=>N/4,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   INV_FFT=>INV_FFT,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>IZ,
                                                VI=>VI,
                                                SI=>SI,
                                                O=>Z,
                                                VO=>VZ,
                                                SO=>SZ);
                 me:entity work.CM3FFT generic map(N=>N,
                                                   RADIX=>N/4,
                                                   SPLIT_RADIX=>2*L+1,
                                                   INV_FFT=>INV_FFT,
                                                   ROUNDING=>ROUNDING,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>Z,
                                                VI=>VZ,
                                                SI=>SZ,
                                                O=>OZ,
                                                VO=>open,
                                                SO=>S1(L));
                 lo:for J in 0 to N/4-1 generate
--2008                      ZO(J)(L)<=OZ(J);
                      ZO(J)((L+1)*ZO(J)'length/2-1+ZO(J)'low downto L*ZO(J)'length/2+ZO(J)'low)<=CFIXED_VECTOR(ELEMENT(OZ,J,N/4));
                    end generate;
               end generate;
            S1I<=S1(0) or S1(1);
            l2:for J in 0 to N/4-1 generate
--2008                 signal O2:CFIXED_VECTOR(0 to 1)(RE(I(I'low).RE'high+X2 downto I(I'low).RE'low),IM(I(I'low).IM'high+X2 downto I(I'low).IM'low));
--2008                 signal IE,IO:CFIXED_VECTOR(0 to 1)(RE(I(I'low).RE'high+X2 downto I(I'low).RE'low),IM(I(I'low).IM'high+X2 downto I(I'low).IM'low));
--2008                 signal OE,OO:CFIXED_VECTOR(0 to 1)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
                 signal O2:CFIXED_VECTOR(2*2*(I_high+X2+1)-1 downto 2*2*I_low);
                 signal IE,IO:CFIXED_VECTOR(2*2*(I_high+X2+1)-1 downto 2*2*I_low);
                 signal OE,OO:CFIXED_VECTOR(2*2*(O_high+1)-1 downto 2*2*O_low);
               begin
                 p2:entity work.PARFFT generic map(N=>2,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   INV_FFT=>INV_FFT,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>ZO(J),
                                                VI=>TRUE,
                                                SI=>S1I,
                                                O=>O2,
                                                VO=>open,
                                                SO=>S2(J));
--2008                 IE(0)<=UD(J);
--2008                 IE(1)<=O2(0);
                 IE((0+1)*IE'length/2-1+IE'low downto 0*IE'length/2+IE'low)<=CFIXED_VECTOR(ELEMENT(UD,J,N/2));
                 IE((1+1)*IE'length/2-1+IE'low downto 1*IE'length/2+IE'low)<=CFIXED_VECTOR(ELEMENT(O2,0,2));
                 pe:entity work.PARFFT generic map(N=>2,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   INV_FFT=>INV_FFT,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>IE,
                                                VI=>TRUE,
                                                SI=>S2I,
                                                O=>OE,
                                                VO=>open,
                                                SO=>S(2*J));
--2008                 O(O'low+J)<=OE(0);
--2008                 O(O'low+J+N/2)<=OE(1);
--2008                 IO(0)<=UD(J+N/4);
--2008                 IO(1).RE<=O2(1).IM;
--2008                 IO(1).IM<=O2(1).RE;
--                 O((J+1)*O'length/N-1+O'low downto J*O'length/N+O'low)<=CFIXED_VECTOR(ELEMENT(OE,0,2));
--                 O((J+N/2+1)*O'length/N-1+O'low downto (J+N/2)*O'length/N+O'low)<=CFIXED_VECTOR(ELEMENT(OE,1,2));
                 O(2*(J+1)*(O_high-O_low+1)-1+O'low downto 2*J*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(ELEMENT(OE,0,2));
                 O(2*(J+N/2+1)*(O_high-O_low+1)-1+O'low downto 2*(J+N/2)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(ELEMENT(OE,1,2));
                 IO((0+1)*IO'length/2-1+IO'low downto 0*IO'length/2+IO'low)<=CFIXED_VECTOR(ELEMENT(UD,J+N/4,N/2));
                 IO((1+1)*IO'length/2-1+IO'low downto 1*IO'length/2+IO'low)<=CFIXED_VECTOR(TO_CFIXED(IM(ELEMENT(O2,1,2)),RE(ELEMENT(O2,1,2))));
                 po:entity work.PARFFT generic map(N=>2,
                                                   ROUNDING=>ROUNDING,
                                                   W_high=>W_high,
                                                   W_low=>W_low,
                                                   INV_FFT=>INV_FFT,
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                                   DSP48E=>DSP48E)
                                       port map(CLK=>CLK,
                                                I=>IO,
                                                VI=>TRUE,
                                                SI=>S2I,
                                                O=>OO,
                                                VO=>open,
                                                SO=>S(2*J+1));
                 ii:if INV_FFT generate
                    begin
--2008                      O(O'low+J+N/4).RE<=OO(1).RE;
--2008                      O(O'low+J+N/4).IM<=OO(0).IM;
--2008                      O(O'low+J+3*N/4).RE<=OO(0).RE;
--2008                      O(O'low+J+3*N/4).IM<=OO(1).IM;
--                      O((J+N/4+1)*O'length/N-1+O'low downto (J+N/4)*O'length/N+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,1,2)),IM(ELEMENT(OO,0,2))));
--                      O((J+3*N/4+1)*O'length/N-1+O'low downto (J+3*N/4)*O'length/N+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,0,2)),IM(ELEMENT(OO,1,2))));
                      O(2*(J+N/4+1)*(O_high-O_low+1)-1+O'low downto 2*(J+N/4)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,1,2)),IM(ELEMENT(OO,0,2))));
                      O(2*(J+3*N/4+1)*(O_high-O_low+1)-1+O'low downto 2*(J+3*N/4)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,0,2)),IM(ELEMENT(OO,1,2))));
--                    end;
                    end generate;
--               else generate
                 id:if not INV_FFT generate
                    begin
--2008                      O(O'low+J+N/4).RE<=OO(0).RE;
--2008                      O(O'low+J+N/4).IM<=OO(1).IM;
--2008                      O(O'low+J+3*N/4).RE<=OO(1).RE;
--2008                      O(O'low+J+3*N/4).IM<=OO(0).IM;
--                      O((J+N/4+1)*O'length/N-1+O'low downto (J+N/4)*O'length/N+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,0,2)),IM(ELEMENT(OO,1,2))));
--                      O((J+3*N/4+1)*O'length/N-1+O'low downto (J+3*N/4)*O'length/N+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,1,2)),IM(ELEMENT(OO,0,2))));
                      O(2*(J+N/4+1)*(O_high-O_low+1)-1+O'low downto 2*(J+N/4)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,0,2)),IM(ELEMENT(OO,1,2))));
                      O(2*(J+3*N/4+1)*(O_high-O_low+1)-1+O'low downto 2*(J+3*N/4)*(O_high-O_low+1)+O'low)<=CFIXED_VECTOR(TO_CFIXED(RE(ELEMENT(OO,1,2)),IM(ELEMENT(OO,0,2))));
--                    end;
                    end generate;
               end generate;
            process(S2)
              variable vS2:UNSIGNED(SI'range);
            begin
              vS2:=SUD;
              for K in S2'range loop
                vS2:=vS2 or S2(K);
              end loop;
              S2I<=vS2;
            end process;
            process(S)
              variable vS:UNSIGNED(SI'range);
            begin
              vS:=(others=>'0');
              for K in S'range loop
                vS:=vS or S(K);
              end loop;
              SO<=vS;
            end process;
--          end;
          end generate;
--     else generate
     end generate;
  i1:if F>0 generate
       constant G:INTEGER:=2**F;          -- size of each PARFFT
       constant H:INTEGER:=N/G;           -- number of PARFFTs
--2008       signal S:UNSIGNED_VECTOR(0 to H)(SO'range);
       type TUV is array(0 to H) of UNSIGNED(SO'range);
       signal S:TUV;
       signal V:BOOLEAN_VECTOR(0 to H-1);
     begin
       S(S'low)<=(others=>'0');
       lk:for K in 0 to H-1 generate
            signal SK:UNSIGNED(SO'range);
--workaround for QuestaSim bug
--2008            signal II:CFIXED_VECTOR(0 to G-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
--2008            signal OO:CFIXED_VECTOR(0 to G-1)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
            signal II:CFIXED_VECTOR((I'high+1)/H-1 downto I'low/H);
            signal OO:CFIXED_VECTOR((O'high+1)/H-1 downto O'low/H);
          begin
--2008            II<=I(I'low+G*K+0 to I'low+G*K+G-1);
            II<=I(I'length/H*(K+1)-1+I'low downto I'length/H*K+I'low);
            bc:entity work.PARFFT generic map(N=>G,
                                              F=>0,
                                              INV_FFT=>INV_FFT,
                                              ROUNDING=>ROUNDING,
                                              W_high=>W_high,
                                              W_low=>W_low,
                                              BRAM_THRESHOLD=>BRAM_THRESHOLD,
                                              DSP48E=>DSP48E)
                              port map(CLK=>CLK,
                                       I=>II,
                                       VI=>VI,
                                       SI=>SI,
                                       O=>OO,
                                       VO=>V(K),
                                       SO=>SK);
--workaround for QuestaSim bug
--            O(O'low+G*K+0 to O'low+G*K+G-1)<=OO;
--2008            lo:for J in 0 to G-1 generate
--2008                 O(O'low+G*K+J)<=OO(J);
--2008               end generate;
            O(O'length/H*(K+1)-1+O'low downto O'length/H*K+O'low)<=OO;
            S(K+1)<=S(K) or SK;
          end generate;
       SO<=S(S'high);
       VO<=V(V'high);
--     end;
     end generate;
end TEST;
