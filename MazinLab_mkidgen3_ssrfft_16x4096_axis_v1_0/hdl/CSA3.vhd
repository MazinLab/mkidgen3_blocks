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
--  \   \                  Filename:             CSA3.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CSA3
-- Purpose:         Generic 3-input Add/Sub Module
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Carry Save 3-input Adder/Subtracter
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity CSA3 is
  generic(PIPELINE:BOOLEAN:=TRUE;
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          NEGATIVE_A:BOOLEAN:=FALSE;
          NEGATIVE_B:BOOLEAN:=FALSE;
          EXTRA_MSBs:INTEGER:=2);
  port(CLK:in STD_LOGIC:='0';
--       A,B,C:in SIGNED; -- if SIGNED, A, B, C and P must be LSB aligned
       A,B,C:in SFIXED; -- if SFIXED, A, B, C and P can be any size
       CY1,CY2:in BOOLEAN:=FALSE; -- the number of CYs TRUE must equal the number of negative A and B terms
--       P:out SIGNED); -- O=C±A±B
       P:out SFIXED); -- O=C±A±B
end CSA3;

architecture FAST of CSA3 is
  constant SH:INTEGER:=MAX(A'high,B'high,C'high)+EXTRA_MSBs;
  constant SM:INTEGER:=work.COMPLEX_FIXED_PKG.MED(A'low,B'low,C'low);
  constant SL:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(A'low,B'low,C'low);
--  signal SA,SB,SC,M:SIGNED(SH downto SM);
--  signal S:SIGNED(SH downto SL);
  signal SA,SB,SC:SFIXED(SH downto SM);
  signal S:SFIXED(SH downto SL);

  signal O5:SIGNED(SH-SM+1 downto 0);
  signal O6:SIGNED(SH-SM downto 0);
  signal CY:STD_LOGIC_VECTOR((SH-SM+1+7)/8*8 downto 0);
  signal SI,DI,O:STD_LOGIC_VECTOR((SH-SM+1+7)/8*8-1 downto 0);
begin
  SA<=RESIZE(A,SA);
  SB<=RESIZE(B,SB);
  SC<=RESIZE(C,SC);
  O5(0)<='1' when CY1 else '0';
  CY(0)<='1' when CY2 else '0';
  lk:for K in SM to SH generate
       constant I0:BIT_VECTOR(63 downto 0):=X"AAAAAAAAAAAAAAAA";
       constant I1:BIT_VECTOR(63 downto 0):=X"CCCCCCCCCCCCCCCC";
       constant I2:BIT_VECTOR(63 downto 0):=X"F0F0F0F0F0F0F0F0" xor (63 downto 0=>BIT'val(BOOLEAN'pos(NEGATIVE_B)));
       constant I3:BIT_VECTOR(63 downto 0):=X"FF00FF00FF00FF00" xor (63 downto 0=>BIT'val(BOOLEAN'pos(NEGATIVE_A)));
       constant I4:BIT_VECTOR(63 downto 0):=X"FFFF0000FFFF0000";
       constant I5:BIT_VECTOR(63 downto 0):=X"FFFFFFFF00000000";
     begin
       l6:LUT6_2 generic map(INIT=>(I5 and (I1 xor I2 xor I3 xor I4)) or (not I5 and ((I2 and I3) or (I3 and I1) or (I1 and I2))))
                 port map(I0=>'0',I1=>SC(K),I2=>SB(K),I3=>SA(K),I4=>O5(K-SM),I5=>'1',O5=>O5(K+1-SM),O6=>O6(K-SM));
     end generate;

  SI<=STD_LOGIC_VECTOR(RESIZE(O6,SI'length));
  DI<=STD_LOGIC_VECTOR(RESIZE(O5,DI'length));
  lj:for J in 0 to (SH-SM)/8 generate
     begin
       i1:if DSP48E=1 generate -- 7-series
            cl:CARRY4 port map(CI=>CY(8*J),                  -- 1-bit carry cascade input
                               CYINIT=>'0',                  -- 1-bit carry initialization
                               DI=>DI(8*J+3 downto 8*J),     -- 4-bit carry-MUX data in
                               S=>SI(8*J+3 downto 8*J),      -- 4-bit carry-MUX select input
                               CO=>CY(8*J+4 downto 8*J+1),   -- 4-bit carry out
                               O=>O(8*J+3 downto 8*J));      -- 4-bit carry chain XOR data out
            ch:CARRY4 port map(CI=>CY(8*J+4),                -- 1-bit carry cascade input
                               CYINIT=>'0',                  -- 1-bit carry initialization
                               DI=>DI(8*J+7 downto 8*J+4),   -- 4-bit carry-MUX data in
                               S=>SI(8*J+7 downto 8*J+4),    -- 4-bit carry-MUX select input
                               CO=>CY(8*J+8 downto 8*J+5),   -- 4-bit carry out
                               O=>O(8*J+7 downto 8*J+4));    -- 4-bit carry chain XOR data out
       end generate;
       i2:if DSP48E=2 generate -- US/US+
            c8:CARRY8 generic map(CARRY_TYPE=>"SINGLE_CY8")  -- 8-bit or dual 4-bit carry (DUAL_CY4, SINGLE_CY8)
                      port map(CI=>CY(8*J),                  -- 1-bit input: Lower Carry-In
                               CI_TOP=>'0',                  -- 1-bit input: Upper Carry-In
                               DI=>DI(8*J+7 downto 8*J),     -- 8-bit input: Carry-MUX data in
                               S=>SI(8*J+7 downto 8*J),      -- 8-bit input: Carry-mux select
                               CO=>CY(8*J+8 downto 8*J+1),   -- 8-bit output: Carry-out
                               O=>O(8*J+7 downto 8*J));      -- 8-bit output: Carry chain XOR data out
       end generate;
     end generate;

  ll:for L in SM to SH generate
       S(L)<=O(L-SM);
     end generate;

  ia:if (A'low<B'low) and (A'low<C'low) generate
       S(SM-1 downto SL)<=A(SM-1 downto SL);
     end generate;
     
  ib:if (B'low<C'low) and (B'low<A'low) generate
       S(SM-1 downto SL)<=B(SM-1 downto SL);
     end generate;
     
  ic:if (C'low<A'low) and (C'low<B'low) generate
       S(SM-1 downto SL)<=C(SM-1 downto SL);
     end generate;
     
  i0:if not PIPELINE generate
       P<=RESIZE(S,P'high,P'low);
     end generate;

  i1:if PIPELINE generate
       signal iP:SFIXED(P'range):=(others=>'0');
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           iP<=RESIZE(S,P'high,P'low);
         end if;
       end process;
       P<=iP;
     end generate;
end FAST;
