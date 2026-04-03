clc; clear; close all;

cd(fileparts(mfilename('fullpath')));
addpath(genpath(cd));

%% =========================
% 0) Output folders and switches
% =========================
outRoot = fullfile(pwd, 'result_task3');
popDir = fullfile(outRoot, 'final_population');
if ~exist(popDir, 'dir'); mkdir(popDir); end

doSinglePointOnly = false;  % true: only run first point for debug

populationSize = 100;
maxFE = 10000;
odName = 'OD1';
networkFile = fullfile('MyModel','data','wangluojiegou.txt');

% Task-3 uncertainty (enabled, not collapsed to deterministic by default)
rho = 0.20;
alpha = 0.80;

%% =========================
% 1) Parameter grids
% =========================
% Demand axis (fixed tau)
tauDemand = 0.40;
qDemandList = [800, 1000, 1200, 1400];

% Carbon-tax axis (fixed Q)
qTax = 1000;
tauTaxList = [0.00, 0.20, 0.40, 0.60, 0.80, 1.00];

% Four-corner points for dominance check
qLow = 800; qHigh = 1400;
tauLow = 0.10; tauHigh = 0.80;
fourCorners = [ ...
    tauLow,  qLow;
    tauLow,  qHigh;
    tauHigh, qLow;
    tauHigh, qHigh];

% Local interval sweep around likely switch area
localSweep = [ ...
    0.30, 900;
    0.40, 900;
    0.50, 900;
    0.30, 1100;
    0.40, 1100;
    0.50, 1100];

jobs = buildJobs(tauDemand, qDemandList, qTax, tauTaxList, fourCorners, localSweep);
if doSinglePointOnly
    jobs = jobs(1);
end

%% =========================
% 2) Run all points (no dependency on platemo output)
% =========================
allRepRows = struct([]);
allSummaryRows = struct([]);
allTradeoffRows = struct([]);

fprintf('\n[Task3] Total jobs = %d\n', numel(jobs));

for i = 1:numel(jobs)
    job = jobs(i);
    saveFile = fullfile(popDir, sprintf('finalPop_tau%.2f_Q%.0f.mat', job.carbonTax, job.quantityOfCargo));

    fprintf('\n==================================================\n');
    fprintf('[Task3] Job %d/%d | axis=%s | tau=%.4f | Q=%.2f\n', i, numel(jobs), job.axisType, job.carbonTax, job.quantityOfCargo);
    fprintf('[Task3] Planned final-pop file: %s\n', saveFile);

    runSingleOptimization(job, saveFile, populationSize, maxFE, odName, networkFile, rho, alpha);

    if ~exist(saveFile, 'file')
        error('[Task3] final population MAT missing: %s', saveFile);
    end

    S = load(saveFile);
    if ~isfield(S, 'finalPopulation') || isempty(S.finalPopulation)
        error('[Task3] file loaded but finalPopulation is missing/empty: %s', saveFile);
    end

    rep = extractRepresentativeSolutions(S.finalPopulation, job, saveFile, odName, networkFile, rho, alpha);

    repRows = repsToRows(rep, job, rho, alpha);
    allRepRows = [allRepRows; repRows]; %#ok<AGROW>

    summaryRow = buildSummaryRow(rep, job, saveFile, rho, alpha);
    allSummaryRows = [allSummaryRows; summaryRow]; %#ok<AGROW>

    allTradeoffRows = [allTradeoffRows; buildTradeoffRow(rep.Tradeoff, job)]; %#ok<AGROW>

    fprintf('[Task3] Representative extraction done (nondominated set): CostBest / CarbonBest / Tradeoff\n');
end

%% =========================
% 3) Reranking analysis (signature-based)
% =========================
rerankingRows = buildRerankingRows(allTradeoffRows);

%% =========================
% 4) Export MAT/XLSX
% =========================
plotData = struct();
plotData.generatedAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');
plotData.jobs = jobs;
plotData.rho = rho;
plotData.alpha = alpha;
plotData.representativeRows = allRepRows;
plotData.summaryRows = allSummaryRows;
plotData.tradeoffRows = allTradeoffRows;
plotData.rerankingRows = rerankingRows;
plotData.demandAxis = allSummaryRows(strcmp({allSummaryRows.axisType}, 'demand'));
plotData.taxAxis = allSummaryRows(strcmp({allSummaryRows.axisType}, 'tax'));
plotData.fourCornerAxis = allSummaryRows(strcmp({allSummaryRows.axisType}, 'fourcorner'));
plotData.localSweepAxis = allSummaryRows(strcmp({allSummaryRows.axisType}, 'localscan'));

