function [alphaIndividual, betaIndividual, deltaIndividual, alphaFitness, betaFitness, deltaFitness] = getEliteIndividual(population, popFitness)
    [popFitness0, index] = sort(popFitness, 'descend');                             % 根据适应度从大到小排序
    population0 = population(index,:);
    
    alphaIndividual = population0(1, :);
    betaIndividual = population0(2, :);
    deltaIndividual = population0(3, :);
    
    alphaFitness = popFitness0(1);
    betaFitness = popFitness0(2);
    deltaFitness = popFitness0(3);
end

