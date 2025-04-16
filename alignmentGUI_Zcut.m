function finalTransform2 = alignmentGUI_Zcut(TR_before, TR_after, initialBeforePoints, initialAfterPoints)
% alignmentGUI_Zcut
% --------------
%
% Name: Tomić Nicolas
% Date: 2025-03-24
%
% This GUI allows manual fine-tune alignment of two meshes (PRE and POST)
% using translation and Z rotation. It also includes options to align and
% center each mesh based on a selected reference (a point under a hole).
%
% The function returns a structure finalTransform2 with three fields:
%   - transformBefore: A structure with fields Tx, Ty, Tz, and Rz (degrees)
%                      for the PRE mesh.
%   - transformAfter:  A structure with fields Tx, Ty, Tz, and Rz (degrees)
%                      for the POST mesh.
%   - Zcut:            The Z cut value (mm) specified by the user.
%
% The GUI displays the two meshes (PRE in cyan and POST in magenta) and 
% provides the following controls:
%   * Sliders for X, Y, and Z translations and Z rotation.
%   * Checkboxes for toggling the visibility of each mesh and its centerline.
%   * Buttons to "Align" each sample (which let the user pick a point via a
%     data cursor, compute a centerline, and rotate the mesh accordingly).
%   * Buttons to "Center" each sample (translating the mesh so the centerline
%     is centered in XY).
%   * View control buttons.
%
% If the user presses Accept, the final transform (and Zcut) is returned.
%
% Inputs:
%   TR_before:       Triangulation object for the PRE mesh.
%   TR_after:        Triangulation object for the POST mesh.
%   initialAfterPoints: Nx3 array with the POST mesh points.
%
% Output:
%   finalTransform2: Structure with fields transformBefore, transformAfter, and Zcut.

%% Initialize Figure and Axes
fig = figure('Name', 'Manual Fine-Tune Alignment', 'Position', [100, 100, 1000, 600]);
ax = axes('Parent', fig, 'Position', [0.05, 0.3, 0.6, 0.65]);
hold(ax, 'on'); axis equal; view(3);
xlabel(ax, 'X'); ylabel(ax, 'Y'); zlabel(ax, 'Z');
grid on;
ax.UserData = struct();  % For storing centerline handles and additional data

%% Plot Initial Meshes
beforePlot = trisurf(TR_before.ConnectivityList, TR_before.Points(:,1), TR_before.Points(:,2), TR_before.Points(:,3), ...
    'FaceColor', 'cyan', 'EdgeColor', 'none', 'FaceAlpha', 0.4);
afterPlot = trisurf(TR_after.ConnectivityList, initialAfterPoints(:,1), initialAfterPoints(:,2), initialAfterPoints(:,3), ...
    'FaceColor', 'magenta', 'EdgeColor', 'none', 'FaceAlpha', 0.4);
legend(ax, {'Pre', 'Post'}, 'Location', 'northeastoutside');

%% Internal Data Initialization
currentBeforePoints = initialBeforePoints;
currentAfterPoints  = initialAfterPoints;
transformBefore = struct('Tx', 0, 'Ty', 0, 'Tz', 0, 'Rz', 0);
transformAfter  = struct('Tx', 0, 'Ty', 0, 'Tz', 0, 'Rz', 0);
currentSelection = 1;  % 1 = POST (default), 2 = PRE

%% Create UI Controls
% -- Mesh Selection Popup --
uicontrol('Style', 'text', 'String', 'Move:', 'Position', [720,550,50,20]);
popupMeshSelect = uicontrol('Style', 'popupmenu', 'String', {'Post','Pre'}, ...
    'Position', [770,550,80,20], 'Callback', @onMeshSwitch);

% -- Translation Sliders --
uicontrol('Style', 'text', 'String', 'X Translation (mm)', 'Position', [720,500,120,20]);
sldTx = uicontrol('Style', 'slider', 'Min', -10, 'Max', 10, 'Value', 0, ...
    'Position', [720,480,120,20], 'Callback', @updateTransform);
uicontrol('Style', 'text', 'String', 'Y Translation (mm)', 'Position', [720,450,120,20]);
sldTy = uicontrol('Style', 'slider', 'Min', -10, 'Max', 10, 'Value', 0, ...
    'Position', [720,430,120,20], 'Callback', @updateTransform);
uicontrol('Style', 'text', 'String', 'Z Translation (mm)', 'Position', [720,400,120,20]);
sldTz = uicontrol('Style', 'slider', 'Min', -10, 'Max', 10, 'Value', 0, ...
    'Position', [720,380,120,20], 'Callback', @updateTransform);