plotMatFile = fullfile(outRoot, 'task3_plot_data.mat');
save(plotMatFile, 'plotData');
fprintf('\n[Task3] Saved: %s\n', plotMatFile);

repTable = struct2table(allRepRows);
repXlsx = fullfile(outRoot, 'task3_representative_table.xlsx');
writetable(repTable, repXlsx);
fprintf('[Task3] Saved: %s\n', repXlsx);

summaryTable = struct2table(allSummaryRows);
summaryXlsx = fullfile(outRoot, 'task3_summary_table.xlsx');
writetable(summaryTable, summaryXlsx);
fprintf('[Task3] Saved: %s\n', summaryXlsx);

rerankTable = struct2table(rerankingRows);
rerankXlsx = fullfile(outRoot, 'task3_reranking_table.xlsx');
writetable(rerankTable, rerankXlsx);
fprintf('[Task3] Saved: %s\n', rerankXlsx);

fprintf('\n[Task3] All done.\n');

%% =========================
% Local functions
% =========================
function jobs = buildJobs(tauDemand, qDemandList, qTax, tauTaxList, fourCorners, localSweep)
    jobs = struct('axisType', {}, 'carbonTax', {}, 'quantityOfCargo', {}, 'pointName', {});

    for k = 1:numel(qDemandList)
        jobs(end+1).axisType = 'demand'; %#ok<AGROW>
        jobs(end).carbonTax = tauDemand;
        jobs(end).quantityOfCargo = qDemandList(k);
        jobs(end).pointName = sprintf('Demand_%d', k);
    end

    for k = 1:numel(tauTaxList)
        jobs(end+1).axisType = 'tax'; %#ok<AGROW>
        jobs(end).carbonTax = tauTaxList(k);
        jobs(end).quantityOfCargo = qTax;
        jobs(end).pointName = sprintf('Tax_%d', k);
    end

    for k = 1:size(fourCorners,1)
        jobs(end+1).axisType = 'fourcorner'; %#ok<AGROW>
        jobs(end).carbonTax = fourCorners(k,1);
        jobs(end).quantityOfCargo = fourCorners(k,2);
        jobs(end).pointName = sprintf('Corner_%d', k);
    end

    for k = 1:size(localSweep,1)
        jobs(end+1).axisType = 'localscan'; %#ok<AGROW>
        jobs(end).carbonTax = localSweep(k,1);
        jobs(end).quantityOfCargo = localSweep(k,2);
        jobs(end).pointName = sprintf('Local_%d', k);
    end
end

function runSingleOptimization(job, saveFile, populationSize, maxFE, odName, networkFile, rho, alpha)
    fprintf('[Task3] Running NSGAIIPlus...\n');

    problem = myObj_task3( ...
        'N', populationSize, ...
        'maxFE', maxFE, ...
        'parameter', {job.carbonTax, job.quantityOfCargo, odName, networkFile, saveFile, rho, alpha});

    alg = NSGAIIPlus();
    alg.Solve(problem);

    fprintf('[Task3] NSGAIIPlus done.\n');
end

