clc; clear; close all;

cd(fileparts(mfilename('fullpath')));
addpath(genpath(cd));

outRoot = fullfile(pwd, 'result_task3');
figDir = fullfile(outRoot, 'figures');
if ~exist(figDir, 'dir'); mkdir(figDir); end

plotFile = fullfile(outRoot, 'task3_plot_data.mat');
if ~exist(plotFile, 'file')
    error('Missing plot data file: %s. Run run_task3_batch first.', plotFile);
end

S = load(plotFile);
if ~isfield(S, 'plotData')
    error('plotData not found in %s.', plotFile);
end
plotData = S.plotData;
requireField(plotData, 'rerankingRows', plotFile);
requireField(plotData, 'representativeRows', plotFile);
requireField(plotData, 'fourcornerComparison', plotFile);

rerankingRows = plotData.rerankingRows;
repRows = plotData.representativeRows;
if isempty(rerankingRows) || isempty(repRows)
    error('rerankingRows/representativeRows is empty. Run run_task3_batch first.');
end

T = struct2table(rerankingRows);
T = sortrows(T, {'solutionType','axisType','carbonTax','quantityOfCargo'});
R = struct2table(repRows);
R = sortrows(R, {'solutionType','axisType','carbonTax','quantityOfCargo'});

% 1) 基础导表：重排链
sw = strcmp(T.switchType, 'Switch');
Tswitch = T(sw,:);
fullFile = fullfile(outRoot, 'task3_reranking_table.xlsx');
if ~exist(fullFile, 'file')
    writetable(T, fullFile);
else
    writetable(T, fullFile, 'Sheet', 'reranking_full');
end
writetable(Tswitch, fullfile(outRoot, 'task3_dominance_switch_chain.xlsx'));

% 分方案导出（含 tradeoff）
solTypes = unique(T.solutionType, 'stable');
for i = 1:numel(solTypes)
    Ti = T(strcmp(T.solutionType, solTypes{i}), :);
    writetable(Ti, fullfile(outRoot, sprintf('task3_reranking_%s.xlsx', lower(solTypes{i}))));
end

% 2) 典型替代事件表
Treplace = buildTypicalReplacementTable(R);
writetable(Treplace, fullfile(outRoot, 'task3_typical_replacement_events.xlsx'));

% 3) 四角点效应对照表（成本+排放）
Tcorner = buildFourCornerEffectTable(plotData.fourcornerComparison);
writetable(Tcorner, fullfile(outRoot, 'task3_fourcorner_effects_table.xlsx'));

% 4) 作图（PNG + FIG）
figBase = plotSingleFactorBaseFigure(R, figDir);
figCost = plotCombinedEffectFigure(Tcorner, figDir, 'cost');
figEmis = plotCombinedEffectFigure(Tcorner, figDir, 'emission');
figLocal = plotLocalReorderMapFromTradeoff(T, figDir);

% 5) 图注建议（论文可直接改写）
captionFile = fullfile(outRoot, 'task3_figure_caption_suggestions.txt');
writeFigureCaptionSuggestions(captionFile);

save(fullfile(outRoot, 'task3_reranking_analysis_artifacts.mat'), ...
    'T', 'Tswitch', 'R', 'Treplace', 'Tcorner', 'figBase', 'figCost', 'figEmis', 'figLocal', 'captionFile');

fprintf('[Task3-Rerank] 保存完成：%s\n', outRoot);

function requireField(S, fieldName, srcFile)
if ~isfield(S, fieldName)
    error('plotData.%s not found in %s.', fieldName, srcFile);
end
end

function T = buildTypicalReplacementTable(R)
axesForEvents = {'demand','tax','fourcorner','localscan'};
rows = cell(0, 1);
for a = 1:numel(axesForEvents)
    axisName = axesForEvents{a};
    A = R(strcmp(R.axisType, axisName), :);
    if isempty(A); continue; end

    solTypes = unique(A.solutionType, 'stable');
    for s = 1:numel(solTypes)
        B = A(strcmp(A.solutionType, solTypes{s}), :);
        B = sortByAxis(B, axisName);
        for i = 2:height(B)
            changedPath = ~strcmp(B.pathSignature{i-1}, B.pathSignature{i});
            changedMode = ~strcmp(B.modeSignature{i-1}, B.modeSignature{i});
            if ~(changedPath || changedMode)
                continue;
            end
            r = struct();
            r.solutionType = B.solutionType{i};
            r.axisType = axisName;
            r.parameterChange = sprintf('Δtau=%.2f, ΔQ=%.0f', B.carbonTax(i)-B.carbonTax(i-1), B.quantityOfCargo(i)-B.quantityOfCargo(i-1));
            r.fromSignature = B.signature{i-1};
            r.toSignature = B.signature{i};
            r.routeChange = yesNo(changedPath);
            r.transportModeChange = yesNo(changedMode);
            r.arrivalTimeChange = B.arriveTime(i) - B.arriveTime(i-1);
            r.totalCostChange = B.totalCost(i) - B.totalCost(i-1);
            r.totalEmissionChange = B.totalEmission(i) - B.totalEmission(i-1);
            r.reorderFeature = classifyFeature(changedPath, changedMode);
            rows{end+1, 1} = r; %#ok<AGROW>
        end
    end
