set_property C_CLK_INPUT_FREQ_HZ 100000000 [get_debug_cores inst_shell/inst_debug_bridge_dynamic/inst/xsdbm]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores inst_shell/inst_debug_bridge_dynamic/inst/xsdbm]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores inst_shell/inst_debug_bridge_dynamic/inst/xsdbm]
connect_debug_port inst_shell/inst_debug_bridge_dynamic/inst/xsdbm [get_nets inst_shell/dclk]

