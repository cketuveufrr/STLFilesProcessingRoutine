%% compare_cross_sections_final.m
% This script processes two rotated STL models (Pre and Post samples) 
% independently and then superposes their cross‐sections.
%
% Built by: Tomić Nicolas
% Date: 06-02-2025
%
% Description:
% 1. For each model:
%    a. The user selects a rotated STL file.
%    b. The model is displayed for inspection.
%    c. The user chooses the vertical cut type and specifies the cut coordinate.
%       - Option 1: XZ cut (vertical plane: Y = constant; independent variable = X)
%       - Option 2: YZ cut (vertical plane: X = constant; independent variable = Y)
%    d. The script computes the intersection (cross‐section) of the mesh with that plane.
%    e. The user supplies a reference Z value; intersection points with z below this are discarded.
%    f. The remaining z–values are shifted (by subtracting the reference).
%    g. The independent variable is centered (by subtracting the midpoint).
%    h. The cross‐section is plotted and saved.
%
% 2. The two centered cross‐sections are then superposed.
% 3. The user is prompted for a measurement line angle (in degrees from the Z axis).
%    A measurement line (with slope = cot(theta)) is constructed.
%    For the Post sample, a dedicated function selects the intersection point that is furthest from the origin.
% 4. The measurement lines and intersection points are plotted and saved.
%
% Requirements: stlread (which returns a triangulation object)

clear all; close all; clc

%% ============================
%% Process Pre Sample (Model 1)
disp('--- Processing Pre Sample ---');

% Prompt user to select the Pre Sample STL file.
[preFileName, preFilePath] = uigetfile('*.stl', 'Select the rotated STL file for Pre Sample');
if isequal(preFileName, 0)
    error('User canceled Pre Sample file selection.');
end
preFullFileName = fullfile(preFilePath, preFileName);

% Read the STL file.
preTri = stlread(preFullFileName);
prePts = preTri.Points;
preFaces = preTri.ConnectivityList;

% Display the Pre Sample for visual inspection.
figure;
trisurf(preFaces, prePts(:,1), prePts(:,2), prePts(:,3), 'EdgeColor', 'none');
axis equal; camlight; lighting gouraud;
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('Pre Sample Loaded - Inspect the Model');
drawnow;
disp('Inspect Pre Sample. Press any key when ready to specify the cut.');
pause;

% Ask the user for the vertical cut type.
preCutType = input('For Pre Sample: Enter 1 for XZ cut (plane: Y = constant) or 2 for YZ cut (plane: X = constant): ');
if preCutType == 1
    preCutPrompt = 'Enter the Y coordinate at which to cut for Pre Sample (e.g., 10): ';
    preIndLabel = 'x';  % independent variable is x
elseif preCutType == 2
    preCutPrompt = 'Enter the X coordinate at which to cut for Pre Sample (e.g., 5): ';
    preIndLabel = 'y';  % independent variable is y
else
    error('Invalid selection for Pre Sample. Please enter 1 or 2.');
end
preCutCoord = input(preCutPrompt);

% Compute the intersection points for the Pre Sample.
tolMesh = 1e-8;
preIntersections = computeIntersectionPoints(prePts, preFaces, preCutType, preCutCoord, tolMesh);
if isempty(preIntersections)
    error('No intersection points found for Pre Sample. Check the cut coordinate or the mesh.');
end

% Ask for the reference Z value and discard points below it.
preRefZ = input('Enter the reference Z value for Pre Sample (points with z below this will be discarded): ');
preIntersections = preIntersections(preIntersections(:,3) >= preRefZ, :);
if isempty(preIntersections)
    error('No intersection points remain for Pre Sample above the reference Z.');
end

% Prepare the Pre Sample cross‐section data.
if preCutType == 1
    preInd = preIntersections(:,1);          % independent variable (x)
    preDep = preIntersections(:,3) - preRefZ;  % adjusted z
else
    preInd = preIntersections(:,2);          % independent variable (y)
    preDep = preIntersections(:,3) - preRefZ;
end
% Sort the data based on the independent variable.
[preInd, sortIdx] = sort(preInd);
preDep = preDep(sortIdx);

% Center the independent variable.
preCenter = (min(preInd) + max(preInd)) / 2;
preIndCentered = preInd - preCenter;

