clc; clear; close all;

cd(fileparts(mfilename('fullpath')));
addpath(genpath(cd));

% =========================================================
% 任务二：OD1 低碳约束驱动的运输方式替代识别
%
% 严格定位：
% 1) 固定 OD1、baseDemand、rho、alpha
% 2) 主扫 carbonTax
% 3) 仍沿用任务一已跑通的主流程
% 4) 统一 repair + reevaluate
% 5) 提取 CostBest / CarbonBest / Tradeoff
% 6) 输出路径、方式、中转、方式占比与碳税成本
%
% 本版调整：
% - 将碳税扫描由粗扫改为分段加密扫描
% - 目的不是追求极端税率，而是识别替代阈值与重组区间
% =========================================================

%% =========================
% 1) 基础设置
% =========================
fileName = 'wangluojiegou.txt';
odName   = 'OD1';

% -------------------------
% 固定需求不确定参数
% -------------------------
baseDemand = 1000;
rho        = 0.20;
alpha      = 0.80;

% -------------------------
% 碳税扫描（分段加密版）
% 低税率区加密：识别替代起点
% 中税率区保留：识别替代重组
% 高税率区仅保留少量锚点
% -------------------------
carbonTaxList = [ ...
    0 ...
    0.05 0.1 0.15 0.2 ...
    0.25 0.3 0.35 0.4 0.45 ...
    0.5 0.55 0.6 0.65 ...
    0.7 0.75 0.8 0.85 ...
    0.9 0.95 1];

% -------------------------
% 输出目录
% -------------------------
outDir = fullfile(pwd, 'result_task2_OD1_tax_sweep');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

summaryCell = cell(length(carbonTaxList) * 3 + 1, 18);
summaryCell(1, :) = { ...
    'carbonTax', 'solutionType', 'nSol', ...
    'F_cost', 'F_carbon', ...
    'path', 'typePath', 'transferType', ...
    'nTransfer', 'nModeChange', 'arriveTime', ...
    'roadDist', 'railDist', 'waterDist', ...
    'roadShare', 'railShare', 'waterShare', ...
    'C_tax'};

summaryRow = 2;

