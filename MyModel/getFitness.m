function [popFitness] = getFitness(population, model)
% 计算种群适应度
    populationSize = size(population, 1);
    popFitness = zeros(populationSize, 1);
    
    for i = 1: populationSize
        individual = population(i, :);
        popFitness(i) = model.getIndividualFitness(individual, model);
%         fprintf('%d --->>%5.4f\n', i, popFitness(i)); 
    end
end