function rep = extractRepresentativeSolutions(finalPopulation, job, saveFile, odName, networkFile, rho, alpha)
    popObj = vertcat(finalPopulation.objs);
    popDec = vertcat(finalPopulation.decs);

    if isempty(popObj)
        error('[Task3] Empty objective matrix from %s', saveFile);
    end

    % 1) Restrict representatives to nondominated front only
    frontNo = NDSort(popObj, inf);
    ndMask = (frontNo == 1);
    ndObj = popObj(ndMask,:);
    ndDec = popDec(ndMask,:);
    ndIdx = find(ndMask);

    if isempty(ndObj)
        error('[Task3] No nondominated solutions found in %s', saveFile);
    end

    [~, iCostND] = min(ndObj(:,1));
    [~, iCarbonND] = min(ndObj(:,2));

    % 2) Tradeoff = normalized equal-weight sum (not ideal-point distance)
    z = min(ndObj, [], 1);
    zMax = max(ndObj, [], 1);
    denom = max(zMax - z, eps);
    normObj = (ndObj - z) ./ denom;
    score = 0.5 * normObj(:,1) + 0.5 * normObj(:,2);
    [~, iTradeND] = min(score);

    rep = struct();
    rep.CostBest   = buildOneRep('CostBest', ndIdx(iCostND), ndDec(iCostND,:), ndObj(iCostND,:), job, odName, networkFile, rho, alpha);
    rep.CarbonBest = buildOneRep('CarbonBest', ndIdx(iCarbonND), ndDec(iCarbonND,:), ndObj(iCarbonND,:), job, odName, networkFile, rho, alpha);
    rep.Tradeoff   = buildOneRep('Tradeoff', ndIdx(iTradeND), ndDec(iTradeND,:), ndObj(iTradeND,:), job, odName, networkFile, rho, alpha);
end

function out = buildOneRep(name, idx, dec, obj, job, odName, networkFile, rho, alpha)
    model = initModel(networkFile, odName);
    model.carbonTax = job.carbonTax;
    model.costOfUnitCarbon = job.carbonTax;
    model.baseDemand = job.quantityOfCargo;
    model.quantityOfCargo = job.quantityOfCargo;
    model.demandUncertaintyRate = rho;
    model.confidenceLevel = alpha;
    Qeq = model.getEquivalentDemand(model);

    [path, typeOfPath] = callCompat(model.analyseIndividual, dec, model);
    pathTransferType = callCompat(model.getPathTransferType, typeOfPath, model);

    [distanceOfPath, distanceArray, hasInvalidEdge] = getDistanceCompat(path, typeOfPath, model);
    [arriveTime, ~] = callCompat(model.getArriveTime, distanceArray, typeOfPath, pathTransferType, model, Qeq);

    [~, detail] = callCompat(model.getIndividualObjs, dec, model);

    lowCarbonModeRatio = calcLowCarbonModeRatio(distanceArray, typeOfPath);

    out = struct();
    out.solutionType = name;
    out.populationIndex = idx;

    out.totalCost = obj(1);
    out.totalEmission = obj(2);

    out.arriveTime = arriveTime(end);
    out.arriveTimeFull = joinNum(arriveTime, '->', '%.2f');
    out.lowCarbonModeRatio = lowCarbonModeRatio;

    out.pathStr = joinNum(path, '-', '%d');
    out.modeStr = modeString(typeOfPath);
    out.transferStr = joinNum(pathTransferType, '-', '%d');

    out.pathDistance = distanceOfPath;
    out.hasInvalidEdge = hasInvalidEdge;
    out.Qeq = Qeq;

    % Evidence-chain fields from detail
    out.C_wait = getFieldOrNaN(detail, 'C_wait');
    out.C_trans = getFieldOrNaN(detail, 'C_trans');
    out.C_transfer = getFieldOrNaN(detail, 'C_transfer');
    out.C_timeWindow = getFieldOrNaN(detail, 'C_timeWindow');
    out.C_damage = getFieldOrNaN(detail, 'C_damage');
    out.C_tax = getFieldOrNaN(detail, 'C_tax');

    out.signature = [out.pathStr, '|', out.modeStr];
end

function rows = repsToRows(rep, job, rho, alpha)
    names = {'CostBest','CarbonBest','Tradeoff'};
    rows = repmat(struct(), 3, 1);
    for k = 1:3
        s = rep.(names{k});
        rows(k).axisType = job.axisType;
        rows(k).pointName = job.pointName;
        rows(k).carbonTax = job.carbonTax;
        rows(k).quantityOfCargo = job.quantityOfCargo;
        rows(k).rho = rho;
        rows(k).alpha = alpha;
        rows(k).Qeq = s.Qeq;

        rows(k).solutionType = s.solutionType;
        rows(k).populationIndex = s.populationIndex;
        rows(k).signature = s.signature;

        rows(k).totalCost = s.totalCost;
        rows(k).totalEmission = s.totalEmission;
        rows(k).arriveTime = s.arriveTime;
        rows(k).arriveTimeFull = s.arriveTimeFull;

        rows(k).lowCarbonModeRatio = s.lowCarbonModeRatio;
        rows(k).pathStr = s.pathStr;
        rows(k).modeStr = s.modeStr;
        rows(k).transferStr = s.transferStr;

        rows(k).C_wait = s.C_wait;
        rows(k).C_trans = s.C_trans;
        rows(k).C_transfer = s.C_transfer;
        rows(k).C_timeWindow = s.C_timeWindow;
        rows(k).C_damage = s.C_damage;
        rows(k).C_tax = s.C_tax;

        rows(k).hasInvalidEdge = s.hasInvalidEdge;
    end