% Save Pre Sample data in a structure.
modelPre.ind = preIndCentered;
modelPre.dep = preDep;
modelPre.file = preFullFileName;
modelPre.cutType = preCutType;
modelPre.indLabel = preIndLabel;

% Plot and save the Pre Sample cross‐section.
figure;
scatter(modelPre.ind, modelPre.dep, 20, 'b', 'filled');
xlabel([preIndLabel ' (centered, mm)']);
ylabel('z (relative to reference, mm)');
if preCutType == 1
    title('Pre Sample Cross‐section: z = f(x)');
else
    title('Pre Sample Cross‐section: z = f(y)');
end
grid on;
drawnow;
saveas(gcf, 'Pre_cross_section.png');
disp('Pre Sample cross‐section plot saved as "Pre_cross_section.png".');

% Save the Pre Sample data to a text file.
if preCutType == 1
    preTxtFile = 'Pre_XZ.txt';
else
    preTxtFile = 'Pre_YZ.txt';
end
writematrix([modelPre.ind, modelPre.dep], preTxtFile, 'Delimiter','tab');
disp(['Pre Sample data saved as "', preTxtFile, '".']);

%% ============================
%% Process Post Sample (Model 2)
disp('--- Processing Post Sample ---');

% Prompt user to select the Post Sample STL file.
[postFileName, postFilePath] = uigetfile('*.stl', 'Select the rotated STL file for Post Sample');
if isequal(postFileName, 0)
    error('User canceled Post Sample file selection.');
end
postFullFileName = fullfile(postFilePath, postFileName);

% Read the STL file.
postTri = stlread(postFullFileName);
postPts = postTri.Points;
postFaces = postTri.ConnectivityList;

% Display the Post Sample for visual inspection.
figure;
trisurf(postFaces, postPts(:,1), postPts(:,2), postPts(:,3), 'EdgeColor','none');
axis equal; camlight; lighting gouraud;
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('Post Sample Loaded - Inspect the Model');
drawnow;
disp('Inspect Post Sample. Press any key when ready to specify the cut.');
pause;

% Ask the user for the vertical cut type for Post Sample.
postCutType = input('For Post Sample: Enter 1 for XZ cut (plane: Y = constant) or 2 for YZ cut (plane: X = constant): ');
if postCutType == 1
    postCutPrompt = 'Enter the Y coordinate at which to cut for Post Sample (e.g., 10): ';
    postIndLabel = 'x';
elseif postCutType == 2
    postCutPrompt = 'Enter the X coordinate at which to cut for Post Sample (e.g., 5): ';
    postIndLabel = 'y';
else
    error('Invalid selection for Post Sample. Please enter 1 or 2.');
end
postCutCoord = input(postCutPrompt);

% Compute the intersection points for the Post Sample.
postIntersections = computeIntersectionPoints(postPts, postFaces, postCutType, postCutCoord, tolMesh);
if isempty(postIntersections)
    error('No intersection points found for Post Sample. Check the cut coordinate or the mesh.');
end

% Ask for the reference Z value and filter the intersection points.
postRefZ = input('Enter the reference Z value for Post Sample (points with z below this will be discarded): ');
postIntersections = postIntersections(postIntersections(:,3) >= postRefZ, :);
if isempty(postIntersections)
    error('No intersection points remain for Post Sample above the reference Z.');
end

% Prepare the Post Sample cross‐section data.
if postCutType == 1
    postInd = postIntersections(:,1);          % independent variable (x)
    postDep = postIntersections(:,3) - postRefZ; % adjusted z
else
    postInd = postIntersections(:,2);          % independent variable (y)
    postDep = postIntersections(:,3) - postRefZ;
end
% Sort the data based on the independent variable.
[postInd, sortIdx] = sort(postInd);
postDep = postDep(sortIdx);

% Center the independent variable.
postCenter = (min(postInd) + max(postInd)) / 2;
postIndCentered = postInd - postCenter;

% Save Post Sample data in a structure.
modelPost.ind = postIndCentered;
modelPost.dep = postDep;
modelPost.file = postFullFileName;
modelPost.cutType = postCutType;
modelPost.indLabel = postIndLabel;

