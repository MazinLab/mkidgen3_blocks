-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
-- ?? Copyright 2018 Xilinx, Inc. All rights reserved.
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
--  \   \                  Filename:             INPUT_SWAP.vhd
--  /   /                  Date Last Modified:   14 February 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     INPUT_SWAP
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-Feb-14 Initial final release
-------------------------------------------------------------------------------- 
--
-- Module Description: Input Order Swap Module for Systolic FFT
--                     The module takes N samples, I'length per clock, in natural input order
--                     and outputs them in natural transposed order
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity INPUT_SWAP is
  generic(N:INTEGER;                   -- N must be a power of 2
          SSR:INTEGER;                 -- SSR must be a power of 2
          BRAM_THRESHOLD:INTEGER:=256; -- adjust this threshold to trade utilization between Distributed RAMs and BRAMs
          USE_CB:BOOLEAN:=TRUE);       -- if FALSE use alternate architecture
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;             -- I'length must be a divisor of N, so it is also a power of 2
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end INPUT_SWAP;

architecture TEST of INPUT_SWAP is
  attribute syn_keep:STRING;
  attribute syn_keep of all:architecture is "hard";
  attribute ram_style:STRING;

--2008  constant RADIX:INTEGER:=I'length;  -- this is the Systolic FFT RADIX or SSR
  constant RADIX:INTEGER:=SSR;  -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  constant F:INTEGER:=L2N mod L2R;   -- if F is not zero there will be a partial last stage
  constant G:INTEGER:=2**F;          -- size of each CB in last stage
  constant H:INTEGER:=RADIX/G;       -- number of CBs in last stage

  function RS(K:INTEGER) return STRING is
  begin
    if K<BRAM_THRESHOLD then
      return "distributed";
    else
      return "block";
    end if;
  end;

  type iCFIXED_MATRIX is array(NATURAL range <>) of CFIXED_VECTOR(I'range);
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity error;
--2008  assert I'length=2**LOG2(I'length) report "Port I length must be a power of 2!" severity error;
  assert SSR=2**LOG2(SSR) report "SSR must be a power of 2!" severity error;

  i0:if USE_CB or (L2N<=2*L2R) generate
       constant SIZE:INTEGER:=L2N/L2R;    -- floor(LOG2(N)/LOG2(RADIX))
     
       signal V:BOOLEAN_VECTOR(0 to SIZE-1);