%% =========================
% 2) 批量运行
% =========================
for i = 1:length(carbonTaxList)

    carbonTax = carbonTaxList(i);

    % -------------------------
    % 构造不确定需求区间
    % -------------------------
    Q_lower  = (1 - rho) * baseDemand;
    Q_center = baseDemand;
    Q_upper  = (1 + rho) * baseDemand;
    demandBand = [Q_lower, Q_center, Q_upper];

    % -------------------------
    % 计算等价需求
    % -------------------------
    Qeq = (1 - alpha) * Q_lower + alpha * Q_upper;

    % -------------------------
    % 初始化模型
    % -------------------------
    model = initModel(fileName, odName);
    model.baseDemand = baseDemand;
    model.demandUncertaintyRate = rho;
    model.confidenceLevel = alpha;
    model.carbonTax = carbonTax;

    % -------------------------
    % 自检：Qeq 是否作用到模型
    % -------------------------
    Qeq_model = model.getEquivalentDemand(model);

    fprintf('\n==================================================\n');
    fprintf('任务二运行中：%d / %d\n', i, length(carbonTaxList));
    fprintf('OD = %s (%s -> %s)\n', model.odName, model.originName, model.destinationName);
    fprintf('baseDemand = %.2f, rho = %.2f, alpha = %.2f\n', baseDemand, rho, alpha);
    fprintf('carbonTax = %.4f\n', carbonTax);
    fprintf('TW = [%.2f, %.2f]\n', model.TW(1), model.TW(2));
    fprintf('demandBand = [%.2f, %.2f, %.2f]\n', demandBand(1), demandBand(2), demandBand(3));
    fprintf('Qeq(script) = %.2f, Qeq(model) = %.2f\n', Qeq, Qeq_model);

    if abs(Qeq - Qeq_model) > 1e-10
        error('自检失败：脚本层 Qeq 与模型层 getEquivalentDemand 结果不一致。');
    end

    %% =========================
    % 3) 创建 Problem 对象
    % =========================
    setappdata(0, 'IntermodalProblem_model', model);
    problem = IntermodalProblem();

    %% =========================
    % 4) 调用算法
    % =========================
    alg = NSGAIIPlus();
    alg.Solve(problem);

    if isempty(alg.result)
        error('alg.result 为空，说明算法未成功输出结果。');
    end

    result = alg.result;

    %% =========================
    % 5) 提取最终种群
    % =========================
    [paretoCost_raw, paretoPos_raw, extractInfo] = extractPlatEMOResult(result);

    %% =========================
    % 6) 统一 repair + reevaluate
    % =========================
    allEval = evaluateAllParetoSolutions_Task2(paretoPos_raw, model);

    paretoCost = vertcat(allEval.objs);
    paretoPos  = vertcat(allEval.pos);

    %% =========================
    % 7) 代表性解提取
    % =========================
    rep = buildRepresentativeSolutions_Task2(allEval);

    %% =========================
    % 8) 自检：代表性解与路径数据
    % =========================
    runRepresentativeSelfCheck_Task2(allEval, rep);

    %% =========================
    % 9) 保存元信息
    % =========================
    meta = struct();
    meta.taskName = 'Task2_OD1_TaxSweep';
    meta.odName = model.odName;
    meta.originName = model.originName;
    meta.destinationName = model.destinationName;

    meta.baseDemand = baseDemand;
    meta.rho = rho;
    meta.alpha = alpha;

    meta.Q_lower = Q_lower;
    meta.Q_center = Q_center;
    meta.Q_upper = Q_upper;
    meta.demandBand = demandBand;
    meta.Qeq = Qeq;

    meta.TW = model.TW;
    meta.carbonTax = carbonTax;
    meta.nSol = size(paretoCost, 1);

    %% =========================
    % 10) 保存文件
    % 只保存轻量结果，避免对象收尾报错
    % =========================
    taxTag = strrep(sprintf('%.3f', carbonTax), '.', 'p');
    saveName = sprintf('OD1_tax_%s.mat', taxTag);
    savePath = fullfile(outDir, saveName);

    save(savePath, ...
        'meta', ...
        'paretoCost_raw', 'paretoPos_raw', ...
        'paretoCost', 'paretoPos', ...
        'extractInfo', 'allEval', 'rep');

    fprintf('Pareto 解个数 = %d\n', meta.nSol);
    fprintf('Pareto 提取来源 = %s\n', extractInfo.source);
    fprintf('结果已保存：%s\n', savePath);

    %% =========================
    % 11) 汇总写入
    % =========================
    repList = {rep.costBest, rep.carbonBest, rep.tradeoff};

    for k = 1:3
        s = repList{k};

        summaryCell{summaryRow, 1}  = carbonTax;
        summaryCell{summaryRow, 2}  = s.name;
        summaryCell{summaryRow, 3}  = meta.nSol;

        summaryCell{summaryRow, 4}  = s.objs(1);
        summaryCell{summaryRow, 5}  = s.objs(2);

        summaryCell{summaryRow, 6}  = s.pathText;
        summaryCell{summaryRow, 7}  = s.typeText;
        summaryCell{summaryRow, 8}  = s.transferText;

        summaryCell{summaryRow, 9}  = s.nTransfer;
        summaryCell{summaryRow, 10} = s.nModeChange;

        if isempty(s.arriveTime)
            summaryCell{summaryRow, 11} = NaN;
        else
            summaryCell{summaryRow, 11} = s.arriveTime(end);
        end

        summaryCell{summaryRow, 12} = s.roadDist;
        summaryCell{summaryRow, 13} = s.railDist;
        summaryCell{summaryRow, 14} = s.waterDist;

        summaryCell{summaryRow, 15} = s.roadShare;
        summaryCell{summaryRow, 16} = s.railShare;
        summaryCell{summaryRow, 17} = s.waterShare;

        summaryCell{summaryRow, 18} = s.C_tax;

        summaryRow = summaryRow + 1;
    end

    %% =========================
    % 12) 清理
    % =========================
    clear alg problem result model

    if isappdata(0, 'IntermodalProblem_model')
        rmappdata(0, 'IntermodalProblem_model');
    end

    close all force;
    drawnow;
