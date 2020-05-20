-- 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
-----------------------------------------------------------------------------------------------
--  Copyright 2018 Xilinx, Inc. All rights reserved.
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
--  \   \                  Filename:             DS.vhd
--  /   /                  Date Last Modified:   14 Feb 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     DS
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-Feb-14 Initial final release
-------------------------------------------------------------------------------- 
--
-- Module Description: Output Order Swap Module for Systolic FFT (Digit Swap)
--                     Produces Transposed Output Order
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity DS is -- LATENCY=0 when N=2*SSR else LATENCY=N/SSR+1
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
end DS;

architecture TEST of DS is
  attribute syn_keep:STRING;
  attribute syn_keep of all:architecture is "hard";
  attribute ram_style:STRING;

--2008  constant RADIX:INTEGER:=I'length;  -- this is the Systolic FFT RADIX or SSR
  constant RADIX:INTEGER:=SSR;  -- this is the Systolic FFT RADIX or SSR
  constant L2N:INTEGER:=LOG2(N);
  constant L2R:INTEGER:=LOG2(RADIX);
  constant F:INTEGER:=L2N mod L2R;
  constant G:INTEGER:=2**F;

  signal VI1D:BOOLEAN:=FALSE;
  signal V:BOOLEAN;
--2008  signal I1D:CFIXED_VECTOR(I'range)(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(I'range=>(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).RE'range=>'0')));
  signal I1D:CFIXED_VECTOR(I'range):=(others=>'0');
  signal WCNT,RCNT:UNSIGNED(LOG2(N/RADIX)-1 downto 0):=(others=>'0');
  signal WA:UNSIGNED(WCNT'range):=(others=>'0');
  signal RA:UNSIGNED(RCNT'range):=(others=>'0');

  function RS(K:INTEGER) return STRING is
  begin
    if K<BRAM_THRESHOLD then
      return "distributed";
    else
      return "block";
    end if;
  end;
  
  type UNSIGNED_VECTOR is array(NATURAL range <>) of UNSIGNED(RCNT'range); --93
  function IDENTITY(K:INTEGER) return UNSIGNED_VECTOR is
    variable RESULT:UNSIGNED_VECTOR(0 to K-1);--93 (LOG2(K)-1 downto 0);
  begin
    for J in RESULT'range loop
      RESULT(J):=TO_UNSIGNED(J,RESULT(J)'length);
    end loop;
    return RESULT;
  end;
  
  function PERMUTE(A:UNSIGNED_VECTOR) return UNSIGNED_VECTOR is
    variable RESULT:UNSIGNED_VECTOR(A'range);--93 (A(A'low)'range);
  begin
    for J in RESULT'range loop
      for J in 0 to A'length/L2R-1 loop
        for K in 0 to L2R-1 loop
          RESULT((A'length/L2R-1-J)*L2R+K+F):=A(J*L2R+K);
        end loop;
      end loop;
      for K in 0 to F-1 loop
        RESULT(K):=A(A'length/L2R*L2R+K);
      end loop;
    end loop;
    return RESULT;
  end;
  
  function INVERSE_PERMUTE(A:UNSIGNED_VECTOR) return UNSIGNED_VECTOR is
    variable RESULT:UNSIGNED_VECTOR(A'range);--93 (A(A'low)'range);
  begin
    for J in RESULT'range loop
      for J in 0 to A'length/L2R-1 loop
        for K in 0 to L2R-1 loop
          RESULT(J*L2R+K):=A((A'length/L2R-1-J)*L2R+K+F);
        end loop;
      end loop;
      for K in 0 to F-1 loop
        RESULT(A'length/L2R*L2R+K):=A(K);
      end loop;
    end loop;
    return RESULT;
  end;
  
--2008  signal WSEL:UNSIGNED_VECTOR(0 to WCNT'length-1)(LOG2(WCNT'length)-1 downto 0):=INVERSE_PERMUTE(IDENTITY(WCNT'length));
--2008  signal RSEL:UNSIGNED_VECTOR(0 to RCNT'length-1)(LOG2(RCNT'length)-1 downto 0):=IDENTITY(RCNT'length);
  signal WSEL:UNSIGNED_VECTOR(0 to WCNT'length-1):=INVERSE_PERMUTE(IDENTITY(WCNT'length));
  signal RSEL:UNSIGNED_VECTOR(0 to RCNT'length-1):=IDENTITY(RCNT'length);
begin
  assert I'length=O'length report "Ports I and O must have the same length!" severity error;
--2008  assert I'length=2**L2R report "Port I length must be a power of 2!" severity error;
  assert SSR=2**L2R report "Port I length must be a power of 2!" severity error;

  i0:if L2N-L2R<2 generate
       O<=I;
       VO<=VI;
       SO<=SI;
--2008     else generate
     end generate;
  i1:if L2N-L2R>=2 generate
       bd:entity work.BDELAY generic map(SIZE=>N/RADIX-2)
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
               RSEL<=PERMUTE(WSEL);
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
           for K in WCNT'range loop
             WA(K)<=WCNT(TO_INTEGER(WSEL(K)));
           end loop;
         end if;
       end process;
-- Read Address Digit Swapping  
       process(CLK)
       begin
         if rising_edge(CLK) then
           for K in RCNT'range loop
             RA(K)<=RCNT(TO_INTEGER(RSEL(K)));
           end loop;
         end if;
       end process;
     
--2008       lk:for K in 0 to I'length-1 generate
       lk:if TRUE generate
--? Vivado synthesis does not infer RAM from this code, just LUTs and FFs
--            signal MEM:CFIXED_VECTOR(0 to 2**(CNT'length+1)-1)(RE(high_f(I(low_f(I)).RE) downto low_f(I(low_f(I)).RE)),IM(high_f(I(low_f(I)).RE) downto low_f(I(low_f(I)).IM))):=(0 to 2**(CNT'length+1)-1=>(RE=>(I(low_f(I)).RE'range=>'0'),IM=>(I(low_f(I)).IM'range=>'0')));
--2008            signal MEMR:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).RE'range):=(0 to 2**WCNT'length-1=>(I(I'low).RE'range=>'0'));
--2008            signal MEMI:SFIXED_VECTOR(0 to 2**WCNT'length-1)(I(I'low).IM'range):=(0 to 2**WCNT'length-1=>(I(I'low).IM'range=>'0'));
--2008            signal Q:CFIXED(RE(I(I'low).RE'range),IM(I(I'low).IM'range)):=(RE=>(I(I'low).RE'range=>'0'),IM=>(I(I'low).RE'range=>'0'));
            type iCFIXED_MATRIX is array(NATURAL range <>) of CFIXED_VECTOR(I'range);
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
--2008                O(K)<=Q;
                O<=Q;
              end if;
            end process;
          end generate;
     
       bo:entity work.BDELAY generic map(SIZE=>3)
                             port map(CLK=>CLK,
                                      I=>V,
                                      O=>VO);

       sd:entity work.UDELAY generic map(SIZE=>N/RADIX+1)
                             port map(CLK=>CLK,
                                      I=>SI,
                                      O=>SO);
     end generate;
end TEST;
