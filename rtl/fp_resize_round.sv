//=====================================================================================
// 		Rounding/extension and overflow handling module
//
//			Parameters:
//				IN_WL - input word length
//				IN_FL - input fraction length
//				OUT_WL - output word length
//				OUT_FL - output fraction length
//				ROUND_MODE - rounding method (0 - Truncation, 1 - Nearest 2 - Convergent)
//				SATURATE - overflow handling (0 - wrap-around, 1 - saturate)
//
//			Data:
//				data_in - input data
//				data_out - output data
//=====================================================================================
module fp_resize_round
#(
	parameter IN_WL = 16, // Input word length
	parameter IN_FL = 8, // Input fraction length
	parameter OUT_WL = 8, // Output word length
	parameter OUT_FL = 4, // Output fraction length
	parameter ROUND_MODE = 0, // Rounding method
	parameter SATURATE = 0 // Overflow handling
)
(
	input [IN_WL - 1:0] data_in, // Input data
	output logic [OUT_WL - 1:0] data_out // Output data
);

//=====================================================================================
// Conditional generation of the module structure
//=====================================================================================
generate
//-------------------------------------------------------------------------------------
// Bypass
	if (IN_WL == OUT_WL && IN_FL == OUT_FL) begin : g_bypass
		assign data_out = data_in;
	end
	else begin : g_process
		localparam V_INT_BITS = (IN_WL > IN_FL) ? (IN_WL - IN_FL) : 1; // Number of integer bits
		localparam V_WL = V_INT_BITS + IN_FL; // Full signed virtual bus width

		logic signed [V_WL - 1:0] v_data_in; // Signed virtual bus, full format
//=====================================================================================
// Fractional part correction
//=====================================================================================
//-------------------------------------------------------------------------------------
// Virtual extension of the sign
		if (IN_FL >= IN_WL) begin : g_virtual_ext
//-------------------------------------------------------------------------------------
// Extension of the integer part
			localparam PAD_BITS = IN_FL - IN_WL + 1; // Number of missing sign bits
			assign v_data_in = $signed({{PAD_BITS{data_in[IN_WL - 1]}}, data_in[IN_WL - 2:0]});
		end
//-------------------------------------------------------------------------------------
// Converting the input to a signed type without changing the width
		else begin : g_direct
			assign v_data_in = $signed(data_in);
		end
		
		localparam R_WL = (IN_FL >= OUT_FL) ? (V_WL - (IN_FL - OUT_FL) + 1) : (V_WL + (OUT_FL - IN_FL)); // Intermediate word length after processing the fractional part

		logic signed [R_WL:0] rounded_val; // Value after changing the fractional part
//-------------------------------------------------------------------------------------
// Reduction of the fraction length
		if (IN_FL > OUT_FL) begin : g_rounding
			localparam DROP_BITS = IN_FL - OUT_FL; // Fraction length delta
		
			logic round_bit; // Most significant dropped bit
			logic sticky_bits; // OR union of all the least significant dropped bits
			logic lsb_bit; // LSB to be stored
			
			assign round_bit = v_data_in[DROP_BITS - 1];
			assign lsb_bit = v_data_in[DROP_BITS];
//-------------------------------------------------------------------------------------
// Logical OR across all bits less significant than the round_bit
			if (DROP_BITS > 1) begin : g_sticky
				assign sticky_bits = |v_data_in[DROP_BITS - 2:0];
			end
//-------------------------------------------------------------------------------------
// No residual bits
			else begin : g_no_sticky
				assign sticky_bits = 1'b0;
			end
			
			logic add_one; // Flag for adding 1 to the LSB during rounding

//-------------------------------------------------------------------------------------
// Conditions for adding one to the LSB		
			always_comb begin
				case (ROUND_MODE)
					0 : add_one = 1'b0; // Truncation Mode
					1 : add_one = round_bit; // Nearest Mode
					2 : add_one = round_bit & (lsb_bit | sticky_bits); // Convergent Mode
					default : add_one = 1'b0; // Default state
				endcase
			end
			
			assign rounded_val = $signed(v_data_in[V_WL - 1:DROP_BITS]) + $signed({1'b0, add_one}); // Shifting the fractional part and adding rounding
		end
//-------------------------------------------------------------------------------------
// Increase in the fractional part
		else if (IN_FL < OUT_FL) begin : g_padding
			localparam PAD_BITS = OUT_FL - IN_FL; // Fraction length delta
			
			assign rounded_val = $signed({v_data_in, {PAD_BITS{1'b0}}}); // Zero Padding
		end
//-------------------------------------------------------------------------------------
// The bit depth does not change
		else begin : g_same_frac
			assign rounded_val = v_data_in;
		end
//=====================================================================================
// Integer part correction (saturate/overflow)
//=====================================================================================
		always_comb begin
//-------------------------------------------------------------------------------------
// Wrap-around
			if (!SATURATE) begin : g_no_saturate
				logic [OUT_WL - 1:0] full_res; // Result
				
				full_res = $signed(rounded_val);
				data_out = full_res;
			end
//-------------------------------------------------------------------------------------
// Saturate
			else begin : g_saturate
				localparam logic signed [OUT_WL - 1:0] MAX_POS = {1'b0, {(OUT_WL - 1){1'b1}}}; // Output max value
				localparam logic signed [OUT_WL - 1:0] MIN_NEG = {1'b1, {(OUT_WL - 1){1'b0}}}; // Output min value
				localparam CMP_WL = (R_WL > OUT_WL) ? R_WL : OUT_WL; // Max width for correct signed comparison
				
				logic signed [CMP_WL - 1:0] rounded_val_ext; // Sign extension of the processed value
				logic signed [CMP_WL - 1:0] max_pos_ext; // Sign extension of the MAX_POS
				logic signed [CMP_WL - 1:0] min_neg_ext; // Sign extension of the MIN_NEG
				logic is_overflow; // Positive overflow
				logic is_underflow; // Negative overflow
				
				rounded_val_ext = $signed(rounded_val);
				max_pos_ext = $signed(MAX_POS);	
				min_neg_ext = $signed(MIN_NEG);
			
				is_overflow = rounded_val_ext > max_pos_ext;
				is_underflow = rounded_val_ext < min_neg_ext;

//-------------------------------------------------------------------------------------
// Overflow		
				if (is_overflow) begin
					data_out = MAX_POS;
				end
//-------------------------------------------------------------------------------------
// Underflow
				else if (is_underflow) begin
					data_out = MIN_NEG;
				end
//-------------------------------------------------------------------------------------
// No overflow
				else begin
					data_out = rounded_val[OUT_WL - 1:0];
				end
			end
		end
	end
endgenerate

endmodule