% -- Rotation Slider --
uicontrol('Style', 'text', 'String', 'Z Rotation (deg)', 'Position', [720,350,120,20]);
sldRz = uicontrol('Style', 'slider', 'Min', -180, 'Max', 180, 'Value', 0, ...
    'Position', [720,330,120,20], 'Callback', @updateTransform);

% -- Visibility Checkboxes for Meshes --
chkBefore = uicontrol('Style', 'checkbox', 'String', 'Show Pre', 'Value', 1, ...
    'Position', [720,300,120,20], 'Callback', @toggleVisibility);
chkAfter  = uicontrol('Style', 'checkbox', 'String', 'Show Post', 'Value', 1, ...
    'Position', [720,280,120,20], 'Callback', @toggleVisibility);

% -- Visibility Checkboxes for Centerlines --
chkLinePre  = uicontrol('Style', 'checkbox', 'String', 'Pre centerline', 'Value', 1, ...
    'Position', [860,300,120,20], 'Callback', @toggleLineVisibility);
chkLinePost = uicontrol('Style', 'checkbox', 'String', 'Post centerline', 'Value', 1, ...
    'Position', [860,280,120,20], 'Callback', @toggleLineVisibility);

% -- Z Cut Input --
uicontrol('Style', 'text', 'String', 'Z Cut (mm)', 'Position', [720,250,80,20]);
editZcut = uicontrol('Style', 'edit', 'String', '0', 'Position', [800,250,50,20]);

% -- View Control Buttons --
uicontrol('Style', 'text', 'String', 'Change View:', 'Position', [720,220,120,20]);
uicontrol('Style', 'pushbutton', 'String', 'X+', 'Position', [720,200,40,20], ...
    'Callback', @(src,event) changeView(1));
uicontrol('Style', 'pushbutton', 'String', 'X-', 'Position', [760,200,40,20], ...
    'Callback', @(src,event) changeView(2));
uicontrol('Style', 'pushbutton', 'String', 'Y+', 'Position', [720,180,40,20], ...
    'Callback', @(src,event) changeView(3));
uicontrol('Style', 'pushbutton', 'String', 'Y-', 'Position', [760,180,40,20], ...
    'Callback', @(src,event) changeView(4));
uicontrol('Style', 'pushbutton', 'String', 'Z+', 'Position', [720,160,40,20], ...
    'Callback', @(src,event) changeView(5));
uicontrol('Style', 'pushbutton', 'String', 'Z-', 'Position', [760,160,40,20], ...
    'Callback', @(src,event) changeView(6));


% -- Align and Center Buttons --
uicontrol('Style', 'pushbutton', 'String', 'Align Pre Sample', 'Position', [820,180,120,30], 'Callback', @(src,event) alignSample(2));
uicontrol('Style', 'pushbutton', 'String', 'Align Post Sample', 'Position', [820,140,120,30], 'Callback', @(src,event) alignSample(1));
uicontrol('Style', 'pushbutton', 'String', 'Center Pre', 'Position', [820,100,120,30], 'Callback', @(src,event) centerSample(2));
uicontrol('Style', 'pushbutton', 'String', 'Center Post', 'Position', [820,60,120,30], 'Callback', @(src,event) centerSample(1));

% -- Standard Buttons --
uicontrol('Style', 'pushbutton', 'String', 'Accept', 'Position', [720,120,80,30], 'Callback', @(src,event) acceptAlignment());
uicontrol('Style', 'pushbutton', 'String', 'Reset', 'Position', [720,80,80,30], 'Callback', @(src,event) resetTransform());
uicontrol('Style', 'pushbutton', 'String', 'Cancel', 'Position', [720,40,80,30], 'Callback', @(src,event) cancelAlignment());

% -- Instruction Text --
instrText = sprintf(['Steps:\n',...
    '1. Align Pre and Post samples using the Align buttons.\n',...
    '2. Center Pre and Post samples using the Center buttons.\n',...
    '3. Adjust as desired using the sliders.\n',...
    '4. Specify the Z cut.\n',...
    '5. Press Accept.']);
uicontrol('Style', 'text', 'String', instrText, 'FontSize', 10, 'HorizontalAlignment', 'left', ...
    'Position', [20,20,680,100]);

% Set initial visibility.
toggleVisibility();

% Wait for user interaction.
uiwait(fig);
if ~isvalid(fig)
    finalTransform2 = struct('transformBefore', [], 'transformAfter', [], 'Zcut', 0);
    return;
