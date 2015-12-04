--! @file        ftm_lm32.vhd
--  DesignUnit   ftm_lm32
--! @author      M. Kreider <>
--! @date        25/02/2014
--! @version     0.0.3
--! @copyright   2015 GSI Helmholtz Centre for Heavy Ion Research GmbH
--!

--! @brief LM32 embedded system. CPU, RAM, MSI-IRQ interface, system time, timer module, atomic cycle line control
--!
--
--! CPU Info ROM Registers:
--! 0x00 CPU ID
--! 0x04 Number of MSI Endpoints
--! 0x08 RAM size
--! 0x10 Is part of a Cluster?
--
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
--



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
use work.wb_irq_pkg.all;
use work.ftm_pkg.all;


entity ftm_lm32 is
generic(g_cpu_id              : t_wishbone_data := x"CAFEBABE";
        g_size                : natural := 65536;                 -- size of the dpram
        g_is_in_cluster       : boolean := false;
        g_is_ftm              : boolean := false; 
        g_cluster_bridge_sdb  : t_sdb_bridge := c_dummy_bridge;   -- record for optional (superior) cluster bridge
        g_world_bridge_sdb    : t_sdb_bridge;                     -- record for (superior) world bridge
        g_profile             : string  := "medium_icache_debug"; -- lm32 profile
        g_init_file           : string;                           -- memory init file - binary for lm32
        g_msi_queues          : natural := 1);                    -- number of msi queues connected to the lm32 (added at prio 1 !!! 0 is always timer
port(
clk_sys_i      : in  std_logic;  -- system clock 
rst_n_i        : in  std_logic;  -- reset, active low 
rst_lm32_n_i   : in  std_logic;  -- reset, active low
tm_tai8ns_i    : in std_logic_vector(63 downto 0) := (others => '0');

-- optional priority queue interface for DataMaster
prioq_master_o : out t_wishbone_master_out; 
prioq_master_i : in  t_wishbone_master_in := ('0', '0', '0', '0', '0', x"00000000");

-- optional cluster periphery interface of the lm32
clu_master_o  : out t_wishbone_master_out; 
clu_master_i  : in  t_wishbone_master_in := ('0', '0', '0', '0', '0', x"00000000");
  
-- wb world interface of the lm32
world_master_o  : out t_wishbone_master_out; 
world_master_i  : in  t_wishbone_master_in := ('0', '0', '0', '0', '0', x"00000000");  
-- wb msi interfaces
irq_slaves_o   : out t_wishbone_slave_out_array(g_msi_queues-1 downto 0);  
irq_slaves_i   : in  t_wishbone_slave_in_array(g_msi_queues-1 downto 0) := (others => ('0', '0', (others => '0'), (others => '0'), '0', (others => '0')));
-- port B of the LM32s DPRAM 
ram_slave_o    : out t_wishbone_slave_out;                           
ram_slave_i    : in  t_wishbone_slave_in := ('0', '0', (others => '0'), (others => '0'), '0', (others => '0'))

);
end ftm_lm32;

architecture rtl of ftm_lm32 is 
   
   -- crossbar layout
   constant c_lm32_slaves          : natural := 8;
   constant c_lm32_masters         : natural := 2;
      
   constant c_lm32_ram             : natural := 0;
   constant c_lm32_msi_ctrl        : natural := 1;
   constant c_lm32_cpu_info        : natural := 2;
   constant c_lm32_sys_time        : natural := 3;
   constant c_lm32_atomic          : natural := 4;
   constant c_lm32_prioq           : natural := 5;
   constant c_lm32_clu_bridge      : natural := 6;
   constant c_lm32_world_bridge    : natural := 7;

   
   signal   s_cpu_info,
            s_sys_time,
            s_atomic               : t_wishbone_master_in;
               
    
   
   -- slightly different version of Wesley's function, accepts an optional fixed address
   function f_sdb_auto_fixed_bridge(bridge : t_sdb_bridge; enable : boolean := true; adr : t_wishbone_address := (others => '0'))
    return t_sdb_record
   is
    variable v_empty : t_sdb_record := (others => '0');
   begin
    v_empty(7 downto 0) := (others => '1');
    if enable then
        return f_sdb_embed_bridge(bridge, adr);
    else
      return v_empty;
    end if;
   end f_sdb_auto_fixed_bridge;

   function f_sdb_auto_fixed_device(device : t_sdb_device; enable : boolean := true; adr : t_wishbone_address := (others => '0'))
    return t_sdb_record
  is
    variable v_empty : t_sdb_record := (others => '0');
  begin
    v_empty(7 downto 0) := (others => '1');
    if enable then
      return f_sdb_embed_device(device, adr);
    else
      return v_empty;
    end if;
  end f_sdb_auto_fixed_device;
   
   constant c_lm32_layout : t_sdb_record_array(c_lm32_slaves-1 downto 0) :=
   (c_lm32_ram                => f_sdb_embed_device(f_xwb_dpram_userlm32(g_size),   x"00000000"), -- this CPU's RAM
    c_lm32_msi_ctrl           => f_sdb_embed_device(c_irq_slave_ctrl_sdb,  x"3FFFFC00"),
    c_lm32_cpu_info           => f_sdb_embed_device(c_cpu_info_sdb,        x"3FFFFEE0"),
    c_lm32_sys_time           => f_sdb_embed_device(c_sys_time_sdb,        x"3FFFFEF8"),
    c_lm32_atomic             => f_sdb_embed_device(c_atomic_sdb,          x"3FFFFF00"),
    c_lm32_prioq              => f_sdb_auto_fixed_device(c_prio_data_sdb,      g_is_ftm, x"3FFFFFA0"),
    c_lm32_clu_bridge         => f_sdb_auto_fixed_bridge(g_cluster_bridge_sdb, g_is_in_cluster, x"40000000"),
    c_lm32_world_bridge       => f_sdb_embed_bridge(g_world_bridge_sdb,    x"80000000"));
    
   constant c_lm32_sdb_address : t_wishbone_address := x"3FFFE000";
 
   --signals

   signal lm32_idwb_master_in    : t_wishbone_master_in_array(c_lm32_masters-1 downto 0);
   signal lm32_idwb_master_out   : t_wishbone_master_out_array(c_lm32_masters-1 downto 0);
   signal lm32_cb_master_in      : t_wishbone_master_in_array(c_lm32_slaves-1 downto 0);
   signal lm32_cb_master_out     : t_wishbone_master_out_array(c_lm32_slaves-1 downto 0);
   
   signal irq_slaves_out         : t_wishbone_slave_out_array(g_msi_queues-1 downto 0); 
   signal irq_slaves_in          : t_wishbone_slave_in_array(g_msi_queues-1 downto 0);
   --signal irq_timer_master_in    : t_wishbone_master_in;
   --signal irq_timer_master_out   : t_wishbone_master_out;
   signal s_irq : std_logic_vector(31 downto 0);
   
   signal r_tai_8ns_HI : std_logic_vector(31 downto 0);
   signal r_tai_8ns_LO, r_time_freeze_LO : std_logic_vector(31 downto 0);
   signal rst_lm32_n   : std_logic;
   signal r_cyc_atomic : std_logic;
   signal r_cyc, s_ext_prioq_cyc, s_ext_clu_cyc, s_ext_world_cyc : std_logic;
   
begin
   
   -- map external IRQs to MSI queues 1 to n
   irq_slaves_o <= irq_slaves_out(irq_slaves_out'left downto 0);
   irq_slaves_in(irq_slaves_in'left downto 0) <= irq_slaves_i;
   -- map timer interrupt to MSI queue 0
   --irq_slaves_in(0) <= irq_timer_master_out;
   --irq_timer_master_in <= irq_slaves_out(0); 
--------------------------------------------------------------------------------
-- Crossbar
-------------------------------------------------------------------------------- 
   LM32_CON : xwb_sdb_crossbar
   generic map(
      g_num_masters => c_lm32_masters,
      g_num_slaves  => c_lm32_slaves,
      g_registered  => true,
      g_wraparound  => true,
      g_layout      => c_lm32_layout,
      g_sdb_addr    => c_lm32_sdb_address)
   port map(
      clk_sys_i     => clk_sys_i,
      rst_n_i       => rst_n_i,
      -- Master connections (INTERCON is a slave)
      slave_i       => lm32_idwb_master_out,
      slave_o       => lm32_idwb_master_in,
      -- Slave connections (INTERCON is a master)
      master_i      => lm32_cb_master_in,
      master_o      => lm32_cb_master_out);

--******************************************************************************
-- Masters *********************************************************************
--******************************************************************************
-- 0 & 1 - LM32
--------------------------------------------------------------------------------  
   LM32_CORE : xwb_lm32
   generic map(g_profile   => g_profile)
   port map(
      clk_sys_i   => clk_sys_i,
      rst_n_i     => rst_lm32_n,
      irq_i       => s_irq,
      dwb_o       => lm32_idwb_master_out(0),
      dwb_i       => lm32_idwb_master_in(0),
      iwb_o       => lm32_idwb_master_out(1),
      iwb_i       => lm32_idwb_master_in(1));

   rst_lm32_n <= rst_n_i and rst_lm32_n_i;

--******************************************************************************
-- Slaves *********************************************************************
--******************************************************************************
-- DPRAM A side
--------------------------------------------------------------------------------
   DPRAM : xwb_dpram
   generic map(
      g_size                  => g_size,
      g_init_file             => g_init_file,
      g_must_have_init_file   => true,
      g_slave1_interface_mode => PIPELINED,
      g_slave2_interface_mode => PIPELINED,
      g_slave1_granularity    => BYTE,
      g_slave2_granularity    => BYTE)  
   port map(
      clk_sys_i   => clk_sys_i,
      rst_n_i     => rst_n_i,
      slave1_i    => lm32_cb_master_out(c_lm32_ram),
      slave1_o    => lm32_cb_master_in(c_lm32_ram),
      slave2_i    => ram_slave_i,
      slave2_o    => ram_slave_o);


--******************************************************************************
-- MSI-IRQ
--------------------------------------------------------------------------------
   MSI_IRQ: wb_irq_slave 
   GENERIC MAP( g_queues  => g_msi_queues, -- +1 for timer IRQ
                g_depth   => 8)
   PORT MAP (
      clk_i         => clk_sys_i,
      rst_n_i       => rst_n_i,  
           
      irq_slave_o   => irq_slaves_out, 
      irq_slave_i   => irq_slaves_in,
      irq_o         => s_irq(g_msi_queues-1 downto 0),
           
      ctrl_slave_o  => lm32_cb_master_in(c_lm32_msi_ctrl),
      ctrl_slave_i  => lm32_cb_master_out(c_lm32_msi_ctrl));

   s_irq(31 downto g_msi_queues) <= (others => '0');


--******************************************************************************
-- CPU INFO ROM 
--------------------------------------------------------------------------------


   rom_id : process(clk_sys_i)
   variable vIdx : natural;
   begin
    vIdx := c_lm32_cpu_info;
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
         
        s_cpu_info <= ('0', '0', '0', '0', '0', (others => '0'));
      else 
        -- rom is an easy solution for a device that never stalls:
        s_cpu_info.dat <= (others => '0');      
        s_cpu_info.ack <= lm32_cb_master_out(vIdx).cyc and lm32_cb_master_out(vIdx).stb and not lm32_cb_master_out(vIdx).we;
        s_cpu_info.err <= lm32_cb_master_out(vIdx).cyc and lm32_cb_master_out(vIdx).stb and     lm32_cb_master_out(vIdx).we;
         
        if(lm32_cb_master_out(vIdx).cyc = '1' and lm32_cb_master_out(vIdx).stb = '1') then         
           case(to_integer(unsigned(lm32_cb_master_out(vIdx).adr(3 downto 2)))) is
              when 0 => s_cpu_info.dat <= g_cpu_id;
              when 1 => s_cpu_info.dat <= std_logic_vector(to_unsigned(g_msi_queues,32));
              when 2 => s_cpu_info.dat <= std_logic_vector(to_unsigned(g_size*4,32));
              when 3 => if(g_is_in_cluster) then
                           s_cpu_info.dat <= std_logic_vector(to_unsigned(1,32));
                        else
                           s_cpu_info.dat <= (others => '0');
                        end if;
              -- unmapped addresses return error
              when others =>  s_cpu_info.ack <= '0';
                              s_cpu_info.err <= '1';
           end case;
        end if;
      end if;
    end if;
  end process;

  lm32_cb_master_in(c_lm32_cpu_info) <= s_cpu_info;
--  
--******************************************************************************
-- System Time
--------------------------------------------------------------------------------
   sys_time : process(clk_sys_i)
   variable vIdx : natural;
   begin
      vIdx := c_lm32_sys_time;
      if rising_edge(clk_sys_i) then
        if(rst_n_i = '0') then
            s_sys_time <= ('0', '0', '0', '0', '0', (others => '0'));
        else
           -- rom is an easy solution for a device that never stalls:
           s_sys_time.ack <= lm32_cb_master_out(vIdx).cyc and lm32_cb_master_out(vIdx).stb and not lm32_cb_master_out(vIdx).we;
           s_sys_time.err <= lm32_cb_master_out(vIdx).cyc and lm32_cb_master_out(vIdx).stb and     lm32_cb_master_out(vIdx).we;
           s_sys_time.dat <= (others => '0');
           
           r_tai_8ns_HI <= tm_tai8ns_i(63 downto 32);  --register hi and low to reduce load on fan out       
           r_tai_8ns_LO <= tm_tai8ns_i(31 downto 0);
  
           if(lm32_cb_master_out(vIdx).cyc = '1' and lm32_cb_master_out(vIdx).stb = '1') then
              if(lm32_cb_master_out(vIdx).adr(2) = '0') then 
                 s_sys_time.dat   <= r_tai_8ns_HI;
                 r_time_freeze_LO <= r_tai_8ns_LO;
              else  
                 s_sys_time.dat   <= r_time_freeze_LO;
              end if;
           end if;
         end if;   
      end if;
   end process;  

   lm32_cb_master_in(c_lm32_sys_time) <= s_sys_time;
--    
----******************************************************************************
---- Atomic Cycle Line Control
----------------------------------------------------------------------------------
   atm : process(clk_sys_i)
   variable vIdx : natural;
   begin
    vIdx := c_lm32_atomic;
    if rising_edge(clk_sys_i) then
      if((rst_lm32_n and rst_n_i) = '0') then
         r_cyc_atomic <= '0';
           s_atomic     <= ('0', '0', '0', '0', '0', (others => '0'));  
      else
         r_cyc <= s_ext_world_cyc or s_ext_clu_cyc; -- Nr. 6 ext if cycle line  
         -- rom is an easy solution for a device that never stalls:
         s_atomic.dat(31 downto 1)   <= (others => '0');
         s_atomic.dat(0)             <= r_cyc_atomic;      
         s_atomic.ack                <= lm32_cb_master_out(vIdx).cyc and lm32_cb_master_out(vIdx).stb;
        
         if(lm32_cb_master_out(vIdx).cyc = '1' and lm32_cb_master_out(vIdx).stb = '1') then         
            if( lm32_cb_master_out(vIdx).we = '1') then
               r_cyc_atomic <= lm32_cb_master_out(vIdx).dat(0);
            end if;
         end if;
      end if;
    end if;
  end process;
  
  lm32_cb_master_in(c_lm32_atomic) <= s_atomic; 


--******************************************************************************
-- Priority Queue Interface
--------------------------------------------------------------------------------
   
   s_ext_prioq_cyc <= lm32_cb_master_out(c_lm32_prioq).cyc or (r_cyc and r_cyc_atomic);
   
   prioq_master_o.cyc <= s_ext_clu_cyc; -- atomic does not raise cyc, but keeps it HI. 
   prioq_master_o.stb <= lm32_cb_master_out(c_lm32_prioq).stb;                             -- write LO to r_cyc_atomic to deassert
   prioq_master_o.we  <= lm32_cb_master_out(c_lm32_prioq).we;
   prioq_master_o.sel <= lm32_cb_master_out(c_lm32_prioq).sel;
   prioq_master_o.adr <= lm32_cb_master_out(c_lm32_prioq).adr;
   prioq_master_o.dat <= lm32_cb_master_out(c_lm32_prioq).dat;

   lm32_cb_master_in(c_lm32_prioq)   <= prioq_master_i;

--******************************************************************************
-- Cluster Interface
--------------------------------------------------------------------------------
   
   s_ext_clu_cyc <= lm32_cb_master_out(c_lm32_clu_bridge).cyc or (r_cyc and r_cyc_atomic);
   
   clu_master_o.cyc <= s_ext_clu_cyc; -- atomic does not raise cyc, but keeps it HI. 
   clu_master_o.stb <= lm32_cb_master_out(c_lm32_clu_bridge).stb;                             -- write LO to r_cyc_atomic to deassert
   clu_master_o.we  <= lm32_cb_master_out(c_lm32_clu_bridge).we;
   clu_master_o.sel <= lm32_cb_master_out(c_lm32_clu_bridge).sel;
   clu_master_o.adr <= lm32_cb_master_out(c_lm32_clu_bridge).adr;
   clu_master_o.dat <= lm32_cb_master_out(c_lm32_clu_bridge).dat;

   lm32_cb_master_in(c_lm32_clu_bridge)   <= clu_master_i;

   
--******************************************************************************
-- World Interface
------------------------------------------------------------------------------
   
   s_ext_world_cyc <= lm32_cb_master_out(c_lm32_world_bridge).cyc or (r_cyc and r_cyc_atomic);
   
   world_master_o.cyc <= s_ext_world_cyc; -- atomic does not raise cyc, but keeps it HI. 
   world_master_o.stb <= lm32_cb_master_out(c_lm32_world_bridge).stb;                             -- write LO to r_cyc_atomic to deassert
   world_master_o.we  <= lm32_cb_master_out(c_lm32_world_bridge).we;
   world_master_o.sel <= lm32_cb_master_out(c_lm32_world_bridge).sel;
   world_master_o.adr <= lm32_cb_master_out(c_lm32_world_bridge).adr;
   world_master_o.dat <= lm32_cb_master_out(c_lm32_world_bridge).dat;

   lm32_cb_master_in(c_lm32_world_bridge)   <= world_master_i;

end rtl;
  
