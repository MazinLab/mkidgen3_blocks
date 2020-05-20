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
--  \   \                  Filename:             CDELAY.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CDELAY
-- Purpose:         Arbitrary Size Systolic FFT - any size N, any SSR (powers of 2 only)
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic CFIXED Delay Module
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

use work.COMPLEX_FIXED_PKG.all;

library UNISIM;
use UNISIM.VComponents.all;

entity CDELAY is
  generic(SIZE:INTEGER:=1;
          BRAM_THRESHOLD:INTEGER:=258);
  port(CLK:in STD_LOGIC;
       I:in CFIXED;
       O:out CFIXED);
end CDELAY;

architecture TEST of CDELAY is
  attribute syn_hier:STRING;
  attribute syn_hier of all:architecture is "hard";
  attribute rloc:STRING;
  signal IRE,IIM:SFIXED((I'high+1)/2-1 downto I'low/2);
  signal ORE,OIM:SFIXED((O'high+1)/2-1 downto O'low/2);
begin
  IRE<=RE(I);
  IIM<=IM(I);
  dr:entity work.SDELAY generic map(SIZE=>SIZE,
                                    BRAM_THRESHOLD=>BRAM_THRESHOLD)
                        port map(CLK=>CLK,
--2008                                 I=>I.RE,
--2008                                 O=>O.RE);
                                 I=>IRE,
                                 O=>ORE);
  di:entity work.SDELAY generic map(SIZE=>SIZE,
                                    BRAM_THRESHOLD=>BRAM_THRESHOLD)
                        port map(CLK=>CLK,
--2008                                 I=>I.IM,
--2008                                 O=>O.IM);
                                 I=>IIM,
                                 O=>OIM);
  O<=TO_CFIXED(ORE,OIM);
end TEST;
