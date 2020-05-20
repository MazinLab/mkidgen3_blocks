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
--  \   \                  Filename:             DSN.vhd
--  /   /                  Date Last Modified:   14 Feb 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     DSN
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-Feb-14 Initial final release
-------------------------------------------------------------------------------- 
--
-- Module Description: Output Order Swap Module for Systolic FFT (Digit Swap)
--                     Produces Natural Output Order
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity DSN is
  generic(N:INTEGER;
          SSR:INTEGER;                  -- SSR must be a power of 2
          BRAM_THRESHOLD:INTEGER:=256); -- adjust this threshold to trade utilization between Distributed RAMs and BRAMs
  port(CLK:in STD_LOGIC;
       I:in CFIXED_VECTOR;
       VI:in BOOLEAN;
       SI:in UNSIGNED;
       O:out CFIXED_VECTOR;
       VO:out BOOLEAN;
       SO:out UNSIGNED);
end DSN;

architecture TEST of DSN is
  attribute syn_keep:STRING;
  attribute syn_keep of all:architecture is "hard";
  attribute rloc:STRING;

--2008  constant RADIX:INTEGER:=I'length;  -- this is the Systolic FFT RADIX or SSR
  constant RADIX:INTEGER:=SSR;  -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  constant F:INTEGER:=L2N mod L2R;
  constant G:INTEGER:=2**F;
  constant H:INTEGER:=RADIX/G;
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity error;
--2008  assert I'length=2**L2R report "Port I length must be a power of 2!" severity error;
  assert SSR=2**L2R report "Port I length must be a power of 2!" severity error;

  i1:if L2N<2*L2R generate
--2008       signal IO:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
       signal IO:CFIXED_VECTOR(I'range);
       signal V:BOOLEAN;
       signal S:UNSIGNED(SI'range);
       signal OV:BOOLEAN_VECTOR(0 to H-1);
--2008       signal OS:UNSIGNED_VECTOR(0 to H-1)(SO'range);
       type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(SO'range); --93
       signal OS:UNSIGNED_VECTOR(0 to H-1);
     begin
       sd:entity work.DS generic map(N=>N,
                                     SSR=>SSR, --93
                                     BRAM_THRESHOLD=>BRAM_THRESHOLD)
                         port map(CLK=>CLK,
                                  I=>I,
                                  VI=>VI,
                                  SI=>SI,
                                  O=>IO,
                                  VO=>V,
                                  SO=>S);
       lk:for K in 0 to H-1 generate
----2008            signal II,OO:CFIXED_VECTOR(0 to G-1)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
            signal II,OO:CFIXED_VECTOR((I'high+1)/H-1 downto I'low/H);
          begin
            li:for J in 0 to G-1 generate
--2008                 II(J)<=IO(IO'low+K+H*J);
                 II(I'length/SSR*(J+1)-1+II'low downto I'length/SSR*J+II'low)<=IO(I'length/SSR*(K+H*J+1)-1+I'low downto I'length/SSR*(K+H*J)+I'low);
               end generate;
            ci:entity work.CB generic map(SSR=>G, --93
                                          PACKING_FACTOR=>1)
                              port map(CLK=>CLK,
                                       I=>II,
                                       VI=>V,
                                       SI=>S,
                                       O=>OO,
                                       VO=>OV(K),
                                       SO=>OS(K));
            lo:for J in 0 to G-1 generate
----2008                 O(O'low+K*G+J)<=OO(J);
                 O(O'length/SSR*(K*G+J+1)-1+O'low downto O'length/SSR*(K*G+J)+O'low)<=OO(O'length/SSR*(J+1)-1+OO'low downto O'length/SSR*J+OO'low);
               end generate;
          end generate;
       VO<=OV(OV'low);
       SO<=OS(OS'low);
--2008     end;
     end generate;
--2008     elsif L2N=2*L2R generate
  i2:if L2N=2*L2R generate
       ci:entity work.CB generic map(SSR=>SSR, --93
                                     PACKING_FACTOR=>1)
                         port map(CLK=>CLK,
                                  I=>I,
                                  VI=>VI,
                                  SI=>SI,
                                  O=>O,
                                  VO=>VO,
                                  SO=>SO);
--2008     else generate
     end generate;
  i3:if L2N>2*L2R generate
--2008       signal IO:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range));
       signal IO:CFIXED_VECTOR(I'range);
       signal V:BOOLEAN;
       signal S:UNSIGNED(SO'range);     
     begin
       ci:entity work.CB generic map(SSR=>SSR, --93
                                     PACKING_FACTOR=>N/RADIX/RADIX,
                                     BRAM_THRESHOLD=>BRAM_THRESHOLD)
                         port map(CLK=>CLK,
                                  I=>I,
                                  VI=>VI,
                                  SI=>SI,
                                  O=>IO,
                                  VO=>V,
                                  SO=>S);

       sd:entity work.DS generic map(N=>N/RADIX,
                                     SSR=>SSR, --93
                                     BRAM_THRESHOLD=>BRAM_THRESHOLD)
                         port map(CLK=>CLK,
                                  I=>IO,
                                  VI=>V,
                                  SI=>S,
                                  O=>O,
                                  VO=>VO,
                                  SO=>SO);
     end generate;
end TEST;
