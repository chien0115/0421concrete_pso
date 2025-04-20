% 分鐘轉換為 HH:MM 格式的函數
function time_str = convert_minutes_to_time(minutes)
hours = floor(minutes / 60);
mins = mod(minutes, 60);
time_str = sprintf('%02d:%02d', hours, mins);
end