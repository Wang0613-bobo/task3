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

% Task-3 uncertainty
rho = 0.20;
alpha = 0.80;
costClosureTol = 1e-6;
objConsistencyTol = 1e-8;

% Scenario-planning configuration
scenarioConfig = struct();
scenarioConfig.numDemandScenarios = 9;
scenarioConfig.demandDistribution = 'triangular';   % triangular / uniform
scenarioConfig.demandScenarioValues = [];           % 可留空；若非空则优先使用
scenarioConfig.demandScenarioProb = [];             % 可留空；若 values 非空且 prob 为空，则默认等概率
scenarioConfig.useCVaRAggregation = true;
scenarioConfig.riskBlend = 0.50;

%% =========================
% 1) Parameter grids
% =========================
% Demand axis (fixed tau)
tauDemand = 0.40;
qDemandList = [800, 1000, 1200, 1400];

% Carbon-tax axis (fixed Q)
qTax = 1000;
tauTaxList = [0.00, 0.20, 0.40, 0.60, 0.80, 1.00];

% Four-corner points for interaction contrast
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
allNDStatsRows = struct([]);

fprintf('\n[Task3] Total jobs = %d\n', numel(jobs));

for i = 1:numel(jobs)
    job = jobs(i);
    saveFile = fullfile(popDir, sprintf('finalPop_tau%.2f_Q%.0f.mat', job.carbonTax, job.quantityOfCargo));

    fprintf('\n==================================================\n');
    fprintf('[Task3] Job %d/%d | axis=%s | tau=%.4f | Q=%.2f\n', i, numel(jobs), job.axisType, job.carbonTax, job.quantityOfCargo);
    fprintf('[Task3] Planned final-pop file: %s\n', saveFile);

    runMeta = runSingleOptimization(job, saveFile, populationSize, maxFE, odName, networkFile, rho, alpha, scenarioConfig);

    if ~exist(saveFile, 'file')
        error('[Task3] final population MAT missing: %s', saveFile);
    end

    S = load(saveFile);
    if ~isfield(S, 'finalPopulation') || isempty(S.finalPopulation)
        error('[Task3] file loaded but finalPopulation is missing/empty: %s', saveFile);
    end

    [rep, ndStats] = extractRepresentativeSolutions( ...
        S.finalPopulation, job, saveFile, odName, networkFile, rho, alpha, ...
        scenarioConfig, runMeta.finalPopulationSource, costClosureTol, objConsistencyTol);

    repRows = repsToRows(rep, job, rho, alpha, ndStats);
    allRepRows = [allRepRows; repRows]; %#ok<AGROW>

    summaryRow = buildSummaryRow(rep, job, saveFile, rho, alpha, ndStats);
    allSummaryRows = [allSummaryRows; summaryRow]; %#ok<AGROW>

    allNDStatsRows = [allNDStatsRows; buildNDStatsRow(ndStats, rep, job, saveFile, rho, alpha)]; %#ok<AGROW>

    fprintf('[Task3] Representative extraction done (nondominated set): CostBest / CarbonBest / Tradeoff\n');
end

validateClosureBeforeExport(allRepRows, costClosureTol);


%% =========================
% 3) Reranking analysis (signature-based)
% =========================
reranking_tradeoff = buildRerankingRows(allRepRows, 'Tradeoff');
reranking_costbest = buildRerankingRows(allRepRows, 'CostBest');
reranking_carbonbest = buildRerankingRows(allRepRows, 'CarbonBest');
rerankingRows = [reranking_tradeoff; reranking_costbest; reranking_carbonbest];
fourcornerComparison = buildFourCornerComparison(allRepRows);

%% =========================
% 4) Export MAT/XLSX
% =========================
plotData = struct();
plotData.generatedAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');
plotData.jobs = jobs;
plotData.rho = rho;
plotData.alpha = alpha;
plotData.scenarioConfig = scenarioConfig;
plotData.representativeRows = allRepRows;
plotData.summaryRows = allSummaryRows;
plotData.ndStatsRows = allNDStatsRows;
plotData.rerankingRows = rerankingRows;
plotData.reranking_tradeoff = reranking_tradeoff;
plotData.reranking_costbest = reranking_costbest;
plotData.reranking_carbonbest = reranking_carbonbest;
plotData.fourcornerComparison = fourcornerComparison;
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

ndTable = struct2table(allNDStatsRows);
ndXlsx = fullfile(outRoot, 'task3_nd_summary_table.xlsx');
writetable(ndTable, ndXlsx);
fprintf('[Task3] Saved: %s\n', ndXlsx);

rerankTable = struct2table(rerankingRows);
rerankXlsx = fullfile(outRoot, 'task3_reranking_table.xlsx');
writetable(rerankTable, rerankXlsx);
fprintf('[Task3] Saved: %s\n', rerankXlsx);

