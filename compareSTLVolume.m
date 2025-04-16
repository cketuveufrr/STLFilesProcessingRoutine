%% compareSTLvolume.m
%   This script compares two high-resolution STL surface meshes ("pre" and 
%   "post" exposure) to compute the net volume change due to material swelling
%   and ablation.
%
% Author: Nicolas Tomić
% Date: 2025-03-24
%
% Repository:
%   https://github.com/LeCodeurSombre/STLFilesProcessingRoutine
%
% Citation:
%   If you use this script or any part of the STLFilesProcessingRoutine toolbox 
%   in your research or project, please cite it as:
%
%   Nicolas Tomić. "STLFilesProcessingRoutine – A MATLAB toolbox for STL-based 
%   volume comparison and processing." GitHub, 2025. 
%   https://github.com/LeCodeurSombre/STLFilesProcessingRoutine
%
% Workflow Summary:
%     1. Load STL files and (optionally) recenter them using reference points.
%     2. Launch a manual alignment GUI (for XYZ translation, Z rotation, and 
%        optional centering via new buttons).
%     3. Apply the alignment transformations.
%     4. (Optional) Proceed with further processing: clipping, voxelization,
%        interactive volume comparison.
%     5. Save the aligned POST mesh as "aligned_post_clipped.stl" (the only new
%        STL file) and overwrite the original PRE and POST STL files with the
%        final aligned meshes.
%     6. Final visualization and saving of all figures and additional outputs 
%        (figures and the new STL file) to a user-selected folder.
%
% Requirements: stlread, stlwrite, VOXELISE
% -------------------------------------------------------------------------

clear; clc; close all

%% STEP 1: Load STL Files (units: mm)
disp('Select PRE exposure STL file:');
[preFileName, preFilePath] = uigetfile('*.stl', 'Select PRE STL');
if preFileName == 0
    error('No file selected.');
end
preFullPath = fullfile(preFilePath, preFileName);
TR_pre = stlread(preFullPath);

disp('Select POST exposure STL file:');
[postFileName, postFilePath] = uigetfile('*.stl', 'Select POST STL');
if postFileName == 0
    error('No file selected.');
end
postFullPath = fullfile(postFilePath, postFileName);
TR_post = stlread(postFullPath);

%% STEP 1.5: (Optional) Reference Point Selection for Centering
answer = questdlg('Do you want to choose a reference for both meshes (if never aligned before)?', ...
    'Reference Points', 'Yes', 'No', 'Yes');
preVertices = TR_pre.Points;
postVertices = TR_post.Points;
if strcmp(answer, 'Yes')
    disp('Pick a reference point on PRE geometry.');
    refPre = pickSingleReferencePoint(TR_pre);
    disp('Pick a reference point on POST geometry.');
    refPost = pickSingleReferencePoint(TR_post);
    
    % Center each mesh in XY by subtracting the chosen reference point.
    preVertices(:,1:2) = preVertices(:,1:2) - refPre(1:2);
    postVertices(:,1:2) = postVertices(:,1:2) - refPost(1:2);
else
    disp('Skipping reference selection. Meshes remain unchanged.');
end
TR_pre_centered = triangulation(TR_pre.ConnectivityList, preVertices);
TR_post_centered = triangulation(TR_post.ConnectivityList, postVertices);

%% STEP 2: Launch the Alignment GUI
finalTransform = alignmentGUI_Zcut(TR_pre_centered, TR_post_centered, preVertices, postVertices);
fprintf('Z Cut: %.2f mm\n', finalTransform.Zcut);

%% STEP 3: Apply Final Transformations
% The GUI returns updated point arrays for both meshes.
TR_pre_aligned  = triangulation(TR_pre.ConnectivityList, finalTransform.prePoints);
TR_post_aligned = triangulation(TR_post.ConnectivityList, finalTransform.postPoints);

%% STEP 3.5: Proceed or Save Only?
choice = questdlg('Do you want to proceed with further processing (clipping, voxelization, etc.)?',...
    'Continue Processing?', 'Yes','No','Yes');
