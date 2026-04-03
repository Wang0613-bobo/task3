M = 3;
I = 1: 200;
%%
load('./data/NSGAII/NSGAII_myObj_M3_D38_1.mat');
n = size(result, 1);
bestFitnessSet1 = zeros(n , M);
for i = 1: n
    Y = result{i, end}.objs;
    bestFitnessSet1(i, :) = min(Y);
end

load('./data/NSGAIII/NSGAIII_myObj_M3_D38_1.mat');
n = size(result, 1);
bestFitnessSet2 = zeros(n , M);
for i = 1: n
    Y = result{i, end}.objs;
    bestFitnessSet2(i, :) = min(Y);
end

load('./data/NSGAIIPlus/NSGAIIPlus_myObj_M3_D38_1.mat');
n = size(result, 1);
bestFitnessSet3 = zeros(n , M);
for i = 1: n
    Y = result{i, end}.objs;
    bestFitnessSet3(i, :) = min(Y);
end

%%
figure;
semilogy(I, bestFitnessSet1(I, 1), I, bestFitnessSet2(I, 1), I, bestFitnessSet3(I, 1), '-', 'LineWidth', 2);
xlabel('迭代次数', 'Fontsize', 15);
ylabel('F1', 'Fontsize', 15);
legend('NSGA-II', 'NSGA-III', 'NSGA-II改进');

figure;
semilogy(I, bestFitnessSet1(I, 2), I, bestFitnessSet2(I, 2), I, bestFitnessSet3(I, 2), '-', 'LineWidth', 2);
xlabel('迭代次数', 'Fontsize', 15);
ylabel('F2', 'Fontsize', 15);
legend('NSGA-II', 'NSGA-III', 'NSGA-II改进');

figure;
semilogy(I, bestFitnessSet1(I, 3), I, bestFitnessSet2(I, 3), I, bestFitnessSet3(I, 3), '-', 'LineWidth', 2);
xlabel('迭代次数', 'Fontsize', 15);
ylabel('F3', 'Fontsize', 15);
legend('NSGA-II', 'NSGA-III', 'NSGA-II改进');
