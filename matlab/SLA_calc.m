%================================================================================
% This script calculates the IIR filter coefficients following the
% Scattered Look-Ahead transformation.
%================================================================================
function [b_sla, a_sla] = SLA_calc(b, a, M, num_sec)

b_sla = zeros(num_sec, 2 * M + 1);
a_sla = zeros(num_sec, 2 * M + 1);
P_sections = cell(num_sec, 1); % Compensating polynomials
    
    %================================================================================
    %% Calculation of coefficients for each section
    %================================================================================
    for k = 1 : num_sec
        b_k = b(k, :); % Original numerator [b0, b1, b2]
        a_k = a(k, :); % Original denominator [1, a1, a2]
    
        p = roots(a_k); % Poles p1 and p2 of the current section
    
        % Formation of a new denominator A'(z) = 1 + a'_M * z^(-M) + a'_2M * z^(-2M)
        a1_prime = -sum(p.^M); % Coefficient of the z^(-M)
        a2_prime = (a_k(3))^M; % Coefficient of the z^(-2M), equal (p1 * p2)^M = a2^M
    
        A_prime = zeros(1, 2 * M + 1);
        A_prime(1) = 1;
        A_prime(M + 1) = real(a1_prime);
        A_prime(2 * M + 1) = real(a2_prime);
    
        [P_k, ~] = deconv(A_prime, a_k); % Compensating polynomial P(z) = A'(z) / A(z)
        B_prime = conv(b_k, P_k); % New numerator B'(z) = B(z) * P(z)
    
        a_sla(k, :) = A_prime;
        b_sla(k, :) = B_prime;
        P_sections{k} = P_k;
    end

end