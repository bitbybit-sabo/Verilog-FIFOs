module sync_fifo(input clk, a_reset, write_en, read_en, input [DATA_WIDTH-1:0] data_in, output full, output empty, output reg [DATA_WIDTH-1:0] data_out);
 
  parameter DATA_WIDTH=8;
  parameter DEPTH=8;
  parameter COUNTER_SIZE=4;
  parameter POINTER_SIZE=3;
 
  reg [DATA_WIDTH-1:0] data_holder[DEPTH-1:0];
  reg [COUNTER_SIZE-1:0] counter;
  reg [POINTER_SIZE-1:0] write_ptr;
  reg [POINTER_SIZE-1:0] read_ptr;

  always@(posedge clk or posedge a_reset)begin
    if(a_reset)begin
        counter<=4'b0;
        read_ptr<=3'b0;
        write_ptr<=3'b0;
    end
    else begin
        case ({write_en,read_en})
        2'b00:;
        2'b01: begin
            if(!empty)begin
                data_out<=data_holder[read_ptr];
                read_ptr<=read_ptr+1;
                counter<=counter-1;
            end
        end 
        2'b10:begin
            if(!full) begin
                data_holder[write_ptr]<=data_in;
                write_ptr<=write_ptr+1;
                counter<=counter+1;
            end
        end
        2'b11:begin
            if(!full&&!empty)begin
                data_holder[write_ptr]<=data_in;
                write_ptr<=write_ptr+1;
                data_out<=data_holder[read_ptr];
                read_ptr<=read_ptr+1;
            end
            else if((!full&&empty)) data_out<=data_in;
            else if((full&&!empty)) begin
                data_holder[write_ptr]<=data_in;
                write_ptr<=write_ptr+1;
                data_out<=data_holder[read_ptr];
                read_ptr<=read_ptr+1;
            end
        end
        default: ;
    endcase
    end
  end
 
  assign empty=(counter==0);
  assign full=(counter==DEPTH);
endmodule

