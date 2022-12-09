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
    wire min_fine_to_min_coarse;
    wire min_coarse_to_hours;
    wire hours_dummy;

    //signals to increment our time registers
    wire inc_sec; 
    wire inc_min;
    wire inc_hour;

    //registers for storing time data
    wire [3:0] sec_fine;
    wire [11:0] sec_coarse;
    wire [3:0] min_fine;
    wire [11:0] min_coarse;
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
    wire change_mode; //this is for the positive edge detect module
    wire increment_demux; //this is for the positive edge detect module


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

    
    
    button_counter zeroto3counter(
      .clk(clk_1024Hz),
    	.trigger(change_mode), //Button input counter_trigger (use clk to test)
    	.reset(our_reset),  //our_reset
      .counter(count)
    );
  
  inc_demux oneto4demux(
        .clk(clk_1024Hz),
        .trigger(increment_demux), //Button input inc_demux_trigger
        .sel(count), //count
        .reset(our_reset),
        .inc_secs(inc_sec),
        .inc_mins(inc_min),
        .inc_hours(inc_hour)
    );
  
  fine_shift_register seconds_fine( 
       .clk(clk_1Hz),     //clk_1Hz
       .reset(our_reset),  //our_reset
       .increment(inc_sec),
       .r_reg(sec_fine),
       .s_out(sec_fine_to_sec_coarse)
    );
  
  coarse_shift_register seconds_coarse( 
      .clk(sec_fine_to_sec_coarse),
      .reset(our_reset),  //our_reset
      .increment(inc_min),
      .r_reg(sec_coarse),
      .s_out(sec_coarse_to_min_fine)
    );
  
  fine_shift_register minutes_fine( 
      .clk(sec_coarse_to_min_fine),
      .reset(our_reset),   //our_reset
      .increment(1'b0),
      .r_reg(min_fine),
      .s_out(min_fine_to_min_coarse)
    );
  coarse_shift_register minutes_coarse( 
      .clk(min_fine_to_min_coarse),
      .reset(our_reset),   //our_reset
      .increment(inc_hour),
      .r_reg(min_coarse),
      .s_out(min_coarse_to_hours)
      );
  coarse_shift_register hrs(
      .clk(min_coarse_to_hours),
      .reset(our_reset),  //our_reset
      .increment(1'b0),
      .r_reg(hours),
      .s_out(hours_dummy)
      );
  
  mode_processor mode_LED_processor (
        .clk(clk_1024Hz), //clk_1024Hz
        .mode(count),//count
        .reset(our_reset),  //our_reset
        .led(mode_led)
    );

  slowClock clock_stepdown (
        .clk(clk),
        .reset(our_reset), //our_reset
        .mode(count),
        .clk_1Hz(clk_1Hz),
        .clk_1024Hz(clk_1024Hz)
    );
  

  output_mux6x6 sixbysix(
        .hours(hours),
        .mins_coarse(min_coarse),
        .secs_coarse(sec_coarse),
        .clk(clk_1024Hz),
   	    .reset(our_reset), //our_reset
        .rows(rows6x6),
        .columns(columns6x6)
    );
  
  output_mux2x4 twobyfour(
        .mins_fine(min_fine), 
        .secs_fine(sec_fine),
        .clk(clk_1024Hz),
    	  .reset(our_reset), //our_reset
        .row(row2x4),
        .columns(columns2x4)
    );
  pos_edge_detect mode_button_processor(
    .button(counter_trigger),
    .clk(clk_1024Hz),
    .reset(our_reset),
    .pulse(change_mode)
  );

  pos_edge_detect increment_button_processor(
    .button(inc_demux_trigger),
    .clk(clk_1024Hz),
    .reset(our_reset),
    .pulse(increment_demux)
  );
endmodule

module pos_edge_detect (
  input button, //change mode button
  input clk,
  input reset,
  output wire pulse
);
  reg [63:0] delay;

  always @(posedge clk or posedge reset)
    begin
      if (reset)
        delay <= 64'b0;
      else
        delay <= {delay[62:0], button}; //r_reg[0], r_reg[N-1:1]  
    end
  //assign pulse = (delay[62:0] == 63'h7FFFFFFFFFFFFFFF) ? ~delay[63] : 1'b0;
    assign pulse = (delay[62:0] == {63{1'b1}}) ? ~delay[63] : 1'b0;  

  
endmodule



module fine_shift_register
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
   
 
  always @(posedge clk or posedge reset) // or posedge increment
   begin
      if (reset)
	      begin
         r_reg <= 4'b0;
     	   start <= 1'b0;
        end
      else if (r_reg[0] == 1'b1)   
        r_reg <= 4'b0;
      else
        begin
         r_reg <= r_next;
         start <= 1'b1;
        end
      
	end	
 
  assign r_next = {1'b1, r_reg[N-1:1]};
  
  assign s_out = (~r_reg[3] & ~reset & start) | increment;
  

endmodule



module coarse_shift_register
  #(parameter N=12)//100000000000, 
   (
    input wire clk,
    input wire reset,
    input wire increment,
    output reg [N-1:0] r_reg,
    output wire s_out
   );
 
   wire [N-1:0] r_next;
   reg start;
 
  always @(posedge clk or posedge reset) // or posedge increment
   begin
      if (reset)
        begin
         r_reg <= 12'b100000000000;
         start <=1'b0;
        end
      else
        begin
         r_reg <= r_next;
         start <=1'b1;
        end
	end	
 
  assign r_next = {r_reg[0], r_reg[N-1:1]};
  assign s_out = (r_reg[11] & ~reset & start) | increment;
 
endmodule



module button_counter 
  #(parameter BITS = 2)
  (
    input wire trigger,
    input wire clk,
    input wire reset,
    output reg [BITS-1:0] counter
  );
    //reg [BITS-1:0] count;
    reg pressed;
    //reg [5:0] delay;
    /*
  always @(posedge reset or posedge clk) 
      begin
        if(reset)
          begin
          //delay <= 6'b0;
          counter <= 0;
          pressed <= 0;
          end
        else if (trigger)
          begin
            if(pressed == 1'b0)
              begin
              pressed <= 1'b1;
              counter <= counter+1;
              end
            
          //delay <= delay + 1;
          end
        else if (delay == 6'b111111)
          begin
            delay <= 6'b0;
            pressed <= 1'b0;
          end
      end
      */
      always @(posedge reset or posedge clk)
        begin
          if (reset)
            begin
              counter <= 0;
              pressed <= 0;
            end
          else if (trigger)
            begin
              if (pressed == 1'b0)
                begin
                  pressed <= 1'b1;
                end
            end
          else
            begin
              if (pressed == 1'b1)
                begin
                  counter <= counter + 1;
                  pressed <= 1'b0;
                end
            end
            
        end

endmodule



module inc_demux (
    input wire trigger,
    input wire clk,
    input [1:0] sel,  //mode 0 = nothing, mode 1 = hours, mode 2 = mins, mode 3 = secs
    input wire reset,
    output reg inc_secs,
    output reg inc_mins,
    output reg inc_hours
);
  
  /*
  reg pressed;
  reg [5:0] delay;
  always @(posedge clk or posedge reset)
    begin
      if (reset)
      begin
        pressed <= 0;
        delay <= 6'b0;
        inc_secs <= 1'b0;
        inc_mins <= 1'b0;
        inc_hours <= 1'b0;
      end
      else if (trigger)
          begin
            if(pressed == 1'b0)
              begin
              pressed <= 1'b1;
              case(sel)
                2'b00 : begin
                    inc_secs <= 1'b0;
                    inc_mins <= 1'b0;
                    inc_hours <= 1'b0;
                end
                2'b01 : begin
                    inc_secs <= 1'b1;
                    inc_mins <= 1'b0;
                    inc_hours <= 1'b0;
                end
                2'b10 : begin
                    inc_secs <= 1'b0;
                    inc_mins <= 1'b1;
                    inc_hours <= 1'b0;
                end
                2'b11 : begin
                    inc_secs <= 1'b0;
                    inc_mins <= 1'b0;
                    inc_hours <= 1'b1;
                end
              endcase
              end
            else
              delay <= delay + 1;
            end
        else if (delay == 6'b111111)
          begin
            delay <= 6'b0;
            pressed <= 1'b0;
            inc_secs <= 1'b0;
            inc_mins <= 1'b0;
            inc_hours <= 1'b0;
          end
          
    end
  */
  reg pressed;
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      begin
        pressed <= 0;
        inc_secs <= 1'b0;
        inc_mins <= 1'b0;
        inc_hours <= 1'b0;
      end
    else if (trigger)
      begin
        if(pressed == 1'b0)
          begin
            pressed <= 1'b1;
          end
      end
    else
      begin
        if (pressed == 1'b1)
          begin
            case(sel)
                2'b00 : begin
                    inc_secs <= 1'b0;
                    inc_mins <= 1'b0;
                    inc_hours <= 1'b0;
                end
                2'b01 : begin
                    inc_secs <= 1'b1;
                    inc_mins <= 1'b0;
                    inc_hours <= 1'b0;
                end
                2'b10 : begin
                    inc_secs <= 1'b0;
                    inc_mins <= 1'b1;
                    inc_hours <= 1'b0;
                end
                2'b11 : begin
                    inc_secs <= 1'b0;
                    inc_mins <= 1'b0;
                    inc_hours <= 1'b1;
                end
              endcase
              pressed = 1'b0;
          end
        else
          begin
            inc_secs <= 1'b0; 
            inc_mins <= 1'b0;
            inc_hours <= 1'b0;
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

    wire clk_4Hz_flip = (counter == (num_ticks - 1));

    always @(posedge clk or posedge reset) 
        if (reset)
            counter <= 11'b0;
        else if(clk_4Hz_flip)
            counter <= 11'b0;
        else 
            counter <= counter + 1'b1; 
    
    always @(posedge clk or posedge reset) 
        if (reset)
            clk_4Hz <= 0;
        else if(clk_4Hz_flip) 
            clk_4Hz <= ~clk_4Hz;  
  
    always @(mode)
        case(mode)
            0 : begin
                led = 1'b0;
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

    always @(posedge clk_4Hz or posedge reset) 
        if (reset)
            clk_div2 <= 1'b0;
        else
            clk_div2 <= ~clk_div2;

    always @(posedge clk_div2 or posedge reset) 
        if (reset)
            clk_div4 <= 1'b0;
        else
            clk_div4 <= ~clk_div4;

endmodule


module slowClock(
    input clk, 
    input reset,
    input [1:0] mode,
    output clk_1Hz, 
    output clk_1024Hz
);

reg         clk_1Hz;
reg         clk_1024Hz;
reg [27:0]  counter;        //Needs to be large enough to fit 80M
reg [27:0]  counter2;

parameter num_ticks = 5000000; //Number of clk ticks you want //THIS IS FOR 10MHz
//parameter num_ticks = 5; //Number of clk ticks you want
// For 1Hz from an 80MHz clock, num_ticks=40,000,000 aka
// half of total frequency b/c 50% duty cycle, 1 pos edge 
// per second.
//parameter num_ticks_2 = 2; //4882 for 10MHz
parameter num_ticks_2 = 4882; //4882 for 10MHz

wire clk_1024Hz_flip    = (counter2 == (num_ticks_2 - 1));
wire clk_1Hz_flip       = (counter == (num_ticks-1));

always @(posedge clk or posedge reset)
    if(reset)
        counter <= 0;
    else if(clk_1Hz_flip)
        counter <= 0;
    else  
        counter <= counter + 1'b1;

always @(posedge clk or posedge reset)
    if(reset)
        counter2 <= 0;
    else if(clk_1024Hz_flip)
        counter2 <= 0;
    else 
        counter2 <= counter2 + 1'b1;

always @(posedge clk or posedge reset)
    if(reset)
        clk_1024Hz <= 0;
    else if(clk_1024Hz_flip)
        clk_1024Hz <= ~clk_1024Hz;

always @(posedge clk or posedge reset)
    if(reset) //|| mode >= 2
        clk_1Hz <= 0;
    else if(clk_1Hz_flip)
        clk_1Hz <= ~clk_1Hz;

endmodule




module output_mux6x6 (
  input [11:0] hours, 
  input [11:0] mins_coarse, 
  input [11:0] secs_coarse,
  input wire clk, 
  input wire reset, 
  output reg [5:0] rows,
  output reg [5:0] columns

);
  wire [5:0] row_next;
  always@(posedge clk or posedge reset)
    begin 
      if (reset)
      begin
        rows <= 6'b100000;
        columns <= 6'b000000;
      end
      else
        begin
          rows <= row_next;
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
    end
  //assign r_next = {r_reg[0], r_reg[N-1:1]};
  assign row_next = {rows[0],rows[5:1]};
endmodule



module output_mux2x4 ( 
  input [3:0] mins_fine, 
  input [3:0] secs_fine,
  input wire clk, 
  input wire reset,
  output reg [1:0] row,
  output reg [3:0] columns

);
  wire [1:0] row_next;
  always@(posedge clk or posedge reset)
    begin 
      if (reset)
      begin
        row <= 2'b10;
        columns <= 4'b0000;
      end
      else 
      begin
        row <= row_next;
        case(row)
          2'b10 : begin 
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
    end
  assign row_next = {row[0],row[1]};
  
endmodule

`default_nettype wire
