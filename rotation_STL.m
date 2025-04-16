%% rotation_STL.m
% This script rotates an STL mesh in two stages and translates it to sit on the XY plane.
%
% Built by: Tomić Nicolas
% Date: 31-01-2025
%
% Stage 1: Align a plane (defined by 3 user-selected points) with the XY plane.
%          (That is, rotate so that the plane’s normal becomes [0 0 1].)
%
% Stage 2: Translate the geometry so that the lowest Z-coordinate is exactly at Z = 0.
%
% Stage 3: Rotate about the normal (now [0 0 1]) so that the vector defined by
%          the two last points (D and E) is aligned with the –x axis.
%
% The overall rotation and translation process ensures the mesh is properly positioned.
%
% Requirements: stlread (returns a triangulation object)

clear all; close all; clc

%% 1. Load and display the STL file
[fileName, filePath] = uigetfile('*.stl', 'Select an STL file');
if isequal(fileName,0)
    disp('User canceled file selection.');
    return;
end
fullFileName = fullfile(filePath, fileName);
TR = stlread(fullFileName);  % Assumes stlread returns a triangulation object
pt = TR.Points;
T  = TR.ConnectivityList;

figure(1)
trisurf(T, pt(:,1), pt(:,2), pt(:,3), 'EdgeColor', 'none');
axis equal; camlight; lighting gouraud;
xlabel('X'); ylabel('Y'); zlabel('Z');
title('Original Mesh');
drawnow;

%% 2. User selects 5 points: 3 for the plane and 2 for the vector.
disp('Select 5 points on the mesh using mouse clicks:');
disp('  - The first 3 points define the plane to be aligned with the XY plane.');
disp('  - The next 2 points define a vector (DE) to be aligned with the -x axis.');
disp('After clicking each point, press ENTER in the Command Window to record it.');

% Enable data cursor mode
dcm_obj = datacursormode(gcf);
set(dcm_obj, 'DisplayStyle', 'datatip', 'SnapToDataVertex', 'off', 'Enable', 'on');

selected_points = [];
i = 0;
while i < 5
    pause;  % Wait for a mouse click and subsequent key press
    c_info = getCursorInfo(dcm_obj);
    if isempty(c_info)
        break
    end
    point = c_info(end).Position;  % Use the last clicked point
    selected_points = [selected_points; point];
    i = i + 1;
    disp(['Point ', num2str(i), ': ', mat2str(point, 4)]);
    datacursormode off; datacursormode on; % Reset for next point
end

if size(selected_points,1) < 5
    error('You must select exactly 5 points: 3 for plane alignment and 2 for vector alignment.');
end

disp('Selected points:');
disp(selected_points);

% For plane alignment, let:
A = selected_points(1,:);
B = selected_points(2,:);
C = selected_points(3,:);
% For vector alignment, let:
D = selected_points(4,:);
E = selected_points(5,:);

%% 3. Stage 1: Compute the rotation needed to align the plane with the XY plane.
% Compute the normal (Vn) of the plane defined by A, B, and C.
Vn = cross(B - A, C - A);
Vn = Vn / norm(Vn);  % Normalize the plane normal

% Express the normal in spherical coordinates:
phi   = atan2(Vn(2), Vn(1));  % Angle in the XY plane
theta = acos(Vn(3));          % Angle from the Z-axis

% To bring Vn to [0 0 1]:
% First, rotate about Z by -phi
Rz_neg_phi = [ cos(-phi)  -sin(-phi)  0;
               sin(-phi)   cos(-phi)  0;
               0           0          1 ];
% Second, rotate about Y by -theta
Ry_neg_theta = [ cos(-theta)   0   sin(-theta);
                 0             1   0;
                -sin(-theta)   0   cos(-theta) ];

% The alignment rotation:
R_align = Ry_neg_theta * Rz_neg_phi;

% Apply R_align to the entire mesh:
rotated_pts_stage1 = (R_align * pt')';

% Compute translation to place the geometry on Z = 0:
z_min = min(rotated_pts_stage1(:,3));
T_translate = [0 0 -z_min];
rotated_pts_stage1 = rotated_pts_stage1 + T_translate;

figure(2)
trisurf(T, rotated_pts_stage1(:,1), rotated_pts_stage1(:,2), rotated_pts_stage1(:,3), 'EdgeColor','none');
axis equal; camlight; lighting gouraud;
xlabel('X'); ylabel('Y'); zlabel('Z');
title('Mesh after Stage 1 (Plane Alignment & Translation)');
drawnow;

%% 4. Stage 2: Rotate about the normal (Z-axis) to align vector DE with the -x axis.
% Compute the vector from D to E:
v = D - E;
% Apply the alignment rotation and translation to v:
v_rot = (R_align * v')';
% Compute the angle of the rotated vector in the XY plane.
theta_v = atan2(v_rot(2), v_rot(1));
% The -x axis corresponds to an angle of pi. Thus, the required rotation is:
gamma = pi - theta_v;

% Build the rotation matrix about Z (the normal after alignment):
Rz_gamma = [ cos(gamma) -sin(gamma) 0;
             sin(gamma)  cos(gamma) 0;
             0           0          1 ];

% Compose the overall transformation:
R_total = Rz_gamma * R_align;

% Apply the final rotation:
rotated_pts = (R_total * pt')' + T_translate;

figure(3)
trisurf(T, rotated_pts(:,1), rotated_pts(:,2), rotated_pts(:,3), 'EdgeColor','none');
axis equal; camlight; lighting gouraud;
xlabel('X'); ylabel('Y'); zlabel('Z');
title('Final Rotated Mesh');
view(-90,0);
drawnow;

%% 5. Save the final rotated mesh to an STL file.
[folder, name, ext] = fileparts(fullFileName);
outFile = fullfile(folder, [name, '_rotated.stl']);
TR2 = triangulation(T, rotated_pts);
stlwrite(TR2, outFile);
disp(['Rotated STL saved as "', outFile, '"']);
