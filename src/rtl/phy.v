/*****************************************************************
* Title     : Ethernet physical layer (100BASE-FX)
* Date      : 2020/12/28
* Design    : kingyo
******************************************************************/
module phy (
    input   wire            i_fclk,     // 375MHz
    input   wire            i_clk,      // 125MHz
    input   wire            i_lclk,     // 25MHz
    input   wire            i_res_n,

    // TX
    input   wire    [3:0]   i_mii_tx_data,
    input   wire            i_mii_tx_en,

    // RX
    output  reg     [3:0]   o_mii_rx_data,
    output  reg             o_mii_rx_dv,

    // Clock output
    output  wire            o_rcv_clk25m,
    output  wire            o_rcv_clk125m,

    // SFP
    input   wire            i_sfp_los,
    input   wire            i_sfp_rx,
    output  wire            o_sfp_tx
);

    wire    w_rcv_clk25m;
    wire    w_rcv_clk125m;

    //==================================================================
    // Tx Module(4b5b + Serializer)
    //==================================================================
    serialTx serialTx (
        .i_clk125m ( w_rcv_clk125m ),
        .i_res_n ( i_res_n ),
        .i_mii_clk ( w_rcv_clk25m ),
        .i_mii_tx_en ( i_mii_tx_en ),
        .i_mii_txd ( i_mii_tx_data[3:0] ),
        .o_sdata ( o_sfp_tx )
    );

    //==================================================================
    // Rx Module
    //==================================================================
    // Clock data recovery
    wire    [4:0]   w_5b_data; 
    cdr cdr (
        .i_clk ( i_fclk ),              // 375MHz
        .i_res_n ( i_res_n ),           // Reset
        .i_rxdata ( i_sfp_rx ),         // Serial data input
        .o_data ( w_5b_data ),          // Parallel Data
        .o_rclk125m ( w_rcv_clk125m ),  // 125MHz Recovery CLK
        .o_rclk25m ( w_rcv_clk25m )     // 25MHz Recovery CLK
    );

    // Detect Start of Stream Delimiter(J/K)
    reg     [14:0]  r_15b_shift;
    reg             r_jk_det;
    reg             r_jk_det_ff1;
    reg             r_jk_det_ff2;
    always @(posedge w_rcv_clk25m) begin
        r_15b_shift <= {r_15b_shift[9:0], w_5b_data[4:0]};
    end
    wire    w_jk_det0 = r_15b_shift[14:5] == 10'b11000_10001;
    wire    w_jk_det1 = r_15b_shift[13:4] == 10'b11000_10001;
    wire    w_jk_det2 = r_15b_shift[12:3] == 10'b11000_10001;
    wire    w_jk_det3 = r_15b_shift[11:2] == 10'b11000_10001;
    wire    w_jk_det4 = r_15b_shift[10:1] == 10'b11000_10001;
    always @(posedge w_rcv_clk25m) begin
        r_jk_det <= w_jk_det0 | w_jk_det1 | w_jk_det2 | w_jk_det3 | w_jk_det4;
        r_jk_det_ff1 <= r_jk_det;
        r_jk_det_ff2 <= r_jk_det_ff1;
    end

    // Word Alignment
    reg     [1:0]   r_bit_pos;
    always @(posedge w_rcv_clk25m or negedge i_res_n) begin
        if (~i_res_n) begin
            r_bit_pos <= 2'd0;
        end else begin
            if (w_jk_det0) r_bit_pos <= 2'd0;
            if (w_jk_det1) r_bit_pos <= 2'd1;
            if (w_jk_det2) r_bit_pos <= 2'd2;
            if (w_jk_det3) r_bit_pos <= 2'd3;
        end
    end

    wire    [4:0]   w_5b_data_posfix = r_bit_pos == 2'd0 ? r_15b_shift[14:10] :  // w_jk_det0
                                       r_bit_pos == 2'd1 ? r_15b_shift[13: 9] :  // w_jk_det1
                                       r_bit_pos == 2'd2 ? r_15b_shift[12: 8] :  // w_jk_det2
                                       r_bit_pos == 2'd3 ? r_15b_shift[11: 7] :  // w_jk_det3
                                                           r_15b_shift[10: 6];   // w_jk_det4

    // Detect End of Stream Delimiter(T/R)
    reg     [4:0]   r_5b_ff;
    wire            w_tr_det;
    always @(posedge w_rcv_clk25m) begin
        r_5b_ff <= w_5b_data_posfix[4:0];
    end
    assign w_tr_det = ({r_5b_ff[4:0], w_5b_data_posfix[4:0]} == 10'b01101_00111);

    // Decode 4b5b
    wire    [3:0]   w_4b_data;
    dec4b5b dec4b5b (
        .i_data ( w_5b_data_posfix[4:0] ),
        .o_data ( w_4b_data )
    );

    // LOS Signal
    reg     [1:0]   r_sfp_los;
    always @(posedge w_rcv_clk25m or negedge i_res_n) begin
        if (~i_res_n) begin
            r_sfp_los <= 2'b11;
        end else begin
            r_sfp_los <= {r_sfp_los[0], i_sfp_los};
        end
    end

    // Output register
    reg     [3:0]   r_mii_rx_data_ff;
    always @(posedge w_rcv_clk25m or negedge i_res_n) begin
        if (~i_res_n) begin
            r_mii_rx_data_ff <= 4'd0;
            o_mii_rx_data <= 4'd0;
            o_mii_rx_dv <= 1'b0;
        end else begin
            r_mii_rx_data_ff <= w_4b_data;
            o_mii_rx_data <= r_mii_rx_data_ff;
            
            if (w_tr_det | r_sfp_los[1]) begin
                o_mii_rx_dv <= 1'b0;
            end else if (r_jk_det_ff2) begin
                o_mii_rx_dv <= 1'b1;
            end
        end
    end

    assign o_rcv_clk25m = w_rcv_clk25m;
    assign o_rcv_clk125m = w_rcv_clk125m;

endmodule
