% STTHK2133 Modeling & Simulation
% Interactive ED Triage Simulation

clc; clear;
disp('===================================================');
disp('   INTERACTIVE EMERGENCY DEPARTMENT SIMULATION');
disp('===================================================');
disp('Press ENTER to accept default values, or type a new number.');
disp(' ');

% --- 1. USER INPUTS: SYSTEM STATE ---
disp('--- INITIALIZE SYSTEM CAPACITIES ---');
cap_ICU = input('ICU Capacity [default 2]: '); if isempty(cap_ICU), cap_ICU = 2; end
cap_ER  = input('ER Capacity [default 5]: ');  if isempty(cap_ER), cap_ER = 5; end
cap_FT  = input('Fast Track Capacity [default 10]: '); if isempty(cap_FT), cap_FT = 10; end
capacities = [cap_ICU, cap_ER, cap_FT];

disp(' ');
disp('--- INITIALIZE WAITING TIMES (Hours) ---');
wt_ICU = input('Initial ICU Wait Time [default 0.0]: '); if isempty(wt_ICU), wt_ICU = 0.0; end
wt_ER  = input('Initial ER Wait Time [default 2.0]: ');  if isempty(wt_ER), wt_ER = 2.0; end
wt_FT  = input('Initial Fast Track Wait Time [default 0.5]: '); if isempty(wt_FT), wt_FT = 0.5; end
wait_times = [wt_ICU, wt_ER, wt_FT];

disp(' ');
disp('--- PATIENT DATA ENTRY ---');
patients = [];
num_p = input('How many patients to simulate? [default 3]: ');
if isempty(num_p), num_p = 3; end

% Offer default patients if user selected 3
if num_p == 3
    use_def = input('Use default assignment patients (Severities: 8.5, 5.0, 1.5)? (y/n) [default y]: ', 's');
    if isempty(use_def) || lower(use_def) == 'y'
        patients = [1, 1, 8.5; 2, 3, 5.0; 3, 5, 1.5];
    end
end

% Manual entry if defaults aren't used
if isempty(patients)
    for i = 1:num_p
        fprintf('--- Patient %d ---\n', i);
        s_val = input(sprintf('Enter Severity Score for Patient %d (0-10): ', i));

        % Auto-calculate ESI based on Severity
        if s_val >= 8
            esi = 1;
        elseif s_val >= 6
            esi = 2;
        elseif s_val >= 4
            esi = 3;
        elseif s_val >= 2
            esi = 4;
        else
            esi = 5;
        end
        patients = [patients; i, esi, s_val];
    end
end

disp(' ');
disp('===================================================');
disp('              SIMULATION RESULTS                   ');
disp('===================================================');

% --- 2. MODEL PARAMETERS ---
target_severity = [8.0, 5.0, 2.0];
lambda = 0.5; % Waiting time penalty
beta = 0.5;   % Congestion scaling
delta = 0.4;  % Deterioration rate
unit_names = {'ICU', 'ER', 'Fast Track'};
num_units = 3;

% --- 3. UTILITY & SOFTMAX CALCULATIONS ---
assignments = zeros(num_p, 1);
probabilities = zeros(num_p, num_units);

for i = 1:num_p
    S_i = patients(i, 3);
    U_i = zeros(1, num_units);

    for j = 1:num_units
        U_i(j) = -abs(S_i - target_severity(j)) - (lambda * wait_times(j));
    end

    exp_U = exp(U_i);
    P_i = exp_U / sum(exp_U);
    probabilities(i, :) = P_i;

    [~, best_unit] = max(P_i);
    assignments(i) = best_unit;
end

% --- 4. QUEUE & NEW WAIT TIMES ---
assigned_counts = zeros(1, num_units);
for j = 1:num_units
    assigned_counts(j) = sum(assignments == j);
end

new_wait_times = zeros(1, num_units);
for j = 1:num_units
    new_wait_times(j) = wait_times(j) + max(0, assigned_counts(j) - capacities(j)) * beta;
end

% --- 5. DETERIORATION & REPORT GENERATION ---
fprintf('%-6s | %-10s | %-12s | %-10s | %-15s | %-10s\n', 'Pat ID', 'Initial S.', 'Assigned To', 'Exp. Wait', 'New Severity', 'Final ESI');
disp('----------------------------------------------------------------------------------');

for i = 1:num_p
    assigned_unit = assignments(i);
    exp_wait = new_wait_times(assigned_unit);

    old_S = patients(i, 3);
    old_ESI = patients(i, 2);

    % Worsen severity
    new_S = old_S + (exp_wait * delta);

    % Re-calculate ESI
    if new_S >= 8
        new_ESI = 1;
    elseif new_S >= 6
        new_ESI = 2;
    elseif new_S >= 4
        new_ESI = 3;
    elseif new_S >= 2
        new_ESI = 4;
    else
        new_ESI = 5;
    end

    deteriorated = '';
    if new_ESI < old_ESI
        deteriorated = '<- DETERIORATED!';
    end

    fprintf('%-6d | %-10.2f | %-12s | %-10.2f | %-15.2f | %d %s\n', ...
        patients(i,1), old_S, unit_names{assigned_unit}, exp_wait, new_S, new_ESI, deteriorated);
end
disp('===================================================');

% --- 6. VISUALIZATION (BAR CHART) ---
% Visualizing Congestion: Capacity vs Assigned Patients
figure_name = 'ED Unit Congestion';
figure('Name', figure_name, 'NumberTitle', 'off');

% Prepare data for grouped bar chart
plot_data = [capacities', assigned_counts'];

b = bar(plot_data, 'grouped');
set(gca, 'XTickLabel', unit_names);
title('Unit Capacity vs. Assigned Patients');
ylabel('Number of Patients');
legend('Maximum Capacity', 'Actually Assigned', 'Location', 'northwest');
grid on;

% Add value labels on top of bars for clarity
for k = 1:size(plot_data,2)
    x_coords = b(k).XEndPoints;
    y_coords = b(k).YEndPoints;
    text(x_coords, y_coords, string(plot_data(:,k)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom');
end

disp('A visualization plot has been generated in a separate window.');
