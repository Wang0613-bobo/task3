function model = initModel(fileName, odName)

    if nargin < 2 || isempty(odName)
        odName = 'OD1';
    end

    data = load(fileName);
    data = updateData(data);

    [startPointId, endPointId, originName, destinationName] = getODSetting(odName);

    model.odName = upper(odName);
    model.originName = originName;
    model.destinationName = destinationName;
    model.startPointId = startPointId;
    model.endPointId = endPointId;

    % =========================
    % 需求不确定性参数接口
    % 主模型层不赋具体值
    % =========================
    model.baseDemand = [];              % Q0
    model.demandUncertaintyRate = [];   % rho
    model.confidenceLevel = [];         % alpha
    model.demandScenarioWeights = [0.25 0.50 0.25]; % [低需求, 基准需求, 高需求] 默认权重
    % =========================
    % 基础参数
    % =========================
    model.TW = [60 100];                            % 时间窗, h
    model.costOfUnitWait = [2 1 0.2];               % [公路 铁路 水路], 元/(h*t)
    model.speedOfTransportType = [80 60 25];        % [公路 铁路 水路], km/h
    model.costOfUnitTransport = [0.6 0.15 0.05];    % [公路 铁路 水路], 元/(km*t)
    model.carbonEmissionsOfUnitTransport = [0.0538 0.0099 0.0128]; % kg/(km*t)

    model.startTimeOfTransportType = [0 8 8];
    model.endTimeOfTransportType   = [24 20 16];
    model.intervalTimeOfTransportType = [0 12 24];

    model.rateDamagedOfRansportType = [0.3 0.2 0.1] / 100;   % 运输货损率

    % 中转参数顺序：[不中转, 公铁, 公水, 铁水]
    model.rateDamagedOfTransferType = [0.00 0.04 0.04 0.04] / 100;
    model.costOfUnitTransfer = [0 3.5 3 4];
    model.timeOfUnitTransfer = [0 0.01 0.015 0.01];
    model.carbonEmissionsOfUnitTransfer = [0 0.54 0.82 1.02];
    model.transferTimeDemandBase = 1000; % 中转时间按Q/基准需求缩放，避免Q线性放大过强
    model.price = 10000;                 % 元/t
    model.p1 = 8;                        % 元/(h*t)
    model.p2 = 20;                       % 元/(h*t)
    model.carbonTax = 0.05;              % 元/kg
    model.penaltyFactor = 10 ^ 10;

    % 双目标：[综合经济目标, 总碳排放目标]
    model.numOfObjs = 2;

    % =========================
    % 网络结构
    % =========================
    model.numOfEdge = size(data, 1);
    model.edgeSet = data(:, 1:2);
    model.distanceTable = data(:, 3:5);
    model.numOfVertex = max(model.edgeSet(:));
    model.numOfTransportType = size(model.distanceTable, 2);

    model.adjacencyMatrix = getAdjacencyMatrix(model.edgeSet);
    [model.distanceMatOfAdjacency, ~] = floyd(model.adjacencyMatrix);
    model.distanceMat3D = getDistanceMat3D(model.edgeSet, model.distanceTable);

    % =========================
    % 编码参数
    % =========================
    model.sequence = removeX(1:model.numOfVertex, model.startPointId);
    model.numOfDecVariablesPart1 = length(model.sequence);
    model.numOfDecVariablesPart2 = length(model.sequence);
    model.numOfDecVariables = model.numOfDecVariablesPart1 + model.numOfDecVariablesPart2;

    model.lower2 = ones(1, model.numOfDecVariablesPart2);
    model.upper2 = ones(1, model.numOfDecVariablesPart2) * model.numOfTransportType;

    % =========================
    % 核心函数句柄
    % =========================
    model.initIndividual = @initIndividual;
    model.repairIndividual = @repairIndividual;
    model.analyseIndividual = @analyseIndividual;
    model.getIndividualFitness = @getIndividualFitness;
    model.getPathTransferType = @getPathTransferType;
    model.getDistanceOfPath = @getDistanceOfPath;
    model.getArriveTime = @getArriveTime;
    model.getEquivalentDemand = @getEquivalentDemand;
    model.getIndividualObjs = @getIndividualObjs;
    model.analyseIndividualUnderQ = @analyseIndividualUnderQ;
