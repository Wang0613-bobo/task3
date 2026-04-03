fileName = './data/data037.txt';
data = load(fileName);
distanceTable = data(:, 3: 5);
s = data(:, 1);
t = data(:, 2);
n = length(s);
weights = rand(n ,1);
codes = cell(n, 1);
for i = 1: n
    codes{i} = num2str(distanceTable(i, :),'%d-');
end

X = unique([s;t]);
m = length(X);
names = cell(m, 1);
for i = 1: m
    names{i} = num2str(i);
end
colors = zeros(n, 3);
path = [1     2     7     9    11    14];
typeOfPath = [1     2     1     1     1];

for i = 1: length(path) - 1
    idS = path(i);
    idT = path(i + 1);
    id = find(s == idS & t == idT);
    if typeOfPath(i) == 1
        colors(id, :) = [1 0 0];
    elseif typeOfPath(i) == 2
        colors(id, :) = [0 1 0];
    else
        colors(id, :) = [0 0 1];
    end
end

G = graph(s, t);
plot(G,'NodeLabel',names,'EdgeLabel',codes,'EdgeColor',colors, 'LineWidth',2);








