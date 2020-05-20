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
--  \   \                  Filename:             CB.vhd
--  /   /                  Date Last Modified:   14 Feb 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CB
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14     2018-Feb-14 Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Arbitrary Size, Matrix Transposer (Corner Bender) Module Stage
--                     It does an RxR matrix transposition where R=I'length
--                     and each matrix element is a group of PACKING_FACTOR consecutive samples
--                     LATENCY=(I'length-1)*PACKING_FACTOR+1 when I'length>1 or 0 when I'length=1
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity CB is
  generic(SSR:INTEGER:=4; --93
          F:INTEGER:=0;
          PACKING_FACTOR:INTEGER:=1;
          INPUT_PACKING_FACTOR_ADJUST:INTEGER:=0;
          OUTPUT_PACKING_FACTOR_ADJUST:INTEGER:=0;
          SHORTEN_VO_BY:INTEGER:=0;
          BRAM_THRESHOLD:INTEGER:=258);
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end CB;

architecture TEST of CB is
  attribute syn_keep:STRING;
  attribute syn_keep of all:architecture is "hard";
  attribute rloc:STRING;

  type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(LOG2(SSR)-1 downto 0); --93 local constrained UNSIGNED_VECTOR type
  type iCFIXED_VECTOR is array(NATURAL range <>) of CFIXED((I'high+1)/SSR-1 downto I'low/SSR); --93 local constrained CFIXED_VECTOR type
  
  signal CNTP:UNSIGNED(LOG2(PACKING_FACTOR) downto 0):=(others=>'0');
  signal CNT:UNSIGNED(LOG2(SSR)-1 downto 0):=(others=>'0');
--2008  signal A:UNSIGNED_VECTOR(0 to I'length):=(others=>(others=>'0'));
--2008  signal EN:BOOLEAN_VECTOR(0 to I'length):=(others=>FALSE);
--2008  signal DI:CFIXED_VECTOR(0 to I'length-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
--2008  signal DO:CFIXED_VECTOR(0 to I'length-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(0 to I'length-1=>(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).IM'range=>'0')));
  signal A:UNSIGNED_VECTOR(0 to SSR):=(others=>(others=>'0'));
  signal EN:BOOLEAN_VECTOR(0 to SSR):=(others=>FALSE);
  signal II,DI,OO:iCFIXED_VECTOR(0 to SSR-1);
  signal DO:iCFIXED_VECTOR(0 to SSR-1):=(others=>(others=>'0'));
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity error;
--2008  assert I'length=2**LOG2(I'length) report "Port I length must be a power of 2!" severity error;
  assert SSR=2**LOG2(SSR) report "SSR must be a power of 2!" severity error;
  assert SI'length=SO'length report "Ports SI and SO must have the same length!" severity error;

  f0:if F=0 generate
     begin
--2008       i0:if I'length=1 generate
       i0:if SSR=1 generate
            O<=I;
            VO<=VI;
            SO<=SI;
          end generate;
--2008          else generate
--2008       i1:if I'length>1 generate
       i1:if SSR>1 generate
            process(CLK)
            begin
              if rising_edge(CLK) then
                if VI then
                  if CNTP=PACKING_FACTOR-1 then
                    CNTP<=(others=>'0');
                    CNT<=CNT+1;
                  else
                    CNTP<=CNTP+1;
                  end if;
                else
                  CNTP<=(others=>'0');
                  CNT<=(others=>'0');
                end if;
              end if;
            end process;
            
            A(0)<=CNT;
            EN(0)<=CNTP=PACKING_FACTOR-1;
--2008            lk:for K in 0 to I'length-1 generate
            lk:for K in 0 to SSR-1 generate
               begin
                 II(K)<=CFIXED(I(I'length/SSR*(K+1)-1+I'low downto I'length/SSR*K+I'low)); --93
                 i1:entity work.CDELAY generic map(SIZE=>K*(PACKING_FACTOR+INPUT_PACKING_FACTOR_ADJUST),
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD)
                                       port map(CLK=>CLK,
                                                I=>II(K), --93 I(I'low+K),
                                                O=>DI(K));
                 process(CLK)
                 begin
                   if rising_edge(CLK) then
                     DO(K)<=DI(TO_INTEGER(A(K)));
                     if EN(K) then
                       A(K+1)<=A(K);
                     end if;
                   end if;
                 end process;
                 bd:entity work.BDELAY generic map(SIZE=>PACKING_FACTOR)
                                       port map(CLK=>CLK,
                                                I=>EN(K),
                                                O=>EN(K+1));
                 o1:entity work.CDELAY generic map(SIZE=>(SSR-1-K)*(PACKING_FACTOR+OUTPUT_PACKING_FACTOR_ADJUST),
                                                   BRAM_THRESHOLD=>BRAM_THRESHOLD)
                                       port map(CLK=>CLK,
                                                I=>DO(K),
                                                O=>OO(K)); --93 O(O'low+K));
                 O(O'length/SSR*(K+1)-1+O'low downto O'length/SSR*K+O'low)<=CFIXED_VECTOR(OO(K)); --93
               end generate;
           
            bd:entity work.BDELAY generic map(SIZE=>(SSR-1)*PACKING_FACTOR+1-SHORTEN_VO_BY)
                                  port map(CLK=>CLK,
                                           I=>VI,
                                           O=>VO);
           
            ud:entity work.UDELAY generic map(SIZE=>(SSR-1)*PACKING_FACTOR+1-SHORTEN_VO_BY,
                                              BRAM_THRESHOLD=>BRAM_THRESHOLD)
                                  port map(CLK=>CLK,
                                           I=>SI,
                                           O=>SO);
       end generate;
--          end;
--     else generate
     end generate;
  i1:if F>0 generate
       constant G:INTEGER:=2**F;          -- size of each PARFFT
       constant H:INTEGER:=SSR/G;           -- number of PARFFTs
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
            bc:entity work.CB generic map(SSR=>G,
                                          F=>0,
                                          PACKING_FACTOR=>PACKING_FACTOR,
                                          INPUT_PACKING_FACTOR_ADJUST=>INPUT_PACKING_FACTOR_ADJUST,
                                          OUTPUT_PACKING_FACTOR_ADJUST=>OUTPUT_PACKING_FACTOR_ADJUST,
                                          SHORTEN_VO_BY=>SHORTEN_VO_BY,
                                          BRAM_THRESHOLD=>BRAM_THRESHOLD)
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
