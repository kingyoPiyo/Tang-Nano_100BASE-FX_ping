/*****************************************************************
* Title     : Ethernet frame splitter
* Date      : 2021/02/23
* Design    : kingyo
******************************************************************/
module eth_frame_split #(
    parameter EtherMyMAC    = 48'h123456789ABC,
    parameter EtherMyIP_1   = 8'd192,
    parameter EtherMyIP_2   = 8'd168,
    parameter EtherMyIP_3   = 8'd37,
    parameter EtherMyIP_4   = 8'd24
    ) (
    input   wire            i_clk,
    input   wire            i_res_n,

    // Input frame data from PHY
    input   wire    [3:0]   i_mii_rx_data,
    input   wire            i_mii_rx_dv,

    // Output frame data to ARP/ICMP echo module
    output  wire    [3:0]   o_mii_rx_data,
    output  wire            o_mii_rx_dv,
    output  reg             o_arp_en,
    output  reg             o_icmp_en
);

    // フレームカウンタ
    reg     [11:0]  r_4b_cnt;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_4b_cnt <= 12'd0;
        end else begin
            if (~i_mii_rx_dv) begin
                r_4b_cnt <= 12'd0;
            end else begin
                if (r_4b_cnt != 12'd4095) begin
                    r_4b_cnt <= r_4b_cnt + 12'd1;
                end
            end
        end
    end

    // ARP/ICMPパケット判定
    reg             r_is_arp;
    reg             r_is_icmp;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            o_arp_en <= 1'b0;
            o_icmp_en <= 1'b0;
            r_is_arp <= 1'b0;
            r_is_icmp <= 1'b0;
        end else begin

            if (r_4b_cnt == 12'd0) begin
                r_is_arp <= 1'b1;
                r_is_icmp <= 1'b1;
            end

            // Destination MAC Address(ARP)
            if (r_4b_cnt == 12'd14 && i_mii_rx_data != EtherMyMAC[43:40] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd15 && i_mii_rx_data != EtherMyMAC[47:44] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd16 && i_mii_rx_data != EtherMyMAC[35:32] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd17 && i_mii_rx_data != EtherMyMAC[39:36] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd18 && i_mii_rx_data != EtherMyMAC[27:24] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd19 && i_mii_rx_data != EtherMyMAC[31:28] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd20 && i_mii_rx_data != EtherMyMAC[19:16] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd21 && i_mii_rx_data != EtherMyMAC[23:20] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd22 && i_mii_rx_data != EtherMyMAC[11: 8] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd23 && i_mii_rx_data != EtherMyMAC[15:12] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd24 && i_mii_rx_data != EtherMyMAC[ 3: 0] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd25 && i_mii_rx_data != EtherMyMAC[ 7: 4] && i_mii_rx_data != 4'hF) r_is_arp <= 1'b0;

            // Target IP Address(ARP)
            if (r_4b_cnt == 12'd90 && i_mii_rx_data != EtherMyIP_1[3:0]) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd91 && i_mii_rx_data != EtherMyIP_1[7:4]) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd92 && i_mii_rx_data != EtherMyIP_2[3:0]) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd93 && i_mii_rx_data != EtherMyIP_2[7:4]) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd94 && i_mii_rx_data != EtherMyIP_3[3:0]) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd95 && i_mii_rx_data != EtherMyIP_3[7:4]) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd96 && i_mii_rx_data != EtherMyIP_4[3:0]) r_is_arp <= 1'b0;
            if (r_4b_cnt == 12'd97 && i_mii_rx_data != EtherMyIP_4[7:4]) r_is_arp <= 1'b0;

            // Destination MAC Address(ICMP)
            if (r_4b_cnt == 12'd14 && i_mii_rx_data != EtherMyMAC[43:40]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd15 && i_mii_rx_data != EtherMyMAC[47:44]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd16 && i_mii_rx_data != EtherMyMAC[35:32]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd17 && i_mii_rx_data != EtherMyMAC[39:36]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd18 && i_mii_rx_data != EtherMyMAC[27:24]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd19 && i_mii_rx_data != EtherMyMAC[31:28]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd20 && i_mii_rx_data != EtherMyMAC[19:16]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd21 && i_mii_rx_data != EtherMyMAC[23:20]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd22 && i_mii_rx_data != EtherMyMAC[11: 8]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd23 && i_mii_rx_data != EtherMyMAC[15:12]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd24 && i_mii_rx_data != EtherMyMAC[ 3: 0]) r_is_icmp <= 1'b0;
            if (r_4b_cnt == 12'd25 && i_mii_rx_data != EtherMyMAC[ 7: 4]) r_is_icmp <= 1'b0;

            // Ethernet Type
            if (r_4b_cnt == 12'd38 && i_mii_rx_data != 4'h8) r_is_arp <= 1'b0;  // ARP
            if (r_4b_cnt == 12'd39 && i_mii_rx_data != 4'h0) r_is_arp <= 1'b0;  // ARP
            if (r_4b_cnt == 12'd40 && i_mii_rx_data != 4'h6) r_is_arp <= 1'b0;  // ARP
            if (r_4b_cnt == 12'd41 && i_mii_rx_data != 4'h0) r_is_arp <= 1'b0;  // ARP
            if (r_4b_cnt == 12'd38 && i_mii_rx_data != 4'h8) r_is_icmp <= 1'b0; // IPv4
            if (r_4b_cnt == 12'd39 && i_mii_rx_data != 4'h0) r_is_icmp <= 1'b0; // IPv4
            if (r_4b_cnt == 12'd40 && i_mii_rx_data != 4'h0) r_is_icmp <= 1'b0; // IPv4
            if (r_4b_cnt == 12'd41 && i_mii_rx_data != 4'h0) r_is_icmp <= 1'b0; // IPv4

            // IPv4 Protocol (ICMP:0x01)
            if (r_4b_cnt == 12'd60 && i_mii_rx_data != 4'h1) r_is_icmp <= 1'b0; // ICMP
            if (r_4b_cnt == 12'd61 && i_mii_rx_data != 4'h0) r_is_icmp <= 1'b0; // ICMP

            // ICMP Type(Echo:0x08)
            if (r_4b_cnt == 12'd82 && i_mii_rx_data != 4'h8) r_is_icmp <= 1'b0; // Echo
            if (r_4b_cnt == 12'd83 && i_mii_rx_data != 4'h0) r_is_icmp <= 1'b0; // Echo

            // 結果更新
            if (r_4b_cnt == 12'd98) begin
                o_arp_en <= r_is_arp;
                o_icmp_en <= r_is_icmp;
            end
        end
    end

    // 遅延用シフトレジスタ
    parameter SLEN = 99; // 遅延段数
    integer i;
    reg     [3:0]   r_data_shift    [SLEN - 1:0];
    reg             r_dv_shift      [SLEN - 1:0];

    // SIM不定値対策
    initial begin
        for (i = 0; i < SLEN; i = i + 1) begin
            r_data_shift[i] = 4'd0;
            r_dv_shift[i] = 1'b0;
        end
    end

    always @(posedge i_clk) begin
        r_data_shift[0] <= i_mii_rx_data[3:0];
        r_dv_shift[0] <= i_mii_rx_dv;
        for (i = 1; i < SLEN; i = i + 1) begin
            r_data_shift[i] <= r_data_shift[i - 1];
            r_dv_shift[i] <= r_dv_shift[i - 1];
        end
    end

    assign o_mii_rx_data[3:0] = r_data_shift[SLEN - 1];
    assign o_mii_rx_dv = r_dv_shift[SLEN - 1];

endmodule