if strcmp(choice, 'No')
    % Overwrite the original STL files with the aligned meshes.
    stlwrite(TR_pre_aligned, fullfile(preFilePath, preFileName));
    stlwrite(TR_post_aligned, fullfile(postFilePath, postFileName));
    disp('Aligned STL files have been saved (overwriting the originals).');
    return;
end

%% STEP 4: Clip and Cap the Meshes
Zcut = finalTransform.Zcut;
TR_pre_clipped  = clipAndCapMesh(TR_pre_aligned, Zcut);
TR_post_clipped = clipAndCapMesh(TR_post_aligned, Zcut);

%% STEP 4.5: Visualize Clipped and Capped Meshes
figure('Name', 'Clipped and Capped Meshes');
subplot(1,2,1);
trisurf(TR_pre_clipped.ConnectivityList, TR_pre_clipped.Points(:,1), TR_pre_clipped.Points(:,2), TR_pre_clipped.Points(:,3), ...
    'FaceColor', 'cyan', 'EdgeColor', 'none');
axis equal; camlight; lighting gouraud; grid on;
title('PRE: Clipped and Capped');
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');

subplot(1,2,2);
trisurf(TR_post_clipped.ConnectivityList, TR_post_clipped.Points(:,1), TR_post_clipped.Points(:,2), TR_post_clipped.Points(:,3), ...
    'FaceColor', 'magenta', 'EdgeColor', 'none');
axis equal; camlight; lighting gouraud; grid on;
title('POST: Clipped and Capped');
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');

allVertices = [TR_pre_clipped.Points; TR_post_clipped.Points];
set(gca, 'XLim', [min(allVertices(:,1)) max(allVertices(:,1))], ...
         'YLim', [min(allVertices(:,2)) max(allVertices(:,2))], ...
         'ZLim', [min(allVertices(:,3)) max(allVertices(:,3))]);

%% STEP 5: Define Voxel Grid and Perform Voxelization
voxelsPerMM = 5;
voxelSize = 1 / voxelsPerMM;
allPts = [TR_pre_clipped.Points; TR_post_clipped.Points];
minPt = min(allPts);
maxPt = max(allPts);
xGrid = minPt(1):voxelSize:maxPt(1);
yGrid = minPt(2):voxelSize:maxPt(2);
zGrid = minPt(3):voxelSize:maxPt(3);

% Export temporary STL files for voxelization.
stlwrite(TR_pre_clipped, 'temp_pre_mm.stl');
stlwrite(TR_post_clipped, 'temp_post_mm.stl');

hWait = waitbar(0, 'Starting voxelization...');
waitbar(0.1, hWait, '10%: STL export finished.');
waitbar(0.3, hWait, '30%: Voxelizing PRE mesh...');
V1 = VOXELISE(xGrid, yGrid, zGrid, 'temp_pre_mm.stl', 'XYZ');
waitbar(0.6, hWait, '60%: Voxelizing POST mesh...');
V2 = VOXELISE(xGrid, yGrid, zGrid, 'temp_post_mm.stl', 'XYZ');
waitbar(1, hWait, '100%: Voxelization finished.');
pause(0.5);
close(hWait);

%% STEP 6: Compute Volume Differences
voxelVolume = voxelSize^3;
fprintf('Volume of a Voxel: %.3f mm^3\n', voxelVolume);

% Determine regions where material has swollen or ablated.
V_swelling = (~V1) & V2;
V_ablation = V1 & (~V2);

volSwelling = sum(V_swelling(:)) * voxelVolume;
volAblation = sum(V_ablation(:)) * voxelVolume;
netVolumeChange = volSwelling - volAblation;
fprintf('Net Volume Change: %.3f mm^3\n', netVolumeChange);

[X, Y, Z] = ndgrid(xGrid, yGrid, zGrid);

%% STEP 6.5: Interactive Volume Comparison
interactiveVolumeComparison(X, Y, Z, V1, V2, V_swelling, V_ablation, voxelVolume);

