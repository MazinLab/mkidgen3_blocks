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
--  \   \                  Filename:             CKCM.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CKCM
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Constant Coeficient Complex Multiplier
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;

use work.COMPLEX_FIXED_PKG.all;

entity CKCM is -- LATENCY=3
  generic(M:INTEGER:=1;              -- must be 0, 1, 2 or 3 to multiply I by (1.0,0.0), (Sqrt(0.5),-Sqrt(0.5)), (0.0,-1.0), (-Sqrt(0.5),-Sqrt(0.5))
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          ROUNDING:BOOLEAN:=FALSE;   -- set to TRUE to round the result
          CONJUGATE:BOOLEAN:=FALSE); -- set to TRUE for IFFT
  port(CLK:in STD_LOGIC;
       I:in CFIXED;
       O:out CFIXED);
end CKCM;

architecture TEST of CKCM is
  attribute use_dsp48:STRING;
  attribute use_dsp48 of TEST:architecture is "no";
--2008  signal RND:SFIXED(O.RE'high downto O.RE'low-1);
  signal RND:SFIXED((O'high+1)/2-1 downto O'low/2-1);
  constant nCONJUGATE:BOOLEAN:=not CONJUGATE;
begin
  i0:if M=0 generate
       cd:entity work.CDELAY generic map(SIZE=>3)
                             port map(CLK=>CLK,
                                      I=>I,
                                      O=>O);
     end generate;
--elsif i1: M=2 generate
  i1:if M=2 generate
      ic:if CONJUGATE generate
--2008           signal NIIM1D:SFIXED(I.IM'range):=TO_SFIXED(0.0,I.IM'high,I.IM'low);
           signal NIIM1D:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
           signal IRE:SFIXED((I'high+1)/2-1 downto I'low/2);
           signal ORE,OIM:SFIXED((O'high+1)/2-1 downto O'low/2);
         begin
           process(CLK)
           begin
             if rising_edge(CLK) then
--2008               NIIM1D<=RESIZE(-I.IM,I.IM);
               NIIM1D<=RESIZE(-IM(I),NIIM1D);
             end if;
           end process;
           r2:entity work.SDELAY generic map(SIZE=>2)
                                 port map(CLK=>CLK,
                                          I=>NIIM1D,
--2008                                          O=>O.RE);
                                          O=>ORE);
           IRE<=RE(I);
           i3:entity work.SDELAY generic map(SIZE=>3)
                                 port map(CLK=>CLK,
--2008                                          I=>I.RE,
--2008                                          O=>O.IM);
                                          I=>IRE,
                                          O=>OIM);
           O<=TO_CFIXED(ORE,OIM);
--         end;
         end generate;
         ---else generate
		  nc:if not CONJUGATE generate
--2008           signal NIRE1D:SFIXED(I.RE'range):=TO_SFIXED(0.0,I.RE'high,I.RE'low);
           signal NIRE1D:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
           signal IIM:SFIXED((I'high+1)/2-1 downto I'low/2);
           signal ORE,OIM:SFIXED((O'high+1)/2-1 downto O'low/2);
         begin
           IIM<=IM(I);
           r3:entity work.SDELAY generic map(SIZE=>3)
                                 port map(CLK=>CLK,
--2008                                          I=>I.IM,
--2008                                          O=>O.RE);
                                          I=>IIM,
                                          O=>ORE);
           process(CLK)
           begin
             if rising_edge(CLK) then
--2008               NIRE1D<=RESIZE(-I.RE,I.RE);
               NIRE1D<=RESIZE(-RE(I),RE(I));
             end if;
           end process;
           i2:entity work.SDELAY generic map(SIZE=>2)
                                 port map(CLK=>CLK,
                                          I=>NIRE1D,
--2008                                          O=>O.IM);
                                          O=>OIM);
           O<=TO_CFIXED(ORE,OIM);
--         end;
         end generate;
       end generate;
--     else generate -- M=1 or 3
  i2:if (M=1) or (M=3) generate -- M=1 or 3
         constant K:SFIXED(0 downto -18):="0101101010000010100"; -- SQRT(0.5)
												 
--2008         signal X1,Y1:SFIXED(I.RE'high downto I.RE'low-14);
--2008         signal X2,Y2:SFIXED(I.RE'range);
--2008         signal KIRE,KIIM:SFIXED(I.RE'range);

  
	   
         signal X1,Y1:SFIXED((I'high+1)/2-1 downto I'low/2-14);
         signal X2,Y2:SFIXED((I'high+1)/2-1 downto I'low/2):=(others=>'0');
         signal KIRE,KIIM:SFIXED((I'high+1)/2-1 downto I'low/2);
--2008         signal I_1:CFIXED(RE(I.RE'high-1 downto I.RE'low-1),IM(I.IM'high-1 downto I.IM'low-1));
--2008         signal I_6:CFIXED(RE(I.RE'high-6 downto I.RE'low-6),IM(I.IM'high-6 downto I.IM'low-6));
--2008         signal I_14:CFIXED(RE(I.RE'high-14 downto I.RE'low-14),IM(I.IM'high-14 downto I.IM'low-14));
         signal I_1:CFIXED(I'high-2*1 downto I'low-2*1);
         signal I_6:CFIXED(I'high-2*6 downto I'low-2*6);
         signal I_14:CFIXED(I'high-2*14 downto I'low-2*14);
         signal I_1RE,I_1IM:SFIXED((I_1'high+1)/2-1 downto I_1'low/2);
         signal I_6RE,I_6IM:SFIXED((I_6'high+1)/2-1 downto I_6'low/2);
         signal I_14RE,I_14IM:SFIXED((I_14'high+1)/2-1 downto I_14'low/2);
         signal X1_2:SFIXED(X1'high-2 downto X1'low-2);
         signal X2_4:SFIXED(X2'high-4 downto X2'low-4);
         signal Y1_2:SFIXED(Y1'high-2 downto Y1'low-2);
         signal Y2_4:SFIXED(Y2'high-4 downto Y2'low-4);
         signal ORE,OIM:SFIXED((O'high+1)/2-1 downto O'low/2);
         constant MEQ3:BOOLEAN:=M=3;
       begin
--2008       RND<=TO_SFIXED(2.0**(O.RE'low-1),RND) when ROUNDING else (others=>'0');
       RND<=TO_SFIXED(2.0**(O'low/2-1),RND) when ROUNDING else (others=>'0');
       process(CLK)
       begin
         if rising_edge(CLK) then
--2008           X2<=I.RE;
--2008           Y2<=I.IM;
           X2<=RE(I);
           Y2<=IM(I);
         end if;
       end process;

       I_1<=SHIFT_RIGHT(I,1);
       I_6<=SHIFT_RIGHT(I,6);
       I_14<=SHIFT_RIGHT(I,14);
       X1_2<=SHIFT_RIGHT(X1,2);
       X2_4<=SHIFT_RIGHT(X2,4);
       Y1_2<=SHIFT_RIGHT(Y1,2);
       Y2_4<=SHIFT_RIGHT(Y2,4);
       I_1RE<=RE(I_1);
       I_6RE<=RE(I_6);
       I_14RE<=RE(I_14);

       a1:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
--2008                                    A=>I_1.RE,
--2008                                    B=>I_6.RE,
--2008                                    C=>I_14.RE,
                                    A=>I_1RE,
                                    B=>I_6RE,
                                    C=>I_14RE,
                                    P=>X1); -- P=C+A+B

       a2:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
                                    A=>X1,
                                    B=>X1_2,
                                    C=>X2_4,
                                    P=>KIRE); -- P=C+A+B

       I_1IM<=IM(I_1);
       I_6IM<=IM(I_6);
       I_14IM<=IM(I_14);
       a3:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
--2008                                    A=>I_1.IM,
--2008                                    B=>I_6.IM,
--2008                                    C=>I_14.IM,
                                    A=>I_1IM,
                                    B=>I_6IM,
                                    C=>I_14IM,
                                    P=>Y1); -- P=C+A+B

       a4:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
                                    A=>Y1,
                                    B=>Y1_2,
                                    C=>Y2_4,
                                    P=>KIIM); -- P=C+A+B

       a5:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       NEGATIVE_A=>MEQ3, --2008 M=3,
                                       NEGATIVE_B=>CONJUGATE,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
                                    A=>KIRE,
                                    B=>KIIM,
                                    C=>RND,
                                    CY1=>MEQ3, --2008 M=3,
                                    CY2=>CONJUGATE,
--2008                                    P=>O.RE); -- P=C+A+B
                                    P=>ORE); -- P=C+A+B
 
       a6:entity work.CSA3 generic map(DSP48E=>DSP48E,
                                       NEGATIVE_A=>nCONJUGATE,
                                       NEGATIVE_B=>MEQ3, --2008 M=3,
                                       EXTRA_MSBs=>0)
                           port map(CLK=>CLK,
                                    A=>KIRE,
                                    B=>KIIM,
                                    C=>RND,
                                    CY1=>nCONJUGATE,
                                    CY2=>MEQ3, --2008 M=3,
--2008                                    P=>O.IM); -- P=C+A+B
                                    P=>OIM); -- P=C+A+B
       O<=TO_CFIXED(ORE,OIM);
  --end;
 end generate;
end TEST;