cornerTable = struct2table(fourcornerComparison);
cornerXlsx = fullfile(outRoot, 'task3_fourcorner_compare_table.xlsx');
writetable(cornerTable, cornerXlsx);
fprintf('[Task3] Saved: %s\n', cornerXlsx);

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

function meta = runSingleOptimization(job, saveFile, populationSize, maxFE, odName, networkFile, rho, alpha, scenarioConfig)
    fprintf('[Task3] Running NSGAIIPlus...\n');
    meta = struct();
    meta.finalPopulationSource = 'algorithm_save_hook';

    problem = myObj_task3( ...
        'N', populationSize, ...
        'maxFE', maxFE, ...
        'parameter', {job.carbonTax, job.quantityOfCargo, odName, networkFile, saveFile, rho, alpha, scenarioConfig});

    alg = NSGAIIPlus();
    alg.Solve(problem);

    if ~exist(saveFile, 'file')
        fprintf(2, '[Task3][WARN] Expected final-pop MAT not found after Solve. Trying fallback save from alg.result...\n');
        try
            if isempty(alg.result)
                error('alg.result is empty.');
            end
            if size(alg.result,2) >= 2
                finalPopulation = alg.result{end,2}; %#ok<NASGU>
            else
                finalPopulation = alg.result{end}; %#ok<NASGU>
            end
            saveDir = fileparts(saveFile);
            if ~isempty(saveDir) && ~exist(saveDir,'dir')
                mkdir(saveDir);
            end
            save(saveFile, 'finalPopulation');
            fprintf('[Task3][Fallback] Saved final population to: %s\n', saveFile);
            meta.finalPopulationSource = 'fallback_alg_result';
        catch ME
            fprintf(2, '[Task3][Fallback] Failed: %s\n', ME.message);
        end
    end

    fprintf('[Task3] NSGAIIPlus done.\n');
end

