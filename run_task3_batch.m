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

%% =========================
% 1) Parameter grids
% =========================
% Demand axis (fixed tau)
tauDemand = 0.40;
qDemandList = [800, 1000, 1200, 1400];

% Carbon-tax axis (fixed Q)
qTax = 1000;
tauTaxList = [0.00, 0.20, 0.40, 0.60, 0.80, 1.00];

% Joint perturbation points
jointPoints = [ ...
    0.20,  900;
    0.40, 1000;
    0.60, 1100;
    0.80, 1200];

jobs = buildJobs(tauDemand, qDemandList, qTax, tauTaxList, jointPoints);
if doSinglePointOnly
    jobs = jobs(1);
end

%% =========================
% 2) Run all points (no dependency on platemo output)
% =========================
allRepRows = struct([]);
allSummaryRows = struct([]);

fprintf('\n[Task3] Total jobs = %d\n', numel(jobs));

for i = 1:numel(jobs)
    job = jobs(i);
    saveFile = fullfile(popDir, sprintf('finalPop_tau%.2f_Q%.0f.mat', job.carbonTax, job.quantityOfCargo));

    fprintf('\n==================================================\n');
    fprintf('[Task3] Job %d/%d | axis=%s | tau=%.4f | Q=%.2f\n', i, numel(jobs), job.axisType, job.carbonTax, job.quantityOfCargo);
    fprintf('[Task3] Planned final-pop file: %s\n', saveFile);

    runSingleOptimization(job, saveFile, populationSize, maxFE, odName, networkFile);

    if ~exist(saveFile, 'file')
        error('[Task3] final population MAT missing: %s', saveFile);
    end

    S = load(saveFile);
    if ~isfield(S, 'finalPopulation') || isempty(S.finalPopulation)
        error('[Task3] file loaded but finalPopulation is missing/empty: %s', saveFile);
    end

    rep = extractRepresentativeSolutions(S.finalPopulation, job, saveFile);

    repRows = repsToRows(rep, job);
    allRepRows = [allRepRows; repRows]; %#ok<AGROW>

    summaryRow = buildSummaryRow(rep, job, saveFile);
    allSummaryRows = [allSummaryRows; summaryRow]; %#ok<AGROW>

    fprintf('[Task3] Representative extraction done: CostBest / CarbonBest / Tradeoff\n');
end

%% =========================
% 3) Export MAT/XLSX
% =========================
plotData = struct();
plotData.generatedAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');
plotData.jobs = jobs;
plotData.representativeRows = allRepRows;
plotData.summaryRows = allSummaryRows;
plotData.demandAxis = allSummaryRows(strcmp({allSummaryRows.axisType}, 'demand'));
plotData.taxAxis = allSummaryRows(strcmp({allSummaryRows.axisType}, 'tax'));
plotData.jointAxis = allSummaryRows(strcmp({allSummaryRows.axisType}, 'joint'));

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

fprintf('\n[Task3] All done.\n');

%% =========================
% Local functions
% =========================
function jobs = buildJobs(tauDemand, qDemandList, qTax, tauTaxList, jointPoints)
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

    for k = 1:size(jointPoints,1)
        jobs(end+1).axisType = 'joint'; %#ok<AGROW>
        jobs(end).carbonTax = jointPoints(k,1);
        jobs(end).quantityOfCargo = jointPoints(k,2);
        jobs(end).pointName = sprintf('Joint_%d', k);
    end
end

function runSingleOptimization(job, saveFile, populationSize, maxFE, odName, networkFile)
    fprintf('[Task3] Running NSGAIIPlus...\n');

    problem = myObj_task3( ...
        'N', populationSize, ...
        'maxFE', maxFE, ...
        'parameter', {job.carbonTax, job.quantityOfCargo, odName, networkFile, saveFile});

    alg = NSGAIIPlus();
    alg.Solve(problem);

    fprintf('[Task3] NSGAIIPlus done.\n');
end

function rep = extractRepresentativeSolutions(finalPopulation, job, saveFile)
    popObj = vertcat(finalPopulation.objs);
    popDec = vertcat(finalPopulation.decs);

    if isempty(popObj)
        error('[Task3] Empty objective matrix from %s', saveFile);
    end

    [~, iCost] = min(popObj(:,1));
    [~, iCarbon] = min(popObj(:,2));

    z = min(popObj, [], 1);
    zMax = max(popObj, [], 1);
    denom = max(zMax - z, eps);
    normObj = (popObj - z) ./ denom;
    [~, iTrade] = min(sum(normObj.^2, 2));

    rep = struct();
    rep.CostBest   = buildOneRep('CostBest', iCost, finalPopulation(iCost), popDec(iCost,:), popObj(iCost,:), job);
    rep.CarbonBest = buildOneRep('CarbonBest', iCarbon, finalPopulation(iCarbon), popDec(iCarbon,:), popObj(iCarbon,:), job);
    rep.Tradeoff   = buildOneRep('Tradeoff', iTrade, finalPopulation(iTrade), popDec(iTrade,:), popObj(iTrade,:), job);
