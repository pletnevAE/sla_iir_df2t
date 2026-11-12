//=====================================================================================
// 		Direct Form II Transposed Section
//
//			Parameters:
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
//				ROUND_MODE - rounding method (0 - Truncation, 1 - Nearest 2 - Convergent)
//				LAST_SEC - IIR last section (0 - No, 1 - Yes)
//				OUT_MULT - activation of the output multiplier (0 - No, 1 - Yes)
//
//			Control Signals:
//				clk - clock signal
//				rst_n – reset (Active-Low)
//				valid_in - input data valid
//
//			Data:
//				b - numerator
//				a - denomenator
//				data_in - input data
//				data_out - output data
//=====================================================================================
module iir_sec_df2t
#(
	parameter OUT_WL = 16, // Output word length
	parameter OUT_FL = 10, // Output fraction length
	parameter SEC_IN_WL = 16, // Section input word length
	parameter SEC_IN_FL = 14, // Section input fraction length
	parameter SEC_OUT_WL = 16, // Section output word length
	parameter SEC_OUT_FL = 14, // Section output fraction length
	parameter STATE_WL = 20, // State word length
	parameter STATE_FL = 14, // State fraction length
	parameter COEFF_WL = 16, // Coefficients word length
	parameter COEFF_NUM_FL = 12, // Numerator fraction length
	parameter COEFF_DENOM_FL = 16, // Denominator fraction length
	parameter MULT_WL = 32, // Product word length
	parameter MULT_NUM_FL = 26, // Product Numerator fraction length
	parameter MULT_DENOM_FL = 30, // Product Denominator fraction length
	parameter ACC_WL = 37, // Accumulator word length
	parameter ACC_NUM_FL = 30, // Accumulator Numerator fraction length
	parameter ACC_DENOM_FL = 30, // Accumlulator Denominator fraction length
	parameter ROUND_MODE = 2, // Rounding method
	parameter LAST_SEC = 0, // IIR last section
	parameter OUT_MULT = 0 // Activation of the output multiplier
)
(
	input clk, // Clock
	input rst_n, // Reset
	input valid_in, // Input data valid
	input signed [COEFF_WL - 1:0] b [3:0], // Numerator
	input signed [COEFF_WL - 1:0] a [1:0], // Denominator
	input signed [SEC_IN_WL - 1:0] data_in, // Input data
	output logic signed [(LAST_SEC && !OUT_MULT ? OUT_WL : SEC_OUT_WL) - 1:0] data_out // Output data
);

logic signed [ACC_WL - 1:0] acc_to_cast [3:0]; // Accum. outputs to state size
logic signed [STATE_WL - 1:0] state [3:0]; // States
logic signed [STATE_WL - 1:0] state_reg [1:0]; // States regitsters
logic signed [STATE_WL - 1:0] state_num_cast [1:0], state_denom_cast [1:0]; // Accum. numerator/denominator rounded outputs
logic signed [ACC_WL - 1:0] state_resized [3:0]; // Resized states
(* multstyle = "dsp" *) logic signed [MULT_WL - 1:0] mult_denom [1:0]; // Feedback products
(* multstyle = "dsp" *) logic signed [MULT_WL - 1:0] mult_num [3:0]; // Feedforward products
logic signed [SEC_IN_WL - 1:0] data_in_reg; // Input data register
logic signed [MULT_WL - 1:0] mult_num_last; // Additional register for last feedforward product
logic signed [ACC_WL - 1:0] acc_denom [1:0]; // Feedback accumulators
logic signed [ACC_WL - 1:0] acc_num_reg; // Delay after feedforward accumulator
logic signed [ACC_WL - 1:0] acc_num [3:0]; // Feedforward accumulators
logic signed [ACC_WL - 1:0] data_num_resized [3:0]; // Data resize for feedforward accumulators
logic signed [SEC_OUT_WL - 1:0] data_out_cast; // Rounded output data
genvar j;

