function [model] = initModel2(fileName)
    data = load(fileName);
   
	model.startPointId = 1;                                                 % 起点id
    model.endPointId = 14;                                                  % 终点id
    model.quantityOfCargo = 1000;                                           % 货物量
    model.TW = [50 60];                                                     % 时间窗,h
    model.costOfUnitWait = [0 8 8 10];                                      % 公路、铁路、水路、航空的单位等待成本,元/(h*t)
    model.speedOfTransportType = [80 60 30 500];                            % 不同运输方式的速度,km/h
    model.costOfUnitTransport = [0.526 0.392 0.09 2.5];                     % 不同运输方式的单位运输成本,元/(km*t)
    model.carbonEmissionsOfUnitTransport = [0.0538 0.01 0.0128 0.02];       % 不同运输方式的单位碳排放量,kg/(km*t)
    model.startTimeOfTransportType = [0 1 1 1];                             % 不同运输方式的发班时刻
    model.endTimeOfTransportType = [24 24 24 24];                           % 不同运输方式的收班时刻
    model.intervalTimeOfTransportType = [0 1 2 3];                          % 不同运输方式的每班间隔
    model.rateDamagedOfRansportType = [0.01 0.015 0.02 0.02] / 100;         % 不同运输方式的货损率，元/t
    model.rateDamagedOfTransferType = [0 0.04 0.04 0.04 0.04 0.04 0.04] / 100;      % [不中转、公路-铁路、公路-水路、铁路-水路、航-公、航-铁、航-水]的货损率，元/t
    model.costOfUnitTransfer = [0 3.5 3 4 4.2 4.3 4.4];                             % [不中转、公路-铁路、公路-水路、铁路-水路、航-公、航-铁、航-水]单位中转成本,元/t
    model.timeOfUnitTransfer = [0 0.01 0.015 0.01 0.021 0.22 0.23];             	% [不中转、公路-铁路、公路-水路、铁路-水路、航-公、航-铁、航-水]单位中转时间,h/t
    model.carbonEmissionsOfUnitTransfer = [0 0.5 0.8 1.0 1.1 1.2 1.3];              % [不中转、公路-铁路、公路-水路、铁路-水路、航-公、航-铁、航-水]单位中转碳排放量,kg/t
    
    model.costOfUnitCarbon = 1;                                             % 单位碳排放量,1元/kg
    model.p1 = 8;                                                           % 单位早到惩罚,8元/(h*t)
    model.p2 = 8;                                                           % 单位晚到惩罚,20元/(h*t)
    model.penaltyFactor = 10 ^ 10;                                          % 惩罚因子
    
	model.numOfObjs = 3;                                                    % 目标数
    model.weightOfObjs = [0.1 0.1 0.1];                                     % 目标权重
    
    model.numOfEdge = size(data, 1);                                        % 总路径数
    model.edgeSet = data(1: model.numOfEdge, 1: 2);                         % 路径
    model.distanceTable = data(1: model.numOfEdge, 3: 6);                   % 节点间各运输方式的距离(公路、铁路、水路、航空)
    model.numOfVertex = max(model.edgeSet(:));                              % 总节点数
    model.numOfTransportType = size(model.distanceTable, 2);                % 运输方式数

    model.adjacencyMatrix = getAdjacencyMatrix(model.edgeSet);              % 连通矩阵
    [model.distanceMatOfAdjacency, ~] = floyd(model.adjacencyMatrix);       % 最短路径(最快几步到达)
    [model.distanceMat3D] = getDistanceMat3D(model.edgeSet, model.distanceTable);           % 各运输方式的距离矩阵(公路、铁路、水路、航空)
    
    model.sequence = removeX(1: model.numOfVertex, model.startPointId);
    model.numOfDecVariablesPart1 = length(model.sequence);                                  % 决定路线
    model.numOfDecVariablesPart2 = length(model.sequence);                                  % 决定运输方式
	model.numOfDecVariables = model.numOfDecVariablesPart1 + model.numOfDecVariablesPart2;	% 决策变量维度
    
    model.lower2 = ones(1, model.numOfDecVariablesPart2);                                   % 决策变量下界
    model.upper2 = ones(1, model.numOfDecVariablesPart2) * model.numOfTransportType;        % 决策变量上界
    
    model.initIndividual = @initIndividual;                                 % 初始化个体
    model.repairIndividual = @repairIndividual;                             % 修复个体
    model.analyseIndividual = @analyseIndividual;
    model.getIndividualFitness = @getIndividualFitness;                     % 计算个体适应度
    model.printIndividual = @printIndividual;                               % 打印结果
    model.showIndividual = @showIndividual;                                 % 个体可视化
    model.getPathTransferType = @getPathTransferType;
    model.getDistanceOfPath = @getDistanceOfPath;
    model.getArriveTime = @getArriveTime;
    model.getIndividualObjs = @getIndividualObjs;