end


%% =========================
%  OD 设置
% =========================
function [startPointId, endPointId, originName, destinationName] = getODSetting(odName)

    switch upper(odName)
        case 'OD1'
            startPointId = 1;
            endPointId = 20;
            originName = '上海';
            destinationName = '成都';

        case 'OD2'
            startPointId = 5;
            endPointId = 18;
            originName = '南京';
            destinationName = '重庆';

        case 'OD3'
            startPointId = 10;
            endPointId = 15;
            originName = '合肥';
            destinationName = '长沙';

        otherwise
            error('未知OD场景：%s。可选值为 OD1 / OD2 / OD3。', odName);
    end
end


%% =========================
%  需求等价化
% =========================
function Qeq = getEquivalentDemand(model)

    assert(~isempty(model.baseDemand), ...
        'baseDemand 未设置，请在外部脚本中赋值。');
    assert(~isempty(model.demandUncertaintyRate), ...
        'demandUncertaintyRate 未设置，请在外部脚本中赋值。');
    assert(~isempty(model.confidenceLevel), ...
        'confidenceLevel 未设置，请在外部脚本中赋值。');

    Q0 = model.baseDemand;
    rho = max(0, model.demandUncertaintyRate);
    alpha = max(0, min(1, model.confidenceLevel));

    lowerQ = (1 - rho) * Q0;
    midQ   = Q0;
    upperQ = (1 + rho) * Q0;

        % 通过置信水平对默认三场景权重进行偏置：
    % alpha越大，越偏向高需求场景；alpha越小，越偏向低需求场景。
    w = model.demandScenarioWeights;
    if numel(w) ~= 3 || any(w < 0)
        w = [0.25 0.50 0.25];
    end
    w = w / sum(w);
    tilt = (alpha - 0.5) * 0.4; % 偏置幅度受控，避免极端畸变
    w = [w(1) - tilt, w(2), w(3) + tilt];
    w = max(w, 0);
    w = w / sum(w);

    Qeq = w(1) * lowerQ + w(2) * midQ + w(3) * upperQ;  
end


%% =========================
%  数据处理
% =========================
function data = updateData(data)
    [~, I] = sort(data(:, 1) * 100 + data(:, 2));
    data = data(I, :);
end

function adjacencyMatrix = getAdjacencyMatrix(edgeSet)
    numOfVertex = max(edgeSet(:));
    adjacencyMatrix = Inf(numOfVertex, numOfVertex);
    for i = 1:numOfVertex
        adjacencyMatrix(i, i) = 0;
    end
    for i = 1:size(edgeSet, 1)
        id1 = edgeSet(i, 1);
        id2 = edgeSet(i, 2);
        adjacencyMatrix(id1, id2) = 1;
    end
end

function distanceMat = getDistanceMat(edgeSet, distanceArray)
    numOfVertex = max(edgeSet(:));
    distanceMat = Inf(numOfVertex, numOfVertex);
    for i = 1:numOfVertex
        distanceMat(i, i) = 0;
    end
    for i = 1:size(edgeSet, 1)
        id1 = edgeSet(i, 1);
        id2 = edgeSet(i, 2);
        distanceMat(id1, id2) = distanceArray(i);
    end
end

function distanceMat3D = getDistanceMat3D(edgeSet, distanceTable)
    numOfVertex = max(edgeSet(:));
    numOfTransportType = size(distanceTable, 2);
    distanceMat3D = zeros(numOfVertex, numOfVertex, numOfTransportType);
    for i = 1:numOfTransportType
        distanceArray = distanceTable(:, i);
        distanceMat3D(:, :, i) = getDistanceMat(edgeSet, distanceArray);
    end
end

function newArray = removeX(originalArray, elementToRemove)
    indexToRemove = originalArray == elementToRemove;
    newArray = originalArray;
    newArray(indexToRemove) = [];
end


