x = allData (:,26)
x1 = allData.Position (:, 1)
y = table2cell(x)
y1 = cell2mat (y)
plot (x1, y1)
xlabel ('Position of Auditory Stimulus')
ylabel ('Response')
ylim ([-1 2])
xlim ([-67.5 67.5])
xticks ([-67.5 -52.5 -37.5 -22.5 -7.5 7.5 22.5 37.5 52.5 67.5])
xticklabels ({ '-67.5', '-52.5', '-37.5', '-22.5', '-7.5', '7.5', '22.5', '37.5', '52.5', '67.5'})
legend ('Auditory')