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
--  \   \                  Filename:             TABLE.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     TABLE
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Arbitrary Size, SinCos Table Module
--
-- Latency is always 2
-- when INV_FFT=FALSE W=exp(-2.0*PI*i*JK/N) and when INV_FFT=TRUE W=exp(2.0*PI*i*JK/N)
-- to maximize W output bit size utilization W.RE and W.IM are always negative (MSB='1') and that bit could be ignored, this is why W.RE'length can be 19 bits but a single BRAM would still be used
-- when W.RE or W.IM need to be positive CS respectively SS are TRUE, same thing when they are 0.0 CZ respectively SZ are TRUE - the complex multiplier has to use CS, SS, CZ and SZ, not just W to produce the correct result
-- the SIN and COS ROM table sizes are N/4 deep and W.RE'length-1 wide (it is implictly assumed that W.RE and W.IM always have the same range)
-- if STYLE="block" a single dual port BRAM is used for both tables
-- if STYLE="distributed" then two fabric LUT based ROMs are used
-- as a general rule for N<2048 "distributed" should be used, otherwise "block" makes more sense but this is not a hard rule
-- W range is unconstrained but W.RE'high and W.IM'high really have to be 0 all the time, do not use other values
-- the maximum SNR without using extra BRAMs is achieved when W.RE'low and W.IM'low are -18 so W.RE'length and W.IM'length are 19 bits but they can be less than that - this would reduce SNR and save resources only when STYLE="distributed"
-- TABLE.VHD also works with more than 19 bits but the current complex multiplier implementation does not support that - this would essentially double the number of BRAMs and DSP48s used and seems too high a price to pay for a few extra dB of SNR
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;

use work.COMPLEX_FIXED_PKG.all;

--!! entity TABLE is -- LATENCY=3 (2 if SEPARATE_SIGN is TRUE)
entity TABLE is -- LATENCY=4 (3 if SEPARATE_SIGN is TRUE) when SPLIT_RADIX=0 else LATENCY=0
  generic(N:INTEGER:=1024;
          SPLIT_RADIX:INTEGER:=0; -- 0 for use in systolic FFT and J*1 or J*3 with J>0 for use in parallel Split Radix FFT
          INV_FFT:BOOLEAN:=FALSE;
          SEPARATE_SIGN:BOOLEAN:=FALSE;
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          STYLE:STRING:="block"); -- use only "block" or "distributed"
  port(CLK:in STD_LOGIC;
       JK:in UNSIGNED;
       VI:in BOOLEAN;
       W:out CFIXED;
       CS,SS,CZ,SZ:out BOOLEAN;
       VO:out BOOLEAN);
end TABLE;

