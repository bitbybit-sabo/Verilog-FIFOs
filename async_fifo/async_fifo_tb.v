`timescale 1ns/1ps
// ============================================================================
// Async FIFO Self-Checking Testbench (matched to current RTL)
// Designed for registered FULL/EMPTY flags.
// ============================================================================

module async_fifo_tb;

parameter DATA_WIDTH   = 8;
parameter DEPTH        = 8;
parameter POINTER_SIZE = 4;

reg write_clk = 0;
reg read_clk  = 0;
reg areset    = 0;
reg write_en  = 0;
reg read_en   = 0;
reg [DATA_WIDTH-1:0] data_in = 0;

wire [DATA_WIDTH-1:0] data_out;
wire full;
wire empty;

async_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH),
    .POINTER_SIZE(POINTER_SIZE)
) dut (
    .write_clk(write_clk),
    .read_clk(read_clk),
    .areset(areset),
    .read_en(read_en),
    .write_en(write_en),
    .data_in(data_in),
    .full(full),
    .empty(empty),
    .data_out(data_out)
);

// -----------------------------------------------------------------------------
// Clocks
// -----------------------------------------------------------------------------
always #5 write_clk = ~write_clk;
always #7 read_clk  = ~read_clk;

// -----------------------------------------------------------------------------
// Reference queue
// -----------------------------------------------------------------------------
byte model[$];
byte expected;

integer pass_cnt=0;
integer fail_cnt=0;
integer wr_accept=0;
integer rd_accept=0;
integer wr_block=0;
integer rd_block=0;

// Latch acceptance exactly as DUT sees it (pre-NBA flag values)
reg wr_fire;
reg rd_fire;

always @(posedge write_clk)
    wr_fire <= write_en && !full;

always @(posedge read_clk)
    rd_fire <= read_en && !empty;

// Update scoreboard from latched acceptance
always @(posedge write_clk) begin
    #1;
    if(wr_fire) begin
        model.push_back(data_in);
        wr_accept = wr_accept + 1;
    end
    else if(write_en)
        wr_block = wr_block + 1;
end

always @(posedge read_clk) begin
    #1;
    if(rd_fire) begin
        rd_accept = rd_accept + 1;
        if(model.size()==0) begin
            $display("[%0t] SCOREBOARD UNDERFLOW",$time);
            fail_cnt = fail_cnt + 1;
        end
        else begin
            expected = model.pop_front();
            #1;
            if(data_out===expected)
                pass_cnt = pass_cnt + 1;
            else begin
                fail_cnt = fail_cnt + 1;
                $display("[%0t] DATA FAIL exp=%02h got=%02h",
                         $time, expected, data_out);
            end
        end
    end
    else if(read_en)
        rd_block = rd_block + 1;
end

task automatic write_word(input byte d);
begin
    @(negedge write_clk);
    data_in=d;
    write_en=1;
    @(posedge write_clk);
    @(negedge write_clk);
    write_en=0;
end
endtask

task automatic read_word;
begin
    @(negedge read_clk);
    read_en=1;
    @(posedge read_clk);
    @(negedge read_clk);
    read_en=0;
end
endtask

integer i;

initial begin

areset=1;
repeat(4) @(posedge write_clk);
repeat(4) @(posedge read_clk);
areset=0;

// allow synchronizers to flush reset
repeat(4) @(posedge write_clk);
repeat(4) @(posedge read_clk);

// Fill
for(i=0;i<DEPTH;i=i+1)
    write_word(i+8'h10);

// Overflow attempts
repeat(4)
    write_word(8'hAA);

// Read half
repeat(DEPTH/2)
    read_word();

// Wrap
for(i=0;i<4;i=i+1)
    write_word(i+8'h80);

// Random traffic
fork
begin
    integer k;
    for(k=0;k<1500;k=k+1) begin
        @(negedge write_clk);
        write_en = $urandom_range(0,1);
        data_in  = $urandom;
        @(posedge write_clk);
        @(negedge write_clk);
        write_en = 0;
    end
end

begin
    integer k;
    for(k=0;k<1500;k=k+1) begin
        @(negedge read_clk);
        read_en = $urandom_range(0,1);
        @(posedge read_clk);
        @(negedge read_clk);
        read_en = 0;
    end
end
join

while(model.size()>0)
    read_word();

repeat(20) @(posedge read_clk);

$display("");
$display("==============================================");
$display("ASYNC FIFO VERIFICATION REPORT");
$display("==============================================");
$display("Writes Accepted    : %0d",wr_accept);
$display("Reads Accepted     : %0d",rd_accept);
$display("Writes Blocked     : %0d",wr_block);
$display("Reads Blocked      : %0d",rd_block);
$display("----------------------------------------------");
$display("PASS               : %0d",pass_cnt);
$display("FAIL               : %0d",fail_cnt);
$display("----------------------------------------------");

if(fail_cnt==0)
    $display("RESULT : PASS");
else
    $display("RESULT : FAIL");

$finish;

end

initial begin
#20000000;
$display("TIMEOUT");
$finish;
end

endmodule