function [rep, ndStats] = extractRepresentativeSolutions(finalPopulation, job, saveFile, odName, networkFile, rho, alpha, scenarioConfig, finalPopulationSource, costClosureTol, objConsistencyTol)
    popObj = vertcat(finalPopulation.objs);
    popDec = vertcat(finalPopulation.decs);

    if isempty(popObj)
        error('[Task3] Empty objective matrix from %s', saveFile);
    end

    [reEvalObjAll, detailAll] = reEvaluatePopulation(popDec, job, odName, networkFile, rho, alpha, scenarioConfig);
    popObjGap = abs(popObj - reEvalObjAll);
    maxObjGap = max(popObjGap, [], 1);
    isObjConsistentPopulation = all(maxObjGap <= objConsistencyTol);
    if ~isObjConsistentPopulation
        fprintf(2, ['[Task3][WARN] Population objective and export objective are inconsistent at %s: ' ...
            'maxCostGap=%.6e, maxCarbonGap=%.6e (tol=%.1e). ' ...
            'Representative extraction will continue using re-evaluated objectives only.\n'], ...
            job.pointName, maxObjGap(1), maxObjGap(2), objConsistencyTol);
    end

    frontNo = NDSort(reEvalObjAll, inf);
    ndMask = (frontNo == 1);
    ndObj = reEvalObjAll(ndMask,:);
    ndDec = popDec(ndMask,:);
    ndObjPop = popObj(ndMask,:);
    ndIdx = find(ndMask);
    ndDetail = detailAll(ndMask);

    if isempty(ndObj)
        error('[Task3] No nondominated solutions found in %s', saveFile);
    end

    [~, iCostND] = min(ndObj(:,1));
    carbonMin = min(ndObj(:,2));
    iCarbonCand = find(abs(ndObj(:,2) - carbonMin) <= 1e-12);
    if numel(iCarbonCand) == 1
        iCarbonND = iCarbonCand;
    else
        [~, kMinCost] = min(ndObj(iCarbonCand,1));
        iCarbonND = iCarbonCand(kMinCost);
    end

    z = min(ndObj, [], 1);
    zMax = max(ndObj, [], 1);
    denom = max(zMax - z, eps);
    normObj = (ndObj - z) ./ denom;
    score = 0.5 * normObj(:,1) + 0.5 * normObj(:,2);
    [~, iTradeND] = min(score);

    rep = struct();
    rep.CostBest   = buildOneRep('CostBest', ndIdx(iCostND), ndDec(iCostND,:), ndObj(iCostND,:), ndObjPop(iCostND,:), ndDetail{iCostND}, job, odName, networkFile, rho, alpha, scenarioConfig, costClosureTol);
    rep.CarbonBest = buildOneRep('CarbonBest', ndIdx(iCarbonND), ndDec(iCarbonND,:), ndObj(iCarbonND,:), ndObjPop(iCarbonND,:), ndDetail{iCarbonND}, job, odName, networkFile, rho, alpha, scenarioConfig, costClosureTol);
    rep.Tradeoff   = buildOneRep('Tradeoff', ndIdx(iTradeND), ndDec(iTradeND,:), ndObj(iTradeND,:), ndObjPop(iTradeND,:), ndDetail{iTradeND}, job, odName, networkFile, rho, alpha, scenarioConfig, costClosureTol);

    [~, iCostMaxND] = max(ndObj(:,1));
    [~, iCarbonMaxND] = max(ndObj(:,2));
    sigCostMax = getSignatureFromDec(ndDec(iCostMaxND,:), job, odName, networkFile, rho, alpha, scenarioConfig);
    sigCarbonMax = getSignatureFromDec(ndDec(iCarbonMaxND,:), job, odName, networkFile, rho, alpha, scenarioConfig);

    ndStats = struct();

    ndRepObj = [rep.CostBest.totalCost, rep.CostBest.totalEmission; ...
        rep.CarbonBest.totalCost, rep.CarbonBest.totalEmission; ...
        rep.Tradeoff.totalCost, rep.Tradeoff.totalEmission];
    domAmongRep = any(any((ndRepObj(:,1) <= ndRepObj(:,1)' & ndRepObj(:,2) <= ndRepObj(:,2)') & ...
        (ndRepObj(:,1) < ndRepObj(:,1)' | ndRepObj(:,2) < ndRepObj(:,2)')));
    if domAmongRep
        error('[Task3] Representative set contains internal dominance at %s; labels invalid.', job.pointName);
    end

    ndStats.finalPopulationSource = finalPopulationSource;
    ndStats.maxObjGapCost = maxObjGap(1);
    ndStats.maxObjGapCarbon = maxObjGap(2);
    ndStats.isObjConsistentPopulation = isObjConsistentPopulation;
    ndStats.rawPopSize = size(popObj,1);
    ndStats.uniqueObjCount = size(unique(reEvalObjAll, 'rows'), 1);
    ndStats.nND = size(ndObj,1);
    ndStats.uniqueNDCount = size(unique(ndObj, 'rows'), 1);
    ndStats.ndRatio = ndStats.nND / max(ndStats.rawPopSize, 1);
    ndStats.uniqueObjRatio = ndStats.uniqueObjCount / max(ndStats.rawPopSize, 1);
    ndStats.uniqueNDRatio = ndStats.uniqueNDCount / max(ndStats.rawPopSize, 1);
    ndStats.ndDuplicateRatio = 1 - ndStats.uniqueNDCount / max(ndStats.nND, 1);
    ndStats.ndDensityClass = classifyNDDensity(ndStats.nND);
    ndStats.ndEvidenceNote = sprintf('nND=%d, density=%s', ndStats.nND, ndStats.ndDensityClass);
    ndStats.isAllPopulationNearlyND = (ndStats.nND == ndStats.rawPopSize);
    ndStats.ndSemanticNote = '';
    if ndStats.nND == ndStats.rawPopSize
        ndStats.ndSemanticNote = 'nND may reflect output semantics rather than frontier richness';
        fprintf(2, '[Task3][WARN] %s | nND=%d equals rawPopSize=%d. nND may reflect output semantics rather than frontier richness.\n', ...
            job.pointName, ndStats.nND, ndStats.rawPopSize);
    end
    ndStats.costRange = max(ndObj(:,1)) - min(ndObj(:,1));
    ndStats.carbonRange = max(ndObj(:,2)) - min(ndObj(:,2));
    ndStats.extremeSignatureSet = strjoin(unique({rep.CostBest.signature, rep.CarbonBest.signature, sigCostMax, sigCarbonMax}, 'stable'), ';');
end

