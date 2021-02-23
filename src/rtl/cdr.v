/*****************************************************************
* Title     : Oversampling Clock Data Recovery module
* Date      : 2020/12/27
* Design    : kingyo
******************************************************************/
module cdr (
    input   wire            i_clk,      // Main Clock(375Mhz)
    input   wire            i_res_n,    // Reset
    input   wire            i_rxdata,   // Serial Data Input(125Mbps)

    output  reg     [4:0]   o_data,     // Parallel Data Output
    output  wire            o_rclk125m, // 125MHz Recovery Clock
    output  wire            o_rclk25m   // 25MHz Recovery Clock
);

    // Input data synchronizer
    reg     [2:0]   r_syncFF;
    always @(posedge i_clk) begin
        r_syncFF <= {r_syncFF[1:0], i_rxdata};
    end

    // Detect data stream transitions
    wire            w_ts = r_syncFF[2] ^ r_syncFF[1];

    // Recovery clock
    reg [1:0]   r_cdr_state;
    wire        w_clk_125m = (r_cdr_state == 2'd0);
    always @(posedge i_clk) begin
        if (w_ts) begin
            r_cdr_state <= 2'd0;
        end else begin
            if (r_cdr_state < 2'd2) begin
                r_cdr_state <= r_cdr_state + 2'd1;
            end else begin
                r_cdr_state <= 2'd0;
            end
        end
    end

    // Capture data stream
    reg r_fix_bit;
    always @(posedge w_clk_125m) begin
        r_fix_bit <= r_syncFF[2];
    end

    // NRZI decoder
    reg r_deced_bit;
    reg r_fix_bit_ff;
    always @(posedge w_clk_125m or negedge i_res_n) begin
        if (~i_res_n) begin
            r_deced_bit <= 1'b0;
            r_fix_bit_ff <= 1'b0;
        end else begin
            r_fix_bit_ff <= r_fix_bit;
            r_deced_bit <= r_fix_bit ^ r_fix_bit_ff;
        end
    end

    // ser => para(5bit)
    reg     [4:0]   r_5b_data;
    always @(posedge w_clk_125m or negedge i_res_n) begin
        if (~i_res_n) begin
            r_5b_data <= 5'd0;
        end else begin
            r_5b_data <= {r_5b_data[3:0], r_deced_bit};
        end
    end

    // Latch
    reg     [2:0]   r_5b_state;
    always @(posedge w_clk_125m or negedge i_res_n) begin
        if (~i_res_n) begin
            r_5b_state <= 3'd0;
            o_data <= 5'd0;
        end else begin
            if (r_5b_state < 3'd4) begin
                r_5b_state <= r_5b_state + 3'd1;
            end else begin
                r_5b_state <= 3'd0;
            end
            if (r_5b_state == 3'd3) o_data <= r_5b_data;
        end
    end

    //==================================================================
    // Clock Divider
    // 125MHz => 25MHz
    //==================================================================
    CLKDIV clkdiv_inst ( 
        .HCLKIN ( w_clk_125m ), 
        .RESETN ( i_res_n ), 
        .CALIB ( 1'b0 ), 
        .CLKOUT ( o_rclk25m ) 
    ); 
    defparam clkdiv_inst.DIV_MODE="5";
    defparam clkdiv_inst.GSREN="false";

    assign  o_rclk125m = w_clk_125m;

endmodule