end

function [adjacencyMatrix] = getAdjacencyMatrix(edgeSet)
    numOfVertex = max(edgeSet(:));                                          % 总节点数
    adjacencyMatrix = Inf(numOfVertex, numOfVertex);
    for i = 1: numOfVertex
        adjacencyMatrix(i, i) = 0;
    end
    for i = 1: size(edgeSet, 1)
        id1 = edgeSet(i, 1);
        id2 = edgeSet(i, 2);
        adjacencyMatrix(id1, id2) = 1;
        adjacencyMatrix(id2, id1) = 1;
    end
end

function [distanceMat] = getDistanceMat(edgeSet, distanceArray)
    numOfVertex = max(edgeSet(:));                                          % 总节点数
    distanceMat = Inf(numOfVertex, numOfVertex);
    for i = 1: numOfVertex
        distanceMat(i, i) = 0;
    end
    for i = 1: size(edgeSet, 1)
        id1 = edgeSet(i, 1);
        id2 = edgeSet(i, 2);
        distanceMat(id1, id2) = distanceArray(i);
        distanceMat(id2, id1) = distanceArray(i);
    end
end

function [distanceMat3D] = getDistanceMat3D(edgeSet, distanceTable)
    numOfVertex = max(edgeSet(:));                                          % 总节点数
    numOfTransportType = size(distanceTable, 2);                            % 运输类型数
    distanceMat3D = zeros(numOfVertex, numOfVertex, numOfTransportType);
    for i = 1: numOfTransportType
        distanceArray = distanceTable(:, i);
        distanceMat3D(:, :, i) = getDistanceMat(edgeSet, distanceArray);
    end
end

function [newArray] = removeX(originalArray, elementToRemove)
    indexToRemove = originalArray == elementToRemove;
    newArray = originalArray;
    newArray(indexToRemove) = [];
end


%% 初始化个体
function [individualPart1] = initIndividualPart1(model)
    [sequence] = model.sequence;
    individualPart1 = sequence(randperm(length(sequence)));
end

function [individualPart2] = initIndividualPart2(model)
    individualPart2 = round(rand(1, model.numOfDecVariablesPart2) .* (model.upper2 - model.lower2) + model.lower2);
end

function [individual] = initIndividual(model)
	[individualPart1] = initIndividualPart1(model);
    [individualPart2] = initIndividualPart2(model);    
    individual = [individualPart1 individualPart2];
end

function [path, typeOfPath] = analyseIndividual(individual, model)
    individualPart1 = individual(1: model.numOfDecVariablesPart1);
    individualPart2 = individual(1 + model.numOfDecVariablesPart1: end);

    [individualPart2] = repairIndividualPart2(individualPart2, model);
    
    path = getPath(individualPart1, model);
    typeOfPath = individualPart2(1: length(path) - 1);
end

function [path] = getPath(individualPart1, model)
    [~, I] = find(individualPart1 == model.endPointId);
    path = [model.startPointId individualPart1(1: I)];
end

function [newIndividualPart2] = repairIndividualPart2(individualPart2, model)
	newIndividualPart2 = individualPart2;
    newIndividualPart2 = max(newIndividualPart2, model.lower2);
	newIndividualPart2 = min(newIndividualPart2, model.upper2);
    newIndividualPart2 = round(newIndividualPart2);
end

function [distanceOfPath, distanceArray, numOfPenalty] = getDistanceOfPath(path, typeOfPath, model)
    numOfRoute = length(path) - 1;                                          % 路径数
    distanceArray = zeros(1, numOfRoute);
    for i = 1: numOfRoute
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