function out = buildOneRep(name, idx, dec, obj, popObjRef, detail, job, odName, networkFile, rho, alpha, scenarioConfig, costClosureTol)
    model = initModel(networkFile, odName);
    model.carbonTax = job.carbonTax;
    model.costOfUnitCarbon = job.carbonTax;
    model.baseDemand = job.quantityOfCargo;
    model.quantityOfCargo = job.quantityOfCargo;
    model.demandUncertaintyRate = rho;
    model.confidenceLevel = alpha;
    model = applyScenarioConfig(model, scenarioConfig);
    
    reEvalObj = obj;
    Qeq = model.getEquivalentDemand(model);

    path = getFieldOrDefault(detail, 'path', []);
    typeOfPath = getFieldOrDefault(detail, 'typeOfPath', []);
    if isempty(path) || isempty(typeOfPath)
        error('[Task3] Missing path/type in detail from getIndividualObjs (%s @ %s).', name, job.pointName);
    end
    pathTransferType = callCompat(model.getPathTransferType, typeOfPath, model);

    [distanceOfPath, distanceArray, hasInvalidEdge] = getDistanceCompat(path, typeOfPath, model);
    
    arriveTimeVec = getFieldOrDefault(detail, 'arriveTimeVector', []);
    if isempty(arriveTimeVec)
        [arriveTimeVec, ~] = callCompat(model.getArriveTime, distanceArray, typeOfPath, pathTransferType, model, Qeq);
    end

    lowCarbonModeRatio = calcLowCarbonModeRatio(distanceArray, typeOfPath);

    out = struct();
    out.solutionType = name;
    out.populationIndex = idx;

    out.populationTotalCost = popObjRef(1);
    out.populationTotalEmission = popObjRef(2);
    out.totalCostRaw = reEvalObj(1);
    out.totalCost = out.totalCostRaw;
    out.totalEmission = reEvalObj(2);
    out.populationObjGapCost = out.populationTotalCost - out.totalCost;
    out.populationObjGapCarbon = out.populationTotalEmission - out.totalEmission;
    out.coreAggregationGap = getFieldOrDefault(detail, 'F_costAggregationGap', NaN);
    out.isCoreCostClosed = getFieldOrDefault(detail, 'isCostClosedCore', true);

    out.arriveTime = arriveTimeVec(end);
    out.arriveTimeFull = joinNum(arriveTimeVec, '->', '%.2f');
    out.lowCarbonModeRatio = lowCarbonModeRatio;

    out.pathStr = joinNum(path, '-', '%d');
    out.modeStr = modeString(typeOfPath);
    out.transferStr = joinNum(pathTransferType, '-', '%d');
    out.pathSignature = out.pathStr;
    out.modeSignature = out.modeStr;

    out.pathDistance = distanceOfPath;
    out.hasInvalidEdge = hasInvalidEdge;
    out.Qeq = Qeq;

    out.C_wait = getFieldOrNaN(detail, 'C_wait');
    out.C_trans = getFieldOrNaN(detail, 'C_trans');
    out.C_transfer = getFieldOrNaN(detail, 'C_transfer');
    out.C_timeWindow = getFieldOrNaN(detail, 'C_timeWindow');
    out.C_damage = getFieldOrNaN(detail, 'C_damage');
    out.C_tax = getFieldOrNaN(detail, 'C_tax');

    out.scenarioCount = getFieldOrDefault(detail, 'scenarioCount', NaN);
    out.useCVaRAggregation = getFieldOrDefault(detail, 'useCVaRAggregation', false);
    out.riskBlend = getFieldOrDefault(detail, 'riskBlend', NaN);

    compVec = [out.C_wait, out.C_trans, out.C_transfer, out.C_timeWindow, out.C_damage, out.C_tax];
    if any(~isfinite(compVec))
        error(['[Task3] Non-finite cost components detected (%s @ %s). ' ...
            'Representative export aborted to prevent non-closed records.'], ...
            name, job.pointName);
    end

    out.costClosureSum = out.C_wait + out.C_trans + out.C_transfer + out.C_timeWindow + out.C_damage + out.C_tax;
    out.costClosureGapRaw = out.costClosureSum - out.totalCostRaw;
    out.isCostClosedRaw = abs(out.costClosureGapRaw) <= costClosureTol;
    out.costClosureAdjusted = false;
    out.costClosureGap = out.costClosureGapRaw;
    out.isCostClosed = out.isCostClosedRaw;
    if ~out.isCoreCostClosed || ~isfinite(out.coreAggregationGap)
        error('[Task3] Core model closure flag invalid (%s @ %s): gap=%.6e', ...
            name, job.pointName, out.coreAggregationGap);
    end
    if ~out.isCostClosedRaw
        error(['[Task3] Raw cost not closed (%s @ %s): rawTotal=%.10f, componentsSum=%.10f, ' ...
            'rawGap=%.6e. Export stage is validation-only and will not auto-correct.'], ...
            name, job.pointName, out.totalCostRaw, out.costClosureSum, out.costClosureGapRaw);
    end
    if abs(out.populationObjGapCost) > costClosureTol || abs(out.populationObjGapCarbon) > costClosureTol
        fprintf(2, ['[Task3][WARN] Representative pop/re-eval gap (%s @ %s): ' ...
            'dCost=%.6e, dCarbon=%.6e. Re-evaluated objectives are used for labels/export.\n'], ...
            name, job.pointName, out.populationObjGapCost, out.populationObjGapCarbon);
    end

    out.signature = [out.pathStr, '|', out.modeStr];
    out.labelSemantic = mapLabelSemantic(name);
    out.isStableEndpoint = false;
end

function validateClosureBeforeExport(allRepRows, costClosureTol)
    if isempty(allRepRows)
        error('[Task3] No representative rows generated; export aborted.');
    end
    compSum = [allRepRows.C_wait]' + [allRepRows.C_trans]' + [allRepRows.C_transfer]' + ...
        [allRepRows.C_timeWindow]' + [allRepRows.C_damage]' + [allRepRows.C_tax]';
    totalCost = [allRepRows.totalCostRaw]';
    gap = compSum - totalCost;
    badMask = ~isfinite(gap) | abs(gap) > costClosureTol;
    if any(badMask)
        firstBad = find(badMask, 1, 'first');
        r = allRepRows(firstBad);
        error(['[Task3] Pre-export closure validation failed at row #%d (%s | %s): ' ...
            'gap=%.6e, compSum=%.6f, totalCostRaw=%.6f'], ...
            firstBad, r.pointName, r.solutionType, gap(firstBad), compSum(firstBad), totalCost(firstBad));
    end
