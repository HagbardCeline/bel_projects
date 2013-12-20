--! @file monster_pkg.vhd
--! @brief Monster (all your top are belong to BEL) package
--! @author Wesley W. Terpstra <w.terpstra@gsi.de>
--!
--! Copyright (C) 2013 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! This combines all the common GSI components together
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
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package monster_pkg is

  component monster is
    generic(
      g_family      : string; -- "Arria II" or "Arria V"
      g_project     : string;
      g_inputs      : natural;
      g_outputs     : natural;
      g_flash_bits  : natural;
      g_ram_size    : natural := 131072;
      g_pll_skew    : natural := 0; -- (ref-tx) in ps
      g_en_pcie     : boolean := false;
      g_en_vme      : boolean := false;
      g_en_usb      : boolean := false;
      g_en_scubus   : boolean := false;
      g_en_oled     : boolean := false;
      g_en_lcd      : boolean := false);
    port(
      -- Required: core signals
      core_clk_20m_vcxo_i    : in    std_logic;
      core_clk_125m_sfpref_i : in    std_logic;
      core_clk_125m_pllref_i : in    std_logic;
      core_clk_125m_local_i  : in    std_logic;
      core_rstn_i            : in    std_logic := '1';
      -- Optional clock outputs
      core_clk_wr_ref_o      : out   std_logic;
      core_clk_butis_o       : out   std_logic;
      core_rstn_wr_ref_o     : out   std_logic;
      core_rstn_butis_o      : out   std_logic;
      -- GPIO for the board
      gpio_o                 : out   std_logic_vector(g_outputs-1 downto 0);
      gpio_i                 : in    std_logic_vector(g_inputs-1  downto 0);
      -- Required: white rabbit pins
      wr_onewire_io          : inout std_logic;
      wr_sfp_sda_io          : inout std_logic;
      wr_sfp_scl_io          : inout std_logic;
      wr_sfp_det_i           : in    std_logic;
      wr_sfp_tx_o            : out   std_logic;
      wr_sfp_rx_i            : in    std_logic;
      wr_dac_sclk_o          : out   std_logic;
      wr_dac_din_o           : out   std_logic;
      wr_ndac_cs_o           : out   std_logic_vector(2 downto 1);
      -- Optional WR features
      wr_ext_clk_i           : in    std_logic := '0'; -- 10MHz
      wr_ext_pps_i           : in    std_logic := '0';
      wr_uart_o              : out   std_logic;
      wr_uart_i              : in    std_logic := '0';
      -- Optional status LEDs
      led_link_up_o          : out   std_logic;
      led_link_act_o         : out   std_logic;
      led_track_o            : out   std_logic;
      led_pps_o              : out   std_logic;
      -- g_en_pcie
      pcie_refclk_i          : in    std_logic := '0';
      pcie_rstn_i            : in    std_logic := '0';
      pcie_rx_i              : in    std_logic_vector(3 downto 0) := (others => '0');
      pcie_tx_o              : out   std_logic_Vector(3 downto 0);
      -- g_en_vme
      vme_as_n_i             : in    std_logic := '0';
      vme_rst_n_i            : in    std_logic := '0';
      vme_write_n_i          : in    std_logic := '1';
      vme_am_i               : in    std_logic_vector(5 downto 0) := (others => '0');
      vme_ds_n_i             : in    std_logic_vector(1 downto 0) := (others => '1');
      vme_ga_i               : in    std_logic_vector(3 downto 0) := (others => '0');
      vme_addr_data_b        : inout std_logic_vector(31 downto 0) := (others => 'Z');
      vme_iack_n_i           : in    std_logic := '1';
      vme_iackin_n_i         : in    std_logic := '1';
      vme_iackout_n_o        : out   std_logic;
      vme_irq_n_o            : out   std_logic_vector(6 downto 0);
      vme_berr_o             : out   std_logic;
      vme_dtack_oe_o         : out   std_logic;
      vme_buffer_latch_o     : out   std_logic_vector(3 downto 0);
      vme_data_oe_ab_o       : out   std_logic;
      vme_data_oe_ba_o       : out   std_logic;
      vme_addr_oe_ab_o       : out   std_logic;
      vme_addr_oe_ba_o       : out   std_logic;
      -- g_en_usb
      usb_rstn_o             : out   std_logic;
      usb_ebcyc_i            : in    std_logic := '0';
      usb_speed_i            : in    std_logic := '0';
      usb_shift_i            : in    std_logic := '0';
      usb_readyn_io          : inout std_logic := 'Z';
      usb_fifoadr_o          : out   std_logic_vector(1 downto 0);
      usb_sloen_o            : out   std_logic;
      usb_fulln_i            : in    std_logic := '1';
      usb_emptyn_i           : in    std_logic := '0';
      usb_slrdn_o            : out   std_logic;
      usb_slwrn_o            : out   std_logic;
      usb_pktendn_o          : out   std_logic;
      usb_fd_io              : inout std_logic_vector(7 downto 0) := (others => 'Z');
      -- g_en_scubus
      scubus_a_a             : out   std_logic_vector(15 downto 0);
      scubus_a_d             : inout std_logic_vector(15 downto 0) := (others => 'Z');
      scubus_nsel_data_drv   : out   std_logic;
      scubus_a_nds           : out   std_logic;
      scubus_a_rnw           : out   std_logic;
      scubus_a_ndtack        : in    std_logic := '1';
      scubus_a_nsrq          : in    std_logic_vector(12 downto 1) := (others => '1');
      scubus_a_nsel          : out   std_logic_vector(12 downto 1);
      scubus_a_ntiming_cycle : out   std_logic;
      scubus_a_sysclock      : out   std_logic;
      -- g_en_oled
      oled_rstn_o            : out   std_logic;
      oled_dc_o              : out   std_logic;
      oled_ss_o              : out   std_logic;
      oled_sck_o             : out   std_logic;
      oled_sd_o              : out   std_logic;
      oled_sh_vr_o           : out   std_logic;
      -- g_en_lcd
      lcd_scp_o              : out   std_logic;
      lcd_lp_o               : out   std_logic;
      lcd_flm_o              : out   std_logic;
      lcd_in_o               : out   std_logic);
  end component;

end package;