% 每个点的到达时间、等待时间
function [arriveTime, waitTime] = getArriveTime(distanceArray, typeOfPath, pathTransferType, model)
    travelTime = distanceArray ./ model.speedOfTransportType(typeOfPath);   % 每段路程行驶时间
    arriveTime = zeros(1, length(distanceArray) + 1);                       % 每个点的到达时间
    waitTime = zeros(1, length(distanceArray) + 1);                         % 每个点的等待时间

    currentTime = 0;
    for i = 1: length(typeOfPath)
        type = typeOfPath(i);
        startTimeOfTransport = model.startTimeOfTransportType(type);
        endTimeOfTransport = model.endTimeOfTransportType(type);
        intervalTimeOfTransport = model.intervalTimeOfTransportType(type);
        [startTime] = getStartTime(currentTime, startTimeOfTransport, endTimeOfTransport, intervalTimeOfTransport);    % 最早出发时间
        waitTime(i) = startTime - currentTime;
        arriveTime(i + 1) = startTime + travelTime(i);                      % 下个点的到达时间
        transferTime = 0;                                                   % 中转时间
        if i > 1
            transferTime = model.quantityOfCargo * model.timeOfUnitTransfer(pathTransferType(i - 1));
        end
        currentTime = arriveTime(i + 1) + transferTime;                     % 当前时间
    end
end

% 等待成本Cost1
function [Cost1] = getCost1(waitTime, typeOfPath, model)
    Cost1 = sum(model.quantityOfCargo * waitTime(1: length(typeOfPath)) .* model.costOfUnitWait(typeOfPath));
end

% 运输成本Cost2
function [Cost2] = getCost2(distanceArray, typeOfPath, model)
    Cost2 = sum(model.quantityOfCargo * distanceArray .* model.costOfUnitTransport(typeOfPath));
end

% 碳排放量Cost3
function [Cost3] = getCost3(distanceArray, typeOfPath, pathTransferType, model)
    Cost31 = sum(model.quantityOfCargo * distanceArray .* model.carbonEmissionsOfUnitTransport(typeOfPath));    % 运输碳排放量
    Cost32 = sum(model.quantityOfCargo * model.carbonEmissionsOfUnitTransfer(pathTransferType));                % 中转排放量
%     Cost3 = (Cost31 + Cost32) * model.costOfUnitCarbon;
    Cost3 = (Cost31 + Cost32);
end

% 中转成本Cost4
function [Cost4] = getCost4(pathTransferType, model)
    Cost4 = sum(model.quantityOfCargo * model.costOfUnitTransfer(pathTransferType));
end

% 时间窗成本Cost5
function [Cost5] = getCost5(arriveTime, model)
    T = arriveTime(end);
    Cost5 = 0;
    if T < model.TW(1)
        Cost5 = model.quantityOfCargo * model.p1 * (model.TW(1) - T);
    elseif T > model.TW(2)
        Cost5 = model.quantityOfCargo * model.p2 * (T - model.TW(2));
    end
end

% 货损成本Cost6
function [Cost6] = getCost6(typeOfPath, pathTransferType, model)
    Cost61 = sum(model.quantityOfCargo * model.rateDamagedOfRansportType(typeOfPath));          % 运输方式的货损
    Cost62 = sum(model.quantityOfCargo * model.rateDamagedOfTransferType(pathTransferType));	% 转运方式的货损
    Cost6 = Cost61 + Cost62;
end

% 转运类型，[不中转、公路-铁路、公路-水路、铁路-水路、航-公、航-铁、航-水]  [1 2 3 4 5 6 7]
function [transferType] = getTransferType(id1, id2)
    transferType = 1;
    if id1 == 1 && id2 == 2 || id1 == 2 && id2 == 1
        transferType = 2;
    elseif id1 == 1 && id2 == 3 || id1 == 3 && id2 == 1
        transferType = 3;
    elseif id1 == 2 && id2 == 3 || id1 == 3 && id2 == 2
        transferType = 4;
	elseif id1 == 1 && id2 == 4 || id1 == 4 && id2 == 1
        transferType = 5;
	elseif id1 == 2 && id2 == 4 || id1 == 4 && id2 == 2
        transferType = 6;
	elseif id1 == 3 && id2 == 4 || id1 == 4 && id2 == 3
        transferType = 7;
    end
end

% 路线转运信息
function [pathTransferType] = getPathTransferType(typeOfPath)
    pathTransferType = zeros(1, length(typeOfPath) -1);
    for i = 1: length(pathTransferType)
        pathTransferType(i) = getTransferType(typeOfPath(i), typeOfPath(i + 1));
    end
end