end


function sig = getSignatureFromDec(dec, job, odName, networkFile, rho, alpha, scenarioConfig)
    model = initModel(networkFile, odName);
    model.carbonTax = job.carbonTax;
    model.baseDemand = job.quantityOfCargo;
    model.quantityOfCargo = job.quantityOfCargo;
    model.demandUncertaintyRate = rho;
    model.confidenceLevel = alpha;
    model = applyScenarioConfig(model, scenarioConfig);
    [path, typeOfPath] = callCompat(model.analyseIndividual, dec, model);
    sig = [joinNum(path, '-', '%d'), '|', modeString(typeOfPath)];
end

function model = applyScenarioConfig(model, scenarioConfig)
    if isempty(scenarioConfig) || ~isstruct(scenarioConfig)
        return;
    end

    fieldNames = {'numDemandScenarios', 'demandDistribution', 'demandScenarioValues', ...
        'demandScenarioProb', 'useCVaRAggregation', 'riskBlend'};
    for i = 1:numel(fieldNames)
        f = fieldNames{i};
        if isfield(scenarioConfig, f)
            model.(f) = scenarioConfig.(f);
        end
    end
end

function rows = repsToRows(rep, job, rho, alpha, ndStats)
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

        rows(k).scenarioCount = s.scenarioCount;
        rows(k).useCVaRAggregation = s.useCVaRAggregation;
        rows(k).riskBlend = s.riskBlend;

        rows(k).solutionType = s.solutionType;
        rows(k).populationIndex = s.populationIndex;
        rows(k).signature = s.signature;

        rows(k).totalCost = s.totalCost;
        rows(k).totalCostRaw = s.totalCostRaw;
        rows(k).totalEmission = s.totalEmission;
        rows(k).arriveTime = s.arriveTime;
        rows(k).arriveTimeFull = s.arriveTimeFull;

        rows(k).lowCarbonModeRatio = s.lowCarbonModeRatio;
        rows(k).pathStr = s.pathStr;
        rows(k).modeStr = s.modeStr;
        rows(k).pathSignature = s.pathSignature;
        rows(k).modeSignature = s.modeSignature;
        rows(k).transferStr = s.transferStr;

        rows(k).C_wait = s.C_wait;
        rows(k).C_trans = s.C_trans;
        rows(k).C_transfer = s.C_transfer;
        rows(k).C_timeWindow = s.C_timeWindow;
        rows(k).C_damage = s.C_damage;
        rows(k).C_tax = s.C_tax;
        rows(k).costClosureSum = s.costClosureSum;
        rows(k).costClosureGapRaw = s.costClosureGapRaw;
        rows(k).isCostClosedRaw = s.isCostClosedRaw;
        rows(k).costClosureAdjusted = s.costClosureAdjusted;
        rows(k).costClosureGap = s.costClosureGap;
        rows(k).isCostClosed = s.isCostClosed;
        rows(k).coreAggregationGap = s.coreAggregationGap;
        rows(k).isCoreCostClosed = s.isCoreCostClosed;

        rows(k).hasInvalidEdge = s.hasInvalidEdge;
        rows(k).finalPopulationSource = ndStats.finalPopulationSource;
        rows(k).rawPopSize = ndStats.rawPopSize;
        rows(k).uniqueObjCount = ndStats.uniqueObjCount;
        rows(k).nND = ndStats.nND;
        rows(k).uniqueNDCount = ndStats.uniqueNDCount;
        rows(k).ndRatio = ndStats.ndRatio;
        rows(k).isAllPopulationNearlyND = ndStats.isAllPopulationNearlyND;
        rows(k).ndSemanticNote = ndStats.ndSemanticNote;
        rows(k).maxObjGapCost = ndStats.maxObjGapCost;
        rows(k).maxObjGapCarbon = ndStats.maxObjGapCarbon;
        rows(k).isObjConsistentPopulation = ndStats.isObjConsistentPopulation;
        rows(k).ndDensityClass = ndStats.ndDensityClass;
        rows(k).ndEvidenceNote = ndStats.ndEvidenceNote;
        rows(k).labelSemantic = s.labelSemantic;
        rows(k).isStableEndpoint = s.isStableEndpoint;
    end
end

