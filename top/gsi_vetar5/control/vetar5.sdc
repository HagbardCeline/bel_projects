derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

# Cut the clock domains from each other
set_clock_groups -asynchronous                              \
 -group { altera_reserved_tck                             } \
 -group { clk_20m_vcxo_i       main|\dmtd_a5:dmtd_inst|*  } \
 -group { clk_osc_i            main|\sys_a5:sys_inst|*    } \
 -group { clk_125m_wrpll_i[0]  main|\ref_a5:ref_inst|*      \
          main|\phy_a5:phy|*.cdr_refclk*                    \
          main|\phy_a5:phy|*.cmu_pll.*                      \
          main|\phy_a5:phy|*|av_tx_pma|*                    \
          main|\phy_a5:phy|*|inst_av_pcs|*|tx*            } \
 -group { main|\phy_a5:phy|*|clk90bdes                      \
          main|\phy_a5:phy|*|clk90b                         \
          main|\phy_a5:phy|*|rcvdclkpma                   } 

# cut: wb sys <=> wb flash   (different frequencies and using xwb_clock_crossing)
set_false_path -from [get_clocks {main|\sys_a5:sys_inst|*|general[0].*}] -to [get_clocks {main|\sys_a5:sys_inst|*|general[3].*}]
set_false_path -from [get_clocks {main|\sys_a5:sys_inst|*|general[3].*}] -to [get_clocks {main|\sys_a5:sys_inst|*|general[0].*}]
# cut: wb sys <=> wb display (different frequencies and using xwb_clock_crossing)
set_false_path -from [get_clocks {main|\sys_a5:sys_inst|*|general[0].*}] -to [get_clocks {main|\sys_a5:sys_inst|*|general[1].*}]
set_false_path -from [get_clocks {main|\sys_a5:sys_inst|*|general[1].*}] -to [get_clocks {main|\sys_a5:sys_inst|*|general[0].*}]
# cut: wr-ref <=> butis
set_false_path -from [get_clocks {main|\ref_a5:ref_inst|*|counter[0].*}] -to [get_clocks {main|\ref_a5:ref_inst|*|counter[1].*}]
set_false_path -from [get_clocks {main|\ref_a5:ref_inst|*|counter[1].*}] -to [get_clocks {main|\ref_a5:ref_inst|*|counter[0].*}]
