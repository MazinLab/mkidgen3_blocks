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
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 3
--
--         Contact:    e-mail  catalinb@xilinx.com - this design is not supported by Xilinx
--                     Worldwide Technical Support (WTS), for support please contact the author
--   ____  ____
--  /   /\/   /
-- /___/  \  /             Vendor:               Xilinx Inc.
-- \   \   \/              Version:              0.14
--  \   \                  Filename:             CM3FFT.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CM3FFT
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic Complex Multiplier Stage Module - uses 3 DSP48s/complex multiplication
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity CM3FFT is -- LATENCY=10
  generic(N:INTEGER;
          RADIX:INTEGER;
          SPLIT_RADIX:INTEGER:=0; -- 0 for use in systolic FFT and 1 or 3 for use in parallel Split Radix FFT
          INV_FFT:BOOLEAN:=FALSE;
          W_high:INTEGER:=1;
          W_low:INTEGER:=-17;
          ROUNDING:BOOLEAN:=TRUE;
          BRAM_THRESHOLD:INTEGER:=256; -- adjust this threshold to trade utilization between Distributed RAMs and BRAMs
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end CM3FFT;

architecture TEST of CM3FFT is
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute keep_hierarchy:STRING;
  attribute keep_hierarchy of all:architecture is "yes";
  
  function STYLE(N:INTEGER) return STRING is
  begin
    if N>BRAM_THRESHOLD then
      return "block";
    else
      return "distributed";
    end if;
  end;

  function TABLE_LATENCY(SPLIT_RADIX:INTEGER) return INTEGER is
  begin
    if SPLIT_RADIX=0 then
      return 4;
    else
      return 0;
    end if;
  end;

--2008  constant RADIX:INTEGER:=I'length;  -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  signal CNT:UNSIGNED(L2N-L2R-1 downto 0):=(others=>'0');
  signal I0:CFIXED((I'high+1)/RADIX-1 downto I'low/RADIX);
  signal O0:CFIXED((O'high+1)/RADIX-1 downto O'low/RADIX);
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity warning;
  assert SI'length=SO'length report "Ports SI and SO must have the same length!" severity warning;

--!!  cd:entity work.CDELAY generic map(SIZE=>3+6)
  I0<=ELEMENT(I,0,RADIX);
  cd:entity work.CDELAY generic map(SIZE=>TABLE_LATENCY(SPLIT_RADIX)+6)
                        port map(CLK=>CLK,
--2008                                 I=>I(I'low),
--2008                                 O=>O(O'low));
                                 I=>I0,
                                 O=>O0);
  O(O'length/RADIX-1+O'low downto O'low)<=CFIXED_VECTOR(O0);

  process(CLK)
  begin
    if rising_edge(CLK) then
      if not VI or (SPLIT_RADIX/=0) then
        CNT<=(others=>'0');
      else
        CNT<=CNT+1;
      end if;
    end if;
  end process;

--2008  lk:for J in 1 to I'length-1 generate
  lk:for J in 1 to RADIX-1 generate
       signal JK:UNSIGNED(L2N-1 downto 0):=(others=>'0');
--2008       signal W:CFIXED(RE(W_high downto W_low),IM(W_high downto W_low));
       signal W:CFIXED(2*(W_high+1)-1 downto 2*W_low);
       signal V,CZ:BOOLEAN;
--2008       signal ID:CFIXED(RE(I(I'low).RE'high downto I(I'low).RE'low),IM(I(I'low).IM'high downto I(I'low).IM'low));
       signal ID:CFIXED((I'high+1)/RADIX-1 downto I'low/RADIX);
       signal IJ:CFIXED((I'high+1)/RADIX-1 downto I'low/RADIX);
       signal OJ:CFIXED((O'high+1)/RADIX-1 downto O'low/RADIX);
     begin  
       process(CLK)
       begin
         if rising_edge(CLK) then
           if SPLIT_RADIX=0 then
             if not VI or (CNT=N/RADIX-1) then
               JK<=(others=>'0');
             else
               JK<=JK+J;
             end if;
           else
             JK<=TO_UNSIGNED(J*SPLIT_RADIX,JK'length);
           end if;
         end if;
       end process;

       ut:entity work.TABLE generic map(N=>N,
                                        INV_FFT=>INV_FFT,
                                        DSP48E=>DSP48E,
                                        STYLE=>STYLE(N/4))
                            port map(CLK=>CLK,
                                     JK=>JK,
                                     VI=>VI,
                                     CZ=>CZ,
                                     W=>W,
                                     VO=>V);

       IJ<=ELEMENT(I,J,RADIX);
--!!       cd:entity work.CDELAY generic map(SIZE=>3)
       cd:entity work.CDELAY generic map(SIZE=>TABLE_LATENCY(SPLIT_RADIX))
                             port map(CLK=>CLK,
--2008                                      I=>I(I'low+J),
                                      I=>IJ,
                                      O=>ID);

       u1:entity work.CM3 generic map(ROUNDING=>ROUNDING,
                                      DSP48E=>DSP48E)
                          port map(CLK=>CLK,
                                   I=>ID,
                                   W=>W,
                                   CZ=>CZ,
                                   VI=>V,
--2008                                   O=>O(O'low+J),
                                   O=>OJ,
                                   VO=>open);
       O((J+1)*O'length/RADIX-1+O'low downto J*O'length/RADIX+O'low)<=CFIXED_VECTOR(OJ);
     end generate;

--!!  bd:entity work.BDELAY generic map(SIZE=>3+6)
  bd:entity work.BDELAY generic map(SIZE=>TABLE_LATENCY(SPLIT_RADIX)+6)
                        port map(CLK=>CLK,
                                 I=>VI,
                                 O=>VO);

--!!  ud:entity work.UDELAY generic map(SIZE=>3+6)
  ud:entity work.UDELAY generic map(SIZE=>TABLE_LATENCY(SPLIT_RADIX)+6)
                        port map(CLK=>CLK,
                                 I=>SI,
                                 O=>SO);
end TEST;
