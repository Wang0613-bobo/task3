classdef NSGAIIPlus < ALGORITHM
% <multi> <real/integer/label/binary/permutation> <constrained/none>
% Nondominated sorting genetic algorithm II

%------------------------------- Reference --------------------------------
% K. Deb, A. Pratap, S. Agarwal, and T. Meyarivan, A fast and elitist
% multiobjective genetic algorithm: NSGA-II, IEEE Transactions on
% Evolutionary Computation, 2002, 6(2): 182-197.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2023 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Generate random population
            populationSize = Problem.N;
            model = Problem.model;
            populationDec = initialPopulation(populationSize, model);                      % 初始化种群
            Population = Problem.Evaluation(populationDec);
            [~,FrontNo,CrowdDis] = EnvironmentalSelection(Population,Problem.N);
            
            crossoverRate0 = 0.6;                                                        % 交叉概率
            mutationRate0 = 0.1;                                                        % 变异概率
            %% Optimization
            i = 0;
            while Algorithm.NotTerminated(Population)
                i = i + 1;
                D = 2;
                n = 1;
                [vUp, vDown] = getVUpAndVDown(i, D, n, 0);
                crossoverRate = crossoverRate0 * vDown;
                mutationRate = mutationRate0 * vUp;
                
                for j = 1: model.numOfDecVariables / 2
                    MatingPool = TournamentSelection(2,Problem.N,FrontNo,-CrowdDis);
                    OffspringDecs = newCrossoverOperation(Population(MatingPool).decs, crossoverRate, model);       % 交叉操作
                    OffspringDecs = newMutationOperation(OffspringDecs, mutationRate, model);                       % 变异操作
                    Offspring = Problem.Evaluation(OffspringDecs);
                    [Population,FrontNo,CrowdDis] = EnvironmentalSelection([Population,Offspring],Problem.N);
                    Problem.FE = Problem.FE - Problem.N;
                end
                Problem.FE = Problem.FE + Problem.N;
            end
        end
    end
end