end

if isempty(rows)
    T = table();
else
    T = struct2table(vertcat(rows{:}));
    T = sortrows(T, {'solutionType','axisType'});
end
end

function T = buildFourCornerEffectTable(fourcornerComparison)
if isempty(fourcornerComparison)
    T = table();
    return;
end
if istable(fourcornerComparison)
    C = fourcornerComparison;
else
    C = struct2table(fourcornerComparison);
end

% 成本效应
T = C(:, {'solutionType', ...
    'deltaQ_atLowTau_cost', 'deltaQ_atHighTau_cost', 'deltaTau_atLowQ_cost', 'deltaTau_atHighQ_cost'});
T.demandEffect_lowTau_cost = T.deltaQ_atLowTau_cost;
T.demandEffect_highTau_cost = T.deltaQ_atHighTau_cost;
T.lowCarbonEffect_lowDemand_cost = T.deltaTau_atLowQ_cost;
T.lowCarbonEffect_highDemand_cost = T.deltaTau_atHighQ_cost;

% 排放效应（由四角点原始值直接计算）
T.demandEffect_lowTau_emission = C.HL_emission - C.LL_emission;
T.demandEffect_highTau_emission = C.HH_emission - C.LH_emission;
T.lowCarbonEffect_lowDemand_emission = C.LH_emission - C.LL_emission;
T.lowCarbonEffect_highDemand_emission = C.HH_emission - C.HL_emission;

T = T(:, {'solutionType', ...
    'demandEffect_lowTau_cost', 'demandEffect_highTau_cost', ...
    'lowCarbonEffect_lowDemand_cost', 'lowCarbonEffect_highDemand_cost', ...
    'demandEffect_lowTau_emission', 'demandEffect_highTau_emission', ...
    'lowCarbonEffect_lowDemand_emission', 'lowCarbonEffect_highDemand_emission'});
end

function figPath = plotSingleFactorBaseFigure(R, figDir)
solTypes = {'CostBest','CarbonBest','Tradeoff'};
colors = lines(numel(solTypes));
Td = sortrows(R(strcmp(R.axisType, 'demand'), :), {'solutionType','quantityOfCargo'});
Tt = sortrows(R(strcmp(R.axisType, 'tax'), :), {'solutionType','carbonTax'});

f = figure('Color','w', 'Position', [100,100,1260,480]);
subplot(1,2,1); hold on; box on; grid on;
title('基础图：固定碳价下代表解轨迹');
xlabel('货量水平 Q（t）'); ylabel('总成本');
for i = 1:numel(solTypes)
    B = Td(strcmp(Td.solutionType, solTypes{i}), :);
    if isempty(B); continue; end
    plot(B.quantityOfCargo, B.totalCost, '-o', 'LineWidth', 1.6, 'Color', colors(i,:), 'DisplayName', solTypes{i});
end
legend('Location','best');

subplot(1,2,2); hold on; box on; grid on;
title('基础图：固定需求下代表解轨迹');
xlabel('碳价水平 \tau'); ylabel('总成本');
for i = 1:numel(solTypes)
    B = Tt(strcmp(Tt.solutionType, solTypes{i}), :);
    if isempty(B); continue; end
    plot(B.carbonTax, B.totalCost, '-o', 'LineWidth', 1.6, 'Color', colors(i,:), 'DisplayName', solTypes{i});
end
legend('Location','best');
annotation(f, 'textbox', [0.12,0.01,0.8,0.06], 'String', ...
    '图注：该图仅用于说明单因素变化下代表解会发生重排，不承担双因素联合作用的主证明任务。', ...
    'EdgeColor', 'none', 'FontSize', 10);

figPath = fullfile(figDir, 'fig5x_base_single_factor_trajectories');
saveas(f, [figPath '.png']);
savefig(f, [figPath '.fig']);
close(f);
end

function figPath = plotCombinedEffectFigure(Tcorner, figDir, metricType)
if isempty(Tcorner)
    figPath = '';
    return;
end
solTypes = {'CostBest','CarbonBest','Tradeoff'};

