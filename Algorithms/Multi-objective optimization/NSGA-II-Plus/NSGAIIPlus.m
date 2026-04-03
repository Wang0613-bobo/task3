classdef NSGAIIPlus < ALGORITHM
% <multi> <real/integer/label/binary/permutation> <constrained/none>
% Nondominated sorting genetic algorithm II

%------------------------------- Reference --------------------------------
% K. Deb, A. Pratap, S. Agarwal, and K. Meyarivan, A fast and elitist
% multiobjective genetic algorithm: NSGA-II, IEEE Transactions on
% Evolutionary Computation, 2002, 6(2): 182-197.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2023 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference
% "Ye Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB
% platform for evolutionary multi-objective optimization [educational
% forum], IEEE Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Generate random population
            populationSize = Problem.N;
            model = Problem.model;
            populationDec = initialPopulation(populationSize, model);
            Population = Problem.Evaluation(populationDec);
            [~,FrontNo,CrowdDis] = EnvironmentalSelection(Population,Problem.N);

            crossoverRate0 = 0.6;
            mutationRate0  = 0.1;

            %% Optimization
            i = 0;
            while Algorithm.NotTerminated(Population)
                i = i + 1;
                D = 2;
                n = 1;
                [vUp, vDown] = getVUpAndVDown(i, D, n, 0);
                crossoverRate = crossoverRate0 * vDown;
                mutationRate  = mutationRate0 * vUp;

                for j = 1 : model.numOfDecVariables / 2
                    MatingPool    = TournamentSelection(2,Problem.N,FrontNo,-CrowdDis);
                    OffspringDecs = newCrossoverOperation(Population(MatingPool).decs, crossoverRate, model);
                    OffspringDecs = newMutationOperation(OffspringDecs, mutationRate, model);
                    Offspring     = Problem.Evaluation(OffspringDecs);
                    [Population,FrontNo,CrowdDis] = EnvironmentalSelection([Population,Offspring],Problem.N);
                    Problem.FE = Problem.FE - Problem.N;
                end
                Problem.FE = Problem.FE + Problem.N;
            end

            %% Task 3: save final population
            try
                saveFile = '';

                if ~isempty(Problem.model)
                    if isfield(Problem.model, 'task3SaveFile')
                        saveFile = Problem.model.task3SaveFile;
                    end
                end

                if isempty(saveFile)
                    outDir = fullfile(pwd, 'task3_output');
                    if ~exist(outDir, 'dir')
                        mkdir(outDir);
                    end

                    tau = NaN;
                    Q   = NaN;

                    if ~isempty(Problem.model)
                        if isfield(Problem.model, 'costOfUnitCarbon')
                            tau = Problem.model.costOfUnitCarbon;
                        end
                        if isfield(Problem.model, 'quantityOfCargo')
                            Q = Problem.model.quantityOfCargo;
                        end
                    end

                    saveFile = fullfile(outDir, sprintf('finalPop_tau%.2f_Q%.0f.mat', tau, Q));
                end

                finalPopulation = Population; %#ok<NASGU>
                save(saveFile, 'finalPopulation');
                fprintf('最终种群已保存：%s\n', saveFile);

            catch ME
                warning('NSGAIIPlus 保存最终种群失败：%s', ME.message);
            end
        end
    end
end