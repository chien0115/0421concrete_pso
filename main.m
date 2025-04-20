clc;
clear all;
close all;
% 問題定義
t = 5; % 卡車數
num_sites = 3; % 工地數量
time_windows = [480, 1080;
                600, 1080;
                510, 1080]; % 各工地時間窗
time = [30, 25;  
        25, 20;
        40, 30]; % 去程與回程時間
max_interrupt_time = [30, 20, 15]; % 各工地最大容許中斷施工時間
work_time = [20, 30, 25]; % 各工地施工時間
demand_trips = [3, 4, 5]; % 各工地需求派遣車次
penalty = 24*60; % 懲罰值
total_trips = sum(demand_trips);

% PSO參數設定
MaxIter = 300; % 迭代次數
nPop = 200; % 粒子數量
w = 0.9; % 慣性權重
wdamp = 0.99; % 慣性權重衰減
c1 = 2; % 個人學習係數
c2 = 2; % 群體學習係數

% 粒子初始化
empty_particle.Position = [];
empty_particle.Velocity = [];
empty_particle.Cost = [];
empty_particle.RealFitness = [];
empty_particle.DispatchTimes = [];
empty_particle.Best = [];

particle = repmat(empty_particle, nPop, 1);%放每個世代的染色體
GlobalBest.Cost = inf;
GlobalBest.RealFitness = -inf;