%% =========================
%  初始化个体
% =========================
function individualPart1 = initIndividualPart1(model)
    path = generateFeasiblePath(model);     % 含起点和终点
    usedNodes = path(2:end);                % 染色体中不含起点
    restNodes = setdiff(model.sequence, usedNodes, 'stable');

    if ~isempty(restNodes)
        restNodes = restNodes(randperm(length(restNodes)));
    end

    individualPart1 = [usedNodes, restNodes];
end

function individualPart2 = initIndividualPart2(individualPart1, model)
    path = getPath(individualPart1, model);
    individualPart2 = ones(1, model.numOfDecVariablesPart2);

    for i = 1:length(path)-1
        I = path(i);
        J = path(i+1);
        availableTypes = find(isfinite(squeeze(model.distanceMat3D(I, J, :))));
        if isempty(availableTypes)
            individualPart2(i) = 1;
        else
            individualPart2(i) = availableTypes(randi(length(availableTypes)));
        end
    end

    if length(path)-1 < model.numOfDecVariablesPart2
        tailLen = model.numOfDecVariablesPart2 - (length(path)-1);
        individualPart2(length(path):end) = randi(model.numOfTransportType, 1, tailLen);
    end
end

function individual = initIndividual(model)
    individualPart1 = initIndividualPart1(model);
    individualPart2 = initIndividualPart2(individualPart1, model);
    individual = [individualPart1 individualPart2];
end


%% =========================
%  个体解析
% =========================
function [path, typeOfPath] = analyseIndividual(individual, model)
    individualPart1 = individual(1:model.numOfDecVariablesPart1);
    individualPart2 = individual(1 + model.numOfDecVariablesPart1:end);

    individualPart2 = repairIndividualPart2(individualPart2, model);
    path = getPath(individualPart1, model);

    if ~isPathFeasible(path, model)
        path = generateFeasiblePath(model);
        usedNodes = path(2:end);
        restNodes = setdiff(model.sequence, usedNodes, 'stable');
        if ~isempty(restNodes)
            restNodes = restNodes(randperm(length(restNodes)));
        end
        individualPart1 = [usedNodes, restNodes];
        path = getPath(individualPart1, model);
    end

    typeOfPath = individualPart2(1:length(path)-1);

    for i = 1:length(path)-1
        I = path(i);
        J = path(i+1);
        if ~isfinite(model.distanceMat3D(I, J, typeOfPath(i)))
            availableTypes = find(isfinite(squeeze(model.distanceMat3D(I, J, :))));
            if ~isempty(availableTypes)
                typeOfPath(i) = availableTypes(randi(length(availableTypes)));
            end
        end
    end
end

function path = getPath(individualPart1, model)
    [~, I] = find(individualPart1 == model.endPointId);
    path = [model.startPointId individualPart1(1:I)];
end

function newIndividualPart2 = repairIndividualPart2(individualPart2, model)
    newIndividualPart2 = individualPart2;
    newIndividualPart2 = max(newIndividualPart2, model.lower2);
    newIndividualPart2 = min(newIndividualPart2, model.upper2);
    newIndividualPart2 = round(newIndividualPart2);
end


%% =========================
%  距离与时间
% =========================
function [distanceOfPath, distanceArray, numOfPenalty] = getDistanceOfPath(path, typeOfPath, model)
    numOfRoute = length(path) - 1;
    distanceArray = zeros(1, numOfRoute);

    for i = 1:numOfRoute
        I = path(i);
        J = path(i + 1);
        K = typeOfPath(i);
        distanceArray(i) = model.distanceMat3D(I, J, K);
    end

    numOfPenalty = 0;
    J = find(distanceArray == inf, 1);
    if ~isempty(J)
        numOfPenalty = model.distanceMatOfAdjacency(path(J), path(end));
    end

    I = distanceArray < inf;
    distanceOfPath = sum(distanceArray(I)) + numOfPenalty * model.penaltyFactor;
end

