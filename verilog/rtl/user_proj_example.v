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

module homegrown_watch #(
    parameter BITS = 2 //0 to 3 Counter
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    
    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,
    input rst,

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

    wire [BITS-1:0] count;

    wire counter_trigger;
    wire inc_demux_trigger;

    // WB MI A
    //assign valid = wbs_cyc_i && wbs_stb_i; 
    //assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    //assign wbs_dat_o = rdata;
    //assign wdata = wbs_dat_i;

    // IO
    assign io_out = count;
    //assign io_oeb = {(`MPRJ_IO_PADS-1){1'b0}};
    //assign io_oeb = {(`MPRJ_IO_PADS-1){1'b0}};
    assign io_oeb[10] = 1'b1;
    assign io_oeb[11] = 1'b1;
    assign io_oeb[12] = 1'b1;
    assign io_oeb[13] = 1'b1;

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



    counter #(
        .BITS(BITS)
    ) counter(
        .trigger(counter_trigger), //switch to IO pad later
        .reset(our_reset),
        .count(count)
    );

    inc_demux inc_demux(
        .trigger(inc_demux_trigger), //pass button in here
        .sel(count),
        .inc_secs(inc_secs),
        .inc_mins(inc_mins),
        .inc_hours(inc_hours)
    );

    fine_shift_register seconds_fine( 
        .clk(clk),
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

    fine_shift_register minutes_fine( 
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

module fine_shift_register
   #(parameter N=4)
   (
    input wire clk, reset, increment,
    output reg [N-1:0] r_reg,
    output wire s_out
   );
 
   wire [N-1:0] r_next;
 
 
   always @(posedge clk, posedge reset, posedge increment)
   begin
      if (reset)
         r_reg <= 4'b0;
      else
         r_reg <= r_next;
      if (r_reg[0] == 1'b1)   
        r_reg <= 4'b0;
	end	
 
	assign r_next = {1'b1, r_reg[N-1:1]};
	assign s_out = r_reg[0];
 
 
endmodule

module coarse_shift_register
    #(parameter N=12)//100000000000, 
   (
    input wire clk, reset, increment,
    output reg [N-1:0] r_reg,
    output wire s_out
   );
 
   wire [N-1:0] r_next;
 
 
   always @(posedge clk, posedge reset, posedge increment)
   begin
      if (reset)
         r_reg <= 12'b100000000000;
      else
         r_reg <= r_next;
	end	
 
	assign r_next = {r_reg[0], r_reg[N-1:1]};
	assign s_out = r_reg[0];
 
 
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

`default_nettype wire