for i = 1:nPop
    % 隨機產生派遣順序並修復
    dispatch_order = [];
    for j = 1:num_sites
        dispatch_order = [dispatch_order, repmat(j, 1, demand_trips(j))];
    end
    particle(i).Position = repair_position(dispatch_order(randperm(total_trips)), demand_trips);
    particle(i).Velocity = zeros(1, total_trips);

    % 安全的派遣時間初始化 (修正索引錯誤)
    safe_positions = max(1, min(num_sites, particle(i).Position));
    particle(i).DispatchTimes = round(rand(1, total_trips) .* ...
        (time_windows(safe_positions, 2)' - time_windows(safe_positions, 1)') + ...
        time_windows(safe_positions, 1)');

    % 評估初始成本與適應度
    [particle(i).Cost, ~] = objective_function_pso_v2(particle(i).Position, t, time_windows, num_sites, particle(i).DispatchTimes, work_time, time, max_interrupt_time, penalty);
    particle(i).RealFitness = -particle(i).Cost;

    % 更新個體與全域最佳
    particle(i).Best = particle(i);
    if particle(i).RealFitness > GlobalBest.RealFitness
        GlobalBest = particle(i).Best;
    end
end

% 繪圖初始化
figure;
hold on;
grid on;
title('PSO Blue-Average      Red-Minimum');
xlabel('Generation');
ylabel('Objective Function Value');

% PSO主迴圈
for it = 1:MaxIter
    costs = zeros(nPop, 1);
    K = zeros(MaxIter, 2);  % 儲存每代的平均與最佳適應度
    for i = 1:nPop
        % 更新速度與位置
        r1 = rand(1, total_trips);
        r2 = rand(1, total_trips);

        particle(i).Velocity = w * particle(i).Velocity ...
            + c1 * r1 .* (particle(i).Best.Position - particle(i).Position) ...
            + c2 * r2 .* (GlobalBest.Position - particle(i).Position);

        % 更新位置與修復
        new_position = particle(i).Position + particle(i).Velocity;
        particle(i).Position = repair_position(round(new_position), demand_trips);

        % 逐一為每個工地更新派遣時間（確保索引在有效範圍內）
        particle(i).DispatchTimes = zeros(1, total_trips);
        for j = 1:total_trips
            site_index = max(1, min(num_sites, particle(i).Position(j)));
            particle(i).DispatchTimes(j) = round(rand() * ...
                (time_windows(site_index, 2) - time_windows(site_index, 1)) + ...
                time_windows(site_index, 1));
        end
        % 計算成本與適應度
        [particle(i).Cost, ~] = objective_function_pso_v2(particle(i).Position, t, time_windows, num_sites, particle(i).DispatchTimes, work_time, time, max_interrupt_time, penalty);
        particle(i).RealFitness = -particle(i).Cost;

        % 更新個體與全域最佳
        if particle(i).RealFitness > particle(i).Best.RealFitness
            particle(i).Best = particle(i);
            if particle(i).Best.RealFitness > GlobalBest.RealFitness
                GlobalBest = particle(i).Best;
            end
        end
        costs(i) = particle(i).Cost;
    end

    % 更新慣性權重
    w = w * wdamp;

    K(it, 1) = mean(costs);  % 平均適應度
    K(it, 2) = min(costs);      % 最佳適應度
    % 繪製收斂圖
    plot(it, K(it, 1), 'b.');
    plot(it, K(it, 2), 'r.');
    drawnow;

    % 顯示每代最佳成本
    disp(['Iteration ' num2str(it) ': Best Cost = ' num2str(GlobalBest.Cost)]);
end

% 輸出最佳解結果
disp('Best Chromosome:');
disp(GlobalBest.Position);
disp('Best Dispatch Times (Planned):');
disp(GlobalBest.DispatchTimes);
disp(['Best Dispatch Times (Actual): ', num2str(GlobalBest.Cost)]);

% 解碼最佳解為派車計畫 (使用decode_chromosome函數，你需自行有此函數)
dispatch_plan = decode_chromosome(GlobalBest.Position, GlobalBest.DispatchTimes, t, demand_trips, time_windows, work_time, time);



vehicle_ids = dispatch_plan(:, 1);
site_ids = dispatch_plan(:, 2);
actual_dispatch_times = dispatch_plan(:, 3);
travel_times_to = dispatch_plan(:, 4);
arrival_times = dispatch_plan(:, 5);
site_set_start_times = dispatch_plan(:, 6);
work_start_times = dispatch_plan(:, 7);
work_times = dispatch_plan(:, 8);
site_finish_times = dispatch_plan(:, 9);
travel_times_back = dispatch_plan(:, 10);
return_times = dispatch_plan(:, 11);
truck_waiting_times = dispatch_plan(:, 12);
site_waiting_times = dispatch_plan(:, 13);


% 將時間轉為 HH:MM 格式
convert_minutes_to_time = @(x) sprintf('%02d:%02d', floor(x/60), mod(x,60));
actual_dispatch_times_formatted = cellstr(arrayfun(convert_minutes_to_time, actual_dispatch_times, 'UniformOutput', false));
arrival_times_formatted = cellstr(arrayfun(convert_minutes_to_time, arrival_times, 'UniformOutput', false));
return_times_formatted = cellstr(arrayfun(convert_minutes_to_time, return_times, 'UniformOutput', false));
site_finish_times_formatted = cellstr(arrayfun(convert_minutes_to_time, site_finish_times, 'UniformOutput', false));
site_set_start_times_formatted = cellstr(arrayfun(convert_minutes_to_time, site_set_start_times, 'UniformOutput', false));
work_start_times_formatted = cellstr(arrayfun(convert_minutes_to_time, work_start_times, 'UniformOutput', false));
truck_waiting_times_formatted = cellstr(arrayfun(@(x) sprintf('%d min', x), truck_waiting_times, 'UniformOutput', false));
site_waiting_times_formatted = cellstr(arrayfun(@(x) sprintf('%d min', x), site_waiting_times, 'UniformOutput', false));

% 建立結果表格
dispatch_data = table(vehicle_ids, site_ids, actual_dispatch_times_formatted, travel_times_to, arrival_times_formatted, site_set_start_times_formatted, work_start_times_formatted, work_times, site_finish_times_formatted, travel_times_back, return_times_formatted, truck_waiting_times_formatted, site_waiting_times_formatted, ...
    'VariableNames', {'VehicleID', 'SiteID', 'ActualDispatchTime', 'TravelTimeTo', 'ArrivalTime', 'SiteSetTime', 'WorkStartTime', 'WorkTime', 'SiteFinishTime', 'TravelTimeBack', 'ReturnTime', 'TruckWaitingTime', 'SiteWaitingTime'});
% 顯示結果表格
figure;
uitable('Data', table2cell(dispatch_data), ...
        'ColumnName', dispatch_data.Properties.VariableNames, ...
        'RowName', [], ...
        'Position', [20 20 800 400]);


