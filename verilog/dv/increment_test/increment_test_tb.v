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

`timescale 1 ns / 1 ps

module increment_test_tb;
	reg clock;
	reg clk;
    reg RSTB;
	reg CSB;

	reg power1, power2;

	wire gpio;
	wire [37:0] mprj_io;
	reg increment_trigger;
	reg counter_trigger;
	reg our_reset;


	always #12.5 clock <= (clock === 1'b0);
	//always #1000 clk <= (clk === 1'b0);
	assign mprj_io[11] = clk;
	assign mprj_io[10] = counter_trigger;
	assign mprj_io[12] = increment_trigger;
	assign mprj_io[13] = our_reset;


	initial begin
		clock = 0;
		clk = 0;
		counter_trigger = 0;
		increment_trigger = 0;
		
	end

	// assign mprj_io[3] = 1'b1;

	initial begin
		$dumpfile("increment_test.vcd");
		$dumpvars(0, increment_test_tb);

		// Repeat cycles of 1000 clock edges as needed to complete testbench
		repeat (100) begin
			repeat (1000) @(posedge clock);
			$display("+1000 cycles");
		end
		$display("%c[1;31m",27);
		`ifdef GL
			$display ("Monitor: Timeout, Test LA (GL) Failed");
		`else
			$display ("Monitor: Timeout, Test LA (RTL) Failed");
		`endif
		$display("%c[0m",27);
		$finish;
	end

	initial begin

		#5000;
		increment_and_change_mode; //don't increment, change to mode 1
		#500;
		increment_and_change_mode; //increment seconds, change to mode 2
		#500;
		increment_and_change_mode; //increment minutes, change to mode 3
		#500;
		increment_and_change_mode; //increment hours, change to mode 0
		#1000;
		$finish;
	end

	task increment_and_change_mode;
		begin
			#100;
			increment_trigger = 1'b1; //increment seconds
			#100;
			increment_trigger = 1'b0;
			#100;
			counter_trigger = 1'b1; //change to mode 2
			#100;
			counter_trigger = 1'b0;
		end
	endtask
	initial begin
		RSTB <= 1'b1;
		#100;
		RSTB <= 1'b0;

		CSB  <= 1'b1;		// Force CSB high
		#200;
		RSTB <= 1'b1;	    	// Release reset

		#1700;
		CSB = 1'b0;		// CSB can be released

		our_reset <= 1'b0;
		#100;
		our_reset <= 1'b1;
		#100;
		our_reset <= 1'b0;
	end

	initial begin		// Power-up sequence
		power1 <= 1'b0;
		power2 <= 1'b0;
		#200;
		power1 <= 1'b1;
		#200;
		power2 <= 1'b1;
	end

	wire flash_csb;
	wire flash_clk;
	wire flash_io0;
	wire flash_io1;

	wire VDD1V8;
	wire VDD3V3;
	wire VSS;
    
	assign VDD3V3 = power1;
	assign VDD1V8 = power2;
	assign VSS = 1'b0;

	assign mprj_io[3] = 1;  // Force CSB high.
	//assign mprj_io[0] = 0;  // Disable debug mode

	caravel uut (
		.vddio	  (VDD3V3),
		.vddio_2  (VDD3V3),
		.vssio	  (VSS),
		.vssio_2  (VSS),
		.vdda	  (VDD3V3),
		.vssa	  (VSS),
		.vccd	  (VDD1V8),
		.vssd	  (VSS),
		.vdda1    (VDD3V3),
		.vdda1_2  (VDD3V3),
		.vdda2    (VDD3V3),
		.vssa1	  (VSS),
		.vssa1_2  (VSS),
		.vssa2	  (VSS),
		.vccd1	  (VDD1V8),
		.vccd2	  (VDD1V8),
		.vssd1	  (VSS),
		.vssd2	  (VSS),
		.clock    (clock),
		.gpio     (gpio),
		.mprj_io  (mprj_io),
		.flash_csb(flash_csb),
		.flash_clk(flash_clk),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.resetb	  (RSTB)
	);

	spiflash #(
		.FILENAME("increment_test.hex")
	) spiflash (
		.csb(flash_csb),
		.clk(flash_clk),
		.io0(flash_io0),
		.io1(flash_io1),
		.io2(),			// not used
		.io3()			// not used
	);


endmodule
`default_nettype wire
