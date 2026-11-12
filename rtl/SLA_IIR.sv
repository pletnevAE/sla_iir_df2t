//=====================================================================================
// 		Scattered look-ahead Direct Form II Transposed IIR
//
//			Parameters:
//				N_SEC - number of coefficients
//				IN_WL - input word length
//				IN_FL - input fraction length
//				OUT_WL - output word length
//				OUT_FL - output fraction length
//				SEC_IN_WL - section input word length
//				SEC_IN_FL - section input fraction length
//				SEC_OUT_WL - section output word length
//				SEC_OUT_FL - section output fraction length
//				STATE_WL - state word length
//				STATE_FL - state fraction length
//				COEFF_WL - coefficients word length
//				COEFF_NUM_FL - numerator fraction length
//				COEFF_DENOM_FL - denominator fraction length
//				SCALE_FL - scale values fraction length
//				MULT_WL - product word length
//				MULT_NUM_FL - product numerator fraction length
//				MULT_DENOM_FL - product denominator fraction length
//				ACC_WL - accumulator word length
//				ACC_NUM_FL - accumulator numerator fraction length
//				ACC_DENOM_FL - accumlulator denominator fraction length
//				OUT_MULT - activation of the output multiplier (0 - No, 1 - Yes)
//				ROUND_MODE - rounding method (0 - Truncation, 1 - Nearest 2 - Convergent)
//
//			Control Signals:
//				clk - clock signal
//				rst_n – reset (Active-Low)
//				valid_in - input data valid
//				valid_out - output data valid
//
//			Data:
//				data_in - input data
//				data_out - output data
//=====================================================================================
`include "iir_params.vh"

module SLA_IIR
#(
	parameter N_SEC = ORDER / 2, // Number of sections
	parameter IN_WL = INPUT_WL, // Input word length
	parameter IN_FL = INPUT_FL, // Input fraction length
	parameter OUT_WL = OUTPUT_WL, // Output word length
	parameter OUT_FL = OUTPUT_FL, // Output fraction length
	parameter SEC_IN_WL = SEC_INPUT_WL, // Section input word length
	parameter SEC_IN_FL = SEC_INPUT_FL, // Section input fraction length
	parameter SEC_OUT_WL = SEC_OUTPUT_WL, // Section output word length
	parameter SEC_OUT_FL = SEC_OUTPUT_FL, // Section output fraction length
	parameter STATE_WL = STATE_IIR_WL, // State word length
	parameter STATE_FL = STATE_IIR_FL, // State fraction length
	parameter COEFF_WL = COEFFICIENT_WL, // Coefficients word length
	parameter COEFF_NUM_FL = COEFFICIENT_NUM_FL, // Numerator fraction length
	parameter COEFF_DENOM_FL = COEFFICIENT_DENOM_FL, // Denominator fraction length
	parameter SCALE_FL = COEFFICIENT_SCALE_FL, // Scale values fraction length
	parameter MULT_WL = PROD_WL, // Product word length
	parameter MULT_NUM_FL = PROD_NUM_FL, // Product Numerator fraction length
	parameter MULT_DENOM_FL = PROD_DENOM_FL, // Product Denominator fraction length
	parameter ACC_WL = ACCUM_WL, // Accumulator word length
	parameter ACC_NUM_FL = ACCUM_NUM_FL, // Accumulator Numerator fraction length
	parameter ACC_DENOM_FL = ACCUM_DENOM_FL, // Accumlulator Denominator fraction length
	parameter OUT_MULT = OUT_MULTIPLIER, // Activation of the output multiplier
	parameter ROUND_MODE = 2 // Rounding method
)
(
	input clk, // Clock
	input rst_n, // Reset
	input valid_in, // Input data valid
	input signed [IN_WL - 1:0] data_in, // Input data
	output logic valid_out, // Output data valid
	output logic signed [OUT_WL - 1:0] data_out // Output data
);

localparam TOTAL_LATENCY = 3 * N_SEC; // Total pipeline delay

logic signed [COEFF_WL - 1:0] b_rom [4 * N_SEC - 1:0]; // Numerator
logic signed [COEFF_WL - 1:0] a_rom [2 * N_SEC - 1:0]; // Denominator
logic signed [COEFF_WL - 1:0] s_rom [(OUT_MULT ? N_SEC : N_SEC - 1):0]; // Scale values
logic signed [COEFF_WL - 1:0] b [4 * N_SEC - 1:0]; // Numerator
logic signed [COEFF_WL - 1:0] a [2 * N_SEC - 1:0]; // Denominator
logic signed [COEFF_WL - 1:0] s [(OUT_MULT ? N_SEC : N_SEC - 1):0]; // Scale values
logic signed [SEC_IN_WL - 1:0] sec_data_in [0:N_SEC - 1]; // Section input data
logic signed [SEC_OUT_WL - 1:0] sec_data_out [0:N_SEC - 2]; // Section output data
logic [TOTAL_LATENCY - 1:0] valid_pipe; // Pipeline for valid signal

//=====================================================================================
// Initialization of Coefficients
//=====================================================================================
initial begin
	$readmemh("b_coeffs.txt", b_rom);
	$readmemh("a_coeffs.txt", a_rom);
	$readmemh("scale_coeffs.txt", s_rom);
end

assign b = b_rom;
assign a = a_rom;
assign s = s_rom;

genvar i;
generate
	for (i = 0; i < N_SEC; i++) begin : g_sec
//-------------------------------------------------------------------------------------
// Data scale for first section
		if (i == 0) begin : g_first_sec_data
			scale_data #(.IN_WL(IN_WL), .IN_FL(IN_FL), .OUT_WL(SEC_IN_WL), .OUT_FL(SEC_IN_FL), .COEFF_WL(COEFF_WL), .COEFF_FL(SCALE_FL), .ROUND_MODE(ROUND_MODE)) u_scale
			(
				.clk(clk),
				.rst_n(rst_n),
				.valid_in(valid_in),
				.scale_val(s[i]),
				.data_in(data_in),
				.data_out(sec_data_in[i])
			);
		end
//-------------------------------------------------------------------------------------
// Data scale for other sections
		else begin : g_other_sec_data
			scale_data #(.IN_WL(SEC_OUT_WL), .IN_FL(SEC_OUT_FL), .OUT_WL(SEC_IN_WL), .OUT_FL(SEC_IN_FL), .COEFF_WL(COEFF_WL), .COEFF_FL(SCALE_FL), .ROUND_MODE(ROUND_MODE)) u_scale
			(
				.clk(clk),
				.rst_n(rst_n),
				.valid_in(valid_in),
				.scale_val(s[i]),
				.data_in(sec_data_out[i - 1]),
				.data_out(sec_data_in[i])
			);
		end
//-------------------------------------------------------------------------------------
// All IIR sections except the last one
		if (i != N_SEC - 1) begin : g_other_sec		
			iir_sec_df2t
			#( 
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
				.MULT_WL(MULT_WL), 
				.MULT_NUM_FL(MULT_NUM_FL), 
				.MULT_DENOM_FL(MULT_DENOM_FL), 
				.ACC_WL(ACC_WL), 
				.ACC_NUM_FL(ACC_NUM_FL), 
				.ACC_DENOM_FL(ACC_DENOM_FL),
				.ROUND_MODE(ROUND_MODE),
				.LAST_SEC(0),
				.OUT_MULT(OUT_MULT)) u_iir_sec
			(
				.clk(clk),
				.rst_n(rst_n),
				.valid_in(valid_in),
				.b(b[4 * (i + 1) - 1:i * 4]),
				.a(a[2 * (i + 1) - 1:i * 2]),
				.data_in(sec_data_in[i]),
				.data_out(sec_data_out[i])
			);
		end
//-------------------------------------------------------------------------------------
// Last section
		else begin : g_last_sec
			logic signed [(!OUT_MULT ? OUT_WL : SEC_OUT_WL) - 1:0] last_sec_data_out;
			
			iir_sec_df2t
			#( 
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
				.MULT_WL(MULT_WL), 
				.MULT_NUM_FL(MULT_NUM_FL), 
				.MULT_DENOM_FL(MULT_DENOM_FL), 
				.ACC_WL(ACC_WL), 
				.ACC_NUM_FL(ACC_NUM_FL), 
				.ACC_DENOM_FL(ACC_DENOM_FL),
				.ROUND_MODE(ROUND_MODE),
				.LAST_SEC(1),
				.OUT_MULT(OUT_MULT)) u_iir_sec
			(
				.clk(clk),
				.rst_n(rst_n),
				.valid_in(valid_in),
				.b(b[4 * (i + 1) - 1:i * 4]),
				.a(a[2 * (i + 1) - 1:i * 2]),
				.data_in(sec_data_in[i]),
				.data_out(last_sec_data_out)
			);
//-------------------------------------------------------------------------------------
// Scaling the output of the last section			
			if (OUT_MULT) begin : g_out_scale
				scale_data #(.IN_WL(SEC_OUT_WL), .IN_FL(SEC_OUT_FL), .OUT_WL(OUT_WL), .OUT_FL(OUT_FL), .COEFF_WL(COEFF_WL), .COEFF_FL(SCALE_FL), .ROUND_MODE(ROUND_MODE)) u_scale
				(
					.clk(clk),
					.rst_n(rst_n),
					.valid_in(valid_in),
					.scale_val(s[N_SEC]),
					.data_in(last_sec_data_out),
					.data_out(data_out)
				);
			end
//-------------------------------------------------------------------------------------
// Unscales output of the last section
			else begin : g_out_not_scale
				assign data_out = last_sec_data_out;
			end
		end
	end
endgenerate

//=====================================================================================
// Output valid delay and syncronization with valid_in
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		valid_pipe <= {TOTAL_LATENCY{1'b0}};
	end
	else begin
		if (valid_in) begin
			valid_pipe <= {valid_pipe[TOTAL_LATENCY - 2:0], 1'b1};
		end
	end
end

assign valid_out = valid_in & valid_pipe[TOTAL_LATENCY - 1];

endmodule