end

function out = buildOneRep(name, idx, ~, dec, obj, job)
    model = initModel(fullfile('MyModel','data','wangluojiegou.txt'), 'OD1');
    model.carbonTax = job.carbonTax;
    model.costOfUnitCarbon = job.carbonTax;
    model.baseDemand = job.quantityOfCargo;
    model.quantityOfCargo = job.quantityOfCargo;
    model.demandUncertaintyRate = 0;
    model.confidenceLevel = 0.5;

    [path, typeOfPath] = callCompat(model.analyseIndividual, dec, model);
    pathTransferType = callCompat(model.getPathTransferType, typeOfPath, model);

    [distanceOfPath, distanceArray] = getDistanceCompat(path, typeOfPath, model);
    [arriveTime, ~] = callCompat(model.getArriveTime, distanceArray, typeOfPath, pathTransferType, model, model.baseDemand);

    lowCarbonModeRatio = calcLowCarbonModeRatio(distanceArray, typeOfPath);

    out = struct();
    out.solutionType = name;
    out.populationIndex = idx;
    out.totalCost = obj(1);
    out.totalEmission = obj(2);
    out.arriveTime = arriveTime(end);
    out.lowCarbonModeRatio = lowCarbonModeRatio;
    out.pathStr = joinNum(path, '-');
    out.modeStr = modeString(typeOfPath);
    out.pathDistance = distanceOfPath;
end

function rows = repsToRows(rep, job)
    names = {'CostBest','CarbonBest','Tradeoff'};
    rows = repmat(struct(), 3, 1);
    for k = 1:3
        s = rep.(names{k});
        rows(k).axisType = job.axisType;
        rows(k).pointName = job.pointName;
        rows(k).carbonTax = job.carbonTax;
        rows(k).quantityOfCargo = job.quantityOfCargo;
        rows(k).solutionType = s.solutionType;
        rows(k).totalCost = s.totalCost;
        rows(k).totalEmission = s.totalEmission;
        rows(k).arriveTime = s.arriveTime;
        rows(k).lowCarbonModeRatio = s.lowCarbonModeRatio;
        rows(k).pathStr = s.pathStr;
        rows(k).modeStr = s.modeStr;
    end
end

function row = buildSummaryRow(rep, job, saveFile)
    row = struct();
    row.axisType = job.axisType;
    row.pointName = job.pointName;
    row.carbonTax = job.carbonTax;
    row.quantityOfCargo = job.quantityOfCargo;
    row.finalPopFile = saveFile;

    row.CostBest_totalCost = rep.CostBest.totalCost;
    row.CostBest_totalEmission = rep.CostBest.totalEmission;
    row.CostBest_arriveTime = rep.CostBest.arriveTime;
    row.CostBest_lowCarbonModeRatio = rep.CostBest.lowCarbonModeRatio;

    row.CarbonBest_totalCost = rep.CarbonBest.totalCost;
    row.CarbonBest_totalEmission = rep.CarbonBest.totalEmission;
    row.CarbonBest_arriveTime = rep.CarbonBest.arriveTime;
    row.CarbonBest_lowCarbonModeRatio = rep.CarbonBest.lowCarbonModeRatio;

    row.Tradeoff_totalCost = rep.Tradeoff.totalCost;
    row.Tradeoff_totalEmission = rep.Tradeoff.totalEmission;
    row.Tradeoff_arriveTime = rep.Tradeoff.arriveTime;
    row.Tradeoff_lowCarbonModeRatio = rep.Tradeoff.lowCarbonModeRatio;
end

function [distanceOfPath, distanceArray] = getDistanceCompat(path, typeOfPath, model)
    n = numel(typeOfPath);
    distanceArray = nan(1,n);
    for i = 1:n
        distanceArray(i) = model.distanceMat3D(path(i), path(i+1), typeOfPath(i));
    end
    bad = ~isfinite(distanceArray);
    distanceArray(bad) = 0;
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

function s = joinNum(vec, sep)
    if isempty(vec)
        s = '';
        return;
    end
    c = arrayfun(@(x)sprintf('%d',x), vec, 'UniformOutput', false);
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