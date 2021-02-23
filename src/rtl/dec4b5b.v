/*****************************************************************
* Title     : 4b5b Decoder for 100BASE-FX
* Date      : 2020/09/20
* Design    : kingyo
******************************************************************/
module dec4b5b (
    input   wire    [4:0]   i_data,
    output  wire    [3:0]   o_data
);

    assign  o_data = (i_data == 5'b11110) ? 4'h0 :
                     (i_data == 5'b01001) ? 4'h1 :
                     (i_data == 5'b10100) ? 4'h2 :
                     (i_data == 5'b10101) ? 4'h3 :
                     (i_data == 5'b01010) ? 4'h4 :
                     (i_data == 5'b01011) ? 4'h5 :
                     (i_data == 5'b01110) ? 4'h6 :
                     (i_data == 5'b01111) ? 4'h7 :
                     (i_data == 5'b10010) ? 4'h8 :
                     (i_data == 5'b10011) ? 4'h9 :
                     (i_data == 5'b10110) ? 4'hA :
                     (i_data == 5'b10111) ? 4'hB :
                     (i_data == 5'b11010) ? 4'hC :
                     (i_data == 5'b11011) ? 4'hD :
                     (i_data == 5'b11100) ? 4'hE :
                     (i_data == 5'b11101) ? 4'hF : 
                                            4'h0;   // Error

endmodule