function [Cost1, Cost2, Cost3, Cost4, Cost5, Cost6, numOfPenalty, distanceOfPath, arriveTime] = getAllCost(individual, model)
    [path, typeOfPath] = model.analyseIndividual(individual, model);
    [distanceOfPath, distanceArray, numOfPenalty] = model.getDistanceOfPath(path, typeOfPath, model);
    [pathTransferType] = model.getPathTransferType(typeOfPath);             % 路线转运信息
    [arriveTime, waitTime] = model.getArriveTime(distanceArray, typeOfPath, pathTransferType, model);
    [Cost1] = getCost1(waitTime, typeOfPath, model);                        % 等待成本Cost1
    [Cost2] = getCost2(distanceArray, typeOfPath, model);                   % 运输成本Cost2
    [Cost3] = getCost3(distanceArray, typeOfPath, pathTransferType, model); % 碳排放量Cost3
    [Cost4] = getCost4(pathTransferType, model);                            % 中转成本Cost4
    [Cost5] = getCost5(arriveTime, model);                                  % 时间窗成本Cost5
    [Cost6] = getCost6(typeOfPath, pathTransferType, model);                % 货损成本Cost6
end

function printIndividual(individual, model)
    [Cost1, Cost2, Cost3, Cost4, Cost5, Cost6, numOfPenalty, distanceOfPath, arriveTime] = getAllCost(individual, model);
    individualFitness = - Cost1 - Cost2 - Cost3 - Cost4 - Cost5 - Cost6 - numOfPenalty * model.penaltyFactor;
    fprintf('等待成本Cost1:%.2f 运输成本Cost2:%.2f 碳排放量Cost3:%.2f 中转成本Cost4:%.2f 时间窗成本Cost5:%.2f 货损成本Cost6:%.2f 目标函数:%.2f\n', Cost1, Cost2, Cost3, Cost4, Cost5, Cost6, -individualFitness);
    [individualObjs] = getIndividualObjs(individual, model);
    fprintf('时间F1:%.2f 成本F2:%.2f 碳排放F3:%.2f\n', individualObjs(1), individualObjs(2), individualObjs(3));
end

% 计算个体适应度
function [individualFitness] = getIndividualFitness(individual, model)
    [Cost1, Cost2, Cost3, Cost4, Cost5, Cost6, numOfPenalty, distanceOfPath, arriveTime] = getAllCost(individual, model);
    individualFitness = - Cost1 - Cost2 - Cost3 - Cost4 - Cost5 - Cost6 - numOfPenalty * model.penaltyFactor;
    if numOfPenalty > 0
        individualFitness = - distanceOfPath;
    end
end

function showIndividual(individual, model)
    [path, typeOfPath] = model.analyseIndividual(individual, model);
    
    distanceTable = model.distanceTable;
    s = model.edgeSet(:, 1);
    t = model.edgeSet(:, 2);
    numOfEdge = length(s);
    numOfVertex = model.numOfVertex;
    
    edgeLabel = cell(numOfEdge, 1);
    for i = 1: numOfEdge
        edgeLabel{i} = num2str(distanceTable(i, :), '%d-');
    end
    nodeLabel = cell(numOfVertex, 1);
    for i = 1: numOfVertex
        nodeLabel{i} = num2str(i);
    end
    
    edgeColor = zeros(numOfEdge, 3);

%     for i = 1: length(path) - 1
%         idS = path(i);
%         idT = path(i + 1);
%         id = find(s == idS & t == idT);
%         if ~isempty(id)
%             if typeOfPath(i) == 1
%                 edgeColor(id, :) = [1 0 0];
%             elseif typeOfPath(i) == 2
%                 edgeColor(id, :) = [0 1 0];
%             elseif typeOfPath(i) == 3
%                 edgeColor(id, :) = [0 0 1];
%             else
%                 edgeColor(id, :) = [0 1 1];
%             end
%         end
%     end
    G = graph(s, t);
%     plot(G,'NodeLabel',nodeLabel,'EdgeLabel',edgeLabel,'EdgeColor',edgeColor, 'LineWidth',2);
	plot(G,'NodeLabel',nodeLabel,'EdgeColor',edgeColor, 'LineWidth',2);
end

function [startTime] = getStartTime(currentTime, startTimeOfTransport, endTimeOfTransport, intervalTimeOfTransport)
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

% 最小化：时间、成本、碳排放
function [individualObjs] = getIndividualObjs(individual, model)
    [Cost1, Cost2, Cost3, Cost4, Cost5, Cost6, numOfPenalty, distanceOfPath, arriveTime] = getAllCost(individual, model);
    f1 = arriveTime(end);                                                   % 时间
    f2 = Cost1 + Cost2 + Cost4 + Cost6;                                     % 成本
    f3 = Cost3;                                                             % 碳排放
    if numOfPenalty > 0
        f1 = numOfPenalty * distanceOfPath;
        f2 = numOfPenalty * distanceOfPath;
        f3 = numOfPenalty * distanceOfPath;
    end
    individualObjs = [f1 f2 f3];
    individualObjs = individualObjs(1: model.numOfObjs);
end




