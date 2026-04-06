function [Population,FrontNo,CrowdDis] = EnvironmentalSelection(Population,N)
% The environmental selection of NSGA-II

%------------------------------- Copyright --------------------------------
% Copyright (c) 2023 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% Non-dominated sorting
    [FrontNo,MaxFNo] = NDSort(Population.objs,Population.cons,N);
    Next = FrontNo < MaxFNo;
    
    %% Calculate the crowding distance of each solution
    CrowdDis = CrowdingDistance(Population.objs,FrontNo);
    
    %% Select the solutions in the last front based on their crowding distances
    Last     = find(FrontNo==MaxFNo);
    [~,Rank] = sort(CrowdDis(Last),'descend');
    Next(Last(Rank(1:N-sum(Next)))) = true;
    
    %% Population for next generation (with objective-space dedup)
    selectedIdx = find(Next);
    selectedIdx = iDeduplicateByObjective(Population, selectedIdx);

    if numel(selectedIdx) < N
        selectedIdx = iSupplementSelection(Population, FrontNo, CrowdDis, selectedIdx, N);
    elseif numel(selectedIdx) > N
        selectedIdx = iTrimSelection(FrontNo, CrowdDis, selectedIdx, N);
    end

    Population = Population(selectedIdx);
    FrontNo    = FrontNo(selectedIdx);
    CrowdDis   = CrowdDis(selectedIdx);
end

function selectedIdx = iDeduplicateByObjective(Population, selectedIdx)
    if isempty(selectedIdx)
        return;
    end
    selectedObj = Population(selectedIdx).objs;
    [~, ia] = unique(selectedObj, 'rows', 'stable');
    selectedIdx = selectedIdx(ia);
end

function selectedIdx = iSupplementSelection(Population, FrontNo, CrowdDis, selectedIdx, N)
    allIdx = 1:numel(Population);
    remainIdx = setdiff(allIdx, selectedIdx, 'stable');
    if isempty(remainIdx)
        return;
    end

    rankKey = [FrontNo(remainIdx)', -CrowdDis(remainIdx)'];
    [~, order] = sortrows(rankKey, [1,2]);
    remainIdx = remainIdx(order);

    chosenObj = Population(selectedIdx).objs;

    % Prefer objective-unique supplements first
    for i = 1:numel(remainIdx)
        idx = remainIdx(i);
        obj = Population(idx).objs;
        if isempty(chosenObj) || ~ismember(obj, chosenObj, 'rows')
            selectedIdx(end+1) = idx; %#ok<AGROW>
            chosenObj(end+1,:) = obj; %#ok<AGROW>
            if numel(selectedIdx) >= N
                return;
            end
        end
    end

    % If still not enough, allow duplicates by rank order
    for i = 1:numel(remainIdx)
        idx = remainIdx(i);
        if ~ismember(idx, selectedIdx)
            selectedIdx(end+1) = idx; %#ok<AGROW>
            if numel(selectedIdx) >= N
                return;
            end
        end
    end
end

function selectedIdx = iTrimSelection(FrontNo, CrowdDis, selectedIdx, N)
    rankKey = [FrontNo(selectedIdx)', -CrowdDis(selectedIdx)'];
    [~, order] = sortrows(rankKey, [1,2]);
    selectedIdx = selectedIdx(order(1:N));
end