//=====================================================================================
// Feedforward products
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		for (int i = 0; i < 4; i++) begin
			mult_num[i] <= {MULT_WL{1'b0}};
		end
		mult_num_last <= {MULT_WL{1'b0}};
		data_in_reg <= {SEC_IN_WL{1'b0}};
	end
	else begin
		if (valid_in) begin
			for (int i = 0; i < 4; i++) begin
				if (i < 3) begin
					mult_num[i] <= data_in * b[i];
				end
				else begin
					mult_num_last <= data_in * b[i];
					mult_num[i] <= mult_num_last;
				end
			end
			data_in_reg <= data_in;
		end
	end
end

//=====================================================================================
// Feedback products
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		for (int i = 0; i < 2; i++) begin
			mult_denom[i] <= {MULT_WL{1'b0}};
		end
	end
	else begin
		if (valid_in) begin
			for (int i = 0; i < 2; i++) begin
				mult_denom[i] <= data_out_cast * a[i];
			end
		end
	end
end

//=====================================================================================
// Feedback accumulators
//=====================================================================================
generate
	if (ACC_NUM_FL > MULT_DENOM_FL) begin
		assign acc_denom[0] = acc_num_reg - (mult_denom[0] << ACC_NUM_FL - MULT_DENOM_FL);
	end
	else if (ACC_NUM_FL < MULT_DENOM_FL) begin
		assign acc_denom[0] = (acc_num_reg << MULT_DENOM_FL - ACC_NUM_FL) - mult_denom[0];
	end
	else begin
		assign acc_denom[0] = acc_num_reg - mult_denom[0];
	end
	
	if (MULT_NUM_FL > MULT_DENOM_FL) begin
		assign acc_denom[1] = mult_num[3] - (mult_denom[1] << MULT_NUM_FL - MULT_DENOM_FL);
	end
	else if (MULT_NUM_FL < MULT_DENOM_FL) begin
		assign acc_denom[1] = (mult_num[3] << MULT_DENOM_FL - MULT_NUM_FL) - mult_denom[1];
	end
	else begin
		assign acc_denom[1] = mult_num[3] - mult_denom[1];
	end
endgenerate

//=====================================================================================
// Feedforward accumulators
//=====================================================================================
generate
	for (j = 0; j < 4; j++) begin : g_numerator_accums
		fp_resize_round #(.IN_WL(STATE_WL), .IN_FL(STATE_FL), .OUT_WL(ACC_WL), .OUT_FL(ACC_NUM_FL), .ROUND_MODE(ROUND_MODE), .SATURATE(0)) state_resize
		(
			.data_in(state[j]),
			.data_out(state_resized[j])
		);
		
		if (j == 0) begin : g_first_accum
			fp_resize_round #(.IN_WL(SEC_IN_WL), .IN_FL(SEC_IN_FL), .OUT_WL(ACC_WL), .OUT_FL(ACC_NUM_FL), .ROUND_MODE(ROUND_MODE), .SATURATE(0)) data_in_resize
			(
				.data_in(data_in_reg),
				.data_out(data_num_resized[j])
			);
		end
		else begin : g_other_accums
			fp_resize_round #(.IN_WL(MULT_WL), .IN_FL(MULT_NUM_FL), .OUT_WL(ACC_WL), .OUT_FL(ACC_NUM_FL), .ROUND_MODE(ROUND_MODE), .SATURATE(0)) data_in_resize
			(
				.data_in(mult_num[j - 1]),
				.data_out(data_num_resized[j])
			);
		end
		
		assign acc_num[j] = data_num_resized[j] + state_resized[j];
	end
endgenerate

//=====================================================================================
// Delay after feedforward accumualtor (for acc_num[2])
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		acc_num_reg <= {ACC_WL{1'b0}};
	end
	else begin
		if (valid_in) begin
			acc_num_reg <= acc_num[2];
		end
	end
end

//=====================================================================================
// States rounding
//=====================================================================================
assign acc_to_cast[0] = acc_num[1];
assign acc_to_cast[1] = acc_denom[0];
assign acc_to_cast[2] = acc_num[3];
assign acc_to_cast[3] = acc_denom[1];

generate
	for (j = 0; j < 4; j++) begin : g_states_round
		if (j == 0 || j == 2) begin : g_acc_num_round
			fp_resize_round #(.IN_WL(ACC_WL), .IN_FL(ACC_NUM_FL), .OUT_WL(STATE_WL), .OUT_FL(STATE_FL), .ROUND_MODE(ROUND_MODE), .SATURATE(0)) state_round
			(
				.data_in(acc_to_cast[j]),
				.data_out(state_num_cast[j / 2])
			);
		end
		else begin : g_acc_denom_round
			fp_resize_round #(.IN_WL(ACC_WL), .IN_FL(ACC_DENOM_FL), .OUT_WL(STATE_WL), .OUT_FL(STATE_FL), .ROUND_MODE(ROUND_MODE), .SATURATE(0)) state_round
			(
				.data_in(acc_to_cast[j]),
				.data_out(state_denom_cast[j / 2])
			);
		end
	end
endgenerate

//=====================================================================================
// States registers
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		for (int i = 0; i < 2; i++) begin
			state_reg[i] <= {STATE_WL{1'b0}};
		end
	end
	else begin
		if (valid_in) begin
			for (int i = 0; i < 2; i++) begin
				state_reg[i] <= state_num_cast[i];
			end
		end
	end
end

//=====================================================================================
// States line formation
//=====================================================================================
always_comb begin
	for (int i = 0; i < 4; i++) begin
		if (i == 0 || i == 2) begin
			state[i] = state_reg[i / 2];
		end
		else begin
			state[i] = state_denom_cast[i / 2];
		end
	end
end

//=====================================================================================
// Output data rounding
//=====================================================================================
fp_resize_round #(.IN_WL(ACC_WL), .IN_FL(ACC_NUM_FL), .OUT_WL(SEC_OUT_WL), .OUT_FL(SEC_OUT_FL), .ROUND_MODE(ROUND_MODE), .SATURATE(0)) data_out_round
(
	.data_in(acc_num[0]),
	.data_out(data_out_cast)
);

//=====================================================================================
// Processing of section output data
//=====================================================================================
generate
	logic signed [(LAST_SEC && !OUT_MULT ? OUT_WL : SEC_OUT_WL) - 1:0] data_out_temp; // Temporary data storage
	logic signed [(LAST_SEC && !OUT_MULT ? OUT_WL : SEC_OUT_WL) - 1:0] data_out_rounded; // Rounded data
//=====================================================================================
// All IIR sections except the last one
//=====================================================================================
	if (!LAST_SEC) begin	: g_other_sec		
		always_ff @ (posedge clk, negedge rst_n) begin
			if (!rst_n) begin
				data_out_temp <= {SEC_OUT_WL{1'b0}};
			end
			else begin
				if (valid_in) begin
					data_out_temp <= data_out_cast;
				end
			end
		end
		
		assign data_out = data_out_temp;
	end
//=====================================================================================
// Last IIR section
//=====================================================================================
	else begin : g_last_sec
//=====================================================================================
// Output bypass
//=====================================================================================
		if (OUT_MULT) begin : g_out_scale
			assign data_out = data_out_cast;
		end
//=====================================================================================
// Without output scaling
//=====================================================================================
		else begin : g_out_not_scale
//-------------------------------------------------------------------------------------
// Rounding of output data	to IIR output lengths
			fp_resize_round #(.IN_WL(SEC_OUT_WL), .IN_FL(SEC_OUT_FL), .OUT_WL(OUT_WL), .OUT_FL(OUT_FL), .ROUND_MODE(ROUND_MODE), .SATURATE(0)) w0_round
			(
				.data_in(data_out_cast),
				.data_out(data_out_rounded)
			);
//-------------------------------------------------------------------------------------
// Output register			
			always_ff @ (posedge clk, negedge rst_n) begin
				if (!rst_n) begin
					data_out_temp <= {OUT_WL{1'b0}};
				end
				else begin
					if (valid_in) begin
						data_out_temp <= data_out_rounded;
					end
				end
			end
			
			assign data_out = data_out_temp;
		end
	end
endgenerate			

endmodule