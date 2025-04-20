%確認是否沒有相鄰
function best_pos = find_best_position(chromosome, positions, new_site)
if isempty(positions)
    best_pos = [];
    return;
end

best_pos = positions(1);
min_conflicts = inf;

for pos = positions
    % 檢查相鄰位置的衝突
    conflicts = 0;
    if pos > 1 && chromosome(pos-1) == new_site
        conflicts = conflicts + 1;
    end
    if pos < length(chromosome) && chromosome(pos+1) == new_site
        conflicts = conflicts + 1;
    end

    if conflicts < min_conflicts
        min_conflicts = conflicts;
        best_pos = pos;
    end
end
end