% Plot and save the Post Sample cross‐section.
figure;
scatter(modelPost.ind, modelPost.dep, 20, 'r', 'filled');
xlabel([postIndLabel ' (centered, mm)']);
ylabel('z (relative to reference, mm)');
if postCutType == 1
    title('Post Sample Cross‐section: z = f(x)');
else
    title('Post Sample Cross‐section: z = f(y)');
end
grid on;
drawnow;
saveas(gcf, 'Post_cross_section.png');
disp('Post Sample cross‐section plot saved as "Post_cross_section.png".');

% Save the Post Sample data to a text file.
if postCutType == 1
    postTxtFile = 'Post_XZ.txt';
else
    postTxtFile = 'Post_YZ.txt';
end
writematrix([modelPost.ind, modelPost.dep], postTxtFile, 'Delimiter','tab');
disp(['Post Sample data saved as "', postTxtFile, '".']);

%% ============================
%% Superpose the two centered cross‐sections
figure;
scatter(modelPre.ind, modelPre.dep, 20, 'b', 'filled'); hold on;
scatter(modelPost.ind, modelPost.dep, 20, 'r', 'filled');
xlabel([modelPre.indLabel ' (centered, mm)']);
ylabel('z (relative to reference, mm)');
title('Superposed Cross‐sections');
legend('Pre', 'Post Sample', 'Location', 'best');
grid on;
hold off;
saveas(gcf, 'superposed_cross_sections.png');
disp('Superposed cross‐section plot saved as "superposed_cross_sections.png".');

%% ============================
%% Measurement along measurement line(s)
thetaLineDeg = input('Enter the measurement line angle (in degrees) from the Z axis: ');

if abs(thetaLineDeg) == 0
    % Special case: vertical measurement line.
    disp('Using vertical measurement line (0°).');
    
    % Use the helper function for both Pre and Post samples.
    preIntersectionPt = findFurthestIntersection(modelPre, 0);
    postIntersectionPt = findFurthestIntersection(modelPost, 0);
    
    % Compute and display the distance along the vertical measurement line.
    distanceVertical = norm(preIntersectionPt - postIntersectionPt);
    disp(['Distance along vertical measurement line: ', num2str(distanceVertical), ' mm']);
    
    measurementMode = 'vertical';
else
    % Nonzero angle: use symmetric measurement lines.
    thetaPos = deg2rad(thetaLineDeg);
    thetaNeg = -deg2rad(thetaLineDeg);
    
    % Compute slopes for the measurement lines (z = slope * ind).
    mLinePos = cot(thetaPos);
    mLineNeg = cot(thetaNeg);
    
    % --- Pre Sample Intersections (using the same function for consistency) ---
    preIntersectionPos = findFurthestIntersection(modelPre, mLinePos);
    preIntersectionNeg = findFurthestIntersection(modelPre, mLineNeg);
    
    % --- Post Sample Intersections ---
    postIntersectionPos = findFurthestIntersection(modelPost, mLinePos);
    postIntersectionNeg = findFurthestIntersection(modelPost, mLineNeg);
    
    % Compute and display distances.
    distancePos = norm(preIntersectionPos - postIntersectionPos);
    distanceNeg = norm(preIntersectionNeg - postIntersectionNeg);
    disp(['Distance on the positive side: ', num2str(distancePos), ' mm']);
    disp(['Distance on the negative side: ', num2str(distanceNeg), ' mm']);
    
    measurementMode = 'symmetric';
end

%% ============================
%% Plot measurement lines and intersections on superposed plot
figure;
% Plot superposed cross‐sections.
scatter(modelPre.ind, modelPre.dep, 20, 'b', 'filled'); hold on;
scatter(modelPost.ind, modelPost.dep, 20, 'r', 'filled');
xlabel([modelPre.indLabel ' (centered, mm)']);
ylabel('z (relative to reference, mm)');
grid on;