%% STEP 7: Save the Aligned, Clipped POST Mesh
stlwrite(TR_post_clipped, 'aligned_post_clipped.stl');
disp('Saved: aligned_post_clipped.stl');

%% STEP 8: Final Visualization (Union of PRE and POST)
figure('Name', 'Union of Pre and Post Samples');
hold on; grid on;
trisurf(TR_pre_clipped.ConnectivityList, TR_pre_clipped.Points(:,1), TR_pre_clipped.Points(:,2), TR_pre_clipped.Points(:,3), ...
    'FaceColor', 'cyan', 'EdgeColor', 'none', 'FaceAlpha', 0.5);
trisurf(TR_post_clipped.ConnectivityList, TR_post_clipped.Points(:,1), TR_post_clipped.Points(:,2), TR_post_clipped.Points(:,3), ...
    'FaceColor', 'magenta', 'EdgeColor', 'none', 'FaceAlpha', 1.0);
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
legend({'Pre','Post'}, 'Location', 'Best');
axis equal; view(45,30); camlight; lighting gouraud;

%% STEP 9: Save Figures and Additional Outputs
outputFolder = uigetdir('', 'Select folder to save additional outputs (figures, aligned_post_clipped.stl, etc.)');
if outputFolder ~= 0
    figHandles = findall(0, 'Type', 'figure');
    for i = 1:length(figHandles)
        fh = figHandles(i);
        figName = get(fh, 'Name');
        figName = regexprep(figName, '[\\/:*?"<>|]', '_');
        if isempty(figName)
            figName = sprintf('Figure_%d', i);
        end
        saveas(fh, fullfile(outputFolder, [figName, '.fig']));
        saveas(fh, fullfile(outputFolder, [figName, '.jpg']));
    end
    stlwrite(TR_post_clipped, fullfile(outputFolder, 'aligned_post_clipped.stl'));
    disp('Additional outputs have been saved to the selected folder.');
else
    disp('No folder selected. Skipping saving additional outputs.');
end

%% STEP 10: Overwrite the Original STL Files
stlwrite(TR_pre_aligned, fullfile(preFilePath, preFileName));
stlwrite(TR_post_aligned, fullfile(postFilePath, postFileName));
disp('Original PRE and POST STL files have been overwritten.');

%% --- Helper Functions ---