end

function row = buildSummaryRow(rep, job, saveFile, rho, alpha)
    row = struct();
    row.axisType = job.axisType;
    row.pointName = job.pointName;
    row.carbonTax = job.carbonTax;
    row.quantityOfCargo = job.quantityOfCargo;
    row.rho = rho;
    row.alpha = alpha;
    row.Qeq = rep.Tradeoff.Qeq;
    row.finalPopFile = saveFile;

    row.CostBest_signature = rep.CostBest.signature;
    row.CostBest_totalCost = rep.CostBest.totalCost;
    row.CostBest_totalEmission = rep.CostBest.totalEmission;
    row.CostBest_arriveTime = rep.CostBest.arriveTime;
    row.CostBest_lowCarbonModeRatio = rep.CostBest.lowCarbonModeRatio;

    row.CarbonBest_signature = rep.CarbonBest.signature;
    row.CarbonBest_totalCost = rep.CarbonBest.totalCost;
    row.CarbonBest_totalEmission = rep.CarbonBest.totalEmission;
    row.CarbonBest_arriveTime = rep.CarbonBest.arriveTime;
    row.CarbonBest_lowCarbonModeRatio = rep.CarbonBest.lowCarbonModeRatio;

    row.Tradeoff_signature = rep.Tradeoff.signature;
    row.Tradeoff_totalCost = rep.Tradeoff.totalCost;
    row.Tradeoff_totalEmission = rep.Tradeoff.totalEmission;
    row.Tradeoff_arriveTime = rep.Tradeoff.arriveTime;
    row.Tradeoff_lowCarbonModeRatio = rep.Tradeoff.lowCarbonModeRatio;
end

function row = buildTradeoffRow(tradeoff, job)
    row = struct();
    row.axisType = job.axisType;
    row.pointName = job.pointName;
    row.carbonTax = job.carbonTax;
    row.quantityOfCargo = job.quantityOfCargo;
    row.Qeq = tradeoff.Qeq;
    row.signature = tradeoff.signature;
    row.totalCost = tradeoff.totalCost;
    row.totalEmission = tradeoff.totalEmission;
    row.C_wait = tradeoff.C_wait;
    row.C_trans = tradeoff.C_trans;
    row.C_transfer = tradeoff.C_transfer;
    row.C_timeWindow = tradeoff.C_timeWindow;
    row.C_damage = tradeoff.C_damage;
    row.C_tax = tradeoff.C_tax;
end

function rows = buildRerankingRows(tradeoffRows)
    if isempty(tradeoffRows)
        rows = struct([]);
        return;
    end

    T = struct2table(tradeoffRows);
    axisList = unique(T.axisType, 'stable');

    rowCell = {};
    for a = 1:numel(axisList)
        axisName = axisList{a};
        A = T(strcmp(T.axisType, axisName), :);
        A = sortAxisRows(A, axisName);

        prevSig = '';
        prevComp = [];
        for i = 1:height(A)
            r = struct();
            r.axisType = A.axisType{i};
            r.pointName = A.pointName{i};
            r.carbonTax = A.carbonTax(i);
            r.quantityOfCargo = A.quantityOfCargo(i);
            r.Qeq = A.Qeq(i);
            r.signature = A.signature{i};
            r.totalCost = A.totalCost(i);
            r.totalEmission = A.totalEmission(i);

            if i == 1
                r.switchType = 'Initial';
                r.fromSignature = '';
                r.toSignature = A.signature{i};
                r.deltaCost = NaN;
                r.deltaEmission = NaN;
                r.mainDriver = '';
                r.deltaMainDriver = NaN;
            else
                r.fromSignature = prevSig;
                r.toSignature = A.signature{i};
                r.deltaCost = A.totalCost(i) - A.totalCost(i-1);
                r.deltaEmission = A.totalEmission(i) - A.totalEmission(i-1);

                if strcmp(prevSig, A.signature{i})
                    r.switchType = 'Keep';
                else
                    r.switchType = 'Switch';
                end

                compNow = [A.C_wait(i), A.C_trans(i), A.C_transfer(i), A.C_timeWindow(i), A.C_damage(i), A.C_tax(i)];
                compPrev = prevComp;
                dComp = compNow - compPrev;
                compNames = {'C_wait','C_trans','C_transfer','C_timeWindow','C_damage','C_tax'};
                [~, iMain] = max(abs(dComp));
                r.mainDriver = compNames{iMain};
                r.deltaMainDriver = dComp(iMain);
            end

            prevSig = A.signature{i};
            prevComp = [A.C_wait(i), A.C_trans(i), A.C_transfer(i), A.C_timeWindow(i), A.C_damage(i), A.C_tax(i)];
            rowCell{end+1,1} = r; %#ok<AGROW>
        end
    end

    rows = vertcat(rowCell{:});
