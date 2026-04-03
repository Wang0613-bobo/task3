clc; clear; close all;

cd(fileparts(mfilename('fullpath')));
addpath(genpath(cd));

outRoot = fullfile(pwd, 'result_task3');
plotFile = fullfile(outRoot, 'task3_plot_data.mat');

if ~exist(plotFile, 'file')
    error('Missing plot data file: %s. Run run_task3_batch first.', plotFile);
end

S = load(plotFile);
if ~isfield(S, 'plotData') || ~isfield(S.plotData, 'rerankingRows')
    error('plotData.rerankingRows not found in %s.', plotFile);
end

rerankingRows = S.plotData.rerankingRows;
if isempty(rerankingRows)
    error('rerankingRows is empty. Run run_task3_batch with valid jobs first.');
end

T = struct2table(rerankingRows);
T = sortrows(T, {'solutionType','axisType','carbonTax','quantityOfCargo'});

% Build compact dominance-switch chain table (Switch only)
sw = strcmp(T.switchType, 'Switch');
Tswitch = T(sw,:);

if isempty(Tswitch)
    warning('No switch events detected. Exporting full reranking table only.');
end

fullFile = fullfile(outRoot, 'task3_reranking_table.xlsx');
if ~exist(fullFile, 'file')
    writetable(T, fullFile);
else
    writetable(T, fullFile, 'Sheet', 'reranking_full');
end

chainFile = fullfile(outRoot, 'task3_dominance_switch_chain.xlsx');
writetable(Tswitch, chainFile);

% Split by representative type
solTypes = unique(T.solutionType, 'stable');
for i = 1:numel(solTypes)
    Ti = T(strcmp(T.solutionType, solTypes{i}), :);
    si = fullfile(outRoot, sprintf('task3_reranking_%s.xlsx', lower(solTypes{i})));
    writetable(Ti, si);
end

matFile = fullfile(outRoot, 'task3_dominance_switch_chain.mat');
save(matFile, 'T', 'Tswitch');

fprintf('[Task3-Rerank] Saved full reranking table: %s\n', fullFile);
fprintf('[Task3-Rerank] Saved switch chain table: %s\n', chainFile);
fprintf('[Task3-Rerank] Saved switch chain mat  : %s\n', matFile);
