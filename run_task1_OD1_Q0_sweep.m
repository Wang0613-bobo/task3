clc; clear; close all;

cd(fileparts(mfilename('fullpath')));
addpath(genpath(cd));

% =========================================================
% 任务一（加密识别版）：OD1 需求规模变化—路径转移识别
%
% 核心目标：
% 1) 固定 rho 和 alpha，保持需求不确定框架不变
% 2) 主扫 Q0，并在可能的切换区间加密
% 3) 使用任务一专用识别型时间窗
% 4) 对最终 Pareto 个体统一 repair + reevaluate
% 5) 在统一结果上选 CostBest / CarbonBest / Tradeoff
% 6) 保存完整路径、方式、中转文本
%
% 与论文主题的关系：
% - 不新增无关机制
% - 仍然服务于“需求变化是否引起路径转移”这一任务一核心
% =========================================================

%% =========================
% 1) 基础设置
% =========================
fileName = 'wangluojiegou.txt';
odName   = 'OD1';

% -------------------------
% 固定需求不确定参数
% -------------------------
rho   = 0.20;
alpha = 0.80;

% -------------------------
% Q0 加密扫描
% 在已有分段变化区间附近补点：
% 1450, 1750, 2050
% -------------------------
Q0List = [400 700 1000 1300 1450 1600 1750 1900 2050 2200];

% -------------------------
% 任务一识别型时间窗
% -------------------------
TW_task1 = [72 88];

% -------------------------
% 输出目录
% -------------------------
outDir = fullfile(pwd, 'result_task1_OD1_identify_dense');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% =========================
% 2) 批量运行
% =========================
for i = 1:length(Q0List)

    % 当前参数
    Q0 = Q0List(i);

    % -------------------------
    % 构造不确定需求区间
    % -------------------------
    Q_lower  = (1 - rho) * Q0;
    Q_center = Q0;
    Q_upper  = (1 + rho) * Q0;
    demandBand = [Q_lower, Q_center, Q_upper];

    % -------------------------
    % 计算等价需求
    % -------------------------
    Qeq = (1 - alpha) * Q_lower + alpha * Q_upper;

    % -------------------------
    % 初始化论文模型
    % -------------------------
    model = initModel(fileName, odName);
    model.baseDemand = Q0;
    model.demandUncertaintyRate = rho;
    model.confidenceLevel = alpha;
    model.TW = TW_task1;   % 任务一识别型时间窗

    % 核对
    Qeq_model = model.getEquivalentDemand(model);

    fprintf('\n==================================================\n');
    fprintf('任务一（加密版）运行中：%d / %d\n', i, length(Q0List));
    fprintf('OD = %s (%s -> %s)\n', model.odName, model.originName, model.destinationName);
    fprintf('Q0 = %.2f, rho = %.2f, alpha = %.2f\n', Q0, rho, alpha);
    fprintf('TW_task1 = [%.2f, %.2f]\n', model.TW(1), model.TW(2));
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
    allEval = evaluateAllParetoSolutions(paretoPos_raw, model);

    % 重评估后的统一目标值
    paretoCost = vertcat(allEval.objs);
    paretoPos  = vertcat(allEval.pos);

    %% =========================
    % 7) 代表性解提取
    % =========================
    rep = buildRepresentativeSolutions(allEval);

    %% =========================
    % 8) 自检：代表性解与路径数据
    % =========================
    runRepresentativeSelfCheck(allEval, rep);

    %% =========================
    % 9) 保存元信息
    % =========================
    meta = struct();
    meta.taskName = 'Task1_OD1_Identify_Dense';
    meta.odName = model.odName;
    meta.originName = model.originName;
    meta.destinationName = model.destinationName;

    meta.baseDemand = Q0;
    meta.rho = rho;
    meta.alpha = alpha;

    meta.Q_lower  = Q_lower;
    meta.Q_center = Q_center;
    meta.Q_upper  = Q_upper;
    meta.demandBand = demandBand;
    meta.Qeq = Qeq;

    meta.TW = model.TW;
    meta.nSol = size(paretoCost, 1);

    %% =========================
    % 10) 保存文件
    % =========================
    saveName = sprintf('OD1_Q0_%04d.mat', round(Q0));
    savePath = fullfile(outDir, saveName);

    save(savePath, ...
        'result', 'alg', 'problem', 'model', 'meta', ...
        'paretoCost_raw', 'paretoPos_raw', ...
        'paretoCost', 'paretoPos', ...
        'extractInfo', 'allEval', 'rep');

    fprintf('Pareto 解个数 = %d\n', meta.nSol);
    fprintf('Pareto 提取来源 = %s\n', extractInfo.source);
    fprintf('结果已保存：%s\n', savePath);

    % 清理
    if isappdata(0, 'IntermodalProblem_model')
        rmappdata(0, 'IntermodalProblem_model');
    end
    close all force;
