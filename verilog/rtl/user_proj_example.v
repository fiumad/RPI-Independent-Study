// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example 
(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb


);
    wire clk;
    wire our_reset;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;
    //carry over signals from one time register to the next
    wire sec_fine_to_sec_coarse;
    wire sec_coarse_to_min_fine;
    wire mins_fine_to_mins_coarse;
    wire mins_coarse_to_hours;
    wire hours_dummy;

    //signals to increment our time registers
    wire inc_secs; 
    wire inc_mins;
    wire inc_hours;

    //registers for storing time data
    wire [3:0] sec_fine;
    wire [11:0] sec_coarse;
    wire [3:0] mins_fine;
    wire [11:0] mins_coarse;
    wire [11:0] hours;

    //outputs for clock stepdown
    wire clk_1Hz;
    wire clk_1024Hz;

    //output dummy wire for mode processor TODO
    wire mode_led;

    //output wires for the 6x6 mux
    wire [5:0] rows6x6;
    wire [5:0] columns6x6;

    //output wires for the 2x4 mux
    wire [1:0] row2x4;
    wire [3:0] columns2x4;
    wire [1:0] count;

    wire counter_trigger;
    wire inc_demux_trigger;

    // WB MI A
    //assign valid = wbs_cyc_i && wbs_stb_i; 
    //assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    //assign wbs_dat_o = rdata;
    //assign wdata = wbs_dat_i;

    // IO
    assign io_out [19:14] = rows6x6;
    assign io_out [25:20] = columns6x6;
    assign io_out [27:26] = row2x4;
    assign io_out [31:28] = columns2x4;
    assign io_out [32] = mode_led;

    //assign io_oeb = {(`MPRJ_IO_PADS-1){1'b0}};
    //assign io_oeb = {(`MPRJ_IO_PADS-1){1'b0}};
    assign io_oeb[10] = 1'b1;
    assign io_oeb[11] = 1'b1;
    assign io_oeb[12] = 1'b1;
    assign io_oeb[13] = 1'b1;
    assign io_oeb[32:14] = 19'b0000000000000000000;

    // IRQ
    //assign irq = 3'b000;	// Unused

    // LA
    //assign la_data_out = {{(127-BITS){1'b0}}, count};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign counter_trigger = io_in[10];
    assign clk = io_in[11];
    assign inc_demux_trigger = io_in[12];
    assign our_reset = io_in[13];



    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    //assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    //assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

    

    counter zeroto3counter(
        .trigger(counter_trigger), //switch to IO pad later
        .reset(our_reset),
        .count(count)
    );

    inc_demux oneto4demux(
        .trigger(inc_demux_trigger), //pass button in here
        .sel(count),
        .inc_secs(inc_secs),
        .inc_mins(inc_mins),
        .inc_hours(inc_hours)
    );

    secs_fine_shift_register seconds_fine( 
        .clk(clk_1Hz),
        .reset(our_reset),
        .increment(inc_secs),
        .r_reg(sec_fine),
        .s_out(sec_fine_to_sec_coarse)
    );

    coarse_shift_register seconds_coarse( 
        .clk(sec_fine_to_sec_coarse),
        .reset(our_reset),
        .increment(1'b0),
        .r_reg(sec_coarse),
        .s_out(sec_coarse_to_min_fine)
    );

    mins_fine_register minutes_fine( 
        .clk(sec_coarse_to_min_fine),
        .reset(our_reset),
        .increment(inc_mins),
        .r_reg(mins_fine), 
        .s_out(mins_fine_to_mins_coarse)
    );
    
    coarse_shift_register minutes_coarse( 
        .clk(mins_fine_to_mins_coarse),
        .reset(our_reset),
        .increment(1'b0),
        .r_reg(mins_coarse),
        .s_out(mins_coarse_to_hours)
    );

    coarse_shift_register hours_1 (
        .clk(mins_coarse_to_hours),
        .reset(our_reset),
        .increment(inc_hours),
        .r_reg(hours),
        .s_out()
    );

    slowClock clock_stepdown (
        .clk(clk),
        .reset(our_reset),
        .clk_1Hz(clk_1Hz),
        .clk_1024Hz(clk_1024Hz)
    );

    mode_processor mode_LED_processor (
        .clk(clk_1024Hz),
        .mode(count),
        .reset(our_reset),
        .led(mode_led)
    );

    output_mux6x6 sixbysix(
        .hours(hours),
        .mins_coarse(mins_coarse),
        .secs_coarse(sec_coarse),
        .clk(clk_1024Hz),
        .reset(our_reset),
        .rows(rows6x6),
        .columns(columns6x6)
    );

    output_mux2x4 twobyfour(
        .mins_fine(mins_fine), 
        .secs_fine(sec_fine),
        .clk(clk_1024Hz),
        .reset(our_reset),
        .row(row2x4),
        .columns(columns2x4)
    );
endmodule

module counter #(
    parameter BITS = 2
)(
    input trigger,
    input reset,
    output [BITS-1:0] count
);
    reg [BITS-1:0] count;

    always @(posedge reset) begin
        count <= 0;
    end

    always @(posedge trigger) begin
        count <= count + 1;
    end


endmodule

module secs_fine_shift_register
   #(parameter N=4)
   (
    input wire clk, 
    input reset, 
    input increment,
    output reg [N-1:0] r_reg,
    output wire s_out
   );
 
   wire [N-1:0] r_next;
 
 
   always @(posedge clk or posedge reset or posedge increment)
   begin
      if (reset)
         r_reg <= 4'b1000;
      else if (r_reg[0] == 1'b1)   
        r_reg <= 4'b0;
      else
         r_reg <= r_next;
      
	end	
 
	assign r_next = {1'b1, r_reg[N-1:1]};
	assign s_out = ~r_reg[3] & ~reset;
 
 
endmodule

module mins_fine_register 
   #(parameter N=4)
   (
    input wire clk, 
    input wire reset, 
    input wire increment,
    output reg [N-1:0] r_reg,
    output wire s_out
   );
 
   wire [N-1:0] r_next;
   reg start;
 
   //always @(posedge clk or posedge reset or posedge increment)
   always @(posedge clk or posedge reset)
   begin
      if (reset)
      begin
         start <= 1'b1;
         r_reg <= 4'b0;
      end
      else if (r_reg[0] == 1'b1)   
        r_reg <= 4'b0;
      else
      begin
         r_reg <= r_next;
         start <= 1'b0;
      end
      
	end	
 
	assign r_next = {1'b1, r_reg[N-1:1]};
	assign s_out = ~(r_reg[3] | reset | start);

endmodule

module coarse_shift_register
    #(parameter N=12)//100000000000, 
   (
    input wire clk, 
    input reset, 
    input increment, 
    input sec_fine,
    output reg [N-1:0] r_reg,
    output wire s_out
   );
 
   wire [N-1:0] r_next;
   reg start;
 
   always @(posedge clk or posedge reset or posedge increment)
   begin
      if (reset)
        begin
          start <= 1'b1;
          r_reg <= 12'b100000000000;
        end
      else
      begin
        start <= 1'b0;
        r_reg <= r_next;
      end
	end	
 
	assign r_next = {r_reg[0], r_reg[N-1:1]};
	assign s_out = r_reg[11] & ~reset & ~start;
 
 
endmodule

module inc_demux (
    input trigger,
    input [1:0] sel,  //mode 0 = nothing, mode 1 = hours, mode 2 = mins, mode 3 = secs
    output reg inc_secs,
    output reg inc_mins,
    output reg inc_hours
);

    always @(posedge trigger)
        begin
            case(sel)
                2'b00 : begin
                    inc_secs = 1'b0;
                    inc_mins = 1'b0;
                    inc_hours = 1'b0;
                end
                2'b01 : begin
                    inc_secs = 1'b1;
                    inc_mins = 1'b0;
                    inc_hours = 1'b0;
                end
                2'b10 : begin
                    inc_secs = 1'b0;
                    inc_mins = 1'b1;
                    inc_hours = 1'b0;
                end
                2'b11 : begin
                    inc_secs = 1'b0;
                    inc_mins = 1'b0;
                    inc_hours = 1'b1;
                end
            endcase
        end
    always@(negedge trigger)
    begin
        inc_secs = 1'b0;
        inc_mins = 1'b0;
        inc_hours = 1'b0;
    end
endmodule

module slowClock(
input clk, 
input reset,
output clk_1Hz, 
output clk_1024Hz
);


reg clk_1Hz;
reg clk_1024Hz;
reg [27:0] counter; //Needs to be large enough to fit 80M
reg [27:0] counter2;
//parameter num_ticks = 5000000; //Number of clk ticks you want //THIS IS FOR 10MHz
parameter num_ticks = 5; //Number of clk ticks you want
//For 1Hz from an 80MHz clock, num_ticks=40,000,000 aka
//half of total frequency b/c 50% duty cycle, 1 pos edge 
//per second.
parameter num_ticks_2=2; //4882 for 10MHz

  always@(posedge clk) //posedge reset
begin
    if (reset)
        begin
            clk_1Hz <= 0;
            clk_1024Hz <= 0;
            counter <= 0;
            counter2 <= 0;
        end
    else
        begin
            counter <= counter + 1;
            counter2 <= counter2 + 1;
          if (counter2 == num_ticks_2-1)
              begin
                   counter2 <= 0;
                   clk_1024Hz <= ~clk_1024Hz;
              end
          if ( counter == num_ticks-1) //minus 1 to account for transistion
                begin
                    counter <= 0;
                    clk_1Hz <= ~clk_1Hz;
                end
        end
end
endmodule   

module mode_processor(
  input clk, //1024Hz
  input [1:0] mode,
  input reset,
  output reg led
);

  reg clk_4Hz;
  reg [10:0] counter;
  reg clk_div1;
  reg clk_div2;
  reg clk_div4;

  parameter num_ticks = 256;
always@(posedge reset or posedge clk)
begin
    if (reset)
        begin
            clk_4Hz <= 0;
            counter <= 0;
            clk_div1 <= 0;
            clk_div2 <= 0;
            clk_div4 <= 0;
            led <= 0;
        end
    else
        begin
            counter <= counter + 1;

          if ( counter == num_ticks-1) //minus 1 to account for transistion
                begin
                    counter <= 0;
                    clk_4Hz <= ~clk_4Hz;
                end
        end
end

  // simple ripple clock divider
  always @(mode)
        begin
          case(mode)
                0 : begin
                    led = 0;
                end
                1 : begin
                    led = clk_div4;
                end
                2 : begin
                    led = clk_div2;
                end
                3 : begin
                    led = clk_4Hz;
                end
            endcase
        end

  always @(posedge clk_4Hz)
    clk_div2 <= ~clk_div2;

  always @(posedge clk_div2)
    clk_div4 <= ~clk_div4;


endmodule

module output_mux6x6 (
  input [11:0] hours, 
  input [11:0] mins_coarse, 
  input [11:0] secs_coarse,
  input clk, 
  input reset, //clk should be suitable refresh rate for led matrix
              // should be 6 times the target refresh for a single led
  
  output reg [5:0] rows,
  output reg [5:0] columns

);
  wire [5:0] row_next;
  always@(posedge clk, posedge reset)
    begin 
      if (reset == 1'b1)
      begin
        rows <= 6'b100000;
        columns <= 6'b000000;
      end
      else
        rows <= row_next;
    end
  //assign r_next = {r_reg[0], r_reg[N-1:1]};
  assign row_next = {rows[0],rows[5:1]};

  always@(posedge clk)
    begin 
      case(rows)
        6'b000001 : begin //first half of hours
          columns <= hours[11:6];
        end
        6'b100000 : begin
          columns <= hours[5:0];
        end
        6'b010000 : begin
          columns <= mins_coarse[11:6];
        end
        6'b001000 : begin
          columns <= mins_coarse[5:0];
        end
        6'b000100 : begin 
          columns <= secs_coarse[11:6];
        end
        6'b000010 : begin
          columns <= secs_coarse[5:0];
        end
        default : begin
          columns <= 6'b000000;
        end
      endcase
    end
  
  
endmodule

module output_mux2x4 ( 
  input [3:0] mins_fine, 
  input [3:0] secs_fine,
  input clk, 
  input reset, //clk should be suitable refresh rate for led matrix
              // should be 6 times the target refresh for a single led
  
  output reg [1:0] row,
  output reg [3:0] columns

);
  wire [1:0] row_next;
  always@(posedge clk, posedge reset)
    begin 
      if (reset == 1'b1)
      begin
        row <= 2'b10;
        columns <= 4'b0000;
      end
      else 
        row <= row_next;
    end
  assign row_next = {row[0],row[1]};
  always@(posedge clk)
    begin 
      case(row)
        2'b10 : begin //first half of hours
          columns <= mins_fine[3:0];
        end
        2'b01 : begin
          columns <= secs_fine[3:0];
        end
        default : begin
          columns <= 4'b0000;
        end
      endcase
    end
  
  
endmodule

`default_nettype wire
