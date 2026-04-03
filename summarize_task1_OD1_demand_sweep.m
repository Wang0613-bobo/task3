clc; clear; close all;

cd(fileparts(mfilename('fullpath')));
addpath(genpath(cd));

dataDir = fullfile(pwd, 'result_task1_OD1_identify_dense');
files = dir(fullfile(dataDir, '*.mat'));

if isempty(files)
    error('未找到任务一加密识别型结果文件，请先运行 run_task1_OD1_identify_dense.m');
end

% 按 Q0 排序
Q0Vals = zeros(length(files),1);
for i = 1:length(files)
    tmp = load(fullfile(dataDir, files(i).name), 'meta');
    Q0Vals(i) = tmp.meta.baseDemand;
end
[~, idxSort] = sort(Q0Vals);
files = files(idxSort);

summaryCell = {};
row = 1;

summaryCell(row,:) = { ...
    'File', 'Q0', 'Qeq', 'rho', 'alpha', ...
    'SolType', ...
    'F_cost', 'F_carbon', ...
    'PathFull', 'TypeFull', 'TransferFull', 'RouteSignature', ...
    'nTransfer', 'nModeChange', ...
    'ArriveTime', ...
    'C_wait', 'C_trans', 'C_transfer', 'C_timeWindow', 'C_damage', 'C_tax'};
row = row + 1;

transitionCell = {};
row2 = 1;

transitionCell(row2,:) = {'Q0', 'CostBestSignature', 'CarbonBestSignature', 'TradeoffSignature'};
row2 = row2 + 1;

for k = 1:length(files)

    S = load(fullfile(dataDir, files(k).name));

    meta = S.meta;
    rep  = S.rep;
    allEval = S.allEval;

    % -------------------------
    % 自检：再次核对标签
    % -------------------------
    objMat = vertcat(allEval.objs);
    if abs(rep.costBest.objs(1) - min(objMat(:,1))) > max(1,abs(min(objMat(:,1))))*1e-9
        error('汇总自检失败：%s 中的 CostBest 标签错误。', files(k).name);
    end
    if abs(rep.carbonBest.objs(2) - min(objMat(:,2))) > max(1,abs(min(objMat(:,2))))*1e-9
        error('汇总自检失败：%s 中的 CarbonBest 标签错误。', files(k).name);
    end

    repList = {rep.costBest, rep.carbonBest, rep.tradeoff};

    for j = 1:length(repList)
        R = repList{j};

        summaryCell(row,:) = { ...
            files(k).name, ...
            meta.baseDemand, meta.Qeq, meta.rho, meta.alpha, ...
            R.name, ...
            R.objs(1), R.objs(2), ...
            R.pathText, R.typeText, R.transferText, R.routeSignature, ...
            R.nTransfer, R.nModeChange, ...
            R.arriveTime, ...
            R.C_wait, R.C_trans, R.C_transfer, R.C_timeWindow, R.C_damage, R.C_tax};
        row = row + 1;
    end

    transitionCell(row2,:) = { ...
        meta.baseDemand, ...
        rep.costBest.routeSignature, ...
        rep.carbonBest.routeSignature, ...
        rep.tradeoff.routeSignature};
    row2 = row2 + 1;
end

disp(' ');
disp('===== 任务一加密识别型汇总结果 =====');
disp(summaryCell);

disp(' ');
disp('===== 任务一路径签名变化表 =====');
disp(transitionCell);

save(fullfile(dataDir, 'task1_identify_dense_summary.mat'), 'summaryCell', 'transitionCell');

% 同时导出 txt，方便直接读
txtPath = fullfile(dataDir, 'task1_identify_dense_summary.txt');
fid = fopen(txtPath, 'w');

fprintf(fid, '===== 任务一加密识别型汇总结果 =====\n\n');
for i = 1:size(summaryCell,1)
    for j = 1:size(summaryCell,2)
        val = summaryCell{i,j};
        if isnumeric(val)
            fprintf(fid, '%g', val);
        elseif ischar(val)
            fprintf(fid, '%s', val);
        else
            try
                fprintf(fid, '%s', mat2str(val));
            catch
                fprintf(fid, '[unprintable]');
            end
        end
        if j < size(summaryCell,2)
            fprintf(fid, '\t');
        end
    end
    fprintf(fid, '\n');
end

fprintf(fid, '\n\n===== 任务一路径签名变化表 =====\n\n');
for i = 1:size(transitionCell,1)
    for j = 1:size(transitionCell,2)
        val = transitionCell{i,j};
        if isnumeric(val)
            fprintf(fid, '%g', val);
        elseif ischar(val)
            fprintf(fid, '%s', val);
        else
            try
                fprintf(fid, '%s', mat2str(val));
            catch
                fprintf(fid, '[unprintable]');
            end
        end
        if j < size(transitionCell,2)
            fprintf(fid, '\t');
        end
    end
    fprintf(fid, '\n');
end

fclose(fid);

fprintf('\n汇总 mat 已保存：%s\n', fullfile(dataDir, 'task1_identify_dense_summary.mat'));
fprintf('汇总 txt 已保存：%s\n', txtPath);