architecture TEST of TABLE is
--2008  constant WH:INTEGER:=W.RE'high-1+BOOLEAN'pos(SEPARATE_SIGN);
--2008  constant WL:INTEGER:=W.RE'low; -- SNR=110.06dB with WL=-17 and 116.27dB with WL=-18
  constant WH:INTEGER:=(W'high+1)/2-1-1+BOOLEAN'pos(SEPARATE_SIGN);
  constant WL:INTEGER:=W'low/2; -- SNR=110.06dB with WL=-17 and 116.27dB with WL=-18
begin
  i0:if SPLIT_RADIX=0 generate
       type wSFIXED_VECTOR is array(INTEGER range <>) of SFIXED(WH-1 downto WL); -- local constrained array of SFIXED type
--2008       function LUT_VALUE(N,WH,WL:INTEGER) return SFIXED_VECTOR is
--2008         variable RESULT:SFIXED_VECTOR(0 to N/4-1)(WH-1 downto WL);
       function LUT_VALUE(N,WH,WL:INTEGER) return wSFIXED_VECTOR is
         variable RESULT:wSFIXED_VECTOR(0 to N/4-1);
       begin
         RESULT(0):=TO_SFIXED(-1.0,WH,WL)(WH-1 downto WL); -- round and drop MSB, it is always 1
         for J in 1 to N/4-1 loop
           RESULT(J):=TO_SFIXED(-COS(-2.0*MATH_PI*REAL(J)/REAL(N))+2.0**(WL-1),WH,WL)(WH-1 downto WL); -- round and drop MSB, it is always 1
           if RESULT(J)=TO_SFIXED(-1.0,WH,WL)(WH-1 downto WL) then
             RESULT(J):=TO_SFIXED(-1.0+2.0**WL,WH,WL)(WH-1 downto WL);
           end if;
         end loop;
         return RESULT;
       end;
  
       signal JKD:UNSIGNED(JK'range):=(others=>'0');
       signal KC,KS:UNSIGNED(JK'range):=(others=>'0');--!!
       signal DC,C,DS,S:SFIXED(WH-1 downto WL):=(others=>'0');
--2008       signal LUT:SFIXED_VECTOR(0 to N/4-1)(WH-1 downto WL):=LUT_VALUE(N,WH,WL);
       signal LUT:wSFIXED_VECTOR(0 to N/4-1):=LUT_VALUE(N,WH,WL);
       attribute rom_style:STRING;
       attribute rom_style of LUT:signal is STYLE;
       signal RC,RS:BOOLEAN:=FALSE;
       signal MC,MS:STD_LOGIC:='0';
       signal CS1,SS1,CS2,SS2:BOOLEAN:=FALSE;
       signal W_RE,W_IM:SFIXED((W'high+1)/2-1 downto W'low/2);
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
--!!
--2008           KC<=JK when JK(JK'high-1)='0' else (not JK)+1;
--2008           KS<=(not JK)+1 when JK(JK'high-1)='0' else JK;
           if JK(JK'high-1)='0' then
             KC<=JK;
             KS<=(not JK)+1;
           else
             KC<=(not JK)+1;
             KS<=JK;
           end if;
           JKD<=JK;
           if (JKD and TO_UNSIGNED(2**(JK'length-2)-1,JK'length))=0 then --mask first two MSBs of JK
             RC<=JKD(JK'high-1)='1';
             RS<=JKD(JK'high-1)='0';
           else
             RC<=FALSE;
             RS<=FALSE;
           end if;
           DC<=LUT(TO_INTEGER(KC and TO_UNSIGNED(2**(KC'length-2)-1,KC'length)));
           DS<=LUT(TO_INTEGER(KS and TO_UNSIGNED(2**(KS'length-2)-1,KS'length)));
           if RC then
             C<=(others=>'0');
             MC<='0';
           else
             C<=DC;
             MC<='1';
           end if;
           if RS then
             S<=(others=>'0');
             MS<='0';
           else
             S<=DS;
             MS<='1';
           end if;
           CS1<=JKD(JK'high)=JKD(JK'high-1);
           SS1<=(JKD(JK'high)='1') xor INV_FFT;
           CS2<=CS1;
           SS2<=SS1;
         end if;  
       end process;  

       i0:if SEPARATE_SIGN generate
--2008            W.RE<=MC&C;
--2008            W.IM<=MS&S;
            W(W'length/2-1+W'low downto W'low)<=CFIXED(MC&C);
            W(W'high downto W'length/2+W'low)<=CFIXED(MS&S);
            CS<=CS2;
            SS<=SS2;
--          else generate
          end generate;
       i1:if not SEPARATE_SIGN generate
            signal WRE,WIM:SFIXED(WH downto WL):=(others=>'0');
            attribute keep:STRING;
            attribute keep of WRE:signal is "yes";
            attribute keep of WIM:signal is "yes";
            signal ZERO:SFIXED(WH downto WL):=TO_SFIXED(0.0,WH,WL);
          begin
            WRE<=MC&C;
            WIM<=MS&S;
       
            process(CLK)
            begin
              if rising_edge(CLK) then
                CS<=CS2;
                SS<=SS2;
                CZ<=WRE(WRE'high)='0';
                SZ<=WIM(WIM'high)='0';
              end if;
            end process;
            ar:entity work.ADDSUB generic map(DSP48E=>DSP48E)
                                  port map(CLK=>CLK,
                                           A=>ZERO,
                                           B=>WRE,
                                           SUB=>CS2,
--2008                                           P=>W.RE); -- P=±B
                                           P=>W_RE); -- P=±B
            ai:entity work.ADDSUB generic map(DSP48E=>DSP48E)
                                  port map(CLK=>CLK,
                                           A=>ZERO,
                                           B=>WIM,
                                           SUB=>SS2,
--2008                                           P=>W.IM); -- P=±B
                                           P=>W_IM); -- P=±B
            W(W'length/2-1+W'low downto W'low)<=CFIXED(W_RE);
            W(W'high downto W'length/2+W'low)<=CFIXED(W_IM);
--          end;
          end generate;

--!!       b2:entity work.BDELAY generic map(SIZE=>3-BOOLEAN'pos(SEPARATE_SIGN))
          b2:entity work.BDELAY generic map(SIZE=>4-BOOLEAN'pos(SEPARATE_SIGN))
                                port map(CLK=>CLK,
                                         I=>VI,
                                         O=>VO);
--          end;
     end generate;
--     else generate
     i1:if SPLIT_RADIX>0 generate
     begin
       i0:if SEPARATE_SIGN generate
--2008            W<=TO_CFIXED(COS(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),SIN(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),W);
            W<=TO_CFIXED(COS(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),SIN(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),W'high/2,W'low/2);
            CS<=FALSE;
            SS<=FALSE;
          end generate;
--          else generate
       ii:if not SEPARATE_SIGN generate
          begin
--2008            W<=TO_CFIXED(COS(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),SIN(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),W);
            W<=TO_CFIXED(COS(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),SIN(-2.0*MATH_PI*REAL(SPLIT_RADIX)/REAL(N))+2.0**(WL-1),W'high/2,W'low/2);
            CS<=FALSE;
            SS<=FALSE;
            CZ<=(SPLIT_RADIX=N/4) or (SPLIT_RADIX=3*N/4);
            SZ<=(SPLIT_RADIX=0) or (SPLIT_RADIX=N/2);
--          end;
          end generate;
       VO<=VI;
     end generate;
end TEST;