f = figure('Color','w', 'Position', [80,120,1320,440]);
for i = 1:numel(solTypes)
    subplot(1,3,i); hold on; box on; grid on;
    idx = strcmp(Tcorner.solutionType, solTypes{i});
    if ~any(idx); continue; end
    row = Tcorner(idx,:);

    if strcmpi(metricType, 'cost')
        yLowTax = [0, row.demandEffect_lowTau_cost];
        yHighTax = [row.lowCarbonEffect_lowDemand_cost, row.lowCarbonEffect_lowDemand_cost + row.demandEffect_highTau_cost];
        yLabel = 'Δ总成本';
        fTitle = '组合条件效应对照图（成本侧）';
        outName = 'fig5x_combined_effect_cost';
    else
        yLowTax = [0, row.demandEffect_lowTau_emission];
        yHighTax = [row.lowCarbonEffect_lowDemand_emission, row.lowCarbonEffect_lowDemand_emission + row.demandEffect_highTau_emission];
        yLabel = 'Δ总排放';
        fTitle = '组合条件效应对照图（排放侧）';
        outName = 'fig5x_combined_effect_emission';
    end

    plot([1,2], yLowTax, '-o', 'LineWidth', 1.8, 'DisplayName', '低碳价条件');
    plot([1,2], yHighTax, '-s', 'LineWidth', 1.8, 'DisplayName', '高碳价条件');
    set(gca, 'XTick', [1,2], 'XTickLabel', {'低需求','高需求'});
    xlabel('需求水平'); ylabel(yLabel);

    if strcmp(solTypes{i}, 'CostBest')
        st = '经济性最优方案';
    elseif strcmp(solTypes{i}, 'CarbonBest')
        st = '低排放最优方案';
    else
        st = '均衡折中方案';
    end
    title(st);
    legend('Location', 'best');
end
sgtitle(fTitle);

figPath = fullfile(figDir, outName);
saveas(f, [figPath '.png']);
savefig(f, [figPath '.fig']);
close(f);
end

function figPath = plotLocalReorderMapFromTradeoff(T, figDir)
% 仅使用 tradeoff + local sweep，避免语义偏移
L = T(strcmp(T.solutionType, 'Tradeoff') & strcmp(T.axisType, 'localscan'), :);
if isempty(L)
    figPath = '';
    return;
end
L = sortrows(L, {'quantityOfCargo','carbonTax'});

classes = cell(height(L),1);
for i = 1:height(L)
    if i == 1 || strcmp(L.switchType{i}, 'Initial') || strcmp(L.switchType{i}, 'Keep')
        classes{i} = '保持原方案';
    elseif strcmp(L.pathSwitchType{i}, 'SwitchPath') && strcmp(L.modeSwitchType{i}, 'KeepMode')
        classes{i} = '仅路径切换';
    elseif strcmp(L.pathSwitchType{i}, 'SwitchPath') && strcmp(L.modeSwitchType{i}, 'SwitchMode')
        classes{i} = '路径与方式同步切换';
    else
        % 本图限定三类：无法归入前两类的变化并入“保持原方案”
        classes{i} = '保持原方案';
    end
end

f = figure('Color','w', 'Position', [120,120,720,540]);
hold on; box on; grid on;
title('局部扫描区域代表性方案重排分布（Tradeoff）');
xlabel('碳价水平'); ylabel('货量');

u = unique(classes, 'stable');
markers = {'o','s','^'};
for i = 1:numel(u)
    idx = strcmp(classes, u{i});
    mk = markers{min(i, numel(markers))};
    scatter(L.carbonTax(idx), L.quantityOfCargo(idx), 88, 'Marker', mk, 'LineWidth', 1.4, 'DisplayName', u{i});
end
text(L.carbonTax + 0.004, L.quantityOfCargo + 4, L.pointName, 'FontSize', 9);
legend('Location', 'bestoutside');

figPath = fullfile(figDir, 'fig5x_local_2d_reranking_tradeoff');
saveas(f, [figPath '.png']);
savefig(f, [figPath '.fig']);
close(f);
end

function writeFigureCaptionSuggestions(filePath)
lines = {
'图注建议1（基础图）: 在固定碳价与固定需求的单因素条件下，三类代表解均出现轨迹变化，说明单因素扰动已可触发方案重排；该图用于提供机制铺垫，不作为双因素联合作用主证据。';
'图注建议2（组合条件效应对照图-成本侧）: 在四角点组合条件下，低/高碳价两条线在低需求与高需求区间的变化幅度不同，表明需求效应会随低碳约束水平而改变。';
'图注建议3（组合条件效应对照图-排放侧）: 成本侧之外，排放侧同样表现出组合条件下的效应差异，进一步支持双因素联合作用并非单一指标现象。';
'图注建议4（局部二维重排图）: 在局部扫描区域内，代表解在“保持原方案—仅路径切换—路径与方式同步切换”三类状态间转移，体现了路径层与方式层的分层重排特征。'
};
fid = fopen(filePath, 'w');
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end

function A = sortByAxis(A, axisName)
switch lower(axisName)
    case 'demand'
        [~, idx] = sort(A.quantityOfCargo, 'ascend');
    case 'tax'
        [~, idx] = sort(A.carbonTax, 'ascend');
    case 'fourcorner'
        key = (A.quantityOfCargo - min(A.quantityOfCargo)) .* 1000 + A.carbonTax;
        [~, idx] = sort(key, 'ascend');
    otherwise
        [~, idx] = sortrows([A.carbonTax, A.quantityOfCargo], [1,2]);
end
A = A(idx,:);
end

function s = yesNo(tf)
if tf
    s = 'Yes';
else
    s = 'No';
end
end

function s = classifyFeature(changedPath, changedMode)
if changedPath && changedMode
    s = 'Path and mode switched';
elseif changedPath
    s = 'Path switched only';
elseif changedMode
    s = 'Mode switched only';
else
    s = 'No switch';
end
end
