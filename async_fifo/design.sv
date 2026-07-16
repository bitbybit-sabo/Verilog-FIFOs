// Code your design here

`timescale 1ns/1ps

module async_fifo(input write_clk, read_clk, areset, read_en, write_en, input [DATA_WIDTH-1:0] data_in, output reg full, output reg empty, output reg [DATA_WIDTH-1:0] data_out);
  
  parameter DATA_WIDTH=8;
  parameter DEPTH=8;
  parameter POINTER_SIZE=4;
  
  reg [DATA_WIDTH-1:0] data_holder[DEPTH-1:0];
  reg [POINTER_SIZE-1:0] write_bin_ptr;
  reg [POINTER_SIZE-1:0] read_bin_ptr;
  reg [POINTER_SIZE-1:0] write_gray_ptr;
  reg [POINTER_SIZE-1:0] read_gray_ptr;
  wire [POINTER_SIZE-1:0] write_gray_sync_ptr;
  wire [POINTER_SIZE-1:0] read_gray_sync_ptr;

  
  wire [POINTER_SIZE-1:0] write_bin_next  = write_bin_ptr + (write_en && !full);
  wire [POINTER_SIZE-1:0] write_gray_next = write_bin_next ^ (write_bin_next >> 1);

  wire [POINTER_SIZE-1:0] read_bin_next   = read_bin_ptr + (read_en && !empty);
  wire [POINTER_SIZE-1:0] read_gray_next  = read_bin_next ^ (read_bin_next >> 1);
  
  always@(posedge write_clk or posedge areset)begin
    if(areset) begin
      write_bin_ptr <= 0;
      write_gray_ptr<=0;
      full<=0;
    end
    else begin
      if(write_en)begin
        if(!full) begin
          data_holder[write_bin_ptr[POINTER_SIZE-2:0]]<=data_in;
          write_bin_ptr<=write_bin_ptr+1;
          write_gray_ptr <= write_gray_next; 
        end
      end
      full <= ({~(read_gray_sync_ptr[POINTER_SIZE-1:POINTER_SIZE-2]),read_gray_sync_ptr[POINTER_SIZE-3:0]}==write_gray_next);
    end
  end
  
  always@(posedge read_clk or posedge areset)begin
    if(areset)begin
      read_bin_ptr<=0;
      read_gray_ptr<=0;
      empty<=1;
    end
    else begin
      if(read_en)begin
        if(!empty) begin
          data_out<=data_holder[read_bin_ptr[POINTER_SIZE-2:0]];
          read_bin_ptr<=read_bin_ptr+1;
          read_gray_ptr <= read_gray_next; 
        end
      end
      empty <= (write_gray_sync_ptr==read_gray_next);
    end    
  end
  

  two_ffsync write_sync (read_clk,areset,write_gray_ptr,write_gray_sync_ptr);
  two_ffsync read_sync (write_clk,areset,read_gray_ptr,read_gray_sync_ptr);
  
endmodule

module two_ffsync(input destination_clk, areset, input [POINTER_SIZE-1:0] ptr_in, output wire [POINTER_SIZE-1:0] ptr_out);
  
  parameter POINTER_SIZE=4;
  
  wire [POINTER_SIZE-1:0] out1;
  
  FF f1(destination_clk, areset, ptr_in, out1);
  FF f2(destination_clk, areset, out1, ptr_out);
  
endmodule
  

module FF (input clk, areset,  input [POINTER_SIZE-1:0] D, output reg [POINTER_SIZE-1:0] out);
  
  parameter POINTER_SIZE=4;
  
  always@(posedge clk or posedge areset) begin
    if(areset) out<=0;
    else out <= D;
  end
endmodule