function row = buildNDStatsRow(ndStats, rep, job, saveFile, rho, alpha)
    row = struct();
    row.axisType = job.axisType;
    row.pointName = job.pointName;
    row.carbonTax = job.carbonTax;
    row.quantityOfCargo = job.quantityOfCargo;
    row.rho = rho;
    row.alpha = alpha;
    row.Qeq = rep.Tradeoff.Qeq;
    row.scenarioCount = rep.Tradeoff.scenarioCount;
    row.useCVaRAggregation = rep.Tradeoff.useCVaRAggregation;
    row.riskBlend = rep.Tradeoff.riskBlend;
    row.finalPopFile = saveFile;
    row.finalPopulationSource = ndStats.finalPopulationSource;
    row.rawPopSize = ndStats.rawPopSize;
    row.uniqueObjCount = ndStats.uniqueObjCount;
    row.nND = ndStats.nND;
    row.uniqueNDCount = ndStats.uniqueNDCount;
    row.ndRatio = ndStats.ndRatio;
    row.maxObjGapCost = ndStats.maxObjGapCost;
    row.maxObjGapCarbon = ndStats.maxObjGapCarbon;
    row.isObjConsistentPopulation = ndStats.isObjConsistentPopulation;
    row.isAllPopulationNearlyND = ndStats.isAllPopulationNearlyND;
    row.ndSemanticNote = ndStats.ndSemanticNote;
    row.ndDensityClass = ndStats.ndDensityClass;
    row.ndEvidenceNote = ndStats.ndEvidenceNote;
    row.costRange = ndStats.costRange;
    row.carbonRange = ndStats.carbonRange;
    row.extremeSignatureSet = ndStats.extremeSignatureSet;
end

function row = buildSummaryRow(rep, job, saveFile, rho, alpha, ndStats)
    row = struct();
    row.axisType = job.axisType;
    row.pointName = job.pointName;
    row.carbonTax = job.carbonTax;
    row.quantityOfCargo = job.quantityOfCargo;
    row.rho = rho;
    row.alpha = alpha;
    row.Qeq = rep.Tradeoff.Qeq;
    row.scenarioCount = rep.Tradeoff.scenarioCount;
    row.useCVaRAggregation = rep.Tradeoff.useCVaRAggregation;
    row.riskBlend = rep.Tradeoff.riskBlend;
    row.finalPopFile = saveFile;
    row.finalPopulationSource = ndStats.finalPopulationSource;
    row.rawPopSize = ndStats.rawPopSize;
    row.uniqueObjCount = ndStats.uniqueObjCount;
    row.nND = ndStats.nND;
    row.uniqueNDCount = ndStats.uniqueNDCount;
    row.ndRatio = ndStats.ndRatio;
    row.uniqueObjRatio = ndStats.uniqueObjRatio;
    row.uniqueNDRatio = ndStats.uniqueNDRatio;
    row.ndDuplicateRatio = ndStats.ndDuplicateRatio;
    row.maxObjGapCost = ndStats.maxObjGapCost;
    row.maxObjGapCarbon = ndStats.maxObjGapCarbon;
    row.isObjConsistentPopulation = ndStats.isObjConsistentPopulation;
    row.isAllPopulationNearlyND = ndStats.isAllPopulationNearlyND;
    row.ndSemanticNote = ndStats.ndSemanticNote;
    row.ndDensityClass = ndStats.ndDensityClass;
    row.ndEvidenceNote = ndStats.ndEvidenceNote;

    row.CostBest_signature = rep.CostBest.signature;
    row.CostBest_totalCost = rep.CostBest.totalCost;
    row.CostBest_totalEmission = rep.CostBest.totalEmission;
    row.CostBest_arriveTime = rep.CostBest.arriveTime;
    row.CostBest_lowCarbonModeRatio = rep.CostBest.lowCarbonModeRatio;
    row.CostBest_costClosureSum = rep.CostBest.costClosureSum;
    row.CostBest_costClosureGap = rep.CostBest.costClosureGap;
    row.CostBest_isCostClosed = rep.CostBest.isCostClosed;

    row.CarbonBest_signature = rep.CarbonBest.signature;
    row.CarbonBest_totalCost = rep.CarbonBest.totalCost;
    row.CarbonBest_totalEmission = rep.CarbonBest.totalEmission;
    row.CarbonBest_arriveTime = rep.CarbonBest.arriveTime;
    row.CarbonBest_lowCarbonModeRatio = rep.CarbonBest.lowCarbonModeRatio;
    row.CarbonBest_costClosureSum = rep.CarbonBest.costClosureSum;
    row.CarbonBest_costClosureGap = rep.CarbonBest.costClosureGap;
    row.CarbonBest_isCostClosed = rep.CarbonBest.isCostClosed;

    row.Tradeoff_signature = rep.Tradeoff.signature;
    row.Tradeoff_totalCost = rep.Tradeoff.totalCost;
    row.Tradeoff_totalEmission = rep.Tradeoff.totalEmission;
    row.Tradeoff_arriveTime = rep.Tradeoff.arriveTime;
    row.Tradeoff_lowCarbonModeRatio = rep.Tradeoff.lowCarbonModeRatio;
    row.Tradeoff_costClosureSum = rep.Tradeoff.costClosureSum;
    row.Tradeoff_costClosureGap = rep.Tradeoff.costClosureGap;
    row.Tradeoff_isCostClosed = rep.Tradeoff.isCostClosed;

    row.costClosureSum = rep.Tradeoff.costClosureSum;
    row.costClosureGap = rep.Tradeoff.costClosureGap;
    row.isCostClosed = rep.Tradeoff.isCostClosed;