function [arriveTime, waitTime] = getArriveTime(distanceArray, typeOfPath, pathTransferType, model, Q)

    if nargin < 5 || isempty(Q)
        Q = getEquivalentDemand(model);
    end

    travelTime = distanceArray ./ model.speedOfTransportType(typeOfPath);
    arriveTime = zeros(1, length(distanceArray) + 1);
    waitTime = zeros(1, length(distanceArray) + 1);

    currentTime = 0;

    for i = 1:length(typeOfPath)

        if i > 1
            transferScale = Q / max(model.transferTimeDemandBase, eps);
            transferTime = transferScale * model.timeOfUnitTransfer(pathTransferType(i - 1));
            currentTime = currentTime + transferTime;
        end

        type = typeOfPath(i);
        startTimeOfTransport = model.startTimeOfTransportType(type);
        endTimeOfTransport = model.endTimeOfTransportType(type);
        intervalTimeOfTransport = model.intervalTimeOfTransportType(type);

        startTime = getStartTime(currentTime, startTimeOfTransport, endTimeOfTransport, intervalTimeOfTransport);
        waitTime(i) = startTime - currentTime;
        arriveTime(i + 1) = startTime + travelTime(i);

        currentTime = arriveTime(i + 1);
    end
end

function startTime = getStartTime(currentTime, startTimeOfTransport, endTimeOfTransport, intervalTimeOfTransport)
    if ~isfinite(currentTime)
        startTime = inf;
        return;
    end

    if intervalTimeOfTransport == 0
        intervalTimeOfTransport = 0.01;
    end

    currentT = mod(currentTime, 24);

    if currentT <= startTimeOfTransport
        startTime = startTimeOfTransport;
    else
        n = ceil((currentT - startTimeOfTransport) / intervalTimeOfTransport);
        startTime = startTimeOfTransport + n * intervalTimeOfTransport;
        if startTime > endTimeOfTransport
            startTime = ceil(startTime / 24) * 24 + startTimeOfTransport;
        end
    end

    awaitTime = startTime - currentT;
    startTime = awaitTime + currentTime;
end


%% =========================
%  中转类型
% =========================
function transferType = getTransferType(id1, id2)
    transferType = 1;
    if (id1 == 1 && id2 == 2) || (id1 == 2 && id2 == 1)
        transferType = 2;
    elseif (id1 == 1 && id2 == 3) || (id1 == 3 && id2 == 1)
        transferType = 3;
    elseif (id1 == 2 && id2 == 3) || (id1 == 3 && id2 == 2)
        transferType = 4;
    end
end

function pathTransferType = getPathTransferType(typeOfPath)
    pathTransferType = zeros(1, length(typeOfPath) - 1);
    for i = 1:length(pathTransferType)
        pathTransferType(i) = getTransferType(typeOfPath(i), typeOfPath(i + 1));
    end
end


%% =========================
%  成本与排放
% =========================
function C_wait = getCostWait(waitTime, typeOfPath, model, Q)
    C_wait = sum(Q * waitTime(1:length(typeOfPath)) .* model.costOfUnitWait(typeOfPath));
end

function C_trans = getCostTransport(distanceArray, typeOfPath, model, Q)
    C_trans = sum(Q * distanceArray .* model.costOfUnitTransport(typeOfPath));
end

function E_total = getCarbonEmission(distanceArray, typeOfPath, pathTransferType, model, Q)
    E_trans = sum(Q * distanceArray .* model.carbonEmissionsOfUnitTransport(typeOfPath));
    E_transfer = sum(Q * model.carbonEmissionsOfUnitTransfer(pathTransferType));
    E_total = E_trans + E_transfer;
end

function C_transfer = getCostTransfer(pathTransferType, model, Q)
    C_transfer = sum(Q * model.costOfUnitTransfer(pathTransferType));
end

function C_timeWindow = getCostTimeWindow(arriveTime, model, Q)
    T = arriveTime(end);
    C_timeWindow = 0;
    if T < model.TW(1)
        C_timeWindow = Q * model.p1 * (model.TW(1) - T);
    elseif T > model.TW(2)
        C_timeWindow = Q * model.p2 * (T - model.TW(2));
    end
end

function C_damage = getCostDamage(typeOfPath, pathTransferType, model, Q)
    C_damage_transport = sum(Q * model.rateDamagedOfRansportType(typeOfPath));
    C_damage_transfer = sum(Q * model.rateDamagedOfTransferType(pathTransferType));
    C_damage = model.price * (C_damage_transport + C_damage_transfer);