if strcmp(measurementMode, 'vertical')
    title('Superposed Cross‐sections with Vertical Measurement Line');
    
    % Determine vertical bounds for the line segments.
    zLower = min(preIntersectionPt(2), postIntersectionPt(2));
    zUpper = max(preIntersectionPt(2), postIntersectionPt(2));
    zMinData = min([modelPre.dep; modelPost.dep]);
    
    % Plot the vertical measurement line.
    plot([0 0], [zMinData, zLower], 'k--', 'LineWidth', 1, 'DisplayName', 'Vertical Line');
    plot([0 0], [zLower, zUpper], 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
    
    % Plot the intersection points.
    plot(preIntersectionPt(1), preIntersectionPt(2), 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    plot(postIntersectionPt(1), postIntersectionPt(2), 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    
    legend('Pre', 'Post Sample', 'Vertical Line', 'Location', 'best');
    saveas(gcf, 'vertical_measurement_line.png');
    saveas(gcf, 'vertical_measurement_line.fig');
    disp('Plot saved as "vertical_measurement_line.png".');
else
    title('Superposed Cross‐sections with Symmetric Measurement Intersections');
    
    % Positive measurement line.
    xPosEnd = max(preIntersectionPos(1), postIntersectionPos(1));
    xPosLine = linspace(0, xPosEnd, 100);
    yPosLine = mLinePos * xPosLine;
    
    % Negative measurement line.
    xNegEnd = min(preIntersectionNeg(1), postIntersectionNeg(1));
    xNegLine = linspace(0, xNegEnd, 100);
    yNegLine = mLineNeg * xNegLine;
    
    % Plot the measurement lines.
    plot(xPosLine, yPosLine, 'k--', 'LineWidth', 1, 'DisplayName', sprintf('± %.0f° lines', thetaLineDeg));
    plot(xNegLine, yNegLine, 'm--', 'LineWidth', 1, 'HandleVisibility', 'off');
    
    % Plot the intersection points.
    plot(preIntersectionPos(1), preIntersectionPos(2), 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    plot(postIntersectionPos(1), postIntersectionPos(2), 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    plot(preIntersectionNeg(1), preIntersectionNeg(2), 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'c');
    plot(postIntersectionNeg(1), postIntersectionNeg(2), 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'c');
    
    legend('Pre', 'Post Sample', sprintf('± %.0f° lines', thetaLineDeg), 'Location', 'best');
    saveas(gcf, 'symmetric_measurement_intersections.png');
    saveas(gcf, 'symmetric_measurement_intersections.fig');
    disp('Plot saved as "symmetric_measurement_intersections.png".');
end

%% ============================
%% Save all generated files to a selected folder
saveFolder = uigetdir(pwd, 'Select a folder to save all generated files');
if saveFolder == 0
    disp('User canceled folder selection. Files will remain in the current directory.');
else
    movefile('Pre_cross_section.png', saveFolder);
    movefile(preTxtFile, saveFolder);
    movefile('Post_cross_section.png', saveFolder);
    movefile(postTxtFile, saveFolder);
    movefile('superposed_cross_sections.png', saveFolder);
    if exist('vertical_measurement_line.png', 'file')
        movefile('vertical_measurement_line.png', saveFolder);
        movefile('vertical_measurement_line.fig', saveFolder);
    end
    if exist('symmetric_measurement_intersections.png', 'file')
        movefile('symmetric_measurement_intersections.png', saveFolder);
        movefile('symmetric_measurement_intersections.fig', saveFolder);
    end
    disp(['All generated files have been moved to: ', saveFolder]);
end

%% --- Helper Functions ---

function intersectionPts = computeIntersectionPoints(vertices, faces, cutType, cutCoord, tol)
% computeIntersectionPoints computes the intersection points between an STL mesh and a vertical plane.
%
% INPUTS:
%   vertices  - Nx3 matrix of vertex coordinates.
%   faces     - Mx3 matrix of triangle indices.
%   cutType   - 1 for XZ cut (Y = constant), 2 for YZ cut (X = constant).
%   cutCoord  - Coordinate value of the cutting plane.
%   tol       - Tolerance for numerical comparisons.
%
% OUTPUT:
%   intersectionPts - Kx3 matrix of intersection points.
%
% The function checks each triangle for intersection with the plane and performs linear interpolation along edges.

    intersectionPts = [];
    numTriangles = size(faces, 1);
    
    for i = 1:numTriangles
        triIdx = faces(i, :);
        triVerts = vertices(triIdx, :);  % 3x3 matrix
        
        % Select coordinate values based on the cut type.
        if cutType == 1
            coordVals = triVerts(:,2);  % Y-values for XZ cut
        else
            coordVals = triVerts(:,1);  % X-values for YZ cut
        end
        
        % Check if the triangle intersects the plane.
        if (min(coordVals) - cutCoord <= tol) && (max(coordVals) - cutCoord >= -tol)
            ptsIntersect = [];
            for j = 1:3
                j2 = mod(j, 3) + 1;
                v1 = triVerts(j, :);
                v2 = triVerts(j2, :);
                val1 = coordVals(j);
                val2 = coordVals(j2);
                
                % Check for an edge crossing.
                if ((val1 - cutCoord) * (val2 - cutCoord) < -tol^2) || (abs(val1 - cutCoord) < tol) || (abs(val2 - cutCoord) < tol)
                    if abs(val2 - val1) > tol
                        t = (cutCoord - val1) / (val2 - val1);
                        P = v1 + t * (v2 - v1);
                    else
                        P = v1;
                    end
                    ptsIntersect = [ptsIntersect; P];
                end
            end
            
            % If two unique intersection points were found, store them.
            if size(ptsIntersect, 1) >= 2
                ptsIntersect = unique(ptsIntersect, 'rows');
                if size(ptsIntersect, 1) == 2
                    intersectionPts = [intersectionPts; ptsIntersect];
                end
            end
        end
    end
    
    intersectionPts = unique(intersectionPts, 'rows');
end

function intPt = findFurthestIntersection(model, slope)
% findFurthestIntersection returns the intersection point between a cross-section and a measurement line
% that is furthest from the origin.
%
% USAGE:
%   intPt = findFurthestIntersection(model, slope)
%
% INPUTS:
%   model - A structure with fields:
%           .ind : vector of centered independent variable values.
%           .dep : vector of adjusted dependent (z) values.
%   slope - Slope of the measurement line (vertical if 0, otherwise defined as z = slope * ind).
%
% OUTPUT:
%   intPt - A 1x2 vector [ind, dep] for the selected intersection point.
%
% The function uses the difference function:
%   g = model.ind - (model.dep / slope)
% and performs linear interpolation between points where g changes sign. Then, it selects the candidate
% with the maximum Euclidean distance from the origin.
%
% Tolerance is set to 1e-4.

    tol = 1e-2;
    candidates = [];
    
    if abs(slope) < tol
        % For a vertical line, intersections occur when the independent variable is near zero.
        g = model.ind;
        n = length(g);
        for i = 1:n-1
            if abs(g(i)) < tol
                candidates = [candidates; model.ind(i), model.dep(i)];
            elseif abs(g(i+1)) < tol
                candidates = [candidates; model.ind(i+1), model.dep(i+1)];
            elseif g(i)*g(i+1) < 0
                t = -g(i) / (g(i+1) - g(i));
                indInterp = model.ind(i) + t*(model.ind(i+1) - model.ind(i));
                depInterp = model.dep(i) + t*(model.dep(i+1) - model.dep(i));
                candidates = [candidates; indInterp, depInterp];
            end
        end
    else
        % For a nonvertical line, use the function g = model.ind - (model.dep/slope).
        g = model.ind - (model.dep / slope);
        n = length(g);
        for i = 1:n-1
            if abs(g(i)) < tol
                candidateInd = model.ind(i);
                candidateDep = slope * candidateInd;
                candidates = [candidates; candidateInd, candidateDep];
            elseif abs(g(i+1)) < tol
                candidateInd = model.ind(i+1);
                candidateDep = slope * candidateInd;
                candidates = [candidates; candidateInd, candidateDep];
            elseif g(i) * g(i+1) < 0
                t = -g(i) / (g(i+1) - g(i));
                candidateInd = model.ind(i) + t*(model.ind(i+1) - model.ind(i));
                candidateDep = slope * candidateInd;
                candidates = [candidates; candidateInd, candidateDep];
            end
        end
    end
    
    if isempty(candidates)
        error('No intersection found between the cross-section and the measurement line.');
    end
    
    % Select the candidate with the maximum Euclidean distance from the origin.
    distances = sqrt(candidates(:,1).^2 + candidates(:,2).^2);
    [~, idxMax] = max(distances);
    intPt = candidates(idxMax, :);
end