function [E, all_dispatch_times] = objective_function_pso_v2(P, t, time_windows, num_sites, dispatch_times, work_time, time, max_interrupt_time, penalty)

[x1, y1] = size(P);
num_dispatch_order = y1;
H = zeros(1, x1);
all_dispatch_times = zeros(x1, t);

for i = 1:x1
    penalty_side_time = 0;
    penalty_truck_time = 0;
    dispatch_times_for_chromosome = dispatch_times(i, :);
    dispatch_order_for_chromosome = P(i, :);
    actual_dispatch_time = zeros(1, num_dispatch_order);
    arrival_times = zeros(1, num_dispatch_order);
    finish_time_site = zeros(1, num_dispatch_order);
    truck_availability = zeros(1, t);

    for k = 1:num_dispatch_order
        site_id = dispatch_order_for_chromosome(k);

        %%% 安全檢查 (避免索引錯誤) %%%
        site_id = max(1, min(num_sites, round(site_id)));

        % 交通高峰延遲設定 (高峰 7:30–9:30 & 17:00–19:00)
        base_travel_to = time(site_id, 1);
        base_travel_back = time(site_id, 2);

        % 前 t 台車直接使用預先派遣時間
        if k <= t
            truck_id = k;
            actual_dispatch_time(k) = dispatch_times_for_chromosome(k);
            all_dispatch_times(i, k) = actual_dispatch_time(k);
        else
            % 第 t 台車之後，找最早可用的車輛
            [next_available_time, truck_id] = min(truck_availability);
            actual_dispatch_time(k) = next_available_time;
        end

        % 計算一天內的分鐘數，決定是否為高峰時間
        dispatch_time_of_day = mod(actual_dispatch_time(k), 1440);
        rush_hour_morning = (dispatch_time_of_day >= 450 && dispatch_time_of_day <= 570);
        rush_hour_evening = (dispatch_time_of_day >= 1020 && dispatch_time_of_day <= 1140);

        traffic_factor = 1.0;
        if rush_hour_morning || rush_hour_evening
            traffic_factor = 1.5;
        end

        % 考慮交通延遲後的去程與回程時間
        travel_to_site = base_travel_to * traffic_factor;
        travel_back_site = base_travel_back * traffic_factor;

        arrival_times(k) = actual_dispatch_time(k) + travel_to_site;

        % 檢查之前是否有卡車前往同一工地
        previous_work_idx = find(dispatch_order_for_chromosome(1:k-1) == site_id, 1, 'last');
        if isempty(previous_work_idx)
            work_start_time = max(arrival_times(k), time_windows(site_id, 1));
        else
            work_start_time = max(arrival_times(k), finish_time_site(previous_work_idx));
        end

        finish_time_site(k) = work_start_time + work_time(site_id);
        return_time = finish_time_site(k) + travel_back_site;
        truck_availability(truck_id) = return_time;

        % 卡車或工地等待時間處理
        if arrival_times(k) < work_start_time
            penalty_truck_time = penalty_truck_time + (work_start_time - arrival_times(k));
        elseif arrival_times(k) > work_start_time
            waiting_time = arrival_times(k) - work_start_time;
            if waiting_time > max_interrupt_time(site_id)
                penalty_side_time = penalty_side_time + 1;
            end
        end
    end

    % 混凝土施工時效懲罰 (派遣後90分鐘內必須完成施工)
    concrete_expiry_penalty = 0;
    for k = 1:num_dispatch_order
        if (finish_time_site(k) - actual_dispatch_time(k)) > 90
            concrete_expiry_penalty = concrete_expiry_penalty + penalty * 2;
        end
    end
    truck_waiting_penalty_factor = 1.5;
    total_penalty = penalty_side_time * penalty + penalty_truck_time*truck_waiting_penalty_factor + concrete_expiry_penalty;
    H(i) = total_penalty;
end

E = H;

end
