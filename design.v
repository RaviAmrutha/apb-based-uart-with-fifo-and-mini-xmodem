module fifo_8x16 ( 
    input  wire       clk, rst_n, wr_en, rd_en, 
    input  wire [7:0] din, 
    output reg  [7:0] dout, 
    output wire       full, empty 
); 
    reg [7:0] mem [0:15]; 
    reg [3:0] wr_ptr, rd_ptr; 
    reg [4:0] count; 
    assign full  = (count==5'd16); 
    assign empty = (count==5'd0); 
    always @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin wr_ptr<=0; rd_ptr<=0; count<=0; dout<=8'hFF; end 
        else case ({wr_en&~full, rd_en&~empty}) 
            2'b10: begin mem[wr_ptr]<=din; wr_ptr<=wr_ptr+1; count<=count+1; end 
            2'b01: begin dout<=mem[rd_ptr]; rd_ptr<=rd_ptr+1; count<=count-1; end 
            2'b11: begin mem[wr_ptr]<=din; dout<=mem[rd_ptr]; wr_ptr<=wr_ptr+1; 
rd_ptr<=rd_ptr+1; end 
            default:; 
        endcase 
    end 
endmodule 
 
module uart_tx ( 
    input  wire       clk, rst_n, tx_start, 
    input  wire [7:0] tx_data, baud_div, 
    output reg        tx_out, tx_busy, tx_rd_en 
); 
    localparam [1:0] IDLE=0,LOAD=1,DATA=2,STOP=3; 
    reg [1:0] state; 
    reg [3:0] bit_cnt; 
    reg [7:0] baud_cnt, shreg; 
    always @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin tx_out<=1; tx_busy<=0; tx_rd_en<=0; state<=IDLE; bit_cnt<=0; 
baud_cnt<=0; shreg<=0; end 
        else begin 
            tx_rd_en<=0; 
            case (state) 
                IDLE: begin tx_out<=1; tx_busy<=0; if(tx_start) begin tx_rd_en<=1; state<=LOAD; 
end end 
                LOAD: begin shreg<=tx_data; baud_cnt<=0; bit_cnt<=8; tx_out<=0; tx_busy<=1; 
state<=DATA; end 
                DATA: if(baud_cnt==baud_div-1) begin baud_cnt<=0; tx_out<=shreg[0]; 
shreg<={1'b1,shreg[7:1]}; bit_cnt<=bit_cnt-1; if(bit_cnt==1) state<=STOP; end else 
baud_cnt<=baud_cnt+1; 
                STOP: begin tx_out<=1; if(baud_cnt==baud_div-1) begin baud_cnt<=0; tx_busy<=0; 
state<=IDLE; end else baud_cnt<=baud_cnt+1; end 
            endcase 
        end 
APB Based UART with FIFO & Mini – X modem 
 
 
                Aditya College of Engineering and Technology                                                                                                     57 | Page  
    end 
endmodule 
 
module uart_rx ( 
    input  wire       clk, rst_n, rx_in, 
    input  wire [7:0] baud_div, 
    output reg  [7:0] rx_data, 
    output reg        rx_valid 
); 
    localparam [1:0] IDLE=0,START=1,DATA=2,STOP=3; 
    reg [1:0] state; 
    reg [3:0] bit_cnt; 
    reg [7:0] baud_cnt, shreg; 
    reg rx_s1, rx_s2; 
    always @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin rx_s1<=1; rx_s2<=1; state<=IDLE; rx_valid<=0; bit_cnt<=0; baud_cnt<=0; 
rx_data<=0; shreg<=0; end 
        else begin 
            rx_s1<=rx_in; rx_s2<=rx_s1; rx_valid<=0; 
            case (state) 
                IDLE:  if(!rx_s2) begin baud_cnt<=0; state<=START; end 
                START: if(baud_cnt==(baud_div>>1)-1) begin baud_cnt<=0; bit_cnt<=8; 
state<=DATA; end else baud_cnt<=baud_cnt+1; 
                DATA:  if(baud_cnt==baud_div-1) begin baud_cnt<=0; shreg<={rx_s2,shreg[7:1]}; 
bit_cnt<=bit_cnt-1; if(bit_cnt==1) state<=STOP; end else baud_cnt<=baud_cnt+1; 
                STOP:  if(baud_cnt==baud_div-1) begin baud_cnt<=0; rx_data<=shreg; rx_valid<=1; 
state<=IDLE; end else baud_cnt<=baud_cnt+1; 
            endcase 
        end 
    end 
endmodule 
 
module mini_xmodem ( 
    input  wire       clk, rst_n, xmodem_en, fifo_empty, uart_busy, rx_valid, 
    input  wire [7:0] rx_data, 
    output reg        tx_done, ack_out 
); 
    localparam [7:0] ACK_BYTE = 8'h06; 
    localparaL[2:0] 
S_IDLE=0,S_WAIT_TX=1,S_TX_DONE=2,S_WAIT_ACK=3,S_GOT_ACK=4; 
    reg [2:0] state; 
    wire packet_sent = fifo_empty & ~uart_busy; 
    always @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin state<=S_IDLE; tx_done<=0; ack_out<=0; end 
        else case (state) 
            S_IDLE:     if(xmodem_en && !packet_sent) state<=S_WAIT_TX; 
            S_WAIT_TX:  if(packet_sent) state<=S_TX_DONE; 
            S_TX_DONE:  begin tx_done<=1; state<=S_WAIT_ACK; end 
            S_WAIT_ACK: if(rx_valid && rx_data==ACK_BYTE) state<=S_GOT_ACK; 
            S_GOT_ACK:  ack_out<=1; 
            default:    state<=S_IDLE; 
        endcase 
end 
APB Based UART with FIFO & Mini – X modem 
endmodule 
module apb_uart_top ( 
input  wire
        PCLK, PRESETn, PSEL, PENABLE, PWRITE, 
input  wire  [7:0] PADDR, PWDATA, 
output reg   [7:0] PRDATA, 
output wire
        PREADY, uart_tx, tx_done, ack_out, 
input  wire
); 
        uart_rx 
reg [7:0] ctrl_reg, baud_div; 
assign PREADY=1; 
wire apb_wr=PSEL&PENABLE&PWRITE, apb_rd=PSEL&PENABLE&~PWRITE; 
wire tx_ff,tx_fe; wire [7:0] tx_byte; wire tx_fifo_wr=apb_wr&(PADDR==8'h00); wire 
tx_fifo_rd; 
wire rx_ff,rx_fe; wire [7:0] rx_dout;  wire rx_fifo_rd=apb_rd&(PADDR==8'h0C); 
wire uart_tx_busy; wire [7:0] uart_rx_data; wire uart_rx_valid; 
always @(posedge PCLK or negedge PRESETn) begin 
if(!PRESETn) begin ctrl_reg<=0; baud_div<=8'd16; end 
else if(apb_wr) begin 
if(PADDR==8'h04) ctrl_reg<=PWDATA; 
if(PADDR==8'h10) baud_div<=PWDATA; 
end 
end 
always @(*) begin 
case(PADDR) 
8'h04: PRDATA=ctrl_reg; 8'h0C: PRDATA=rx_dout; 
8'h10: PRDATA=baud_div; default: PRDATA=8'h00; 
endcase 
end 
fifo_8x16 
u_txf(.clk(PCLK),.rst_n(PRESETn),.wr_en(tx_fifo_wr),.rd_en(tx_fifo_rd),.din(PWDATA),.dout(
tx_byte),.full(tx_ff),.empty(tx_fe)); 
fifo_8x16 
u_rxf(.clk(PCLK),.rst_n(PRESETn),.wr_en(uart_rx_valid),.rd_en(rx_fifo_rd),.din(uart_rx_data),.
dout(rx_dout),.full(rx_ff),.empty(rx_fe)); 
uart_tx   
u_utx(.clk(PCLK),.rst_n(PRESETn),.tx_start(!tx_fe&ctrl_reg[0]),.tx_data(tx_byte),.baud_div(ba
ud_div),.tx_out(uart_tx),.tx_busy(uart_tx_busy),.tx_rd_en(tx_fifo_rd)); 
uart_rx   
u_urx(.clk(PCLK),.rst_n(PRESETn),.rx_in(uart_rx),.baud_div(baud_div),.rx_data(uart_rx_data),.
rx_valid(uart_rx_valid)); 
mini_xmodem 
u_xm(.clk(PCLK),.rst_n(PRESETn),.xmodem_en(ctrl_reg[2]),.fifo_empty(tx_fe),.uart_busy(uart
_tx_busy),.rx_valid(uart_rx_valid),.rx_data(uart_rx_data),.tx_done(tx_done),.ack_out(ack_out)); 
endmodule