end

function rows = buildRerankingRows(allRepRows, solutionType)
    if isempty(allRepRows)
        rows = struct([]);
        return;
    end

    T = struct2table(allRepRows);
    T = T(strcmp(T.solutionType, solutionType), :);
    if isempty(T)
        rows = struct([]);
        return;
    end
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
            r.pathSignature = A.pathSignature{i};
            r.modeSignature = A.modeSignature{i};
            r.totalCost = A.totalCost(i);
            r.totalEmission = A.totalEmission(i);
            r.solutionType = solutionType;
            r.scanOrder = i;
            r.scanOrderLabel = getAxisOrderLabel(axisName, A, i);

            if i == 1
                r.switchType = 'Initial';
                r.fromSignature = '';
                r.toSignature = A.signature{i};
                r.pathSwitchType = 'Initial';
                r.modeSwitchType = 'Initial';
                r.deltaCost = NaN;
                r.deltaEmission = NaN;
                r.mainDriver = '';
                r.deltaMainDriver = NaN;
                r.delta_C_wait = NaN;
                r.delta_C_trans = NaN;
                r.delta_C_transfer = NaN;
                r.delta_C_timeWindow = NaN;
                r.delta_C_damage = NaN;
                r.delta_C_tax = NaN;
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
                if strcmp(A.pathSignature{i-1}, A.pathSignature{i})
                    r.pathSwitchType = 'KeepPath';
                else
                    r.pathSwitchType = 'SwitchPath';
                end
                if strcmp(A.modeSignature{i-1}, A.modeSignature{i})
                    r.modeSwitchType = 'KeepMode';
                else
                    r.modeSwitchType = 'SwitchMode';
                end

                compNow = [A.C_wait(i), A.C_trans(i), A.C_transfer(i), A.C_timeWindow(i), A.C_damage(i), A.C_tax(i)];
                compPrev = prevComp;
                dComp = compNow - compPrev;
                compNames = {'C_wait','C_trans','C_transfer','C_timeWindow','C_damage','C_tax'};
                [~, iMain] = max(abs(dComp));
                r.mainDriver = compNames{iMain};
                r.deltaMainDriver = dComp(iMain);
                r.delta_C_wait = dComp(1);
                r.delta_C_trans = dComp(2);
                r.delta_C_transfer = dComp(3);
                r.delta_C_timeWindow = dComp(4);
                r.delta_C_damage = dComp(5);
                r.delta_C_tax = dComp(6);
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
            cornerOrder = arrayfun(@(q,t) getFourCornerOrder(q,t,A), A.quantityOfCargo, A.carbonTax);
            [~, idx] = sort(cornerOrder, 'ascend');
        otherwise
            [~, idx] = sortrows([A.carbonTax, A.quantityOfCargo], [1,2]);
    end
    A = A(idx,:);
end

