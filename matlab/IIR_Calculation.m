%================================================================================
% This function calculates an IIR filter based on the given parameters. 
% The function outputs a filter object.
%================================================================================
function Hd = IIR_Calculation(F_s, filterType, filterApprox, Fpass, Fstop, Apass, Astop)
    %================================================================================
    %% Selecting a design method
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
    
    %================================================================================
    %% Selecting a filter type
    %================================================================================
    switch filterType
        case 'lowpass'
            if (Fpass >= Fstop)
                error('[ERROR] For lowpass Fstop must be greater then Fpass');
            end
            if (any(Apass >= Astop))
                error('[ERROR] Astop must be greater then Apass.');
            end
            h  = fdesign.lowpass(Fpass, Fstop, Apass, Astop, F_s);
        case 'highpass'
            if (Fpass <= Fstop)
                error('[ERROR] For highpass Fpass must be greater then Fstop');
            end
            if (any(Apass >= Astop))
                error('[ERROR] Astop must be greater then Apass.');
            end
            h  = fdesign.highpass(Fstop, Fpass, Astop, Apass, F_s);
        case 'bandpass'
            if (any(Apass >= Astop))
                error('[ERROR] Astop must be greater then Apass.');
            end
            f_edges = [Fstop(1) Fpass(1) Fpass(2) Fstop(2)];
            if (~issorted(f_edges(:), 'strictascend'))
                error('[ERROR] For a bandpass filter, frequencies are in ascending order as follows: Fstop1 Fpass1 Fpass2 Fstop2');
            end
            h  = fdesign.bandpass(Fstop(1), Fpass(1), Fpass(2), Fstop(2), Astop(1), Apass, Astop(2), F_s);
        case 'bandstop'
            if (any(Apass >= Astop))
                error('[ERROR] Astop must be greater then Apass.');
            end
            f_edges = [Fpass(1), Fstop(1), Fstop(2), Fpass(2)];
            if (~issorted(f_edges(:), 'strictascend'))
                error('[ERROR] For a bandstop filter, frequencies are in ascending order as follows: Fpass1 Fstop1 Fstop2 Fpass2');
            end
            h  = fdesign.bandstop(Fpass(1), Fstop(1), Fstop(2), Fpass(2), Apass(1), Astop, Apass(2), F_s);
    end
    
    %================================================================================
    %% Filter calculation
    %================================================================================
    Hd = design(h, filterApprox, 'MatchExactly', match);

end