% -------------------------------------------------------------------------
% 遗传算法改进
% @作者：冰中呆
% @邮箱：1209805090@qq.com
% @时间：2026.02.03
% -------------------------------------------------------------------------

%% 清空
clear;                                                                      % 清除所有变量
close all;                                                                  % 清图
clc;                                                                        % 清屏
%% 参数配置
addpath(genpath('.\'));                                                     % 将当前文件夹下的所有文件夹都包括进调用函数的目录
% rand('state', 0);
populationSize = 50;                                                         % 种群规模
maxGeneration = 1000;                                                        % 最大进化代数
crossoverRate0 = 0.6;                                                        % 交叉概率
mutationRate0 = 0.01;                                                        % 变异概率


% fileName = './data/data037.txt';
% [model] = initModel(fileName);

fileName = './data/data02.txt';
[model] = initModel2(fileName);

%% 初始化
population = initialPopulation(populationSize, model);                      % 初始化种群
popFitness = getFitness(population, model);                                 % 计算种群适应度

numOfDecVariables = size(population, 2);                                    % 决策变量维度
bestIndividualSet = zeros(maxGeneration, numOfDecVariables);                % 每代最优个体集合
bestFitnessSet = zeros(maxGeneration, 1);                                   % 每代最高适应度集合
avgFitnessSet = zeros(maxGeneration, 1);                                    % 每代平均适应度集合
%% 进化
for i = 1 : maxGeneration
    D = 2;
    n = 1;
    [vUp, vDown] = getVUpAndVDown(i, D, n, 0);
    crossoverRate = crossoverRate0 * vDown;
    mutationRate = mutationRate0 * vUp;
    
    [newPopulation, newPopFitness] = selectionOperationOfTournament(population, popFitness);	% 选择操作
    newPopulation = newCrossoverOperation(newPopulation, crossoverRate, model);                 % 交叉操作
    newPopulation = newMutationOperation(newPopulation, mutationRate, model);                   % 变异操作
    newPopFitness = getFitness(newPopulation, model);                       % 子代种群适应度
    [population, popFitness] = eliteStrategy(population, popFitness, newPopulation, newPopFitness, 2); % 精英策略
 
    
    [bestIndividual, bestFitness, avgFitness] = getBestIndividualAndFitness(population, popFitness);
    bestIndividualSet(i, :) = bestIndividual;                               % 第i代最优个体
    bestFitnessSet(i) = bestFitness;                                        % 第i代最高适应度
    avgFitnessSet(i) = avgFitness;                                          % 第i代种群平均适应度
    fprintf('第%i代种群的最优值：%.3f\n', i, -bestFitness);
    
    if mod(i, 1000) == 0                                                     % 每隔100代绘制一幅图，因为绘图代价较大
        close all;
        subplot(1,2,1);
        model.showIndividual(bestIndividual, model);                        % 路线可视化
        subplot(1,2,2);
        showEvolCurve(1, i, -bestFitnessSet);                               % 显示进化曲线
        model.printIndividual(bestIndividual, model);
        [path, typeOfPath] = model.analyseIndividual(bestIndividual, model);
    end
end
bestIndividual = round(bestIndividual);
%%
[path, typeOfPath] = model.analyseIndividual(bestIndividual, model);
[distanceOfPath, distanceArray, numOfPenalty] = model.getDistanceOfPath(path, typeOfPath, model);
[pathTransferType] = model.getPathTransferType(typeOfPath);                                         % 路线转运信息
[arriveTime, waitTime] = model.getArriveTime(distanceArray, typeOfPath, pathTransferType, model);   % 每个节点的到达时间

bestFitnessSetGaPlus = bestFitnessSet;
save('.\result\bestFitnessSetGaPlus.mat', 'bestFitnessSetGaPlus');