end


%% =========================
%  单一等价需求下评估
% =========================
function [C_wait, C_trans, C_transfer, C_timeWindow, C_damage, E_total, arriveTime, path, typeOfPath, numOfPenalty, distanceOfPath] = ...
    analyseIndividualUnderQ(individual, model, Q)

    [path, typeOfPath] = model.analyseIndividual(individual, model);
    [distanceOfPath, distanceArray, numOfPenalty] = getDistanceOfPath(path, typeOfPath, model);
    pathTransferType = model.getPathTransferType(typeOfPath);

    if numOfPenalty > 0 || any(~isfinite(distanceArray))
        C_wait = inf;
        C_trans = inf;
        C_transfer = inf;
        C_timeWindow = inf;
        C_damage = inf;
        E_total = inf;
        arriveTime = [0, inf];
        return;
    end

    [arriveTime, waitTime] = getArriveTime(distanceArray, typeOfPath, pathTransferType, model, Q);

    C_wait = getCostWait(waitTime, typeOfPath, model, Q);
    C_trans = getCostTransport(distanceArray, typeOfPath, model, Q);
    C_transfer = getCostTransfer(pathTransferType, model, Q);
    C_timeWindow = getCostTimeWindow(arriveTime, model, Q);
    C_damage = getCostDamage(typeOfPath, pathTransferType, model, Q);
    E_total = getCarbonEmission(distanceArray, typeOfPath, pathTransferType, model, Q);
end


%% =========================
%  双目标
% =========================
function [individualObjs, detail] = getIndividualObjs(individual, model)

    assert(~isempty(model.baseDemand), 'baseDemand 未设置，请在外部脚本中赋值。');
    assert(~isempty(model.demandUncertaintyRate), 'demandUncertaintyRate 未设置，请在外部脚本中赋值。');
    assert(~isempty(model.confidenceLevel), 'confidenceLevel 未设置，请在外部脚本中赋值。');

        Q0 = model.baseDemand;
    rho = max(0, model.demandUncertaintyRate);
    alpha = max(0, min(1, model.confidenceLevel));

    qScen = [(1-rho)*Q0, Q0, (1+rho)*Q0];
    w = model.demandScenarioWeights;
    if numel(w) ~= 3 || any(w < 0)
        w = [0.25 0.50 0.25];
    end
    w = w / sum(w);
    tilt = (alpha - 0.5) * 0.4;
    w = [w(1) - tilt, w(2), w(3) + tilt];
    w = max(w, 0);
    w = w / sum(w);

    c_wait_s = zeros(1,3);
    c_trans_s = zeros(1,3);
    c_transfer_s = zeros(1,3);
    c_timeWindow_s = zeros(1,3);
    c_damage_s = zeros(1,3);
    e_total_s = zeros(1,3);
    penaltyFlag = false;
    arriveTime = [];
    path = [];
    typeOfPath = [];
    numOfPenalty = 0;
    distanceOfPath = NaN;

    for s = 1:3
        [c_wait_s(s), c_trans_s(s), c_transfer_s(s), c_timeWindow_s(s), c_damage_s(s), e_total_s(s), ...
            arriveTime_s, path_s, typeOfPath_s, numOfPenalty_s, distanceOfPath_s] = ...
            analyseIndividualUnderQ(individual, model, qScen(s));
        if s == 2
            arriveTime = arriveTime_s;
            path = path_s;
            typeOfPath = typeOfPath_s;
            numOfPenalty = numOfPenalty_s;
            distanceOfPath = distanceOfPath_s;
        end
        if numOfPenalty_s > 0 || any(~isfinite([c_wait_s(s), c_trans_s(s), c_transfer_s(s), c_timeWindow_s(s), c_damage_s(s), e_total_s(s)]))
            penaltyFlag = true;
        end
    end

    penaltyValue = model.penaltyFactor;

    detail = struct();
    detail.path = path;
    detail.typeOfPath = typeOfPath;
    detail.equivalentDemand = sum(w .* qScen);
    detail.scenarioDemand = qScen;
    detail.scenarioWeight = w;
    detail.baseDemand = model.baseDemand;
    detail.demandUncertaintyRate = model.demandUncertaintyRate;
    detail.confidenceLevel = model.confidenceLevel;

    if penaltyFlag
        individualObjs = [1 1] * (penaltyValue + abs(distanceOfPath));
        detail.arriveTime = inf;
        return;
    end

    C_wait = sum(w .* c_wait_s);
    C_trans = sum(w .* c_trans_s);
    C_transfer = sum(w .* c_transfer_s);
    C_timeWindow = sum(w .* c_timeWindow_s);
    C_damage = sum(w .* c_damage_s);
    E_total = sum(w .* e_total_s);

    C_base = C_wait + C_trans + C_transfer + C_timeWindow + C_damage;
    C_tax = model.carbonTax * E_total;

    F_cost = C_base + C_tax;
    F_carbon = E_total;

    individualObjs = [F_cost, F_carbon];

    detail.arriveTime = arriveTime(end);
    detail.C_wait = C_wait;
    detail.C_trans = C_trans;
    detail.C_transfer = C_transfer;
    detail.C_timeWindow = C_timeWindow;
    detail.C_damage = C_damage;
    detail.C_tax = C_tax;