end
finalTransform2.transformBefore = transformBefore;
finalTransform2.transformAfter = transformAfter;
finalTransform2.Zcut = str2double(editZcut.String);
finalTransform2.prePoints = currentBeforePoints;   % Updated PRE mesh points from GUI
finalTransform2.postPoints = currentAfterPoints;     % Updated POST mesh points from GUI
close(fig);

%% Nested Callback Functions

    function updateTransform(~, ~)
        % Update the transformation for the currently selected mesh.
        Tx = sldTx.Value; Ty = sldTy.Value; Tz = sldTz.Value;
        Rz = deg2rad(sldRz.Value);
        RzMat = [cos(Rz), -sin(Rz), 0; sin(Rz), cos(Rz), 0; 0,0,1];
        switch currentSelection
            case 1  % POST mesh
                transformAfter = struct('Tx', Tx, 'Ty', Ty, 'Tz', Tz, 'Rz', rad2deg(Rz));
                currentAfterPoints = (RzMat * initialAfterPoints')' + [Tx, Ty, Tz];
                afterPlot.Vertices = currentAfterPoints;
                if isfield(ax.UserData, 'linePostData')
                    base = ax.UserData.linePostData.base;
                    newLine = (RzMat * base')' + [Tx, Ty, Tz];
                    set(ax.UserData.linePost, 'XData', newLine(:,1), 'YData', newLine(:,2), 'ZData', newLine(:,3));
                end
            case 2  % PRE mesh
                transformBefore = struct('Tx', Tx, 'Ty', Ty, 'Tz', Tz, 'Rz', rad2deg(Rz));
                currentBeforePoints = (RzMat * initialBeforePoints')' + [Tx, Ty, Tz];
                beforePlot.Vertices = currentBeforePoints;
                if isfield(ax.UserData, 'linePreData')
                    base = ax.UserData.linePreData.base;
                    newLine = (RzMat * base')' + [Tx, Ty, Tz];
                    set(ax.UserData.linePre, 'XData', newLine(:,1), 'YData', newLine(:,2), 'ZData', newLine(:,3));
                end
        end
        drawnow;
    end

    function onMeshSwitch(~, ~)
        % When switching the selection, store current slider values and update
        % the sliders to match the newly selected mesh's transform.
        if currentSelection == 1
            transformAfter.Tx = sldTx.Value;
            transformAfter.Ty = sldTy.Value;
            transformAfter.Tz = sldTz.Value;
            transformAfter.Rz = sldRz.Value;
        else
            transformBefore.Tx = sldTx.Value;
            transformBefore.Ty = sldTy.Value;
            transformBefore.Tz = sldTz.Value;
            transformBefore.Rz = sldRz.Value;
        end
        currentSelection = popupMeshSelect.Value;  % 1 for POST, 2 for PRE
        if currentSelection == 1
            sldTx.Value = transformAfter.Tx;
            sldTy.Value = transformAfter.Ty;
            sldTz.Value = transformAfter.Tz;
            sldRz.Value = transformAfter.Rz;
        else
            sldTx.Value = transformBefore.Tx;
            sldTy.Value = transformBefore.Ty;
            sldTz.Value = transformBefore.Tz;
            sldRz.Value = transformBefore.Rz;
        end
    end

    function toggleVisibility(~, ~)
        % Toggle mesh visibility.
        if chkBefore.Value, beforePlot.Visible = 'on'; else, beforePlot.Visible = 'off'; end
        if chkAfter.Value, afterPlot.Visible = 'on'; else, afterPlot.Visible = 'off'; end
        drawnow;
    end

    function toggleLineVisibility(~, ~)
        % Toggle centerline visibility.
        if isfield(ax.UserData, 'linePre') && isvalid(ax.UserData.linePre)
            if chkLinePre.Value, ax.UserData.linePre.Visible = 'on'; else, ax.UserData.linePre.Visible = 'off'; end
        end
        if isfield(ax.UserData, 'linePost') && isvalid(ax.UserData.linePost)
            if chkLinePost.Value, ax.UserData.linePost.Visible = 'on'; else, ax.UserData.linePost.Visible = 'off'; end
        end
        drawnow;
    end

    function resetTransform(~, ~)
        % Reset sliders to zero.
        sldTx.Value = 0; sldTy.Value = 0; sldTz.Value = 0; sldRz.Value = 0;
        updateTransform();
    end

    function acceptAlignment(~, ~)
        uiresume(fig);
    end

    function cancelAlignment(~, ~)
        finalTransform2 = struct('transformBefore', [], 'transformAfter', [], 'Zcut', 0);
        uiresume(fig);
        close(fig);
    end

    function changeView(viewIndex)
        % Change the view based on the provided viewIndex.
        switch viewIndex
            case 1, view(ax, [1, 0, 0]);    % X+
            case 2, view(ax, [-1, 0, 0]);   % X-
            case 3, view(ax, [0, 1, 0]);    % Y+
            case 4, view(ax, [0, -1, 0]);   % Y-
            case 5, view(ax, [0, 0, 1]);    % Z+
            case 6, view(ax, [0, 0, -1]);   % Z-
        end
    end

    function alignSample(sampleId)
        % Perform alignment for the selected sample (1 = POST, 2 = PRE)
        tol = 0.01;
        if sampleId == 2
            beforePlot.Visible = 'on'; chkBefore.Value = 1;
            afterPlot.Visible = 'off'; chkAfter.Value = 0;
            if isfield(ax.UserData, 'linePre') && isvalid(ax.UserData.linePre)
                delete(ax.UserData.linePre);
            end
        else
            afterPlot.Visible = 'on'; chkAfter.Value = 1;
            beforePlot.Visible = 'off'; chkBefore.Value = 0;
            if isfield(ax.UserData, 'linePost') && isvalid(ax.UserData.linePost)
                delete(ax.UserData.linePost);
            end
        end
        drawnow;
        title(ax, 'Select a point under the hole using data cursor, then press Enter');
        dcm_obj = datacursormode(fig);
        set(dcm_obj, 'Enable', 'on', 'DisplayStyle', 'datatip', 'SnapToDataVertex', 'off');
        pause;
        cursorInfo = getCursorInfo(dcm_obj);
        dcm_obj.removeAllDataCursors;
        if isempty(cursorInfo)
            title(ax, '');
            disp('No point selected.');
            return;
        end
        selectedPoint = cursorInfo(1).Position;
        set(dcm_obj, 'Enable', 'off');
        title(ax, '');
        
        selectedZ = selectedPoint(3);
        if sampleId == 2
            pts = initialBeforePoints;
        else
            pts = initialAfterPoints;
        end
        idx_sameZ = abs(pts(:,3) - selectedZ) < tol;
        pts_sameZ = pts(idx_sameZ, :);
        dXY = sqrt((pts_sameZ(:,1) - selectedPoint(1)).^2 + (pts_sameZ(:,2) - selectedPoint(2)).^2);
        [~, farIdx] = max(dXY);
        oppositePt = pts_sameZ(farIdx, :);
        
        % Draw the centerline between the selected point and its opposite.
        if sampleId == 2
            hLine = line(ax, [selectedPoint(1), oppositePt(1)], [selectedPoint(2), oppositePt(2)], ...
                [selectedPoint(3), oppositePt(3)], 'Color', 'blue', 'LineWidth', 2);
            set(hLine, 'HitTest', 'off', 'PickableParts', 'none', 'DisplayName', 'Pre centerline');
            ax.UserData.linePre = hLine;
        else
            hLine = line(ax, [selectedPoint(1), oppositePt(1)], [selectedPoint(2), oppositePt(2)], ...
                [selectedPoint(3), oppositePt(3)], 'Color', 'red', 'LineWidth', 2);
            set(hLine, 'HitTest', 'off', 'PickableParts', 'none', 'DisplayName', 'Post centerline');
            ax.UserData.linePost = hLine;
        end
        drawnow;
        
        % Compute the midpoint of the centerline and determine the rotation angle.
        centerPt = (selectedPoint + oppositePt) / 2;
        v_sel = selectedPoint - centerPt;
        theta_sel = atan2(v_sel(2), v_sel(1));
        angleDiff = pi - theta_sel;
        angleDiff_deg = mod(rad2deg(angleDiff)+180,360)-180;
        
        % Apply rotation about the midpoint.
        if sampleId == 2
            transformBefore.Rz = angleDiff_deg;
            RzRad = deg2rad(transformBefore.Rz);
            RzMat = [cos(RzRad), -sin(RzRad), 0; sin(RzRad), cos(RzRad), 0; 0,0,1];
            newPts = (RzMat * (initialBeforePoints - centerPt)')' + centerPt;
            currentBeforePoints = newPts;
            beforePlot.Vertices = currentBeforePoints;
            if currentSelection == 2, sldRz.Value = transformBefore.Rz; end
            newSelected = (RzMat * (selectedPoint - centerPt)')' + centerPt;
            newOpposite = (RzMat * (oppositePt - centerPt)')' + centerPt;
            set(ax.UserData.linePre, 'XData', [newSelected(1), newOpposite(1)], ...
                'YData', [newSelected(2), newOpposite(2)], 'ZData', [newSelected(3), newOpposite(3)]);
            ax.UserData.linePreData.base = [newSelected; newOpposite];
            initialBeforePoints = currentBeforePoints;
            transformBefore.Tx = 0; transformBefore.Ty = 0; transformBefore.Rz = 0;
            if currentSelection == 2, sldTx.Value = 0; sldTy.Value = 0; sldRz.Value = 0; end
        else
            transformAfter.Rz = angleDiff_deg;
            RzRad = deg2rad(transformAfter.Rz);
            RzMat = [cos(RzRad), -sin(RzRad), 0; sin(RzRad), cos(RzRad), 0; 0,0,1];
            newPts = (RzMat * (initialAfterPoints - centerPt)')' + centerPt;
            currentAfterPoints = newPts;
            afterPlot.Vertices = currentAfterPoints;
            if currentSelection == 1, sldRz.Value = transformAfter.Rz; end
            newSelected = (RzMat * (selectedPoint - centerPt)')' + centerPt;
            newOpposite = (RzMat * (oppositePt - centerPt)')' + centerPt;
            set(ax.UserData.linePost, 'XData', [newSelected(1), newOpposite(1)], ...
                'YData', [newSelected(2), newOpposite(2)], 'ZData', [newSelected(3), newOpposite(3)]);
            ax.UserData.linePostData.base = [newSelected; newOpposite];
            initialAfterPoints = currentAfterPoints;
            transformAfter.Tx = 0; transformAfter.Ty = 0; transformAfter.Rz = 0;
            if currentSelection == 1, sldTx.Value = 0; sldTy.Value = 0; sldRz.Value = 0; end
        end
        drawnow;
    end

    function centerSample(sampleId)
        % Centers the mesh in XY by translating so that the centerline's center
        % becomes (0,0,z). If no centerline data exists, a warning is displayed.
        if sampleId == 2
            if ~isfield(ax.UserData, 'linePreData') || isempty(ax.UserData.linePreData.base)
                warndlg('Please use "Align Pre Sample" first.','Center Pre');
                return;
            end
            base = ax.UserData.linePreData.base;
            centerLineCenter = mean(base, 1);
            T = [-centerLineCenter(1), -centerLineCenter(2), 0];
            initialBeforePoints = initialBeforePoints + repmat(T, size(initialBeforePoints,1), 1);
            currentBeforePoints = initialBeforePoints;
            beforePlot.Vertices = currentBeforePoints;
            ax.UserData.linePreData.base = ax.UserData.linePreData.base + repmat(T, size(ax.UserData.linePreData.base,1), 1);
            set(ax.UserData.linePre, 'XData', ax.UserData.linePreData.base(:,1), ...
                'YData', ax.UserData.linePreData.base(:,2), 'ZData', ax.UserData.linePreData.base(:,3));
            transformBefore.Tx = 0; transformBefore.Ty = 0; transformBefore.Rz = 0;
            if currentSelection == 2, sldTx.Value = 0; sldTy.Value = 0; sldRz.Value = 0; end
        else
            if ~isfield(ax.UserData, 'linePostData') || isempty(ax.UserData.linePostData.base)
                warndlg('Please use "Align Post Sample" first.','Center Post');
                return;
            end
            base = ax.UserData.linePostData.base;
            centerLineCenter = mean(base, 1);
            T = [-centerLineCenter(1), -centerLineCenter(2), 0];
            initialAfterPoints = initialAfterPoints + repmat(T, size(initialAfterPoints,1), 1);
            currentAfterPoints = initialAfterPoints;
            afterPlot.Vertices = currentAfterPoints;
            ax.UserData.linePostData.base = ax.UserData.linePostData.base + repmat(T, size(ax.UserData.linePostData.base,1), 1);
            set(ax.UserData.linePost, 'XData', ax.UserData.linePostData.base(:,1), ...
                'YData', ax.UserData.linePostData.base(:,2), 'ZData', ax.UserData.linePostData.base(:,3));
            transformAfter.Tx = 0; transformAfter.Ty = 0; transformAfter.Rz = 0;
            if currentSelection == 1, sldTx.Value = 0; sldTy.Value = 0; sldRz.Value = 0; end
        end
        drawnow;
    end

end
