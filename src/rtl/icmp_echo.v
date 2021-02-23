/*****************************************************************
* Title     : ICMP Echo module
* Date      : 2021/02/23
* Design    : kingyo
******************************************************************/
module icmp_echo (
    input   wire            i_clk,
    input   wire            i_res_n,
    input   wire            i_4b_en,
    input   wire    [3:0]   i_4b_data,

    // OUTPUT
    output  reg             o_tx_en,
    output  wire    [3:0]   o_tx_data
);

    // エッジ検出（仮）
    reg     r_4b_en_ff;
    wire    w_start_trig = (~r_4b_en_ff & i_4b_en);
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_4b_en_ff <= 1'b0;
        end else begin
            r_4b_en_ff <= i_4b_en;
        end
    end

    // フレーム開始検出&カウンタ
    reg     [11:0]  r_jk_cnt;
    reg             r_sfd_wait;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_jk_cnt <= 12'd0;
            r_sfd_wait <= 1'b0;
        end else begin
            if (w_start_trig) begin
                r_sfd_wait <= 1'b1;
            end else begin
                // SFD 検出
                if (r_sfd_wait && i_4b_data == 4'hd) begin
                    r_jk_cnt <= 12'd0;
                    r_sfd_wait <= 1'b0;
                end else begin
                    if (r_jk_cnt != 12'd4095) begin
                        r_jk_cnt <= r_jk_cnt + 12'd1;
                    end
                end
            end
        end
    end

    // IPv4全長取得
    reg     [15:0]  r_ipv4_total_len;
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            r_ipv4_total_len <= 16'd0;
        end else begin
            if (r_jk_cnt == 12'd32) r_ipv4_total_len[11: 8] <= i_4b_data;
            if (r_jk_cnt == 12'd33) r_ipv4_total_len[15:12] <= i_4b_data;
            if (r_jk_cnt == 12'd34) r_ipv4_total_len[ 3: 0] <= i_4b_data;
            if (r_jk_cnt == 12'd35) r_ipv4_total_len[ 7: 4] <= i_4b_data;
            if (r_jk_cnt == 12'd36) r_ipv4_total_len <= r_ipv4_total_len + 16'd24; 
        end
    end

    // パイプラインレジスタ
    parameter PLEN = 25;
    integer i;
    reg     [3:0]   r_pip   [PLEN - 1:0];
    always @(posedge i_clk) begin
        r_pip[0] <= i_4b_data[3:0];
        for (i = 1; i < PLEN; i = i + 1) begin
            r_pip[i] <= r_pip[i - 1];
        end
    end

    reg     [3:0]   r_tx_data;
    reg     [15:0]  r_icmp_sum;
    wire    [15:0]  w_icmp_sum = r_icmp_sum + 16'h0800;
    always @(posedge i_clk) begin
        // ICMP チェックサム再計算
        if (r_jk_cnt == 12'd84) begin
            r_icmp_sum <= {r_pip[10], r_pip[11], r_pip[8], r_pip[9]};
        end
        // MACアドレス、IPアドレス入れ替え & ICMP echo Reply、ICMP Check sum改変
        r_tx_data <= (r_jk_cnt >= 12'd13 && r_jk_cnt <= 12'd24)  ? r_pip[ 0] :  // Dest MAC Addr
                     (r_jk_cnt >= 12'd25 && r_jk_cnt <= 12'd36)  ? r_pip[24] :  // Src MAC Addr
                     (r_jk_cnt >= 12'd65 && r_jk_cnt <= 12'd72)  ? r_pip[ 4] :  // Src IP Addr
                     (r_jk_cnt >= 12'd73 && r_jk_cnt <= 12'd80)  ? r_pip[20] :  // Dest IP Addr
                     (r_jk_cnt == 12'd81)                        ? 4'h0 :       // ICMP echo Reply
                     (r_jk_cnt == 12'd82)                        ? 4'h0 :       // ICMP echo Reply
                     (r_jk_cnt == 12'd85)                        ? w_icmp_sum[11: 8] :  // ICMP Check sum
                     (r_jk_cnt == 12'd86)                        ? w_icmp_sum[15:12] :  // ICMP Check sum
                     (r_jk_cnt == 12'd87)                        ? w_icmp_sum[ 3: 0] :  // ICMP Check sum
                     (r_jk_cnt == 12'd88)                        ? w_icmp_sum[ 7: 4] :  // ICMP Check sum
                     r_pip[12];
    end

    // FCS(CRC-32) Calc
    wire    [31:0]  w_crc_out;
    wire            w_crc_en = (r_jk_cnt >= 12'd14 && r_jk_cnt <= ({r_ipv4_total_len[10:0], 1'b0} - 12'd7));
    crc crc (
        .CLK ( i_clk ),
        .RESET_N ( i_res_n ),
        .IN_CLR ( w_start_trig ),
        .IN_ENA ( w_crc_en ),
        .IN_DATA ( r_tx_data[3:0] ),
        .OUT_CRC ( w_crc_out[31:0] )
    );
    defparam crc.DATA_WIDTH = 4;
    defparam crc.CRC_WIDTH = 32;
    defparam crc.POLYNOMIAL = 32'h04C11DB7;
    defparam crc.SEED_VAL = 32'hFFFFFFFF;
    defparam crc.OUTPUT_EXOR = 32'hFFFFFFFF;

    // OUTPUT
    assign o_tx_data = (r_jk_cnt == ({r_ipv4_total_len[10:0], 1'b0} - 12'd6)) ? {w_crc_out[28], w_crc_out[29], w_crc_out[30], w_crc_out[31]} :
                       (r_jk_cnt == ({r_ipv4_total_len[10:0], 1'b0} - 12'd5)) ? {w_crc_out[24], w_crc_out[25], w_crc_out[26], w_crc_out[27]} :
                       (r_jk_cnt == ({r_ipv4_total_len[10:0], 1'b0} - 12'd4)) ? {w_crc_out[20], w_crc_out[21], w_crc_out[22], w_crc_out[23]} :
                       (r_jk_cnt == ({r_ipv4_total_len[10:0], 1'b0} - 12'd3)) ? {w_crc_out[16], w_crc_out[17], w_crc_out[18], w_crc_out[19]} :
                       (r_jk_cnt == ({r_ipv4_total_len[10:0], 1'b0} - 12'd2)) ? {w_crc_out[12], w_crc_out[13], w_crc_out[14], w_crc_out[15]} :
                       (r_jk_cnt == ({r_ipv4_total_len[10:0], 1'b0} - 12'd1)) ? {w_crc_out[ 8], w_crc_out[ 9], w_crc_out[10], w_crc_out[11]} :
                       (r_jk_cnt == ({r_ipv4_total_len[10:0], 1'b0} - 12'd0)) ? {w_crc_out[ 4], w_crc_out[ 5], w_crc_out[ 6], w_crc_out[ 7]} :
                       (r_jk_cnt == ({r_ipv4_total_len[10:0], 1'b0} + 12'd1)) ? {w_crc_out[ 0], w_crc_out[ 1], w_crc_out[ 2], w_crc_out[ 3]} :
                       r_tx_data;

    // TX Enable制御
    always @(posedge i_clk or negedge i_res_n) begin
        if (~i_res_n) begin
            o_tx_en <= 1'b0;
        end else begin
            if (r_jk_cnt == 12'd8)                                      o_tx_en <= 1'b1;
            if (r_jk_cnt == ({r_ipv4_total_len[10:0], 1'b0} + 12'd1))   o_tx_en <= 1'b0;
        end
    end

endmodule
