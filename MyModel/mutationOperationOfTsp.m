function [newPopulation] = mutationOperationOfTsp(population, mutationRate)
% 种群变异操作
    populationSize = size(population, 1);
    newPopulation = zeros(size(population));
    for i = 1 : populationSize
        individual = population(i, :);
        newPopulation(i, :) = mutateIndividual(individual, mutationRate);
    end

end

%% 个体变异，每个基因位有mutationRate概率与任意基因位互换
function [individual] = mutateIndividual(individual, mutationRate)
    n = length(individual);
    for i = 1: n
        if rand() < mutationRate
            r0 = i;                                                         % 第i,j位互换
            r1 = round(rand() * (n-1) + 1);                                 % 产生一个1-n间的随机数
            s = sort([r0 r1]);                                              % 排序，使r0<r1
            r0 = s(1);
            r1 = s(2);
            individual(r0:r1) = individual(r1:-1:r0);                      	% r0-r1间元素倒序
        end
    end
end

