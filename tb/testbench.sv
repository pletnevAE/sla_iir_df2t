//=====================================================================================
// 		IIR Testbench Module
//
//			The module is used to feed the stimulus signal to the IIR SystemVerilog
//			module being verified. The module output signal are written to
//			separate file using the enable signal.
//
//=====================================================================================
`timescale 1 ns / 1 ps
`include "iir_params.vh"

module testbench;

//=====================================================================================
// Testbench parameters
//=====================================================================================
parameter N_SEC = ORDER / 2; // Number of sections
parameter IN_WL = INPUT_WL; // Input word length
parameter IN_FL = INPUT_FL; // Input fraction length
parameter OUT_WL = OUTPUT_WL; // Output word length
parameter OUT_FL = OUTPUT_FL; // Output fraction length
parameter SEC_IN_WL = SEC_INPUT_WL; // Section input word length
parameter SEC_IN_FL = SEC_INPUT_FL; // Section input fraction length
parameter SEC_OUT_WL = SEC_OUTPUT_WL; // Section output word length
parameter SEC_OUT_FL = SEC_OUTPUT_FL; // Section output fraction length
parameter STATE_WL = STATE_IIR_WL; // State word length
parameter STATE_FL = STATE_IIR_FL; // State fraction length
parameter COEFF_WL = COEFFICIENT_WL; // Coefficients word length
parameter COEFF_NUM_FL = COEFFICIENT_NUM_FL; // Numerator fraction length
parameter COEFF_DENOM_FL = COEFFICIENT_DENOM_FL; // Denominator fraction length
parameter SCALE_FL = COEFFICIENT_SCALE_FL; // Scale values fraction length
parameter MULT_WL = PROD_WL; // Product word length
parameter MULT_NUM_FL = PROD_NUM_FL; // Product Numerator fraction length
parameter MULT_DENOM_FL = PROD_DENOM_FL; // Product Denominator fraction length
parameter ACC_WL = ACCUM_WL; // Accumulator word length
parameter ACC_NUM_FL = ACCUM_NUM_FL; // Accumulator Numerator fraction length
parameter ACC_DENOM_FL = ACCUM_DENOM_FL; // Accumlulator Denominator fraction length
parameter OUT_MULT = OUT_MULTIPLIER;
parameter ROUND_MODE = 2;
parameter CLK_PERIOD = 1_000_000_000 / F_CLK; // Clock period
parameter CLK_ENABLE_DIV = CLK_EN_DIV; // Division factor for the clock enable
parameter RESET_CYCLES = 10; // Reset cycles
parameter NUM_SAMPLES = SIN_NUM_SAMPLES; // Number of stimulus samples

//=====================================================================================
// Testbench signals
//=====================================================================================	
logic clk; // Clock
logic rst_n; // Reset
logic valid_in; // Input data valid
logic signed [IN_WL - 1:0] data_in; // Input data
logic valid_out; // Output data valid
logic signed [OUT_WL - 1:0] data_out; // Output data

integer clk_cnt = 0; // Clock counter
integer stim_file; // Stimulus file descriptor
integer scanf_ret;
integer value; // Read sample
integer stim_values [$]; // Storage for Stimulus
integer out_file_iir; // Output file descriptor
integer sample_idx; // Storage index
integer sample_wr_cnt = 0; // Output write counter

//=====================================================================================
// IIR Instantiation
//=====================================================================================
SLA_IIR 
#(
	.N_SEC(N_SEC),
	.IN_WL(IN_WL),
	.IN_FL(IN_FL),
	.OUT_WL(OUT_WL),
	.OUT_FL(OUT_FL),
	.SEC_IN_WL(SEC_IN_WL),
	.SEC_IN_FL(SEC_IN_FL),
	.SEC_OUT_WL(SEC_OUT_WL),
	.SEC_OUT_FL(SEC_OUT_FL),
	.STATE_WL(STATE_WL),
	.STATE_FL(STATE_FL),
	.COEFF_WL(COEFF_WL),
	.COEFF_NUM_FL(COEFF_NUM_FL),
	.COEFF_DENOM_FL(COEFF_DENOM_FL),
	.SCALE_FL(SCALE_FL),
	.MULT_WL(MULT_WL),
	.MULT_NUM_FL(MULT_NUM_FL),
	.MULT_DENOM_FL(MULT_DENOM_FL),
	.ACC_WL(ACC_WL),
	.ACC_NUM_FL(ACC_NUM_FL),
	.ACC_DENOM_FL(ACC_DENOM_FL),
	.OUT_MULT(OUT_MULT),
	.ROUND_MODE(ROUND_MODE)
	) dut
(
	.clk(clk),
	.rst_n(rst_n),
	.valid_in(valid_in),
	.data_in(data_in),
	.valid_out(valid_out),
	.data_out(data_out)
);

//=====================================================================================
// Clock signal generation
//=====================================================================================
initial begin
	clk = 0;
	forever clk = #(CLK_PERIOD/2) ~clk;
end

//=====================================================================================
// Clock Enable signal generation
//=====================================================================================
initial begin
	clk_cnt = 0;
	forever begin
		@(posedge clk);
		if (CLK_ENABLE_DIV > 1) begin
			clk_cnt  = (clk_cnt >= CLK_ENABLE_DIV - 1) ? '0 : clk_cnt + 1'b1;
		end
		else begin
			clk_cnt = 0;
		end
	end
end

assign valid_in = (CLK_ENABLE_DIV == 1) ? 1'b1 : (CLK_ENABLE_DIV  > 1 && clk_cnt == 0);

initial begin
//=====================================================================================
// Reading from a file
//=====================================================================================
	stim_file = $fopen("stimulus.txt", "r");
	if (stim_file == 0) begin
		$display("ERROR");
		$stop;
	end
	
	while (!$feof(stim_file)) begin
		scanf_ret = $fscanf(stim_file, "%d\n", value);
		if (scanf_ret == 1) begin
			stim_values.push_back(value);
		end
	end
	$fclose(stim_file);
	
	$display("Loaded %0d samples from stimulus.txt", stim_values.size());
	
//=====================================================================================
// Opening output file
//=====================================================================================
	out_file_iir = $fopen("output_iir.txt", "w");
	if (out_file_iir == 0) begin
		$display("ERROR");
		$stop;
	end
	
//=====================================================================================
// Starting value of signals	
//=====================================================================================
	rst_n = 1'b0;
	data_in = {IN_WL{1'b0}};
	sample_idx = 0;

//=====================================================================================
// Removing the reset	
//=====================================================================================
	repeat (RESET_CYCLES) @(posedge clk);
	#1;
	rst_n = 1'b1;
	
	while (sample_idx < stim_values.size()) begin
		if (valid_in) begin
			data_in = stim_values[sample_idx];
			sample_idx++;
		end
		@(posedge clk);
	end
	
	wait (sample_wr_cnt == stim_values.size());
	
	$display("Simulation finished.");
	$fclose(out_file_iir);
	$stop;
end

//=====================================================================================	
// Writing samples to a file
//=====================================================================================	
always @ (posedge clk) begin
	if (valid_out) begin
		$fwrite(out_file_iir, "%0d\n", data_out);
		sample_wr_cnt++;
	end
end

endmodule