end

%% =========================
% 13) 保存总汇总表
% =========================
summaryXlsxPath = fullfile(outDir, 'task2_OD1_tax_summary.xlsx');
writecell(summaryCell, summaryXlsxPath);

fprintf('\n==================================================\n');
fprintf('任务二运行完成。\n');
fprintf('汇总表已保存：%s\n', summaryXlsxPath);


%% =========================================================
%  辅助函数1：从 PlatEMO / NSGAIIPlus 结果中提取最终种群
% =========================================================
function [paretoCost, paretoPos, info] = extractPlatEMOResult(result)

    paretoCost = [];
    paretoPos  = [];

    info = struct();
    info.source = '';
    info.resultClass = class(result);
    info.resultSize = size(result);

    fprintf('\n----- 开始提取 PlatEMO 结果 -----\n');
    fprintf('class(result) = %s\n', class(result));
    disp('size(result) = ');
    disp(size(result));

    [Population, sourceName] = locateFinalPopulation(result);

    if isempty(Population)
        error(['无法从 alg.result 中定位最终 Population。', newline, ...
               '请检查 alg.result 的真实结构。']);
    end

    try
        paretoCost = Population.objs;
    catch
        error('已定位到最终 Population，但无法读取 Population.objs。');
    end

    try
        paretoPos = Population.decs;
    catch
        error('已定位到最终 Population，但无法读取 Population.decs。');
    end

    info.source = sourceName;
    fprintf('成功定位最终 Population，来源 = %s\n', sourceName);
end


%% =========================================================
%  辅助函数2：递归寻找最终 Population
% =========================================================
function [Population, sourceName] = locateFinalPopulation(x)

    Population = [];
    sourceName = '';

    if hasObjsDecs(x)
        Population = x;
        sourceName = 'direct_result';
        return;
    end

    if iscell(x)
        for k = numel(x):-1:1
            node = x{k};

            if hasObjsDecs(node)
                Population = node;
                sourceName = sprintf('result{%d}', k);
                return;
            end

            if iscell(node) || isstruct(node) || isobject(node)
                [Population, sourceNameSub] = locateFinalPopulation(node);
                if ~isempty(Population)
                    sourceName = sprintf('result{%d}->%s', k, sourceNameSub);
                    return;
                end
            end
        end
    end

    if isstruct(x)
        fieldCandidates = {'Population', 'population', 'pop', 'result', 'finalPopulation', 'FinalPopulation'};

        for i = 1:length(fieldCandidates)
            fn = fieldCandidates{i};
            if isfield(x, fn)
                node = x.(fn);

                if hasObjsDecs(node)
                    Population = node;
                    sourceName = sprintf('struct.%s', fn);
                    return;
                end

                [Population, sourceNameSub] = locateFinalPopulation(node);
                if ~isempty(Population)
                    sourceName = sprintf('struct.%s->%s', fn, sourceNameSub);
                    return;
                end
            end
        end

        fns = fieldnames(x);
        for i = 1:length(fns)
            fn = fns{i};
            try
                node = x.(fn);

                if hasObjsDecs(node)
                    Population = node;
                    sourceName = sprintf('struct.%s', fn);
                    return;
                end

                if iscell(node) || isstruct(node) || isobject(node)
                    [Population, sourceNameSub] = locateFinalPopulation(node);
                    if ~isempty(Population)
                        sourceName = sprintf('struct.%s->%s', fn, sourceNameSub);
                        return;
                    end
                end
            catch
            end
        end
    end

    if isobject(x)
        try
            pnList = properties(x);
        catch
            pnList = {};
        end

        for i = 1:length(pnList)
            pn = pnList{i};
            try
                node = x.(pn);

                if hasObjsDecs(node)
                    Population = node;
                    sourceName = sprintf('object.%s', pn);
                    return;
                end

                if iscell(node) || isstruct(node) || isobject(node)
                    [Population, sourceNameSub] = locateFinalPopulation(node);
                    if ~isempty(Population)
                        sourceName = sprintf('object.%s->%s', pn, sourceNameSub);
                        return;
                    end
                end
            catch
            end
        end
    end
