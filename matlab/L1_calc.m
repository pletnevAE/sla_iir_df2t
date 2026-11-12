%================================================================================
% This script calculates the L1 norm for SLA IIR sections and determines
% the lengths of the integer and fractional parts of the states and length
% of the integer part of the output
%================================================================================
function [IL_y_out, IL_state_out, FL_state_out] = L1_calc(b_fix, a_fix, N_imp, M, num_sections)
    %================================================================================
    %% Converting Fixed-Point to double
    %================================================================================
    b_double = double(b_fix); % Numerator Fixed-Point to double
    a_double = zeros(num_sections, 2 * M + 1); % Denominator matrix
    a_double(:,1) = 1; % First coefficient
    a_double(:,2:end) = double(a_fix); % Denominator Fixed-Point to double
    
    %================================================================================
    %% L1-Norm calculation (DF2T)
    %================================================================================
    TARGET_SQNR_DB = 80; % Required SQNR
    x_imp = [1, zeros(1, N_imp - 1)]; % Delta function
    L1_s = zeros(2 * M + 1, num_sections); % L1 matrix
    IL_s = zeros(2 * M + 1, num_sections); % Integer length matrix
    for i = 1 : num_sections
        y_imp(i,:) = filter(b_double(i,:), a_double(i,:), x_imp); % Impulse response of a filter section
        s = zeros(2 * M + 1, N_imp); % Internal states of the filter section upon application of a Dirac delta function
        for n = 1 : N_imp
            y_val = y_imp(i, n);
            x_val = x_imp(n);
            s(end, n) = b_double(i, end) * x_val - a_double(i, end) * y_val;
            if (n > 1)
                for k = 1 : 2 * M
                    if (k ~= 2 * M)
                        s(end - k, n) = b_double(i, end - k) * x_val - a_double(i, end - k) * y_val + s(end - k + 1,n - 1);
                    else
                        s(end - k, n) = b_double(i, end - k) * x_val + s(end - k + 1,n - 1);
                    end
                end
            else
                for k = 1 : 2 * M
                    if (k ~= 2 * M)
                        s(end - k, n) = b_double(i, end - k) * x_val - a_double(i, end - k) * y_val;
                    else
                        s(end - k, n) = b_double(i, end - k + 1) * x_val;
                    end
                end
            end
        end
        
        % L1-norms calculation
        L1_y(i) = sum(abs(y_imp(i,:)));
        for k = 2 * M + 1 : -1 : 1
            L1_s(k,i) = sum(abs(s(k,:)));
        end
        
        % Integer length calculation
        for k = 2 * M + 1 : -1 : 1
            IL_s(k, i) = ceil(log2(L1_s(k, i))) + 1;
        end
        IL_y(i) = ceil(log2(L1_y(i))) + 1;
        IL_state(i) = max(IL_s(:, i)); % State integer length for section
        
        %================================================================================
        %% Calculation of the fractional length based on the required precision
        %================================================================================
        [h_noise, ~] = impz(1, a_double(i, :), N_imp); % Quantization noise transfer function from states to the output
        L2_noise_power(i) = sum(h_noise.^2); % Noise power
        P_signal = 0.5; % For sin
        P_noise_target(i) = P_signal / (10^(TARGET_SQNR_DB / 10));
        N_convert = 2 * M + 1; % Number of conversion blocks in the section
        q2_target(i) = (12 * P_noise_target(i)) / (N_convert * L2_noise_power(i)); % Total noise power of N conversion blocks
        FL_state(i) = ceil(-0.5 * log2(q2_target(i))); % State fraction length for section
    end
    
    IL_y_out = max(IL_y); % Section input/output integer length
    IL_state_out = max(IL_state); % State integer length
    FL_state_out = max(FL_state); % State fraction length

end