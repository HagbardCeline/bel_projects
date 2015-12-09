--! @file        ftm_lm32_cluster.vhd
--  DesignUnit   ftm_lm32_cluster
--! @author      M. Kreider <>
--! @date        25/02/2014
--! @version     0.0.3
--! @copyright   2015 GSI Helmholtz Centre for Heavy Ion Research GmbH
--!

--! @brief LM32 Cluster. Instantiates desired number of LM32 CPUs + Periphery 
--!
--! Cluster Info ROM Registers:
--! 0x00 Number of Cores
--! 0x04 MSI Endpoints per Core
--! 0x08 RAM size per Core
--! 0x0C Cluster shared RAM size
--! 0x10 Configured as DataMaster?
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
use work.prio_pkg.all;
use work.etherbone_pkg.all;

entity ftm_lm32_cluster is
generic(g_is_ftm        : boolean := false;
        g_cores         : natural := 1;
        g_ram_per_core  : natural := 32768/4;
        g_shared_mem    : natural := 32768/4;
        g_msi_per_core  : natural := 2;
        g_profile       : string  := "medium_icache_debug";
        g_init_files    : string;   
        g_world_bridge_sdb    : t_sdb_bridge                      -- superior crossbar         
   );
port(
   clk_ref_i      : in  std_logic;
   rst_ref_n_i    : in  std_logic;
   
   clk_sys_i      : in  std_logic;
   rst_sys_n_i    : in  std_logic;
   rst_lm32_n_i   : in  std_logic_vector(g_cores-1 downto 0); 

   tm_tai8ns_sys_i : in std_logic_vector(63 downto 0);
   tm_tai8ns_ref_i : in std_logic_vector(63 downto 0);
	
   irq_slave_o    : out t_wishbone_slave_out; 
   irq_slave_i    : in  t_wishbone_slave_in;

   -- optional cluster ctrl slave interface
   cluster_slave_o  : out t_wishbone_slave_out; 
   cluster_slave_i  : in  t_wishbone_slave_in := ('0', '0', x"00000000", x"F", '0', x"00000000");

   -- optional FTM ebm queue master interface
   ftm_queue_master_o : out t_wishbone_master_out; 
   ftm_queue_master_i : in  t_wishbone_master_in := ('0', '0', '0', '0', '0', x"00000000"); 
            
   master_o   : out t_wishbone_master_out; 
   master_i   : in  t_wishbone_master_in  
);
end ftm_lm32_cluster;

