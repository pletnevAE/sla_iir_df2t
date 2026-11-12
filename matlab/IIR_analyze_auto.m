%================================================================================
% This function compares the output of an RTL IIR filter with a filter that has 
% double coefficients.
%================================================================================
function IIR_analyze_auto(build_path)
    output_rtl_path = build_path + "/output_iir.txt"; % RTL output file path
    stimul_path = build_path + "/stimulus.txt"; % Stimulus file path
    params_path = "../matlab/params.mat"; % Parameters file path
    
    %================================================================================
    %% Reading parameters
    %================================================================================
    if (exist(params_path, 'file') == 2)
        params = load(params_path);
        delete(params_path);
    else
        error('File ''params.mat'' not found.');
    end

    F_s = params.F_s; % Sampling frequency
    Fpass = params.Fpass; % Passband edge
    Fstop = params.Fstop; % Stopband edge
    filterType = params.filterType; % Filter Type
    filterApprox = params.filterApprox; % Design Method
    Apass = params.Apass; % Passband ripple in dB
    Astop = params.Astop; % Stopband ripple in dB
    in_WL = params.in_WL; % Word lengths for input signal
    in_FL = params.in_FL; % Fraction lengths for input signal
    out_WL = params.out_WL; % Word lengths for output signal (symmetry)
    out_FL = params.out_FL; % Fraction lengths for output signal (symmetry)
    coeff_WL = params.coeff_WL; % Word lengths for coefficients
    coeff_b_FL = params.coeff_b_FL; % Fraction lengths for Numerator
    coeff_a_FL = params.coeff_a_FL; % Fraction lengths for Denominator
    scale_FL = params.scale_FL; % Fraction lengths for Scale Value
    s_in_WL = params.s_in_WL; % Section input word length
    s_in_FL = params.s_in_FL; % Section input fraction length
    s_out_WL = params.s_out_WL; % Section output word length
    s_out_FL = params.s_out_FL; % Section output fraction length
    mult_WL = params.mult_WL; % Word lengths for multipliers 
    mult_b_FL = params.mult_b_FL; % Mult Num. fraction length
    mult_a_FL = params.mult_a_FL; % Mult Denom. fraction length
    acc_WL = params.acc_WL; % Word lengths for accumulators
    acc_b_FL = params.acc_b_FL; % Accum Num. fraction length
    acc_a_FL = params.acc_a_FL; % Accum Denom. fraction length
    state_WL = params.state_WL; % State word length
    state_FL = params.state_FL; % State fraction length
    M = params.M; % Pipelining depth
    
    %================================================================================
    %% Reading stimulus signal
    %================================================================================
    if (exist(stimul_path, 'file') == 2)
        stimulus = readmatrix(stimul_path);
    else
        error('File ''stimul_path.txt'' not found.');
    end
    
    %================================================================================
    %% Reading RTL output signal
    %================================================================================
    if (exist(output_rtl_path, 'file') == 2)
        rtl_out = readmatrix(output_rtl_path);
    else
        error('File ''output_iir.txt'' not found.');
    end
    
    %================================================================================
    %% Reference IIR calculation
    %================================================================================
    switch filterApprox
        case 'butter'
            match = 'stopband';
        case 'ellip'
            match = 'both';
        case 'cheby1'
            match = 'passband';
        case 'cheby2'
            match = 'stopband';
    end

    switch filterType
        case 'lowpass'
            h  = fdesign.lowpass(Fpass, Fstop, Apass, Astop, F_s);
        case 'highpass'
            h  = fdesign.highpass(Fstop, Fpass, Astop, Apass, F_s);
        case 'bandpass'
            h  = fdesign.bandpass(Fstop(1), Fpass(1), Fpass(2), Fstop(2), Astop(1), Apass, Astop(2), F_s);
        case 'bandstop'
            h  = fdesign.bandstop(Fpass(1), Fstop(1), Fstop(2), Fpass(2), Apass(1), Astop, Apass(2), F_s);
    end

    Hd = design(h, filterApprox, 'MatchExactly', match);
    [num_sections, ~] = size(Hd.sosMatrix); % Number of sections
    N = num_sections * 2 * M; % IIR Order
    
    %================================================================================
    %% Converting the stimulus
    %================================================================================
    stimulus_fi = fi([], true, in_WL, in_FL);
    stimulus_fi.int = stimulus;
    stimulus_double = double(stimulus_fi);
    
    %================================================================================
    %% Filtering the stimulus signal with double coefficients
    %================================================================================
    out_double = double(filter(Hd, stimulus_double)); % Filtering

    %================================================================================
    %% Converting the RTL output signal
    %================================================================================
    rtl_out_fi = fi([], true, out_WL, out_FL);
    rtl_out_fi.int = rtl_out;
    rtl_out_double = double(rtl_out_fi);
    
    num_samples = length(rtl_out_double);
    n = 0 : num_samples - 1;

    %================================================================================
    %% Calculation of Absolute Error
    %================================================================================
    err = rtl_out_double - out_double;
    abs_err = abs(err);
    max_err = max(abs_err);
    rms_err = sqrt(mean(err.^2));
    sqnr = 10 * log10(sum((out_double).^2) / sum(err.^2));
    
    %================================================================================
    %% Report
    %================================================================================
    fprintf('\n==================== SLA IIR REPORT ====================\n')
    fprintf('Filter Type                        : %s\n', filterType);
    fprintf('Design Method                      : %s\n', filterApprox);
    fprintf('Filter Order                       : %d\n', N);
    fprintf('Pipelining depth                   : %d\n', M);
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
    fprintf('\n--------------------------------------------------------\n')
    fprintf('Maximum Absolute Error             : %e\n', max_err);
    fprintf('RMS Error                          : %e\n', rms_err);
    fprintf('Actual Measured SQNR               : %.2f dB\n', sqnr);
    fprintf('\n========================================================\n')

    %================================================================================
    %% Signals and Error Graphs
    %================================================================================
    figure;
    subplot(2, 1, 1);
    plot(n, rtl_out_double, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(n, out_double, 'r--', 'LineWidth', 1);
    grid on;
    xlim([0 num_samples - 1]);
    title('IIR Output');
    xlabel('Sample');
    ylabel('Amplitude');
    legend('RTL, Fixed-Point IIR', 'MATLAB, Double IIR');
    
    subplot(2, 1, 2);
    plot(n, abs_err, 'r-');
    grid on;
    xlim([0 num_samples - 1]);
    title('Error');
    xlabel('Sample');
    ylabel('Absolute Error (LBSs)');
    
	fprintf('[INFO] Close all charts to finish...\n');
    %================================================================================
    %% Waiting for charts to close
    %================================================================================
	figs = findall(0, 'Type', 'figure');
	while ~isempty(findall(0, 'Type', 'figure'))
		figs = findall(0, 'Type', 'figure');
		uiwait(figs(1))
    end
end