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
--  \   \                  Filename:             CBFS.vhd
--  /   /                  Date Last Modified:   16 Apr 2018
-- /___/   /\              Date Created:         
-- \   \  /  \
--  \___\/\___\
-- 
-- Device:          Any UltraScale Xilinx FPGA
-- Author:          Catalin Baetoniu
-- Entity Name:     CBFS
-- Purpose:         Generic Add/Subtract Module
--
-- Revision History: 
-- Revision 0.14    2018-April-16  Version with workarounds for Vivado Simulator limited VHDL-2008 support
-------------------------------------------------------------------------------- 
--
-- Module Description: Generic, Complex Arbitrary Fixed Point Size, Add/Subtract FFT Module with scaling and overflow detection
--
-------------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.COMPLEX_FIXED_PKG.all;

entity CBFS is -- O0=I0+I1, O1=I0-I1
  generic(ROUNDING:BOOLEAN:=TRUE;
          PIPELINE:BOOLEAN:=TRUE;
          DSP48E:INTEGER:=2; -- use 1 for 7-series and 2 for US/US+
          EXTRA_MSBs:INTEGER:=1);
  port(CLK:in STD_LOGIC;
         I0,I1:in CFIXED;
         SCALE:in STD_LOGIC;
         O0,O1:out CFIXED;
         OVR:out STD_LOGIC);
end CBFS;

architecture TEST of CBFS is
  signal I0RE,I0IM,I1RE,I1IM:SFIXED(I0'high/2 downto I0'low/2);
  signal O0RE,O0IM,O1RE,O1IM:SFIXED(O0'high/2 downto O0'low/2);
  signal OVR4:STD_LOGIC_VECTOR(3 downto 0);
begin
  I0RE<=RE(I0);
  I0IM<=IM(I0);
  I1RE<=RE(I1);
  I1IM<=IM(I1);
  
  u0:entity work.BFS generic map(DSP48E=>DSP48E,
                                 SUB=>FALSE) -- O0RE=I0RE+I1RE
                     port map(CLK=>CLK,
                              A=>I0RE,
                              B=>I1RE,
                              SCALE=>SCALE,
                              P=>O0RE,
                              OVR=>OVR4(0));

  u1:entity work.BFS generic map(DSP48E=>DSP48E,
                                 SUB=>FALSE) -- O0IM=I0IM+I1IM
                     port map(CLK=>CLK,
                              A=>I0IM,
                              B=>I1IM,
                              SCALE=>SCALE,
                              P=>O0IM,
                              OVR=>OVR4(1));

  u2:entity work.BFS generic map(DSP48E=>DSP48E,
                                 SUB=>TRUE) -- O1RE=I0RE-I1RE
                     port map(CLK=>CLK,
                              A=>I0RE,
                              B=>I1RE,
                              SCALE=>SCALE,
                              P=>O1RE,
                              OVR=>OVR4(2));

  u3:entity work.BFS generic map(DSP48E=>DSP48E,
                                 SUB=>TRUE) -- O1IM=I0IM-I1IM
                     port map(CLK=>CLK,
                              A=>I0IM,
                              B=>I1IM,
                              SCALE=>SCALE,
                              P=>O1IM,
                              OVR=>OVR4(3));

  O0<=TO_CFIXED(O0RE,O0IM);
  O1<=TO_CFIXED(O1RE,O1IM);
  OVR<=OVR4(0) or OVR4(1) or OVR4(2) or OVR4(3);
end TEST;