architecture rtl of ftm_lm32_cluster is 

   --**************************************************************************--
   -- WORLD CROSSBAR. mux CPUs to world IF (not an SDB crossbar!)
   ------------------------------------------------------------------------------
   constant c_world_slaves  : natural := 1;
   constant c_world_masters : natural := g_cores;
   signal world_cbar_masterport_in   : t_wishbone_master_in_array  (c_world_slaves-1 downto 0);
   signal world_cbar_masterport_out  : t_wishbone_master_out_array (c_world_slaves-1 downto 0);
   signal world_cbar_slaveport_in    : t_wishbone_slave_in_array   (c_world_masters-1 downto 0);
   signal world_cbar_slaveport_out   : t_wishbone_slave_out_array  (c_world_masters-1 downto 0);

      --**************************************************************************--
   -- IRQ CROSSBAR
   ------------------------------------------------------------------------------
   constant c_irq_slaves   : natural := g_cores*g_msi_per_core;  -- all but one irq queue per lm32 are connected here
   constant c_irq_masters  : natural := 2;                  -- eca action queues, interlocks
   constant c_irq_layout_aux  : t_sdb_record_array(c_irq_slaves-1 downto 0) := f_cluster_irq_sdb(g_cores, g_msi_per_core);
   constant c_irq_sdb_address : t_wishbone_address := f_sdb_auto_sdb(c_irq_layout_aux);
   constant c_irq_layout      : t_sdb_record_array(c_irq_slaves-1 downto 0) := f_sdb_auto_layout(c_irq_layout_aux);
   
   signal irq_cbar_masterport_in    : t_wishbone_master_in_array  (c_irq_slaves-1 downto 0);
   signal irq_cbar_masterport_out   : t_wishbone_master_out_array (c_irq_slaves-1 downto 0);
   signal irq_cbar_slaveport_in     : t_wishbone_slave_in_array   (c_irq_masters-1 downto 0);
   signal irq_cbar_slaveport_out    : t_wishbone_slave_out_array  (c_irq_masters-1 downto 0);

   --**************************************************************************--
   -- RAM CROSSBAR
   ------------------------------------------------------------------------------
   constant c_ram_slaves      : natural := g_cores;  
   constant c_ram_masters     : natural := 1;       
   constant c_ram_layout_aux  : t_sdb_record_array(c_ram_slaves-1 downto 0) := f_cluster_ram_sdb(c_ram_slaves, g_ram_per_core);
   constant c_ram_sdb_address : t_wishbone_address := f_sdb_auto_sdb(c_ram_layout_aux);
   constant c_ram_layout      : t_sdb_record_array(c_ram_slaves-1 downto 0) := f_sdb_auto_layout(c_ram_layout_aux);
   signal ram_cbar_masterport_in    : t_wishbone_master_in_array  (c_ram_slaves-1 downto 0);
   signal ram_cbar_masterport_out   : t_wishbone_master_out_array (c_ram_slaves-1 downto 0);
   signal ram_cbar_slaveport_in     : t_wishbone_slave_in_array   (c_ram_masters-1 downto 0);
   signal ram_cbar_slaveport_out    : t_wishbone_slave_out_array  (c_ram_masters-1 downto 0);

   --**************************************************************************--
   -- LM32 CROSSBAR. this is the main crossbar of the FTM
   ------------------------------------------------------------------------------
   --
   -- <--- World <--- All LM32s master ports 
   --
   -- ---> LM32 <--- All LM32s Cluster ports
   --       |
   --       |---> RAM ---> All LM32 RAM ports
   --       |---> IRQ ---> All LM32 IRQ ports 
   --             ^
   -- ---->-------|
   
   --constant c_clu_slaves    -> pkg  : natural := 7; 
   constant c_clu_masters     : natural := g_cores+1; -- lm32's + top
   constant c_cluster_ext_if  : natural := c_clu_masters-1; -- last master is ext if
   
   constant c_clu_layout_aux  : t_sdb_record_array(c_clu_slaves-1 downto 0)
   := f_cluster_main_sdb(c_irq_layout_aux, c_ram_layout_aux, g_shared_mem, g_is_ftm);
   constant c_clu_sdb_address : t_wishbone_address := f_sdb_auto_sdb(c_clu_layout_aux);
   constant c_clu_layout      : t_sdb_record_array(c_clu_slaves-1 downto 0)
   := f_sdb_auto_layout(c_clu_layout_aux);
   
   constant c_clu_bridge_sdb  : t_sdb_bridge       
   := f_lm32_main_bridge_sdb(g_cores, g_msi_per_core, g_ram_per_core, g_shared_mem, g_is_ftm);
   
   signal clu_cbar_masterport_in   : t_wishbone_master_in_array  (c_clu_slaves-1 downto 0);
   signal clu_cbar_masterport_out  : t_wishbone_master_out_array (c_clu_slaves-1 downto 0);
   signal clu_cbar_slaveport_in    : t_wishbone_slave_in_array   (c_clu_masters-1 downto 0);
   signal clu_cbar_slaveport_out   : t_wishbone_slave_out_array  (c_clu_masters-1 downto 0);

   signal clu_master_in   : t_wishbone_master_in_array  (c_clu_slaves-1 downto 0);
   signal clu_master_out  : t_wishbone_master_out_array (c_clu_slaves-1 downto 0); 
   ------------------------------------------------------------------------------
   
   signal s_rst_lm32_n,
          r_rst_lm32_n0,
          r_rst_lm32_n1 : std_logic_vector(g_cores-1 downto 0);            
   signal s_clu_info   : t_wishbone_master_in;

   signal s_prio_data_in  : t_wishbone_master_in;
   signal s_prio_data_out : t_wishbone_master_out; 

   signal prioq_slaves_in    : t_wishbone_slave_in_array(g_cores-1 downto 0);
   signal prioq_slaves_out   : t_wishbone_slave_out_array(g_cores-1 downto 0); 

   signal prioq_masters_in    : t_wishbone_master_in_array(g_cores-1 downto 0);
   signal prioq_masters_out   : t_wishbone_master_out_array(g_cores-1 downto 0);  


   begin

   G1: for I in 0 to g_cores-1 generate
      --instantiate an ftm-lm32 (LM32 core with its own DPRAM and 2..n msi queues)
      LM32 : ftm_lm32
      generic map(g_cpu_id                         => x"BBEE" & std_logic_vector(to_unsigned(I, 16)),
                  g_size                           => g_ram_per_core,
                  g_is_ftm                         => g_is_ftm,  
                  g_is_in_cluster                  => true,
                  g_cluster_bridge_sdb             => c_clu_bridge_sdb,
                  g_world_bridge_sdb               => g_world_bridge_sdb,
                  g_profile                        => g_profile,
                  g_init_file                      => f_substr(g_init_files, I, ';'),
                  g_msi_queues                     => g_msi_per_core) -- 1 for inter CPU communication
      port map(clk_sys_i      => clk_ref_i,
               rst_n_i        => rst_ref_n_i,
               rst_lm32_n_i   => s_rst_lm32_n(I),

               tm_tai8ns_i    => tm_tai8ns_ref_i,            
               
               prioq_master_o => prioq_masters_out (I),
               prioq_master_i => prioq_masters_in (I),  

               clu_master_o   => clu_master_out (I), 
               clu_master_i   => clu_master_in (I),
               --LM32               
               world_master_o => world_cbar_slaveport_in  (I),
               world_master_i => world_cbar_slaveport_out (I), 
               -- MSI
               irq_slaves_o   => irq_cbar_masterport_in ((I+1)*g_msi_per_core-1 downto I*g_msi_per_core),
               irq_slaves_i   => irq_cbar_masterport_out ((I+1)*g_msi_per_core-1 downto I*g_msi_per_core),       
               --2nd RAM port               
               ram_slave_o    => ram_cbar_masterport_in(I),                      
               ram_slave_i    => ram_cbar_masterport_out(I));
   
               -------------------------------------------------------------------------------------------------------------------------------------- 
         

          lm32_prio : xwb_register_link
          port map(
            clk_sys_i     => clk_ref_i,
            rst_n_i       => rst_ref_n_i,
            slave_i       => prioq_masters_out (I),
            slave_o       => prioq_masters_in (I),
            master_i      => prioq_slaves_out(I),
            master_o      => prioq_slaves_in (I)
          );

          lm32_clu : xwb_register_link
          port map(
            clk_sys_i     => clk_ref_i,
            rst_n_i       => rst_ref_n_i,
            slave_i       => clu_master_out (I),
            slave_o       => clu_master_in (I),
            master_i      => clu_cbar_slaveport_out (I),
            master_o      => clu_cbar_slaveport_in (I)
          );


      end generate G1;  