end

function individualFitness = getIndividualFitness(individual, model)
    individualObjs = getIndividualObjs(individual, model);
    if any(~isfinite(individualObjs)) || any(individualObjs >= model.penaltyFactor)
        individualFitness = -model.penaltyFactor;
        return;
    end

    F_cost = individualObjs(1);
    individualFitness = -F_cost;
end


%% =========================
%  修复个体
% =========================
function newIndividual = repairIndividual(individual, model)
    individualPart1 = individual(1:model.numOfDecVariablesPart1);
    individualPart2 = individual(model.numOfDecVariablesPart1 + 1:end);

    individualPart1 = repairIndividualPart1(individualPart1, model);
    individualPart2 = repairIndividualPart2(individualPart2, model);
    newIndividual = [individualPart1 individualPart2];
end

function newIndividualPart1 = repairIndividualPart1(individualPart1, model)
    [~, IA] = unique(individualPart1, 'stable');
    missSet = setdiff(model.sequence, individualPart1(IA), 'stable');
    newIndividualPart1 = individualPart1;
    dupId = setdiff(1:length(individualPart1), IA, 'stable');
    if ~isempty(dupId)
        fillLen = min(length(dupId), length(missSet));
        newIndividualPart1(dupId(1:fillLen)) = missSet(1:fillLen);
    end
end


%% =========================
%  生成可行路径
% =========================
function path = generateFeasiblePath(model)
    maxRetry = 200;

    for trial = 1:maxRetry
        current = model.startPointId;
        path = current;
        visited = false(1, model.numOfVertex);
        visited(current) = true;

        while current ~= model.endPointId
            outNodes = find(isfinite(model.adjacencyMatrix(current, :)) & model.adjacencyMatrix(current, :) > 0);

            feasibleNext = [];
            for k = 1:length(outNodes)
                nxt = outNodes(k);
                if ~visited(nxt) && isfinite(model.distanceMatOfAdjacency(nxt, model.endPointId))
                    feasibleNext(end+1) = nxt; %#ok<AGROW>
                end
            end

            if isempty(feasibleNext)
                break;
            end

            nextNode = feasibleNext(randi(length(feasibleNext)));
            path(end+1) = nextNode; %#ok<AGROW>
            visited(nextNode) = true;
            current = nextNode;
        end

        if path(end) == model.endPointId
            return;
        end
    end

    error('初始化失败：多次尝试后仍未生成可行路径，请检查网络连通性或初始化逻辑。');
end

function flag = isPathFeasible(path, model)
    flag = true;
    for i = 1:length(path)-1
        if ~isfinite(model.adjacencyMatrix(path(i), path(i+1))) || model.adjacencyMatrix(path(i), path(i+1)) <= 0
            flag = false;
            return;
        end
    end
end