function newPoints = applyTransform(points, transform)
    % applyTransform rotates (about Z) and translates a set of points.
    %   points    - Nx3 matrix of point coordinates.
    %   transform - Struct with fields: Rz (rotation in degrees), Tx, Ty, Tz.
    %
    % Returns:
    %   newPoints - Transformed points.
    
    Rz = [cosd(transform.Rz), -sind(transform.Rz), 0;
          sind(transform.Rz),  cosd(transform.Rz), 0;
          0, 0, 1];
    newPoints = (Rz * points')';
    newPoints(:,1) = newPoints(:,1) + transform.Tx;
    newPoints(:,2) = newPoints(:,2) + transform.Ty;
    newPoints(:,3) = newPoints(:,3) + transform.Tz;
end

function interactiveVolumeComparison(X, Y, Z, V1, V2, V_swelling, V_ablation, voxelVolume)
    % interactiveVolumeComparison displays the volumes (PRE, POST, swelling, ablation)
    % and creates an interactive GUI to toggle visibility and adjust clipping.
    
    volPre = sum(V1(:)) * voxelVolume;
    volPost = sum(V2(:)) * voxelVolume;
    volSwelling = sum(V_swelling(:)) * voxelVolume;
    volAblation = sum(V_ablation(:)) * voxelVolume;
    
    hFig = figure('Name', 'Interactive Volume Comparison', 'Position', [100, 100, 800, 600]);
    hAxes = axes('Parent', hFig, 'Position', [0.05, 0.15, 0.6, 0.8]);
    hold(hAxes, 'on'); axis(hAxes, 'equal'); camlight; lighting gouraud; grid on;
    xlabel(hAxes, 'X (mm)'); ylabel(hAxes, 'Y (mm)'); zlabel(hAxes, 'Z (mm)');
    view(hAxes, [45, 30]);
    
    % Create isosurfaces for each volume.
    hPatchPre = patch(isosurface(X, Y, Z, V1, 0.5));
    set(hPatchPre, 'FaceColor', 'cyan', 'EdgeColor', 'none', 'FaceAlpha', 'interp');
    hPatchPost = patch(isosurface(X, Y, Z, V2, 0.5));
    set(hPatchPost, 'FaceColor', 'magenta', 'EdgeColor', 'none', 'FaceAlpha', 'interp');
    hPatchSwelling = patch(isosurface(X, Y, Z, V_swelling, 0.5));
    set(hPatchSwelling, 'FaceColor', 'green', 'EdgeColor', 'none', 'FaceAlpha', 'interp');
    hPatchAblation = patch(isosurface(X, Y, Z, V_ablation, 0.5));
    set(hPatchAblation, 'FaceColor', 'red', 'EdgeColor', 'none', 'FaceAlpha', 'interp');
    
    % Set uniform alpha values.
    set(hPatchPre, 'FaceVertexAlphaData', ones(size(get(hPatchPre, 'Vertices'),1),1));
    set(hPatchPost, 'FaceVertexAlphaData', ones(size(get(hPatchPost, 'Vertices'),1),1));
    set(hPatchSwelling, 'FaceVertexAlphaData', ones(size(get(hPatchSwelling, 'Vertices'),1),1));
    set(hPatchAblation, 'FaceVertexAlphaData', ones(size(get(hPatchAblation, 'Vertices'),1),1));
    
    hold(hAxes, 'off');
    
    % Create a control panel for toggling and clipping.
    hPanel = uipanel('Parent', hFig, 'Title', 'Volume Options', 'Units', 'normalized', ...
                     'Position', [0.7, 0.15, 0.28, 0.8]);
    uicontrol('Parent', hPanel, 'Style', 'checkbox', 'String', ...
        ['Swelling: ', num2str(volSwelling, '%.1f'), ' mm^3'], 'Units', 'normalized', ...
        'Position', [0.05, 0.80, 0.9, 0.1], 'Value', 1, ...
        'Callback', @(src, event) togglePatch(src, hPatchSwelling));
    uicontrol('Parent', hPanel, 'Style', 'checkbox', 'String', ...
        ['Ablation: ', num2str(volAblation, '%.1f'), ' mm^3'], 'Units', 'normalized', ...
        'Position', [0.05, 0.65, 0.9, 0.1], 'Value', 1, ...
        'Callback', @(src, event) togglePatch(src, hPatchAblation));
    uicontrol('Parent', hPanel, 'Style', 'checkbox', 'String', ...
        ['Post: ', num2str(volPost, '%.1f'), ' mm^3'], 'Units', 'normalized', ...
        'Position', [0.05, 0.50, 0.9, 0.1], 'Value', 1, ...
        'Callback', @(src, event) togglePatch(src, hPatchPost));
    uicontrol('Parent', hPanel, 'Style', 'checkbox', 'String', ...
        ['Pre: ', num2str(volPre, '%.1f'), ' mm^3'], 'Units', 'normalized', ...
        'Position', [0.05, 0.35, 0.9, 0.1], 'Value', 1, ...
        'Callback', @(src, event) togglePatch(src, hPatchPre));
    
    xMin = min(X(:)); xMax = max(X(:));
    yMin = min(Y(:)); yMax = max(Y(:));
    uicontrol('Parent', hPanel, 'Style', 'slider', 'Min', xMin, 'Max', xMax, 'Value', xMax, ...
        'Units', 'normalized', 'Position', [0.05, 0.20, 0.9, 0.05], ...
        'Callback', @(src, event) updatePatchAlphas(src, []));
    uicontrol('Parent', hPanel, 'Style', 'text', 'String', 'X Clip', 'Units', 'normalized', ...
        'Position', [0.05, 0.26, 0.9, 0.03], 'HorizontalAlignment', 'center');
    uicontrol('Parent', hPanel, 'Style', 'slider', 'Min', yMin, 'Max', yMax, 'Value', yMin, ...
        'Units', 'normalized', 'Position', [0.05, 0.10, 0.9, 0.05], ...
        'Callback', @(src, event) updatePatchAlphas([], src));
    uicontrol('Parent', hPanel, 'Style', 'text', 'String', 'Y Clip', 'Units', 'normalized', ...
        'Position', [0.05, 0.16, 0.9, 0.03], 'HorizontalAlignment', 'center');
    
    clipX = xMax;  
    clipY = yMin;  
    
    % Update alpha values for clipping.
    function updatePatchAlphas(srcX, srcY)
        if ~isempty(srcX)
            clipX = get(srcX, 'Value');
        end
        if ~isempty(srcY)
            clipY = get(srcY, 'Value');
        end
        function updateAlphaForPatch(patchHandle)
            verts = get(patchHandle, 'Vertices');
            alphaVals = ones(size(verts,1),1);
            alphaVals(verts(:,1) > clipX) = 0;
            alphaVals(verts(:,2)) = alphaVals(verts(:,2)) .* (verts(:,2) >= clipY);
            set(patchHandle, 'FaceVertexAlphaData', alphaVals);
        end
        updateAlphaForPatch(hPatchPre);
        updateAlphaForPatch(hPatchPost);
        updateAlphaForPatch(hPatchSwelling);
        updateAlphaForPatch(hPatchAblation);
    end

    function togglePatch(src, patchHandle)
        if get(src, 'Value') == 1
            set(patchHandle, 'Visible', 'on');
        else
            set(patchHandle, 'Visible', 'off');
        end
    end
end

function refPoint = pickSingleReferencePoint(TR)
    % pickSingleReferencePoint allows the user to pick a reference point
    % from the provided triangulation object.
    
    figure('Name', 'Select Reference Point');
    trisurf(TR.ConnectivityList, TR.Points(:,1), TR.Points(:,2), TR.Points(:,3), 'EdgeColor', 'none');
    axis equal; camlight; lighting gouraud; grid on;
    title('Select Reference Point');
    dcm = datacursormode(gcf);
    set(dcm, 'DisplayStyle', 'datatip', 'SnapToDataVertex', 'off', 'Enable', 'on');
    disp('Click a reference point and press ENTER.');
    pause;
    info = getCursorInfo(dcm);
    refPoint = info.Position;
    close(gcf);
end

function TR_out = clipAndCapMesh(TR_in, Zcut)
    % clipAndCapMesh clips the input mesh above a Zcut and caps the open surface.
    
    pts = TR_in.Points;
    faces = TR_in.ConnectivityList;
    
    % Determine the Z values for each triangle.
    zValues = reshape(pts(faces(:), 3), size(faces));
    
    % Keep only triangles completely above the cut.
    keepFaces = all(zValues > Zcut, 2);
    facesClipped = faces(keepFaces, :);
    
    % Remap points to only include those used.
    usedIdx = unique(facesClipped(:));
    ptsUsed = pts(usedIdx, :);
    [~, idxMap] = ismember(facesClipped, usedIdx);
    facesRemapped = idxMap;
    
    TR_clipped = triangulation(facesRemapped, ptsUsed);
    
    % Find the free boundary (edges that form the open boundary).
    boundaryEdges = freeBoundary(TR_clipped);
    boundaryLoop = unique(boundaryEdges(:));
    
    % Get the 3D coordinates of the boundary.
    capPts3D = ptsUsed(boundaryLoop, :);
    capPts2D = capPts3D(:, 1:2);
    DT = delaunayTriangulation(capPts2D);
    capFaces2D = DT.ConnectivityList;
    
    % Create cap points at the Zcut.
    capPts3D(:, 3) = Zcut;
    capFaces3D = capFaces2D + size(ptsUsed, 1);
    
    % Concatenate the original and cap points and faces.
    pts_out = [ptsUsed; capPts3D];
    faces_out = [facesRemapped; capFaces3D];
    TR_out = triangulation(faces_out, pts_out);
end