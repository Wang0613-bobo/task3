function [newPopulation] = mutationOperationOfReal(population, mutationRate, model)
% 种群变异操作
    populationSize = size(population, 1);
    newPopulation = zeros(size(population));
    for i = 1 : populationSize
        individual = population(i, :);
        newPopulation(i, :) = round(mutateIndividual(individual, mutationRate, model));
    end

end

%% 个体变异
function [individual] = mutateIndividual(individual, mutationRate, model)
    D = size(individual, 2);
    lower = model.lower2;
    upper = model.upper2;
    
    if rand() < 0.2
        individual = rand(1, D) .* (upper - lower) + lower;
    else
        r = zeros(1, D);
        for i = 1: D
            if rand() < mutationRate
                individual(i) = rand() * (upper(i) - lower(i)) + lower(i);       % 局部扰动     
            end
        end
    end
    
end