-- must be transparent, NOT SDB
  WORLD_CON : xwb_crossbar 
  generic map(
    g_num_masters => c_world_masters,
    g_num_slaves  => c_world_slaves,
    g_registered  => true,
    -- Address of the slaves connected
    g_address     => (0 => x"00000000"),
    g_mask        => (0 => x"00000000"))
  port map(
     clk_sys_i     => clk_ref_i,
     rst_n_i       => rst_ref_n_i,
        -- Master connections (INTERCON is a slave)
     slave_i       => world_cbar_slaveport_in,
     slave_o       => world_cbar_slaveport_out,
     -- Slave connections (INTERCON is a master)
     master_i      => world_cbar_masterport_in,
     master_o      => world_cbar_masterport_out);

   -- 1st slave is external world IF
   -- sync to SYS domain
   world_ref2sys : xwb_clock_crossing
   port map(
      -- Slave control port
      slave_clk_i    => clk_ref_i,
      slave_rst_n_i  => rst_ref_n_i,
      slave_i        => world_cbar_masterport_out(0),
      slave_o        => world_cbar_masterport_in(0),
      -- Master reader port
      master_clk_i   => clk_sys_i,
      master_rst_n_i => rst_sys_n_i,
      master_i       => master_i,
      master_o       => master_o);
   
   CLUSTER_CON : xwb_sdb_crossbar
   generic map(
     g_num_masters => c_clu_masters,
     g_num_slaves  => c_clu_slaves,
     g_registered  => true,
     g_wraparound  => true,
     g_layout      => c_clu_layout,
     g_sdb_addr    => c_clu_sdb_address)
   port map(
     clk_sys_i     => clk_ref_i,
     rst_n_i       => rst_ref_n_i,
     -- Master connections (INTERCON is a slave)
     slave_i       => clu_cbar_slaveport_in,
     slave_o       => clu_cbar_slaveport_out,
     -- Slave connections (INTERCON is a master)
     master_i      => clu_cbar_masterport_in,
     master_o      => clu_cbar_masterport_out);

   -- <--- World <--- All LM32s master ports 
   --
   -- ---> CLU <--- All LM32s Cluster ports
   --       |
   --       |---> RAM ---> All LM32 RAM ports
   --       |---> IRQ ---> All LM32 IRQ ports 
   --             ^
   -- ---->-------|

   -- the first n masters are the lm32 cores. c_cluster_slave_if is the outside world and master to LM32_CON
   -- sync to REF domain
   
   clu_sys2ref : xwb_clock_crossing
   port map(
      -- Slave control port
      slave_clk_i    => clk_sys_i,
      slave_rst_n_i  => rst_sys_n_i,
      slave_i        => cluster_slave_i,
      slave_o        => cluster_slave_o,
      -- Master reader port
      master_clk_i   => clk_ref_i,
      master_rst_n_i => rst_ref_n_i,
      master_i       => clu_cbar_slaveport_out(c_cluster_ext_if),
      master_o       => clu_cbar_slaveport_in(c_cluster_ext_if));


   IRQ_CON : xwb_sdb_crossbar
   generic map(
     g_num_masters => c_irq_masters,
     g_num_slaves  => c_irq_slaves,
     g_registered  => true,
     g_wraparound  => true,
     g_layout      => c_irq_layout,
     g_sdb_addr    => c_irq_sdb_address)
   port map(
     clk_sys_i     => clk_ref_i,
     rst_n_i       => rst_ref_n_i,
     -- Master connections (INTERCON is a slave)
     slave_i       => irq_cbar_slaveport_in,
     slave_o       => irq_cbar_slaveport_out,
     -- Slave connections (INTERCON is a master)
     master_i      => irq_cbar_masterport_in,
     master_o      => irq_cbar_masterport_out);

   -- 1st master is cluster crossbar
   clu2irq : xwb_register_link
    port map(
      clk_sys_i     => clk_ref_i,
      rst_n_i       => rst_ref_n_i,
      slave_i       => clu_cbar_masterport_out(c_clu_irq_bridge),
      slave_o       => clu_cbar_masterport_in(c_clu_irq_bridge),
      master_i      => irq_cbar_slaveport_out(0),
      master_o      => irq_cbar_slaveport_in(0));