end


%% =========================================================
%  辅助函数3：判断是否可作为最终种群
% =========================================================
function flag = hasObjsDecs(x)

    flag = false;

    if isobject(x)
        try
            a = x.objs;
            b = x.decs;
            if isnumeric(a) && isnumeric(b)
                flag = true;
                return;
            end
        catch
        end
    end

    if isstruct(x)
        try
            if isfield(x, 'objs') && isfield(x, 'decs')
                if isnumeric(x.objs) && isnumeric(x.decs)
                    flag = true;
                    return;
                end
            end
        catch
        end
    end
end


%% =========================================================
%  辅助函数4：统一 repair + reevaluate
%  补充方式距离与占比统计
% =========================================================
function allEval = evaluateAllParetoSolutions_Task2(paretoPos_raw, model)

    n = size(paretoPos_raw, 1);

    template = struct( ...
        'index', [], ...
        'pos_raw', [], ...
        'pos', [], ...
        'objs', [], ...
        'path', [], ...
        'typeOfPath', [], ...
        'pathTransferType', [], ...
        'pathText', '', ...
        'typeText', '', ...
        'transferText', '', ...
        'routeSignature', '', ...
        'nTransfer', [], ...
        'nModeChange', [], ...
        'arriveTime', [], ...
        'C_wait', NaN, ...
        'C_trans', NaN, ...
        'C_transfer', NaN, ...
        'C_timeWindow', NaN, ...
        'C_damage', NaN, ...
        'C_tax', NaN, ...
        'roadDist', NaN, ...
        'railDist', NaN, ...
        'waterDist', NaN, ...
        'roadShare', NaN, ...
        'railShare', NaN, ...
        'waterShare', NaN);

    allEval = repmat(template, n, 1);

    for i = 1:n
        posRaw = paretoPos_raw(i, :);
        pos    = model.repairIndividual(posRaw, model);

        [objs, detail] = model.getIndividualObjs(pos, model);
        [path, typeOfPath] = model.analyseIndividual(pos, model);
        pathTransferType = model.getPathTransferType(typeOfPath);

        [~, distanceArray, ~] = model.getDistanceOfPath(path, typeOfPath, model);

        nTransfer   = sum(pathTransferType > 1);
        nModeChange = sum(typeOfPath(1:end-1) ~= typeOfPath(2:end));

        pathText     = vec2str_Task2(path);
        typeText     = vec2str_Task2(typeOfPath);
        transferText = vec2str_Task2(pathTransferType);

        roadDist  = sum(distanceArray(typeOfPath == 1 & isfinite(distanceArray)));
        railDist  = sum(distanceArray(typeOfPath == 2 & isfinite(distanceArray)));
        waterDist = sum(distanceArray(typeOfPath == 3 & isfinite(distanceArray)));

        totalDist = roadDist + railDist + waterDist;
        if totalDist > 0
            roadShare  = roadDist  / totalDist;
            railShare  = railDist  / totalDist;
            waterShare = waterDist / totalDist;
        else
            roadShare  = NaN;
            railShare  = NaN;
            waterShare = NaN;
        end

        allEval(i).index = i;
        allEval(i).pos_raw = posRaw;
        allEval(i).pos = pos;
        allEval(i).objs = objs;
        allEval(i).path = path;
        allEval(i).typeOfPath = typeOfPath;
        allEval(i).pathTransferType = pathTransferType;
        allEval(i).pathText = pathText;
        allEval(i).typeText = typeText;
        allEval(i).transferText = transferText;
        allEval(i).routeSignature = [pathText ' | ' typeText];
        allEval(i).nTransfer = nTransfer;
        allEval(i).nModeChange = nModeChange;

        if isfield(detail, 'arriveTime')
            allEval(i).arriveTime = detail.arriveTime;
        else
            allEval(i).arriveTime = [];
        end

        if isfield(detail, 'C_wait'),       allEval(i).C_wait = detail.C_wait; end
        if isfield(detail, 'C_trans'),      allEval(i).C_trans = detail.C_trans; end
        if isfield(detail, 'C_transfer'),   allEval(i).C_transfer = detail.C_transfer; end
        if isfield(detail, 'C_timeWindow'), allEval(i).C_timeWindow = detail.C_timeWindow; end
        if isfield(detail, 'C_damage'),     allEval(i).C_damage = detail.C_damage; end
        if isfield(detail, 'C_tax'),        allEval(i).C_tax = detail.C_tax; end

        allEval(i).roadDist = roadDist;
        allEval(i).railDist = railDist;
        allEval(i).waterDist = waterDist;
        allEval(i).roadShare = roadShare;
        allEval(i).railShare = railShare;
        allEval(i).waterShare = waterShare;
    end
