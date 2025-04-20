function plan = decode_chromosome(chromosome, dispatch_times, t, demand_trips, time_windows, work_time, time)
    
    total_trips = sum(demand_trips);
    num_sites = length(demand_trips);
    
    % 初始化所有陣列
    site_ids = zeros(total_trips, 1);
    actual_dispatch_times = zeros(total_trips, 1);
    travel_times_to = zeros(total_trips, 1);
    arrival_times = zeros(total_trips, 1);
    site_set_start_times = zeros(total_trips, 1);
    work_start_times = zeros(total_trips, 1);
    work_times = zeros(total_trips, 1);
    site_finish_times = zeros(total_trips, 1);
    travel_times_back = zeros(total_trips, 1);
    return_times = zeros(total_trips, 1);
    truck_waiting_times = zeros(total_trips, 1);
    site_waiting_times = zeros(total_trips, 1);
    
    truck_availability = zeros(t, 1);
    
    for i = 1:total_trips
        site_id = chromosome(i);

        %%% 安全檢查索引，避免超出範圍 %%%
        site_id = max(1, min(num_sites, round(site_id)));
        site_ids(i) = site_id;

        travel_times_to(i) = time(site_id, 1);
        travel_times_back(i) = time(site_id, 2);
        site_set_start_times(i) = time_windows(site_id, 1);
        work_times(i) = work_time(site_id);
        
        if i <= t
            actual_dispatch_times(i) = dispatch_times(i);
            truck_id = i;
        else
            [next_available_time, truck_id] = min(truck_availability);
            actual_dispatch_times(i) = next_available_time;
        end
        
        arrival_times(i) = actual_dispatch_times(i) + travel_times_to(i);
        
        previous_work_idx = find(site_ids(1:i-1) == site_id, 1, 'last');
        if isempty(previous_work_idx)
            work_start_times(i) = max(arrival_times(i), site_set_start_times(i));
        else
            work_start_times(i) = max(arrival_times(i), site_finish_times(previous_work_idx));
        end
        
        site_finish_times(i) = work_start_times(i) + work_times(i);
        return_times(i) = site_finish_times(i) + travel_times_back(i);
        truck_availability(truck_id) = return_times(i);
        
        % 等待時間計算
        if ~isempty(previous_work_idx)
            if arrival_times(i) < site_finish_times(previous_work_idx)
                truck_waiting_times(i) = site_finish_times(previous_work_idx) - arrival_times(i);
            elseif arrival_times(i) > site_finish_times(previous_work_idx)
                site_waiting_times(i) = arrival_times(i) - site_finish_times(previous_work_idx);
            end
        else
            if arrival_times(i) < site_set_start_times(i)
                truck_waiting_times(i) = site_set_start_times(i) - arrival_times(i);
            else
                site_waiting_times(i) = arrival_times(i) - site_set_start_times(i);
            end
        end
        
    end
    
    vehicle_ids = (1:total_trips)';
    plan = [vehicle_ids, site_ids, actual_dispatch_times, travel_times_to, arrival_times, ...
        site_set_start_times, work_start_times, work_times, site_finish_times, travel_times_back, ...
        return_times, truck_waiting_times, site_waiting_times];
end
