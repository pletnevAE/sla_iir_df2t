%================================================================================
% This script calculates the SLA IIR filter coefficients, the bit depth of this 
% filter, and calculates the stimulus signal.
%================================================================================
function SLA_IIR_calc_auto(build_path, varargs)
    
    F_clk = 100e6; % Clock
    F_s = 100e6; % Sampling frequency
    filterType = 'lowpass'; % Filter Type
    filterApprox = 'butter'; % Design method ('butter' 'ellip', 'cheby1', 'cheby2')
    Fpass = 10e6; % Passband edge
    Fstop = 20e6; % Stopband edge
    Fpass1 = 10e6; % First Passband edge
    Fpass2 = 15e6; % Second Passband edge
    Fstop1 = 7e6; % First Stopband edge
    Fstop2 = 18e6; % Stopband edge
    Apass = 3; % Passband ripple in dB
    Astop = 30; % Stopband ripple in dB
    Apass1 = 0.1; % First Passband ripple in dB
    Apass2 = 0.1; % Second Passband ripple in dB
    Astop1 = 60; % First Stopband ripple in dB
    Astop2 = 60; % Second Stopband ripple in dB
    coeff_WL = 16; % Word lengths for coefficients
    in_WL = 16; % Word lengths for input signal
    in_FL = 15; % Fraction lengths for input signal
    out_WL = 16; % Word lengths for output signal
    out_FL = 15; % Fraction length for output signal
    s_in_WL = 16; % Section input word length
    s_out_WL = 16; % Section output word length
    out_file_a = build_path + "/a_coeffs.txt"; % Denominator coefficients file path
    out_file_b = build_path + "/b_coeffs.txt"; % Numerator coefficients file path
    out_file_scale = build_path + "/scale_coeffs.txt"; % Scale coefficients file path
    out_file_params = build_path + "/iir_params.vh"; % IIR parameters file path
    out_file_stimul = build_path + "/stimulus.txt"; % Stimulus file path
    num_format = 'hex'; % Coefficients representation format ('dec', 'hex', 'bin')
    
    if (F_s > F_clk)
        error('[ERROR] F_clk must be greater than or equal to F_s');
    elseif (mod(F_clk, F_s) ~= 0)
        error('[ERROR] F_clk must be divisible by F_s');
    end
    
    if ~isfolder(build_path)
        mkdir(build_path); % Build directory
    end

    %================================================================================
    %% Checking command line arguments
    %================================================================================
    for i = 1:2:length(varargs)
        flag = varargs{i};
        if (i + 1 <= length(varargs))
            val = varargs{i + 1};
            switch flag
                case '-F_CLK'
                    F_clk = str2double(val);
                case '-F_S'
                    F_s = str2double(val);
                case '-FILTER_TYPE'
                    filterType = val;
                case '-FILTER_APPROX'
                    filterApprox = val;
                case '-F_PASS'
                    Fpass = str2double(val);
                case '-F_STOP'
                    Fstop = str2double(val);
                case '-F_PASS1'
                    Fpass1 = str2double(val);
                case '-F_PASS2'
                    Fpass2 = str2double(val);
                case '-F_STOP1'
                    Fstop1 = str2double(val);
                case '-F_STOP2'
                    Fstop2 = str2double(val);
                case '-A_PASS'
                    Apass = str2double(val);
                case '-A_STOP'
                    Astop = str2double(val);
                case '-A_PASS1'
                    Apass1 = str2double(val);
                case '-A_PASS2'
                    Apass2 = str2double(val);
                case '-A_STOP1'
                    Astop1 = str2double(val);
                case '-A_STOP2'
                    Astop2 = str2double(val);
                case '-IN_WL'
                    in_WL = str2double(val);
                case '-IN_FL'
                    in_FL = str2double(val);
                case '-H_WL'
                    coeff_WL = str2double(val);
                case '-OUT_WL'
                    out_WL = str2double(val);
                case '-OUT_FL'
                    out_FL = str2double(val);
                case '-SEC_IN_WL'
                    s_in_WL = str2double(val);
                case '-SEC_OUT_WL'
                    s_out_WL = str2double(val);
            end
        end
    end
    
    %================================================================================
    %% Selecting a filter type
    %================================================================================
    switch filterType
        case 'lowpass'
            Fpass = Fpass;
            Fstop = Fstop;
            Apass = Apass;
            Astop = Astop;
        case 'highpass'
            Fpass = Fpass;
            Fstop = Fstop;
            Apass = Apass;
            Astop = Astop;
        case 'bandpass'
            Fpass = [Fpass1 Fpass2];
            Fstop = [Fstop1 Fstop2];
            Apass = Apass;
            Astop = [Astop1 Astop2];
        case 'bandstop'
            Fpass = [Fpass1 Fpass2];
            Fstop = [Fstop1 Fstop2];
            Apass = [Apass1, Apass2];
            Astop = Astop;
    end
    
    %================================================================================
    %% Calculation of filter coefficients
    %================================================================================
    Hd = IIR_Calculation(F_s, filterType, filterApprox, Fpass, Fstop, Apass, Astop);
    
    b = Hd.sosMatrix; % SOS Matrix (a and b coefficients)
    [num_sections, ~] = size(Hd.sosMatrix); % Number of sections
    N = num_sections * 2; % IIR Order
    scale = Hd.ScaleValues; % Scale coefficients
    
    B_sections = b(:, 1:3); % Numerator
    A_sections = b(:, 4:6); % Denominator
    
    [h_dbl, f] = freqz(Hd.sosMatrix, 4096, F_s); % Magnitude response of digital filter (Double coefficients)
    h_dbl = h_dbl * prod(Hd.ScaleValues); % Scaling Magnitude response
    
    %================================================================================
    %% Calculation of SLA IIR Coefficients
    %================================================================================
    M = 2; % The order of the numerator and denominator after the SLA operation will be 2 * M
    
    [B_sla, A_sla] = SLA_calc(B_sections, A_sections, M, num_sections); % SLA Calculation
    
    % Calculation of the total magnitude response for all sections
    H_sla_total = ones(4096, 1);
    for k = 1 : num_sections
        [h_sec, ~] = freqz(B_sla(k, :), A_sla(k, :), 4096, F_s);
        H_sla_total = H_sla_total .* h_sec;
    end
    H_sla_total = H_sla_total * prod(Hd.ScaleValues);
    
    %================================================================================
    %% Calculation of word/fraction lengths for SLA IIR coefficients
    %================================================================================
    b_fix = fi(B_sla, true, coeff_WL); % Converting numerator coefficients to Fixed-Point
    coeff_b_FL = b_fix.FractionLength; % Determining the optimal length of the fractional part

    a_fix = fi(A_sla(:,2:end), true, coeff_WL); % Converting numerator coefficients to Fixed-Point
    coeff_a_FL = a_fix.FractionLength; % Determining the optimal length of the fractional part
    
    if (scale(end) == 1) % The last coefficient is not taken into account when calculating bit bit depths if it equals 1
        scale_IL = ceil(log2(max(abs(scale(1:end - 1))))) + 1; % Scale integer bit depth
    else
        scale_IL = ceil(log2(max(abs(scale)))) + 1; % Scale integer bit depth
    end
    scale_FL = coeff_WL - scale_IL; % Scale fraction length
    
    %================================================================================
    %% L1-Norm calculation
    %================================================================================
    N_imp = 8192; % Length of the impulse response for calculating L1-norm
    [s_out_IL, state_IL, state_FL] = L1_calc(b_fix, a_fix, N_imp, M, num_sections);
    
    %================================================================================
    %% Calculation of fraction lengths for SLA IIR section input/output
    %================================================================================
    s_out_FL = s_out_WL - s_out_IL; % Section output fraction length
    s_in_IL = s_out_IL; % Section input integer length
    s_in_FL = s_in_WL - s_in_IL; % Section input fraction length
    
    %================================================================================
    %% Calculation of word lengths for SLA IIR states
    %================================================================================
    state_WL = state_IL + state_FL; % State word length
    
    %================================================================================
    %% Calculation of word/fraction lengths for SLA IIR section accums and prods
    %================================================================================
    mult_a_WL = s_in_WL + coeff_WL; % Product denominator word length
    mult_b_FL = s_in_FL + coeff_b_FL; % Product numerator fraction length
    mult_b_WL = s_out_WL + coeff_WL; % Product numerator word length
    mult_a_FL = s_out_FL + coeff_a_FL; % Product denominator fraction length
    mult_b_IL = mult_b_WL - mult_b_FL; % Product numerator integer length
    mult_a_IL = mult_a_WL - mult_a_FL; % Product denominatro integer length
    mult_WL = max([mult_a_WL, mult_b_WL]); % Product word length
    
    acc_s4_IL = max([mult_a_IL, mult_b_IL]) + 1; % s4 accum. integer length
    acc_s4_FL = max([mult_a_FL, mult_b_FL]); % s4 accum. fraction length
    acc_s4_WL = acc_s4_IL + acc_s4_FL; % s4 accum. word length
    
    acc_s3_IL = max([mult_b_IL, state_IL]) + 1; % s3 accum. integer length
    acc_s3_FL = max([mult_b_FL, state_FL]); % s3 accum. fraction length
    acc_s3_WL = acc_s3_IL + acc_s3_FL; % s3 accum. word length
    
    acc_s2_num_IL = max([mult_b_IL, state_IL]) + 1; % s2 accum. numerator integer length
    acc_s2_num_FL = max([mult_b_FL, state_FL]); % s2 accum. numerator fraction length
    acc_s2_num_WL = acc_s2_num_IL + acc_s2_num_FL; % s2 accum. numerator word length
    acc_s2_den_IL = max([acc_s2_num_IL, mult_b_IL]) + 1; % s2 accum. denominator integer length
    acc_s2_den_FL = max([acc_s2_num_FL, mult_b_FL]); % s2 accum. denominator fraction length
    acc_s2_den_WL = acc_s2_den_IL + acc_s2_den_FL; % s2 accum. denominator word length
    
    acc_s1_IL = max([mult_a_IL, state_IL]) + 1; % s1 accum. integer length
    acc_s1_FL = max([mult_a_FL, state_FL]); % s1 accum. fraction length
    acc_s1_WL = acc_s1_IL + acc_s1_FL; % s1 accum. word length
    
    acc_out_IL = max([s_in_WL - s_in_FL, state_IL]) + 1; % output accum. integer length
    acc_out_FL = max([s_out_FL, state_FL]); % output accum. fraction length
    acc_out_WL = acc_out_IL + acc_out_FL; % output accum. word length
    
    acc_WL = max([acc_s4_WL acc_s3_WL acc_s2_den_WL acc_s2_num_WL acc_s1_WL acc_out_WL]); % Accum. word length
    acc_a_FL = max([acc_s4_FL acc_s2_den_FL]); % Accum. denominator fraction length
    acc_b_FL = max([acc_s3_FL acc_s2_num_FL acc_s1_FL acc_out_FL]); % Accum. numerator fractios length

    %================================================================================
    %% Quantization of SLA coefficients and Scale Values
    %================================================================================
    b_fix_out = fi(reshape(double(b_fix(:,2:end))', [], 1), true, coeff_WL, coeff_b_FL);
    a_fix_out = fi(reshape(double(a_fix(:, [M, 2 * M]))', [], 1), true, coeff_WL, coeff_a_FL);
    
    if (scale(end) == 1)
        scale_fix = fi(scale(1:end - 1), true, coeff_WL, scale_FL);
        out_mult = 0; % Output multiplier disable
    else
        scale_fix = fi(scale, true, coeff_WL, scale_FL);
        out_mult = 1; % Output multiplier enable
    end
    
    write_file(out_file_b, b_fix_out, num_format);
    write_file(out_file_a, a_fix_out, num_format);
    write_file(out_file_scale, scale_fix, num_format);
    
    %================================================================================
    %% 4th-order filter cascade in fixed-point format
    %================================================================================
    Hd_stages = cell(1, num_sections);
    for i = 1 : num_sections
        B_prime = B_sla(i, :);
        A_prime = A_sla(i, :);
        
        G = dfilt.scalar(scale(i)); % Scale
        if (i == 1)
            G.Arithmetic = 'fixed'; % Fixed-point
            G.InputWordLength = in_WL; % Section input word length
            G.InputFracLength = in_FL; % Section input fraction length
            G.OutputMode = 'SpecifyPrecision'; % Specify precision output mode
            G.OutputWordLength = s_in_WL; % Section output word length
            G.OutputFracLength = s_in_FL; % Section output fraction length
            G.CoeffWordLength = coeff_WL; % Coefficients word length
            G.CoeffAutoScale = false; % Coefficients auto scale disable 
            G.CoeffFracLength = scale_FL; % Numerator fraction length
        else
            G.Arithmetic = 'fixed'; % Fixed-point
            G.InputWordLength = s_in_WL; % Section input word length
            G.InputFracLength = s_in_FL; % Section input fraction length
            G.OutputMode = 'SpecifyPrecision'; % Specify precision output mode
            G.OutputWordLength = s_in_WL; % Section output word length
            G.OutputFracLength = s_in_FL; % Section output fraction length
            G.CoeffWordLength = coeff_WL; % Coefficients word length
            G.CoeffAutoScale = false; % Coefficients auto scale disable 
            G.CoeffFracLength = scale_FL; % Numerator fraction length
        end
        
        Hd_sec = dfilt.df2t(B_prime, A_prime); % Direct Form II Transposed
        Hd_sec.Arithmetic = 'fixed'; % Fixed-point
        Hd_sec.InputWordLength = s_in_WL; % Section input word length
        Hd_sec.InputFracLength = s_in_FL; % Section input fraction length
        Hd_sec.OutputWordLength = s_out_WL; % Section output word length
        Hd_sec.OutputFracLength = s_out_FL; % Section output fraction length
        Hd_sec.CoeffWordLength = coeff_WL; % Coefficients word length
        Hd_sec.CoeffAutoScale = false; % Coefficients auto scale disable 
        Hd_sec.NumFracLength = coeff_b_FL; % Numerator fraction length
        Hd_sec.DenFracLength = coeff_a_FL; % Denominator fraction length
        Hd_sec.ProductMode = 'SpecifyPrecision'; % Product mode - Specify precision
        Hd_sec.ProductWordLength = mult_WL; % Product word length
        Hd_sec.DenProdFracLength = mult_a_FL; % Product denominator fraction length
        Hd_sec.NumProdFracLength = mult_b_FL; % Product numerator fraction length
        Hd_sec.StateWordLength = state_WL; % State word length
        Hd_sec.CastBeforeSum = false; % Cast signals before accum. disable
        Hd_sec.StateAutoScale = false; % State auto scale disable
        Hd_sec.StateFracLength = state_FL; % State fraction length
        Hd_sec.AccumMode = 'SpecifyPrecision'; % Accum. mode - Specify precision
        Hd_sec.AccumWordLength = acc_WL; % Accum. word length
        Hd_sec.DenAccumFracLength = acc_a_FL; % Accum. denominator fraction length
        Hd_sec.NumAccumFracLength = acc_b_FL; % Accum. numerator fraction length
        Hd_sec.OverflowMode = 'wrap'; % Overflow mode
        Hd_stages{i} = dfilt.cascade(G, Hd_sec); % Cascade section
        
        sec_mult_WL(i) = Hd_sec.ProductWordLength; % Section product word length
        sec_mult_a_FL(i) = Hd_sec.DenProdFracLength; % Section product denominator fraction length
        sec_mult_b_FL(i) = Hd_sec.NumProdFracLength; % Section product numerator fraction length
        sec_acc_WL(i) = Hd_sec.AccumWordLength; % Section accum. word length
        sec_acc_a_FL(i) = Hd_sec.DenAccumFracLength; % Section denominator fraction length
        sec_acc_b_FL(i) = Hd_sec.NumAccumFracLength; % Section numerator fraction length
        sec_state_FL(i) = Hd_sec.StateFracLength; % Section state fraction length
    end
    
    if (out_mult == 1) % Output scale
        G = dfilt.scalar(scale(end));
        G.Arithmetic = 'fixed'; % Fixed-point
        G.InputWordLength = s_out_WL; % Section input word length
        G.InputFracLength = s_out_FL; % Section input fraction length
        G.OutputMode = 'SpecifyPrecision'; % Output mode - Specify precision
        G.OutputWordLength = out_WL; % Section output word length
        G.OutputFracLength = out_FL; % Section output fraction length
        G.CoeffWordLength = coeff_WL; % Coefficients word length
        G.CoeffAutoScale = false; % Coefficients auto scale disable 
        G.CoeffFracLength = scale_FL; % Numerator fraction length
    
        Hd_sla_cascade = dfilt.cascade(Hd_stages{:}, G); % Formation of a filter cascade
    else
        Hd_sla_cascade = dfilt.cascade(Hd_stages{:}); % Formation of a filter cascade
    end

    mult_WL = max(sec_mult_WL); % Generalized product word length
    mult_a_FL = max(sec_mult_a_FL); % Generalized product denominator fraction length
    mult_b_FL = max(sec_mult_b_FL); % Generalized product numerator fraction length
    acc_WL = max(sec_acc_WL); % Generalized accum. word length
    acc_a_FL = max(sec_acc_a_FL); % Generalized accum. denominator fraction length
    acc_b_FL = max(sec_acc_b_FL); % Generalized accum. numerator fraction length
    state_FL = max(sec_state_FL); % Generalized state fraction length
     
    %================================================================================
    %% Report
    %================================================================================
    fprintf('\n==================== IIR Parameters ====================\n')
    fprintf('Input Word length                  : %d\n', in_WL);
    fprintf('Input Fraction length              : %d\n', in_FL);
    fprintf('Output Word length                 : %d\n', out_WL);
    fprintf('Output Fraction length             : %d\n', out_FL);
    fprintf('Coeff Word length                  : %d\n', coeff_WL);
    fprintf('Coeff Num. Fraction length         : %d\n', coeff_b_FL);
    fprintf('Coeff Denom. Fraction length       : %d\n', coeff_a_FL);
    fprintf('Scale Values Fraction length       : %d\n', scale_FL);
    fprintf('Section Input Word length          : %d\n', s_in_WL);
    fprintf('Section Input Fraction length      : %d\n', s_in_FL);
    fprintf('Section Output Word length         : %d\n', s_out_WL);
    fprintf('Section Output Fraction length     : %d\n', s_out_FL);
    fprintf('State Word length                  : %d\n', state_WL);
    fprintf('State Fraction length              : %d\n', state_FL);
    fprintf('Product Word length                : %d\n', mult_WL);
    fprintf('Product Num. Fraction length       : %d\n', mult_b_FL);
    fprintf('Product Denom. Fraction length     : %d\n', mult_a_FL);
    fprintf('Accum. Word length                 : %d\n', acc_WL);
    fprintf('Accum. Num. Fraction length        : %d\n', acc_b_FL);
    fprintf('Accum. Denom. Fraction length      : %d\n', acc_a_FL);
    
    %================================================================================
    %% Frequency Response Calculation for Fixed-Point SLA
    %================================================================================
    [h_fix, ~] = freqz(Hd_sla_cascade, 4096, F_s);
    
    %================================================================================
    %% Plotting Frequency Response graphs
    %================================================================================
    figure('Visible', 'off');
    plot(f/1e6, 20 * log10(abs(h_dbl)), 'b', 'LineWidth', 1.5);
    hold on;
    plot(f/1e6, 20 * log10(abs(H_sla_total)), 'g-.', 'LineWidth', 0.5);
    plot(f/1e6, 20 * log10(abs(h_fix)), 'r--', 'LineWidth', 1.2);
    grid on;
    
    set(gcf, 'WindowState', 'maximized');
    
    title(sprintf('SLA IIR Magnitude Response (%s, M = %d) | Reference Filter Order N = %d', filterType, M,  N), 'FontSize', 12);
    xlabel('Frequency (MHz)');
    ylabel('Magnitude (dB)');
    legend({'Double Precision (Original SOS)', 'Double Precision (SLA)', 'Fixed-Point (SLA)'}, 'Location', 'northeast');
    
    exportgraphics(gca, build_path + "/MagResponse.png")
    %================================================================================
    %% Stimulus signal generation
    %================================================================================
    f_sig = [Fpass/10 Fpass/2 Fpass Fpass * 2 Fpass * 2.5]; % Sin frequencies
    N_sine = 500; % Number of Sine Samples
    A = 0.9; % Amplitude
    noise_std = 0.03; % Standart Deviation of Noise
    
    noise = noise_std * randn(1, N_sine); % Noise signal
    
    %================================================================================
    %% Samples of different segments of sinusoids with noise
    %================================================================================
    t = (0:N_sine - 1) / F_s;
    for i = 1:5
        sine_wave(i,:) = A * sin(2 * pi * f_sig(i) * t) + noise;
    end
    
    %================================================================================
    %% Stimulus signal and writing its samples to a file
    %================================================================================
    sine_stimul = fi([sine_wave(1,:) sine_wave(2,:) sine_wave(3,:) sine_wave(4,:) sine_wave(5,:)], true, in_WL, in_FL);
    write_file(out_file_stimul, sine_stimul, 'dec');
    
    %================================================================================
    %% Writing parameters for RTL
    %================================================================================
    fid = fopen(out_file_params, 'w');
    fprintf(fid, 'localparam ORDER = %d;\n', N); % IIR order
    fprintf(fid, 'localparam INPUT_WL = %d;\n', in_WL); % Input word length
    fprintf(fid, 'localparam INPUT_FL = %d;\n', in_FL); % Input fraction length
    fprintf(fid, 'localparam COEFFICIENT_WL = %d;\n', coeff_WL); % Coeffs word length
    fprintf(fid, 'localparam COEFFICIENT_NUM_FL = %d;\n', coeff_b_FL); % Coeffs Num. fraction length
    fprintf(fid, 'localparam COEFFICIENT_DENOM_FL = %d;\n', coeff_a_FL); % Coeffs Denom. fraction length
    fprintf(fid, 'localparam COEFFICIENT_SCALE_FL = %d;\n', scale_FL); % Scale fraction length
    fprintf(fid, 'localparam SEC_INPUT_WL = %d;\n', s_in_WL); % Section input word length
    fprintf(fid, 'localparam SEC_INPUT_FL = %d;\n', s_in_FL); % Section input fraction length
    fprintf(fid, 'localparam SEC_OUTPUT_WL = %d;\n', s_out_WL); % Section output word length
    fprintf(fid, 'localparam SEC_OUTPUT_FL = %d;\n', s_out_FL); % Section output fraction length
    fprintf(fid, 'localparam PROD_WL = %d;\n', mult_WL); % Mults word length
    fprintf(fid, 'localparam PROD_NUM_FL = %d;\n', mult_b_FL); % Mult Num. fraction length
    fprintf(fid, 'localparam PROD_DENOM_FL = %d;\n', mult_a_FL); % Mult Denom. fraction length
    fprintf(fid, 'localparam ACCUM_WL = %d;\n', acc_WL); % Accumulators word length
    fprintf(fid, 'localparam ACCUM_NUM_FL = %d;\n', acc_b_FL); % Accumulator Num. fraction length
    fprintf(fid, 'localparam ACCUM_DENOM_FL = %d;\n', acc_a_FL); % Accumulator Denom. fraction length
    fprintf(fid, 'localparam OUTPUT_WL = %d;\n', out_WL); % Output word length
    fprintf(fid, 'localparam OUTPUT_FL = %d;\n', out_FL); % Output fraction length
    fprintf(fid, 'localparam STATE_IIR_WL = %d;\n', state_WL); % State word length
    fprintf(fid, 'localparam STATE_IIR_FL = %d;\n', state_FL); % State fraction length
    fprintf(fid, 'localparam OUT_MULTIPLIER = %d;\n', out_mult); % Output multiplier
    fprintf(fid, 'localparam F_CLK = %d;\n', F_clk); % Clock frequency
    fprintf(fid, 'localparam CLK_EN_DIV = %d;\n', F_clk/F_s); % Clock division factor for determining the clock enable frequency
    fprintf(fid, 'localparam SIN_NUM_SAMPLES = %d;', length(sine_stimul)); % Number of stimulus signal samples
    fclose(fid);
    
    %================================================================================
    %% Saving data for analysis
    %================================================================================
    save_data.F_clk = F_clk;
    save_data.F_s = F_s;
    save_data.Fpass = Fpass;
    save_data.Fstop = Fstop;
    save_data.filterType = char(filterType);
    save_data.filterApprox = char(filterApprox);
    save_data.Apass = Apass;
    save_data.Astop = Astop;
    save_data.in_WL = in_WL;
    save_data.in_FL = in_FL;
    save_data.coeff_WL = coeff_WL;
    save_data.coeff_b_FL = coeff_b_FL;
    save_data.coeff_a_FL = coeff_a_FL;
    save_data.out_WL = out_WL;
    save_data.out_FL = out_FL;
    save_data.scale_FL = scale_FL;
    save_data.s_in_WL = s_in_WL;
    save_data.s_in_FL = s_in_FL;
    save_data.s_out_WL = s_out_WL;
    save_data.s_out_FL = s_out_FL;
    save_data.mult_WL = mult_WL;
    save_data.mult_b_FL = mult_b_FL;
    save_data.mult_a_FL = mult_a_FL;
    save_data.acc_WL = acc_WL;
    save_data.acc_b_FL = acc_b_FL;
    save_data.acc_a_FL = acc_a_FL;
    save_data.state_WL = state_WL;
    save_data.state_FL = state_FL;
    save_data.M = M;
    
    save('../matlab/params.mat', '-struct', 'save_data');
end