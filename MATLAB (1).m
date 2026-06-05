classdef Robot3R_App < matlab.apps.AppBase

    properties (Access = public)

        UIFigure matlab.ui.Figure
        StartButton matlab.ui.control.Button
        GripperField matlab.ui.control.NumericEditField
        GripperLabel matlab.ui.control.Label

    end

    properties (Access = private)

        robot
        arduino

        % Link lengths
        a1 = 115
        a2 = 110
        a3 = 120

        currentGrip = 20;

    end

    methods (Access = private)

        %% ================= STARTUP =================
        function startupFcn(app)

            L1 = Link([0 app.a1 0 deg2rad(270)]);
            L2 = Link([0 0 app.a2 deg2rad(180)]);
            L3 = Link([0 0 app.a3 0]);

            L1.offset = 0;
            L2.offset = deg2rad(270);
            L3.offset = deg2rad(270);

            app.robot = SerialLink([L1 L2 L3], ...
                'name','Robokit');

            figure;
            app.robot.plot([0 0 0],...
                'workspace',[-250 250 -250 250 -10 350]);

            try

                app.arduino = serialport("COM9",115200);

                configureTerminator(...
                    app.arduino,...
                    "LF");

                pause(2);

                disp("Arduino connected");

            catch

                app.arduino = [];

                disp("Simulation only");

            end

        end

        %% ================= SEND =================
        function sendToArduino(app,q,gripper)

            s1 = min(max(...
                round(rad2deg(q(1))),...
                0),180);

            s2 = min(max(...
                round(rad2deg(q(2))),...
                0),180);

            s3 = min(max(...
                round(rad2deg(q(3))),...
                0),180);

            cmd = sprintf(...
                "SERVO %d %d %d %d",...
                s1,s2,s3,gripper);

            if ~isempty(app.arduino)

                writeline(app.arduino,cmd);

            end

            disp(cmd)

        end

        %% ================= MOVE =================
        %% ================= ARM MOTION =================
        function moveRobot(app,qTarget)

    % Current robot position
    qStart = app.robot.getpos();

    % Smooth simulation trajectory
    steps = 10;

    traj = jtraj(qStart,qTarget,steps);

    % ===== SIMULATION ONLY =====
    for i = 1:steps

        qNow = traj(i,:);

        app.robot.animate(qNow);

        pause(0.03)

    end

    % ===== SEND ONLY FINAL TARGET =====
    sendToArduino(...
        app,...
        qTarget,...
        app.currentGrip);

end


%% ================= OPEN GRIPPER =================
function openGripper(app)

    app.currentGrip = 40;

    q = app.robot.getpos();

    sendToArduino(...
        app,...
        q,...
        app.currentGrip);

    pause(1)

end


%% ================= CLOSE GRIPPER =================
function closeGripper(app)

    app.currentGrip = 0;

    q = app.robot.getpos();

    sendToArduino(...
        app,...
        q,...
        app.currentGrip);

    pause(1)

end

       %% ================= PICK PLACE =================
function StartButtonPushed(app,~)

    %% HOME
    q0 = deg2rad([0 0 0]);

    %% PICK POSITION
    q1 = deg2rad([45 0 0]);

    %% PICK DOWN
    q2 = deg2rad([45 75 38]);

    %% ABOVE DROP
    q3 = deg2rad([80 0 0]);

    %% DROP DOWN
    q4 = deg2rad([80 75 38]);

    %% RETURN HOME
    q5 = deg2rad([0 0 0]);

    disp("START PICK PLACE")

    % Repeat exactly 2 times
    for cycle = 1:2

        fprintf('\n========== CYCLE %d OF 2 ==========\n',cycle);

        %% HOME
        moveRobot(app,q0);
        openGripper(app);

        %% MOVE TO PICK POSITION
        moveRobot(app,q1);
        moveRobot(app,q2);

        %% PICK OBJECT
        closeGripper(app);

        %% LIFT OBJECT
        moveRobot(app,q1);

        %% MOVE TO DROP AREA
        moveRobot(app,q3);
        moveRobot(app,q4);

        %% RELEASE OBJECT
        openGripper(app);

        %% LIFT FROM DROP AREA
        moveRobot(app,q3);

        %% RETURN HOME
        moveRobot(app,q5);

        %% RESET GRIPPER
        closeGripper(app);

        pause(1);

    end

    disp("DONE")

end

        %% ================= UI =================
        function createComponents(app)

            app.UIFigure = uifigure(...
                'Position',...
                [100 100 300 220],...
                'Name',...
                'Pick and Place');

            app.StartButton = uibutton(...
                app.UIFigure,...
                'push');

            app.StartButton.Text = ...
                'START PICK & PLACE';

            app.StartButton.Position = ...
                [50 120 200 50];

            app.StartButton.ButtonPushedFcn = ...
                @(s,e)StartButtonPushed(app);

            app.GripperLabel = ...
                uilabel(...
                app.UIFigure,...
                'Text',...
                'Gripper');

            app.GripperLabel.Position = ...
                [70 60 60 20];

            app.GripperField = ...
                uieditfield(...
                app.UIFigure,...
                'numeric');

            app.GripperField.Position = ...
                [140 60 80 25];

            app.GripperField.Value = 20;

        end

    end

    methods (Access = public)

        function app = Robot3R_App

            createComponents(app)

            startupFcn(app)

        end

    end

end