end

fprintf('\n==================================================\n');
fprintf('任务一（加密识别版）运行完成。\n');


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
    end

    if isobject(x)
        propCandidates = {'Population', 'population', 'pop', 'result', 'finalPopulation', 'FinalPopulation'};

        for i = 1:length(propCandidates)
            pn = propCandidates{i};
            try
                node = x.(pn);

                if hasObjsDecs(node)
                    Population = node;
                    sourceName = sprintf('object.%s', pn);
                    return;
                end

                [Population, sourceNameSub] = locateFinalPopulation(node);
                if ~isempty(Population)
                    sourceName = sprintf('object.%s->%s', pn, sourceNameSub);
                    return;
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
% =========================================================
function allEval = evaluateAllParetoSolutions(paretoPos_raw, model)

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
        'C_tax', NaN);

    allEval = repmat(template, n, 1);

    for i = 1:n
        posRaw = paretoPos_raw(i, :);
        pos    = model.repairIndividual(posRaw, model);

        [objs, detail] = model.getIndividualObjs(pos, model);
        [path, typeOfPath] = model.analyseIndividual(pos, model);
        pathTransferType = model.getPathTransferType(typeOfPath);

        nTransfer   = sum(pathTransferType > 1);
        nModeChange = sum(typeOfPath(1:end-1) ~= typeOfPath(2:end));

        pathText     = vec2str(path);
        typeText     = vec2str(typeOfPath);
        transferText = vec2str(pathTransferType);

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
        allEval(i).arriveTime = detail.arriveTime;

        if isfield(detail, 'C_wait'),       allEval(i).C_wait = detail.C_wait; end
        if isfield(detail, 'C_trans'),      allEval(i).C_trans = detail.C_trans; end
        if isfield(detail, 'C_transfer'),   allEval(i).C_transfer = detail.C_transfer; end
        if isfield(detail, 'C_timeWindow'), allEval(i).C_timeWindow = detail.C_timeWindow; end
        if isfield(detail, 'C_damage'),     allEval(i).C_damage = detail.C_damage; end
        if isfield(detail, 'C_tax'),        allEval(i).C_tax = detail.C_tax; end
    end
end


%% =========================================================
%  辅助函数5：代表性解提取
% =========================================================
function rep = buildRepresentativeSolutions(allEval)

    objMat = vertcat(allEval.objs);

    idxCost   = findMinCostSolution(objMat);
    idxCarbon = findMinCarbonSolution(objMat);
    idxTrade  = findTradeoffSolution(objMat);

    rep = struct();
    rep.costBest   = addSolutionName(allEval(idxCost),   'CostBest');
    rep.carbonBest = addSolutionName(allEval(idxCarbon), 'CarbonBest');
    rep.tradeoff   = addSolutionName(allEval(idxTrade),  'Tradeoff');
end

function one = addSolutionName(one, solName)
    one.name = solName;
end


%% =========================================================
%  辅助函数6：自检
% =========================================================
function runRepresentativeSelfCheck(allEval, rep)

    objMat = vertcat(allEval.objs);
    costVec   = objMat(:,1);
    carbonVec = objMat(:,2);

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
function idx = findMinCostSolution(objMat)
    [~, idx] = min(objMat(:,1));
end

function idx = findMinCarbonSolution(objMat)
    [~, idx] = min(objMat(:,2));
end

function idx = findTradeoffSolution(objMat)
    f1 = objMat(:,1);
    f2 = objMat(:,2);

    f1n = normalize01(f1);
    f2n = normalize01(f2);

    d = sqrt(f1n.^2 + f2n.^2);
    [~, idx] = min(d);
end

function y = normalize01(x)
    xmin = min(x);
    xmax = max(x);
    if abs(xmax - xmin) < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) / (xmax - xmin);
    end
end

function s = vec2str(v)
    if isempty(v)
        s = '[]';
        return;
    end
    s = sprintf('%d-', v);
    s(end) = [];
end