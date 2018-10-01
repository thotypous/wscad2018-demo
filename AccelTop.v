module AccelTop (

	//////////// CLOCK //////////
	input 		          		CLOCK_50,
	input 		          		CLOCK2_50,
	input 		          		CLOCK3_50,

    //////////// KEY (Active Low) ///////////
    input            [3:0]      KEY,

	 //////////// LEDG ////////
	 output          [8:0]   LEDG,

	 //////////// LEDR
	 output          [17:0]  LEDR,

	//////////// PCIe //////////
	input 		          		PCIE_PERST_N,
	input 		          		PCIE_REFCLK_P,
	input 		     [0:0]		PCIE_RX_P,
	output		     [0:0]		PCIE_TX_P,
	output		          		PCIE_WAKE_N,

	//////////// GPIO, GPIO connect to GPIO Default //////////
	inout 		     [35:0]		GPIO,

	//////////// Fan Control //////////
	inout 		          		FAN_CTRL
);

    wire [ 4:0] pcie_reconfig_fromgxb_0_data;
    wire [ 3:0] pcie_reconfig_togxb_data;
	 wire        pcie_reconfig_clk;

    altgx_reconfig gxreconf0 (
        .reconfig_clk(pcie_reconfig_clk),
        .reconfig_fromgxb(pcie_reconfig_fromgxb_0_data),
        .reconfig_togxb(pcie_reconfig_togxb_data)
    );

    AccelSystem accelsys0 (
	     .clk_clk                                   (CLOCK_50),
		  .reset_reset_n										(KEY[0]),
        .pcie_hard_ip_0_refclk_export              (PCIE_REFCLK_P),
        .pcie_hard_ip_0_pcie_rstn_export           (PCIE_PERST_N),
        .pcie_hard_ip_0_powerdown_pll_powerdown    (PCIE_WAKE_N),
        .pcie_hard_ip_0_powerdown_gxb_powerdown    (PCIE_WAKE_N),
        .pcie_hard_ip_0_rx_in_rx_datain_0          (PCIE_RX_P[0]),
        .pcie_hard_ip_0_tx_out_tx_dataout_0        (PCIE_TX_P[0]),
        .pcie_hard_ip_0_reconfig_fromgxb_0_data    (pcie_reconfig_fromgxb_0_data),
		  .pcie_hard_ip_0_reconfig_togxb_data        (pcie_reconfig_togxb_data),
		  .pcie_hard_ip_0_reconfig_gxbclk_clk        (pcie_reconfig_clk),
		  .altpll_0_c1_clk                           (pcie_reconfig_clk),
    );
	 
	//////////// FAN Control //////////
	assign FAN_CTRL = 1'bz; // turn on FAN

	assign LEDR = 0;
	assign LEDG = 0;

endmodule