--   clu_cbar_masterport_in(c_clu_irq_bridge)  <= irq_cbar_slaveport_out(0);                           
--   irq_cbar_slaveport_in(0)                  <= clu_cbar_masterport_out(c_clu_irq_bridge);

   

   -- 2nd master is external irq slave if
   -- sync from SYS to REF domain
   
   irq_sys2ref : xwb_clock_crossing
   port map(
      -- Slave control port
      slave_clk_i    => clk_sys_i,
      slave_rst_n_i  => rst_sys_n_i,
      slave_i        => irq_slave_i,
      slave_o        => irq_slave_o,
      -- Master reader port
      master_clk_i   => clk_ref_i,
      master_rst_n_i => rst_ref_n_i,
      master_i       => irq_cbar_slaveport_out(1),
      master_o       => irq_cbar_slaveport_in(1));


   RAM_CON : xwb_sdb_crossbar
   generic map(
     g_num_masters => c_ram_masters,
     g_num_slaves  => c_ram_slaves,
     g_registered  => true,
     g_wraparound  => true,
     g_layout      => c_ram_layout,
     g_sdb_addr    => c_ram_sdb_address)
   port map(
     clk_sys_i     => clk_ref_i,
     rst_n_i       => rst_ref_n_i,
        -- Master connections (INTERCON is a slave)
     slave_i       => ram_cbar_slaveport_in,
     slave_o       => ram_cbar_slaveport_out,
     -- Slave connections (INTERCON is a master)
     master_i      => ram_cbar_masterport_in,
     master_o      => ram_cbar_masterport_out);

   -- 1st master is cluster crossbar
   clu2ram : xwb_register_link
    port map(
      clk_sys_i     => clk_ref_i,
      rst_n_i       => rst_ref_n_i,
      slave_i       => clu_cbar_masterport_out(c_clu_ram_bridge),
      slave_o       => clu_cbar_masterport_in(c_clu_ram_bridge),
      master_i      => ram_cbar_slaveport_out(0),
      master_o      => ram_cbar_slaveport_in(0));
	

--   clu_cbar_masterport_in(c_clu_ram_bridge)  <= ram_cbar_slaveport_out(0);                           
--   ram_cbar_slaveport_in(0)                  <= clu_cbar_masterport_out(c_clu_ram_bridge);  