end

function A = sortAxisRows(A, axisName)
    switch lower(axisName)
        case 'demand'
            [~, idx] = sort(A.quantityOfCargo, 'ascend');
        case 'tax'
            [~, idx] = sort(A.carbonTax, 'ascend');
        case 'fourcorner'
            key = (A.quantityOfCargo - min(A.quantityOfCargo)) .* 1000 + A.carbonTax;
            [~, idx] = sort(key, 'ascend');
        otherwise
            [~, idx] = sortrows([A.carbonTax, A.quantityOfCargo], [1,2]);
    end
    A = A(idx,:);
end

function [distanceOfPath, distanceArray, hasInvalidEdge] = getDistanceCompat(path, typeOfPath, model)
    n = numel(typeOfPath);
    distanceArray = nan(1,n);
    hasInvalidEdge = false;
    for i = 1:n
        distanceArray(i) = model.distanceMat3D(path(i), path(i+1), typeOfPath(i));
    end
    if any(~isfinite(distanceArray))
        hasInvalidEdge = true;
        error('[Task3] Invalid edge detected in representative solution path/mode.');
    end
    distanceOfPath = sum(distanceArray);
end

function ratio = calcLowCarbonModeRatio(distanceArray, typeOfPath)
    totalDist = sum(distanceArray);
    if totalDist <= 0
        ratio = 0;
        return;
    end
    lowCarbonMask = ismember(typeOfPath, [2,3]);
    ratio = sum(distanceArray(lowCarbonMask)) / totalDist;
end

function s = joinNum(vec, sep, fmt)
    if isempty(vec)
        s = '';
        return;
    end
    c = arrayfun(@(x)sprintf(fmt,x), vec, 'UniformOutput', false);
    s = strjoin(c, sep);
end

function s = modeString(typeOfPath)
    map = {'R','T','W'};
    c = cell(1,numel(typeOfPath));
    for i = 1:numel(typeOfPath)
        id = typeOfPath(i);
        if id >= 1 && id <= numel(map)
            c{i} = map{id};
        else
            c{i} = sprintf('M%d', id);
        end
    end
    s = strjoin(c, '-');
end

function x = getFieldOrNaN(S, f)
    if isstruct(S) && isfield(S, f) && ~isempty(S.(f))
        x = S.(f);
    else
        x = NaN;
    end
end

function varargout = callCompat(funcHandle, varargin)
    errLog = {};

    try
        [varargout{1:nargout}] = funcHandle(varargin{:});
        return;
    catch ME
        errLog{end+1} = ME.message; %#ok<AGROW>
    end

    if ~isempty(varargin)
        try
            [varargout{1:nargout}] = funcHandle(varargin{1});
            return;
        catch ME
            errLog{end+1} = ME.message; %#ok<AGROW>
        end
    end

    if numel(varargin) >= 2
        try
            [varargout{1:nargout}] = funcHandle(varargin{2}, varargin{1});
            return;
        catch ME
            errLog{end+1} = ME.message; %#ok<AGROW>
        end
    end

    error('run_task3_batch:CallFailed', 'Compatibility call failed. Errors:\n%s', strjoin(errLog, '\n---\n'));
end
