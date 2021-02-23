/*****************************************************************
* Title     : ACK LED Controller
* Date      : 2021/02/23
* Design    : kingyo
******************************************************************/
module ack_led (
    input   wire    i_clk,
    input   wire    i_res_n,
    input   wire    i_trig,
    output  wire    o_led
);

    reg [20:0]  r_ack_led;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_ack_led <= 21'd0;
        end else begin
            if (i_trig && (r_ack_led == 21'd0)) begin
                r_ack_led <= 21'd1250000;
            end else begin
                if (r_ack_led != 21'd0) begin
                    r_ack_led <= r_ack_led - 21'd1;
                end
            end
        end
    end

    assign o_led = ~(r_ack_led >= 21'd625000);

endmodule