--2008       signal S:UNSIGNED_VECTOR(0 to SIZE-1)(SI'range);
--2008       signal D:CFIXED_MATRIX(0 to SIZE-1)(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
       type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(SI'range);
       signal S:UNSIGNED_VECTOR(0 to SIZE-1);
       signal D:iCFIXED_MATRIX(0 to SIZE-1);
     begin
       D(D'low)<=I;
       V(V'low)<=VI;
       S(S'low)<=SI;
       lk:for K in 0 to SIZE-2 generate
            bc:entity work.CB generic map(SSR=>SSR, --93
                                          PACKING_FACTOR=>RADIX**K,
                                          INPUT_PACKING_FACTOR_ADJUST=>-(RADIX**K/RADIX),                    -- this helps reduce
                                          OUTPUT_PACKING_FACTOR_ADJUST=>-(RADIX**K mod RADIX**(SIZE-2)),     -- RAM count and
                                          SHORTEN_VO_BY=>(RADIX-1)*RADIX**K mod ((RADIX-1)*RADIX**(SIZE-2))) -- latency by N/RADIX/RADIX-1 clocks
                              port map(CLK=>CLK,
                                       I=>D(K),
                                       VI=>V(K),
                                       SI=>S(K),
                                       O=>D(K+1),
                                       VO=>V(K+1),
                                       SO=>S(K+1));
          end generate;
--Last stage, it becomes a trivial assignment if F=0
       bl:block
            signal OV:BOOLEAN_VECTOR(0 to H-1);
--2008            signal OS:UNSIGNED_VECTOR(0 to H-1)(SI'range);
            signal OS:UNSIGNED_VECTOR(0 to H-1);
          begin
            lj:for J in OV'range generate
--2008                 signal OO:CFIXED_VECTOR(0 to G-1)(RE(O(O'low).RE'range),IM(O(O'low).IM'range));
                 signal OO:CFIXED_VECTOR((O'high+1)/H-1 downto O'low/H);
               begin
                 bc:entity work.CB generic map(SSR=>G, --93
                                               PACKING_FACTOR=>RADIX**(SIZE-1))
                                   port map(CLK=>CLK,
--2008                                            I=>D(D'high)(I'low+G*J+0 to I'low+G*J+G-1),
                                            I=>D(D'high)(I'length/H*(J+1)-1+I'low downto I'length/H*J+I'low),
                                            VI=>V(V'high),
                                            SI=>S(S'high),
                                            O=>OO,
                                            VO=>OV(J),
                                            SO=>OS(J));
                 lk:for K in 0 to G-1 generate
--2008                      O(O'low+J+H*K)<=OO(K);
                      O(O'length/SSR*(J+H*K+1)-1+O'low downto O'length/SSR*(J+H*K)+O'low)<=OO(O'length/SSR*(K+1)-1+OO'low downto O'length/SSR*K+OO'low);
                    end generate;
               end generate;
            VO<=OV(OV'low);
            SO<=OS(OS'low);
          end block;
--2008     end;
     end generate;
--2008     else generate
  i1:if (not USE_CB) and (L2N>2*L2R) generate
       signal VI1D:BOOLEAN:=FALSE;
       signal V:BOOLEAN;
--2008       signal I1D:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(I'range=>(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).RE'range=>'0')));
       signal I1D:CFIXED_VECTOR(I'range):=(others=>'0');
       signal WCNT,RCNT:UNSIGNED(LOG2(N/RADIX)-1 downto 0):=(others=>'0');
       signal WA:UNSIGNED(WCNT'range):=(others=>'0');
       signal RA:UNSIGNED(RCNT'range):=(others=>'0');
       signal WSEL:UNSIGNED(LOG2(WCNT'length)-1 downto 0):=TO_UNSIGNED(0,LOG2(RCNT'length));
       signal RSEL:UNSIGNED(LOG2(RCNT'length)-1 downto 0):=TO_UNSIGNED(L2N-2*L2R,LOG2(RCNT'length));
--2008       signal IO:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
       signal IO:CFIXED_VECTOR(I'range);
       signal OV:BOOLEAN;
       signal S:UNSIGNED(SO'range);     
     begin
       bd:entity work.BDELAY generic map(SIZE=>N/RADIX-RADIX-N/RADIX/RADIX+2)
                             port map(CLK=>CLK,
                                      I=>VI,
                                      O=>V);
     
       process(CLK)
       begin
         if rising_edge(CLK) then
           if VI then
             if WCNT=N/RADIX-1 then
               WSEL<=RSEL;
             end if;
             WCNT<=WCNT+1;
           else
             WCNT<=(others=>'0');
           end if;
         end if;
       end process;
     
       process(CLK)
       begin
         if rising_edge(CLK) then
           if V then
             if RCNT=N/RADIX-1 then
               if RSEL<L2R then
                 RSEL<=RSEL+TO_UNSIGNED(L2N-2*L2R,RSEL'length);
               else
                 RSEL<=RSEL+TO_UNSIGNED(2**LOG2(L2N-L2R)-L2R,RSEL'length);
               end if;
             end if;
             RCNT<=RCNT+1;
           else
             RCNT<=(others=>'0');
           end if;
           VI1D<=VI;
           I1D<=I;
         end if;
       end process;
-- Write Address Digit Swapping  
       process(CLK)
       begin
         if rising_edge(CLK) then
           WA<=ROTATE_LEFT(WCNT,TO_INTEGER(WSEL));
         end if;
       end process;
-- Read Address Digit Swapping  
       process(CLK)
       begin
         if rising_edge(CLK) then
           RA<=ROTATE_LEFT(RCNT,TO_INTEGER(RSEL));
         end if;
       end process;
          
--2008       lk:for K in 0 to I'length-1 generate
       lk:if TRUE generate
--? Vivado synthesis does not infer RAM from this code, just LUTs and FFs
--            signal MEM:CFIXED_VECTOR(0 to 2**(CNT'length+1)-1)(RE(high_f(I(low_f(I)).RE) downto low_f(I(low_f(I)).RE)),IM(high_f(I(low_f(I)).RE) downto low_f(I(low_f(I)).IM))):=(0 to 2**(CNT'length+1)-1=>(RE=>(I(low_f(I)).RE'range=>'0'),IM=>(I(low_f(I)).IM'range=>'0')));
--2008            signal MEMR:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).RE'range):=(0 to 2**WCNT'length-1=>(I(I'low).RE'range=>'0'));
--2008            signal MEMI:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).IM'range):=(0 to 2**WCNT'length-1=>(I(I'low).IM'range=>'0'));
--2008            signal Q:CFIXED(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).RE'range=>'0'));
            signal MEM:iCFIXED_MATRIX(0 to 2**WCNT'length-1):=(0 to 2**WCNT'length-1=>(others=>'0'));
            signal Q:CFIXED_VECTOR(I'range):=(others=>'0');
--WBR            shared variable MEMR,MEMI:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).RE'range):=(0 to 2**WCNT'length-1=>(I(I'low).RE'range=>'0'));
--2008            attribute ram_style of MEMR:signal is RS(N/RADIX);
--2008            attribute ram_style of MEMI:signal is RS(N/RADIX);
            attribute ram_style of MEM:signal is RS(N/RADIX);
          begin
            process(CLK)
            begin
              if rising_edge(CLK) then
                if VI1D then
                  MEM(TO_INTEGER(WA))<=I1D;
--2008                  MEMR(TO_INTEGER(WA))<=I1D(K).RE;
--2008                  MEMI(TO_INTEGER(WA))<=I1D(K).IM;
--                  MEMR(TO_INTEGER(WA)):=I1D(K).RE;
--                  MEMI(TO_INTEGER(WA)):=I1D(K).IM;
--WBR                  Q.RE<=I1D(K).RE;
--WBR                  Q.IM<=I1D(K).IM;
--WBR                else
--WBR                  Q.RE<=MEMR(TO_INTEGER(WA));
--WBR                  Q.IM<=MEMI(TO_INTEGER(WA));
                end if;
                Q<=MEM(TO_INTEGER(RA));
--2008                Q.RE<=MEMR(TO_INTEGER(RA));
--2008                Q.IM<=MEMI(TO_INTEGER(RA));
                IO<=Q;
              end if;
            end process;
          end generate;

       bo:entity work.BDELAY generic map(SIZE=>3)
                             port map(CLK=>CLK,
                                      I=>V,
                                      O=>OV);

       sd:entity work.UDELAY generic map(SIZE=>N/RADIX-RADIX-N/RADIX/RADIX+5)
                             port map(CLK=>CLK,
                                      I=>SI,
                                      O=>S);

       ci:entity work.CB generic map(SSR=>SSR, --93
                                     PACKING_FACTOR=>1)
                         port map(CLK=>CLK,
                                  I=>IO,
                                  VI=>OV,
                                  SI=>S,
                                  O=>O,
                                  VO=>VO,
                                  SO=>SO);
     end generate;
end TEST;
