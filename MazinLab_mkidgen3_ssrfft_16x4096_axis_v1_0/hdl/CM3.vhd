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
--  \   \                  Filename:             CM3.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CM3
-- Purpose:         Generic Parallel FFT Module (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Complex Multiplier Using 3 DSP48E2s
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity CM3 is -- LATENCY=6
  generic(ROUNDING:BOOLEAN:=FALSE;
          DSP48E:INTEGER:=2); -- use 1 for DSP48E1 and 2 for DSP48E2
  port(CLK:in STD_LOGIC;
       I:in CFIXED; -- I.RE'length and I.IM'length<27
       W:in CFIXED; -- W must be (1 downto -16) or (1 downto -17)
       CS,SS,CZ,SZ:in BOOLEAN:=FALSE;
       VI:in BOOLEAN;
       O:out CFIXED;
       VO:out BOOLEAN);
end CM3;

architecture TEST of CM3 is
  attribute keep_hierarchy:STRING;
  attribute keep_hierarchy of all:architecture is "yes";
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute loc:STRING;

--2008  constant HMAX:INTEGER:=MAX(I.RE'high,I.IM'high)+MAX(W.RE'high,W.IM'high)+3;
--2008  constant LMIN:INTEGER:=work.COMPLEX_FIXED_PKG.MIN(I.RE'low,I.IM'low)+work.COMPLEX_FIXED_PKG.MIN(W.RE'low,W.IM'low);
  constant HMAX:INTEGER:=(I'high+1)/2-1+(W'high+1)/2-1+3;
  constant LMIN:INTEGER:=I'low/2+W'low/2;

--  signal WRE,WIM:SFIXED(work.COMPLEX_FIXED_PKG.MIN(W.RE'high,1) downto MAX(W.RE'low,-16));
--  signal WRE,WIM:SFIXED(work.COMPLEX_FIXED_PKG.MIN(W.RE'high,0) downto MAX(W.RE'low,-17));
--2008  signal WRE,WIM:SFIXED(work.COMPLEX_FIXED_PKG.MIN(W.RE'low+17,1) downto W.RE'low); -- we only have 18 bits max to work with
--2008  signal WRE1D,nWRE2D:SFIXED(WRE'range):=TO_SFIXED(0.0,WRE'high,WRE'low);
--2008  signal IRE1D,IRE2D:SFIXED(I.IM'range):=TO_SFIXED(0.0,I.RE'high,I.RE'low);
--2008  signal IIM1D,IIM2D:SFIXED(I.IM'range):=TO_SFIXED(0.0,I.IM'high,I.IM'low);
  signal WRE,WIM:SFIXED(work.COMPLEX_FIXED_PKG.MIN(W'low/2+17,1) downto W'low/2); -- we only have 18 bits max to work with
  signal WRE1D,nWRE2D:SFIXED(WRE'range):=TO_SFIXED(0.0,WRE'high,WRE'low);
  signal IRE,IRE1D,IRE2D:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
  signal IIM,IIM1D,IIM2D:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
  signal CS2D,SS2D:BOOLEAN;
  signal C0S1:BOOLEAN:=FALSE;
  signal P1,P2,P3:SFIXED(HMAX downto LMIN);
  signal P2D:SFIXED(HMAX downto LMIN):=(others=>'0');
  signal C1,C2,C3:SFIXED(HMAX downto LMIN):=(others=>'0');
  signal AC1,AC2:STD_LOGIC_VECTOR(29 downto 0);
  signal BC1:STD_LOGIC_VECTOR(17 downto 0);
  signal PC1,PC2:STD_LOGIC_VECTOR(47 downto 0);
--2008  signal A_ZERO:SFIXED(I.RE'range):=TO_SFIXED(0.0,I.RE'high,I.RE'low);
  signal A_ZERO:SFIXED((I'high+1)/2-1 downto I'low/2):=TO_SFIXED(0.0,(I'high+1)/2-1,I'low/2);
  signal B_ZERO:SFIXED(WRE'range):=TO_SFIXED(0.0,WRE'high,WRE'low);
  signal C_ZERO:SFIXED(HMAX downto LMIN):=TO_SFIXED(0.0,HMAX,LMIN);
  signal BR,BI:BOOLEAN;
  signal iO:CFIXED(O'range);
begin
--!!
--2008  WRE<=RESIZE(W.RE,WRE);
  WRE<=RESIZE(RE(W),WRE);
--!!  WRE<=TO_SFIXED(1.0-2.0**WRE'low,WRE) when W.RE=TO_SFIXED(1.0,W.RE) else RESIZE(W.RE,WRE);
--!!
--2008  WIM<=RESIZE(W.IM,WIM);
  WIM<=RESIZE(IM(W),WIM);
  process(CLK)
  begin
    if rising_edge(CLK) then
      WRE1D<=WRE;
--2008      IRE1D<=I.RE;
--2008      IIM1D<=I.IM;
      IRE1D<=RE(I);
      IIM1D<=IM(I);
--2008      C0S1<=CZ and (W.IM(W.IM'high)='0');
      C0S1<=CZ and (W(W'high)='0');
--!!
      NWRE2D<=RESIZE(-WRE1D,NWRE2D);
--!!      if WRE1D=TO_SFIXED(-1.0,WRE1D) then
--!!        for K in NWRE2D'range loop
--!!          NWRE2D(K)<=not WRE1D(K);
--!!        end loop;
--!!      else
--!!        NWRE2D<=RESIZE(-WRE1D,NWRE2D);
--!!      end if;
--!!
      IRE2D<=IRE1D;
      IIM2D<=IIM1D;
    end if;
  end process;
  
  process(CLK)
  begin
    if rising_edge(CLK) then
--2008      if (W.RE'low=-17) and C0S1 then
      if (W'low/2=-17) and C0S1 then
        C1<=RESIZE(SHIFT_LEFT(IRE1D+IIM1D,1),C1);
      else
        C1<=TO_SFIXED(0.0,C1);
      end if;
    end if;
  end process;
  
  IRE<=RE(I);
  IIM<=IM(I);
  dsp1:entity work.DSP48E2GW generic map(DSP48E=>DSP48E,        -- 1 for DSP48E1, 2 for DSP48E2
                                         AMULTSEL=>"AD",         -- Selects A input to multiplier (A, AD)
                                         BREG=>2)                -- Pipeline stages for B (0-2)
                             port map(CLK=>CLK,
                                      INMODE=>"00101",  -- (D+A1)*B2
                                      ALUMODE=>"0011",  -- Z-W-X-Y
                                      OPMODE=>"110000101", -- PCOUT=-C-(D+A1)*B2
--2008                                      A=>I.RE,  
                                      A=>IRE,
                                      B=>WIM,
                                      C=>C1,
--2008                                      D=>I.IM,
                                      D=>IIM,
                                      ACOUT=>AC1,
                                      BCOUT=>BC1,
                                      P=>P1,
                                      PCOUT=>PC1);

--  C2<=TO_SFIXED(2.0**(O.RE'low-1),C2) when ROUNDING else TO_SFIXED(0.0,C2);
  BR<=W(W'length/2-1+W'low)='0';
  BI<=W(W'high)='0';
  cd:entity work.BDELAY generic map(SIZE=>2)
                        port map(CLK=>CLK,
--2008                                 I=>W.RE(W.RE'high)='0',
                                 I=>BR,
                                 O=>CS2D);
  sd:entity work.BDELAY generic map(SIZE=>2)
                        port map(CLK=>CLK,
--2008                                 I=>W.IM(W.IM'high)='0',
                                 I=>BI,
                                 O=>SS2D);
  process(CLK)
  begin
    if rising_edge(CLK) then
--2008      if (W.RE'low=-17) and CS2D=SS2D then
      if (W'low/2=-17) and CS2D=SS2D then
        if CS2D then
          if ROUNDING then
--2008            C2<=RESIZE(TO_SFIXED(2.0**(O.RE'low-1),C2)+SHIFT_LEFT(IRE2D,1),C2);
            C2<=RESIZE(TO_SFIXED(2.0**(O'low/2-1),C2)+SHIFT_LEFT(IRE2D,1),C2);
          else
--2008            C2<=RESIZE(I.RE,C2);
            C2<=RESIZE(SHIFT_LEFT(IRE2D,1),C2);
          end if;
        else
          if ROUNDING then
--2008            C2<=RESIZE(TO_SFIXED(2.0**(O.RE'low-1),C2)-SHIFT_LEFT(IRE2D,1),C2);
            C2<=RESIZE(TO_SFIXED(2.0**(O'low/2-1),C2)-SHIFT_LEFT(IRE2D,1),C2);
          else
--2008            C2<=RESIZE(-I.RE,C2);
            C2<=RESIZE(-SHIFT_LEFT(IRE2D,1),C2);
          end if;
        end if;
      else
        if ROUNDING then
--2008          C2<=TO_SFIXED(2.0**(O.RE'low-1),C2);
          C2<=TO_SFIXED(2.0**(O'low/2-1),C2);
        else
          C2<=TO_SFIXED(0.0,C2);
        end if;
      end if;
    end if;
  end process;
  
  dsp2:entity work.DSP48E2GW generic map(DSP48E=>DSP48E,        -- 1 for DSP48E1, 2 for DSP48E2
                                         A_INPUT=>"CASCADE",     -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                         BMULTSEL=>"AD",         -- Selects B input to multiplier (AD, B)
                                         B_INPUT=>"CASCADE",     -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                         PREADDINSEL=>"B",       -- Selects input to preadder (A, B)
                                         AREG=>2)                -- Pipeline stages for A (0-2)
                             port map(CLK=>CLK,
                                      INMODE=>"10100",  -- (D+B1)*A2
                                      ALUMODE=>"0000",  -- Z+W+X+Y
                                      OPMODE=>"110010101", -- PCOUT=PCIN+C+(D+B1)*A2    
                                      A=>A_ZERO,
                                      B=>B_ZERO,
                                      C=>C2,
                                      D=>WRE1D,
                                      ACIN=>AC1,
                                      BCIN=>BC1,
                                      PCIN=>PC1,
                                      ACOUT=>AC2,
                                      P=>P2,
                                      PCOUT=>PC2);

--  C3<=RESIZE(SHIFT_RIGHT(P1,-16-W.RE'low),P1);
  C3<=P1;
  dsp3:entity work.DSP48E2GW generic map(DSP48E=>DSP48E,        -- 1 for DSP48E1, 2 for DSP48E2
                                         AMULTSEL=>"AD",         -- Selects A input to multiplier (A, AD)
                                         A_INPUT=>"CASCADE",     -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                         BREG=>2)                -- Pipeline stages for B (0-2)
                             port map(CLK=>CLK,
                                      INMODE=>"01101", --5x"0C",  -- (D-A1)*B2
                                      ALUMODE=>"0011",  -- Z-W-X-Y
                                      OPMODE=>"110010101", -- PCOUT=PCIN-C-(D-A1)*B2 
                                      A=>A_ZERO,
                                      B=>NWRE2D,
                                      C=>C3,
                                      D=>IIM2D,
                                      ACIN=>AC2,
                                      PCIN=>PC2,
                                      P=>P3);

  process(CLK)
  begin
    if rising_edge(CLK) then
--2008      O.RE<=RESIZE(P2,O.RE);
      P2D<=P2;
    end if;
  end process;
--2008  O.IM<=RESIZE(P3,O.IM);
--  O<=RESIZE(TO_CFIXED(P2D,P3),O);
  O<=RESIZE(TO_CFIXED(P2D,P3),iO);
  
  bd:entity work.BDELAY generic map(SIZE=>6)
                        port map(CLK=>CLK,
                                 I=>VI,
                                 O=>VO);  
end TEST;