function rows = buildFourCornerComparison(allRepRows)
    rows = struct([]);
    if isempty(allRepRows)
        return;
    end
    T = struct2table(allRepRows);
    T = T(strcmp(T.axisType, 'fourcorner'), :);
    if isempty(T)
        return;
    end

    qLow = min(T.quantityOfCargo);
    qHigh = max(T.quantityOfCargo);
    tauLow = min(T.carbonTax);
    tauHigh = max(T.carbonTax);

    T.corner = repmat({''}, height(T), 1);
    for i = 1:height(T)
        if T.quantityOfCargo(i) == qLow && T.carbonTax(i) == tauLow
            T.corner{i} = 'LL';
        elseif T.quantityOfCargo(i) == qHigh && T.carbonTax(i) == tauLow
            T.corner{i} = 'HL';
        elseif T.quantityOfCargo(i) == qLow && T.carbonTax(i) == tauHigh
            T.corner{i} = 'LH';
        elseif T.quantityOfCargo(i) == qHigh && T.carbonTax(i) == tauHigh
            T.corner{i} = 'HH';
        else
            T.corner{i} = 'OTHER';
        end
    end

    keepMask = ismember(T.corner, {'LL','HL','LH','HH'});
    T = T(keepMask,:);
    if isempty(T)
        return;
    end

    solTypes = unique(T.solutionType, 'stable');
    rowCell = {};
    for s = 1:numel(solTypes)
        S = T(strcmp(T.solutionType, solTypes{s}), :);
        if height(S) < 4
            continue;
        end

        R = struct();
        R.solutionType = solTypes{s};

        % 原始签名
        R.LL_signature = getCornerValue(S, 'LL', 'signature');
        R.HL_signature = getCornerValue(S, 'HL', 'signature');
        R.LH_signature = getCornerValue(S, 'LH', 'signature');
        R.HH_signature = getCornerValue(S, 'HH', 'signature');

        % 成本原值
        R.LL_cost = getCornerValue(S, 'LL', 'totalCost');
        R.HL_cost = getCornerValue(S, 'HL', 'totalCost');
        R.LH_cost = getCornerValue(S, 'LH', 'totalCost');
        R.HH_cost = getCornerValue(S, 'HH', 'totalCost');

        % 排放原值
        R.LL_emission = getCornerValue(S, 'LL', 'totalEmission');
        R.HL_emission = getCornerValue(S, 'HL', 'totalEmission');
        R.LH_emission = getCornerValue(S, 'LH', 'totalEmission');
        R.HH_emission = getCornerValue(S, 'HH', 'totalEmission');

        % 成本侧四个效应
        R.deltaQ_atLowTau_cost  = R.HL_cost - R.LL_cost;
        R.deltaQ_atHighTau_cost = R.HH_cost - R.LH_cost;
        R.deltaTau_atLowQ_cost  = R.LH_cost - R.LL_cost;
        R.deltaTau_atHighQ_cost = R.HH_cost - R.HL_cost;

        % 排放侧四个效应
        R.deltaQ_atLowTau_emission  = R.HL_emission - R.LL_emission;
        R.deltaQ_atHighTau_emission = R.HH_emission - R.LH_emission;
        R.deltaTau_atLowQ_emission  = R.LH_emission - R.LL_emission;
        R.deltaTau_atHighQ_emission = R.HH_emission - R.HL_emission;

        % 交互差分：同一因素在另一因素不同水平下的变化差异
        R.interaction_deltaQ_cost = R.deltaQ_atHighTau_cost - R.deltaQ_atLowTau_cost;
        R.interaction_deltaTau_cost = R.deltaTau_atHighQ_cost - R.deltaTau_atLowQ_cost;

        R.interaction_deltaQ_emission = R.deltaQ_atHighTau_emission - R.deltaQ_atLowTau_emission;
        R.interaction_deltaTau_emission = R.deltaTau_atHighQ_emission - R.deltaTau_atLowQ_emission;

        rowCell{end+1,1} = R; %#ok<AGROW>
    end

    if ~isempty(rowCell)
        rows = vertcat(rowCell{:});
    end
end

function v = getCornerValue(T, cornerName, fieldName)
    idx = strcmp(T.corner, cornerName);
    if ~any(idx)
        if isnumeric(T.(fieldName))
            v = NaN;
        else
            v = '';
        end
        return;
    end
    val = T.(fieldName)(find(idx,1,'first'));
    if iscell(val)
        v = val{1};
    else
        v = val;
    end
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

function x = getFieldOrDefault(S, f, defaultValue)
    if isstruct(S) && isfield(S, f) && ~isempty(S.(f))
        x = S.(f);
    else
        x = defaultValue;
    end
end


function [reEvalObjAll, detailAll] = reEvaluatePopulation(popDec, job, odName, networkFile, rho, alpha, scenarioConfig)
    model = initModel(networkFile, odName);
    model.carbonTax = job.carbonTax;
    model.costOfUnitCarbon = job.carbonTax;
    model.baseDemand = job.quantityOfCargo;
    model.quantityOfCargo = job.quantityOfCargo;
    model.demandUncertaintyRate = rho;
    model.confidenceLevel = alpha;
    model = applyScenarioConfig(model, scenarioConfig);

    n = size(popDec,1);
    reEvalObjAll = nan(n,2);
    detailAll = cell(n,1);
    for i = 1:n
        [obj, detail] = model.getIndividualObjs(popDec(i,:), model);
        reEvalObjAll(i,:) = obj;
        detailAll{i,1} = detail;
    end
end

function cls = classifyNDDensity(nND)
    if nND <= 3
        cls = 'sparse';
    elseif nND <= 8
        cls = 'medium';
    else
        cls = 'dense';
    end
end

function label = mapLabelSemantic(name)
    switch name
        case 'CostBest'
            label = 'MinCost in ND candidates';
        case 'CarbonBest'
            label = 'MinEmission in ND candidates';
        otherwise
            label = 'Compromise in ND candidates';
    end
end

function ord = getFourCornerOrder(q, tau, T)
    qLow = min(T.quantityOfCargo);
    qHigh = max(T.quantityOfCargo);
    tauLow = min(T.carbonTax);
    tauHigh = max(T.carbonTax);
    if q == qLow && tau == tauLow
        ord = 1; % LL
    elseif q == qLow && tau == tauHigh
        ord = 2; % LH
    elseif q == qHigh && tau == tauLow
        ord = 3; % HL
    elseif q == qHigh && tau == tauHigh
        ord = 4; % HH
    else
        ord = 99;
    end
end

function label = getAxisOrderLabel(axisName, A, i)
    if strcmpi(axisName, 'fourcorner')
        ord = getFourCornerOrder(A.quantityOfCargo(i), A.carbonTax(i), A);
        map = {'LL','LH','HL','HH'};
        if ord >= 1 && ord <= 4
            label = map{ord};
        else
            label = 'OTHER';
        end
    else
        label = upper(axisName);
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