--------------------------------------------------------------------------------
-- Slave - CLUSTER INFO ROM 
--------------------------------------------------------------------------------  
 

   
   cluster_info_rom : process(clk_ref_i)
   variable vIdx : natural;
   begin
    vIdx := c_clu_cluster_info;
    if rising_edge(clk_ref_i) then
      if(rst_ref_n_i = '0') then
        s_clu_info <= ('0', '0', '0', '0', '0', (others => '0'));
      else 
        -- rom is an easy solution for a device that never stalls:
        s_clu_info.dat <= (others => '0');      
        -- read only
        s_clu_info.ack <= clu_cbar_masterport_out(vIdx).cyc and clu_cbar_masterport_out(vIdx).stb and not   clu_cbar_masterport_out(vIdx).we;
        s_clu_info.err <= clu_cbar_masterport_out(vIdx).cyc and clu_cbar_masterport_out(vIdx).stb and       clu_cbar_masterport_out(vIdx).we;
         
        if(clu_cbar_masterport_out(vIdx).cyc = '1' and clu_cbar_masterport_out(vIdx).stb = '1') then         
           case(to_integer(unsigned(clu_cbar_masterport_out(vIdx).adr(4 downto 2)))) is
              when 0 => s_clu_info.dat <= std_logic_vector(to_unsigned(g_cores,32));
              when 1 => s_clu_info.dat <= std_logic_vector(to_unsigned(g_msi_per_core,32));
              when 2 => s_clu_info.dat <= std_logic_vector(to_unsigned(g_ram_per_core*4,32));
              when 3 => s_clu_info.dat <= std_logic_vector(to_unsigned(g_shared_mem*4,32));
              when 4 => if(g_is_ftm) then
                           s_clu_info.dat <= std_logic_vector(to_unsigned(1,32));
                        else
                           s_clu_info.dat <= (others => '0');
                        end if;
              -- unmapped addresses return error
              when others =>  s_clu_info.ack <= '0';
                              s_clu_info.err <= '1';
           end case;
        end if;
      end if;
    end if;
  end process;

  clu_cbar_masterport_in(c_clu_cluster_info) <= s_clu_info;

   
   --------------------------------------------------------------------------------
-- SHARED MEMORY
--------------------------------------------------------------------------------   
   SHARED_MEM : xwb_dpram
   generic map(
      g_size                  => g_shared_mem,
      g_init_file             => "",
      g_must_have_init_file   => false,
      g_slave1_interface_mode => PIPELINED,
      g_slave2_interface_mode => PIPELINED,
      g_slave1_granularity    => BYTE,
      g_slave2_granularity    => BYTE)  
   port map(
      clk_sys_i   => clk_ref_i,
      rst_n_i     => rst_ref_n_i,
      slave1_i    => clu_cbar_masterport_out(c_clu_shared_mem),
      slave1_o    => clu_cbar_masterport_in(c_clu_shared_mem),
      slave2_i    => c_dummy_slave_in,
      slave2_o    => open);


--******************************************************************************
-- FTM Prio Queue
--------------------------------------------------------------------------------
 prioQ : if(g_is_ftm) generate  
   prio_queue : prio
     generic map(
      g_ebm_bits    => f_hi_adr_bits(c_ebm_sdb),
      g_depth       => 16,    
      g_num_masters => g_cores
    )
    port map(
      clk_i         => clk_ref_i,                                        
      rst_n_i       => rst_ref_n_i,                                          

      time_i        => tm_tai8ns_ref_i,   

      ctrl_i        => clu_cbar_masterport_out(c_clu_prioq_ctrl),
      ctrl_o        => clu_cbar_masterport_in(c_clu_prioq_ctrl),
      slaves_i      => prioq_slaves_in,
      slaves_o      => prioq_slaves_out,
      master_o      => s_prio_data_out,
      master_i      => s_prio_data_in
      
    );
  end generate;

	 -- sync from REF to SYS domain
  priossrc_ref2sys : xwb_clock_crossing
   port map(
      -- Slave control port
      slave_clk_i    => clk_ref_i,
      slave_rst_n_i  => rst_ref_n_i,
      slave_i        => s_prio_data_out,
      slave_o        => s_prio_data_in,
      -- Master reader port
      master_clk_i   => clk_sys_i,
      master_rst_n_i => rst_sys_n_i,
      master_i       => ftm_queue_master_i,
      master_o       => ftm_queue_master_o
  );

   sync_individual_resets : process(clk_ref_i)
   begin
      -- no need to sync vector, just individual bits.
      -- CPU's shouldn't rely on simultaneous reset anyway
      if rising_edge(clk_ref_i) then
         r_rst_lm32_n0 <= rst_lm32_n_i;
         r_rst_lm32_n1 <= r_rst_lm32_n0;
      end if;
   end process;  

   s_rst_lm32_n <= r_rst_lm32_n1;
      
 
  end architecture rtl;
