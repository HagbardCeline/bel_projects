--! @file        prio_auto_pkg.vhd
--  DesignUnit   prio_auto
--! @author      M. Kreider <m.kreider@gsi.de>
--! @date        23/06/2016
--! @version     0.0.1
--! @copyright   2016 GSI Helmholtz Centre for Heavy Ion Research GmbH
--!

--! @brief AUTOGENERATED WISHBONE-SLAVE PACKAGE FOR prio.vhd
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
--------------------------------------------------------------------------------

-- ***********************************************************
-- ** WARNING - THIS IS AUTO-GENERATED CODE! DO NOT MODIFY! **
-- ***********************************************************
--
-- If you want to change the interface,
-- modify prio.xml and re-run 'python wbgenplus.py prio.xml' !

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
use work.wbgenplus_pkg.all;
use work.genram_pkg.all;
package prio_auto_pkg is

  constant c_reset_OWR          : natural := 16#00#;  -- wo,          1 b, Resets the Priority Queue
  constant c_mode_GET           : natural := 16#04#;  -- ro,          3 b, b2: Time limit, b1: Msg limit, b0 enable
  constant c_mode_CLR           : natural := 16#08#;  -- wo,          3 b, b2: Time limit, b1: Msg limit, b0 enable
  constant c_mode_SET           : natural := 16#0c#;  -- wo,          3 b, b2: Time limit, b1: Msg limit, b0 enable
  constant c_clear_OWR          : natural := 16#10#;  -- wo,          1 b, Clears counters and status
  constant c_st_full_GET        : natural := 16#14#;  -- ro, g_channels b, Channel Full flag (n..0) 
  constant c_st_late_GET        : natural := 16#18#;  -- ro,          1 b, Late message detected
  constant c_ebm_adr_RW         : natural := 16#1c#;  -- rw,         32 b, Etherbone Master address
  constant c_eca_adr_RW         : natural := 16#20#;  -- rw,         32 b, Event Condition Action Unit address
  constant c_tx_max_msgs_RW     : natural := 16#24#;  -- rw,          8 b, Max msgs per packet
  constant c_tx_max_wait_RW     : natural := 16#28#;  -- rw,         32 b, Max wait time for non empty packet
  constant c_tx_rate_limit_RW   : natural := 16#2c#;  -- rw,         32 b, Max msgs per milliseconds
  constant c_offs_late_RW_0     : natural := 16#30#;  -- rw,         32 b, Time offset before message is late
  constant c_offs_late_RW_1     : natural := 16#34#;  -- rw,         32 b, Time offset before message is late
  constant c_cnt_late_GET       : natural := 16#38#;  -- ro,         32 b, Sum of all late messages
  constant c_ts_late_GET_0      : natural := 16#3c#;  -- ro,         32 b, First late Timestamp
  constant c_ts_late_GET_1      : natural := 16#40#;  -- ro,         32 b, First late Timestamp
  constant c_cnt_out_all_GET_0  : natural := 16#44#;  -- ro,         32 b, Sum of all outgoing messages
  constant c_cnt_out_all_GET_1  : natural := 16#48#;  -- ro,         32 b, Sum of all outgoing messages

  --| Component ------------------------- prio_auto -------------------------------------------|
  component prio_auto is
  generic(
    g_channels  : natural := 16 --Input channels
  );
  Port(
    clk_sys_i       : std_logic;                                    -- Clock input for sys domain
    rst_sys_n_i     : std_logic;                                    -- Reset input (active low) for sys domain
    cnt_late_i      : in  std_logic_vector(32-1 downto 0);          -- Sum of all late messages
    cnt_late_V_i    : in  std_logic_vector(1-1 downto 0);           -- Valid flag - cnt_late
    cnt_out_all_i   : in  std_logic_vector(64-1 downto 0);          -- Sum of all outgoing messages
    cnt_out_all_V_i : in  std_logic_vector(1-1 downto 0);           -- Valid flag - cnt_out_all
    error_i         : in  std_logic_vector(1-1 downto 0);           -- Error control
    st_full_i       : in  std_logic_vector(g_channels-1 downto 0);  -- Channel Full flag (n..0) 
    st_full_V_i     : in  std_logic_vector(1-1 downto 0);           -- Valid flag - st_full
    st_late_i       : in  std_logic_vector(1-1 downto 0);           -- Late message detected
    st_late_V_i     : in  std_logic_vector(1-1 downto 0);           -- Valid flag - st_late
    stall_i         : in  std_logic_vector(1-1 downto 0);           -- flow control
    ts_late_i       : in  std_logic_vector(64-1 downto 0);          -- First late Timestamp
    ts_late_V_i     : in  std_logic_vector(1-1 downto 0);           -- Valid flag - ts_late
    clear_o         : out std_logic_vector(1-1 downto 0);           -- Clears counters and status
    ebm_adr_o       : out std_logic_vector(32-1 downto 0);          -- Etherbone Master address
    eca_adr_o       : out std_logic_vector(32-1 downto 0);          -- Event Condition Action Unit address
    mode_o          : out std_logic_vector(3-1 downto 0);           -- b2: Time limit, b1: Msg limit, b0 enable
    offs_late_o     : out std_logic_vector(64-1 downto 0);          -- Time offset before message is late
    reset_o         : out std_logic_vector(1-1 downto 0);           -- Resets the Priority Queue
    tx_max_msgs_o   : out std_logic_vector(8-1 downto 0);           -- Max msgs per packet
    tx_max_wait_o   : out std_logic_vector(32-1 downto 0);          -- Max wait time for non empty packet
    tx_rate_limit_o : out std_logic_vector(32-1 downto 0);          -- Max msgs per milliseconds
    
    ctrl_i          : in  t_wishbone_slave_in;
    ctrl_o          : out t_wishbone_slave_out

    
  );
  end component;

  constant c_prio_ctrl_sdb : t_sdb_device := (
  abi_class     => x"0000", -- undocumented device
  abi_ver_major => x"01",
  abi_ver_minor => x"00",
  wbd_endian    => c_sdb_endian_big,
  wbd_width     => x"7", -- 8/16/32-bit port granularity
  sdb_component => (
  addr_first    => x"0000000000000000",
  addr_last     => x"000000000000007f",
  product => (
  vendor_id     => x"0000000000000651",
  device_id     => x"10040200",
  version       => x"00000001",
  date          => x"20160623",
  name          => "DM-PriorityQ-Ctrl  ")));

end prio_auto_pkg;
package body prio_auto_pkg is
end prio_auto_pkg;
