//=====================================================================================
// 		Data scaling module
//
//			Parameters:
//				IN_WL - input word length
//				IN_FL - input fraction length
//				OUT_WL - output word length
//				OUT_FL - output fraction length
//				COEFF_WL - scale values word length
//				COEFF_FL - scale values fraction length
//				ROUND_MODE - rounding method (0 - Truncation, 1 - Convergent, 2 - Nearest)
//
//			Control Signals:
//				clk - clock signal
//				rst_n – reset (Active-Low)
//				valid_in - input data valid
//
//			Data:
//				data_in - input data
//				scale_val - scale coefficient
//				data_out - output data
//=====================================================================================
module scale_data
#(
	parameter IN_WL = 16, // Input word length
	parameter IN_FL = 15, // Input fraction length
	parameter OUT_WL = 16, // Output word length
	parameter OUT_FL = 15, // Output fraction length
	parameter COEFF_WL = 16, // Scale values word length
	parameter COEFF_FL = 15, // Scale values fraction length
	parameter ROUND_MODE = 2 // Rounding method
)
(
	input clk, // Clock
	input rst_n, // Reset
	input valid_in, // Input data valid
	input signed [COEFF_WL - 1:0] scale_val, // Scale coefficient
	input signed [IN_WL - 1:0] data_in, // Input data
	output logic signed [OUT_WL - 1:0] data_out // Output data
);

localparam SCALE_PROD_WL = IN_WL + COEFF_WL; // Product word length
localparam SCALE_PROD_FL = IN_FL + COEFF_FL; // Product fraction length

(* multstyle = "dsp" *) logic signed [SCALE_PROD_WL - 1:0] x_scale_prod; // Scaled data with full precision
logic signed [OUT_WL - 1:0] x_scale; // Rounded scaled data

//=====================================================================================
// Rounding
//=====================================================================================
fp_resize_round #(.IN_WL(SCALE_PROD_WL), .IN_FL(SCALE_PROD_FL), .OUT_WL(OUT_WL), .OUT_FL(OUT_FL), .ROUND_MODE(ROUND_MODE), .SATURATE(0)) x_scale_round
(
	.data_in(x_scale_prod),
	.data_out(x_scale)
);

//=====================================================================================
// Output register
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		data_out <= {OUT_WL{1'b0}};
	end
	else begin
		if (valid_in) begin
			data_out <= x_scale;
		end
	end
end

//=====================================================================================
// Scaling
//=====================================================================================
assign x_scale_prod = data_in * scale_val;

endmodule