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
--  \   \                  Filename:             BDELAY.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     BDELAY
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic BOOLEAN Delay Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity BDELAY is
  generic(SIZE:INTEGER:=1;
          BRAM_THRESHOLD:INTEGER:=258);
  port(CLK:in STD_LOGIC;
       I:in BOOLEAN;
       O:out BOOLEAN);
end BDELAY;

architecture TEST of BDELAY is
  attribute rloc:STRING;
  
  component BDELAY
    generic(SIZE:INTEGER:=1);
    port(CLK:in STD_LOGIC;
         I:in BOOLEAN;
         O:out BOOLEAN);
  end component;

begin
  l0:if SIZE=0 generate
     begin
       O<=I;
     end generate l0;
  --   end;

 l1:if SIZE=1 generate
       signal iO:BOOLEAN:=FALSE;
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           iO<=I;
         end if;
       end process;
       O<=iO;
     end generate l1;
     -- end;

  l17: if SIZE>=2 and SIZE<18 generate
        signal A:UNSIGNED(3 downto 0);
        signal D,Q:STD_LOGIC;
        signal RQ:STD_LOGIC:='0';
        --attribute rloc of sr:label is "X0Y"&INTEGER'image(K/8);
      begin
        A<=TO_UNSIGNED(SIZE-2,A'length);
        D<='1' when I else '0';
        sr:SRL16E port map(CLK=>CLK,
                           CE=>'1',
                           A0=>A(0),
                           A1=>A(1),
                           A2=>A(2),
                           A3=>A(3),
                           D=>D,
                           Q=>Q);
        process(CLK)
        begin
          if rising_edge(CLK) then
            RQ<=Q;
          end if;
        end process;
        O<=RQ='1';	
      end generate l17;
  --   end;

  l33: if SIZE>=18 and SIZE<34 generate
--       signal MEM:UFIXED_VECTOR(0 to SIZE-2)(I'range):=(others=>(others=>'0'));
       signal A:UNSIGNED(LOG2(SIZE-1)-1 downto 0):=(others=>'0');
--       attribute ram_style:STRING;
--       attribute ram_style of MEM:signal is "distributed";
            signal D,Q:STD_LOGIC;
       signal RQ:STD_LOGIC:='0';
     begin
       process(CLK)
       begin
         if rising_edge(CLK) then
           if A=SIZE-2 then
             A<=(others=>'0');
           else
             A<=A+1;
           end if;
--           MEM(TO_INTEGER(A))<=I;
--           O<=MEM(TO_INTEGER(A));
         end if;
       end process;
--       O<=RESIZE(iO,O);
            D<='1' when I else '0';
            rs:RAM32X1S port map(A0=>A(0),
                                 A1=>A(1),
                                 A2=>A(2),
                                 A3=>A(3),
                                 A4=>A(4),
                                 D=>D,
                                 WCLK=>CLK,
                                 WE=>'1',
                                 O=>Q);
            process(CLK)
            begin
              if rising_edge(CLK) then
                RQ<=Q;
              end if;
            end process;
            O<=RQ='1';	
      end generate l33;
  --   end;

  l257: if SIZE>=34 and SIZE<BRAM_THRESHOLD generate
       signal iO:BOOLEAN;
     begin
       ld:entity work.BDELAY generic map(SIZE=>33,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD)
                             port map(CLK=>CLK,
                                      I=>I,
                                      O=>iO);
       hd:entity work.BDELAY generic map(SIZE=>SIZE-33,
                                         BRAM_THRESHOLD=>BRAM_THRESHOLD)
                             port map(CLK=>CLK,
                                      I=>iO,
                                      O=>O);
     -- end;
      end generate l257;

  ln: if SIZE>=BRAM_THRESHOLD generate
--       signal MEM:UNSIGNED_VECTOR(0 to SIZE-2)(I'range):=(others=>(others=>'0'));
       type TUV is array(0 to SIZE-3) of UNSIGNED(0 downto 0);
--2008       signal MEM:UNSIGNED_VECTOR(0 to SIZE-3)(0 downto 0):=(others=>(others=>'0'));
       signal MEM:TUV:=(others=>(others=>'0'));
       signal RA,WA:UNSIGNED(LOG2(SIZE-2)-1 downto 0):=(others=>'0');
       signal iO1E,iO:UNSIGNED(0 downto 0):=(others=>'0');
       signal D,Q:UNSIGNED(0 downto 0);
       attribute ram_style:STRING;
       attribute ram_style of MEM:signal is "block";
     begin
       D<="1" when I else "0";
       process(CLK)
       begin
         if rising_edge(CLK) then
--           if RA=SIZE-2 then
           if RA=SIZE-3 then
             RA<=(others=>'0');
           else
             RA<=RA+1;
           end if;
           WA<=RA;
           MEM(TO_INTEGER(WA))<=D;
--           iO<=MEM(TO_INTEGER(RA));
           iO1E<=MEM(TO_INTEGER(RA));
           iO<=iO1E;
           O<=iO="1";
         end if;
       end process;
     -- end;
     end generate;
end TEST;