end


%% =========================================================
%  辅助函数5：代表性解提取
% =========================================================
function rep = buildRepresentativeSolutions_Task2(allEval)

    objMat = vertcat(allEval.objs);

    idxCost   = findMinCostSolution_Task2(objMat);
    idxCarbon = findMinCarbonSolution_Task2(objMat);
    idxTrade  = findTradeoffSolution_Task2(objMat);

    rep = struct();
    rep.costBest   = addSolutionName_Task2(allEval(idxCost),   'CostBest');
    rep.carbonBest = addSolutionName_Task2(allEval(idxCarbon), 'CarbonBest');
    rep.tradeoff   = addSolutionName_Task2(allEval(idxTrade),  'Tradeoff');
end

function one = addSolutionName_Task2(one, solName)
    one.name = solName;
end


%% =========================================================
%  辅助函数6：自检
% =========================================================
function runRepresentativeSelfCheck_Task2(allEval, rep)

    objMat = vertcat(allEval.objs);
    costVec   = objMat(:, 1);
    carbonVec = objMat(:, 2);

    tolCost   = max(1, abs(min(costVec))) * 1e-9;
    tolCarbon = max(1, abs(min(carbonVec))) * 1e-9;

    if abs(rep.costBest.objs(1) - min(costVec)) > tolCost
        error('自检失败：rep.costBest 不是统一重评估结果中的最小 F_cost。');
    end

    if abs(rep.carbonBest.objs(2) - min(carbonVec)) > tolCarbon
        error('自检失败：rep.carbonBest 不是统一重评估结果中的最小 F_carbon。');
    end

    if isempty(rep.costBest.path) || isempty(rep.carbonBest.path) || isempty(rep.tradeoff.path)
        error('自检失败：代表性解路径为空。');
    end

    if isempty(rep.costBest.typeOfPath) || isempty(rep.carbonBest.typeOfPath) || isempty(rep.tradeoff.typeOfPath)
        error('自检失败：代表性解运输方式为空。');
    end

    fprintf('自检通过：代表性解标签、目标值、路径数据一致。\n');
end


%% =========================================================
%  辅助函数7：代表性解索引
% =========================================================
function idx = findMinCostSolution_Task2(objMat)
    [~, idx] = min(objMat(:, 1));
end

function idx = findMinCarbonSolution_Task2(objMat)
    [~, idx] = min(objMat(:, 2));
end

function idx = findTradeoffSolution_Task2(objMat)
    f1 = objMat(:, 1);
    f2 = objMat(:, 2);

    f1n = normalize01_Task2(f1);
    f2n = normalize01_Task2(f2);

    d = sqrt(f1n.^2 + f2n.^2);
    [~, idx] = min(d);
end

function y = normalize01_Task2(x)
    xmin = min(x);
    xmax = max(x);
    if abs(xmax - xmin) < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) / (xmax - xmin);
    end
end

function s = vec2str_Task2(v)
    if isempty(v)
        s = '[]';
        return;
    end
    s = sprintf('%d-', v);
    s(end) = [];
end