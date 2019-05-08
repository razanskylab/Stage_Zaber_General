% This example demonstrates the bare minimum amount of setup needed to use
% Zaber devices, assuming you are using the ASCII protocol and already
% know what address and baud rate your Zaber device is configured to use.
% This example just connects to the device and homes it. There is a place
% marked in the code below to insert your own commands.

% You may need to edit the values below to make this example work for your
% particular setup.

portName = 'COM8'; % Name of the serial port to use.
baudRate = 115200; % Baud rate the Zaber device is configured to use.
deviceAddress = 1; % Address the Zaber device is configured to use.

% Note for simplicity this example does minimal error checking.

% Initialize port.
port = serial(portName);
set(port, ...
    'BaudRate', baudRate,   'DataBits', 8, ...
    'FlowControl', 'none',  'Parity', 'none', ...
    'StopBits', 1,          'Terminator','CR/LF');

set(port, 'Timeout', 0.5)
warning off MATLAB:serial:fgetl:unsuccessfulRead

% Open the port.
fopen(port);

% In this example we know we're using the ASCII protocol, so just
% instantiate it directly.
protocol = Zaber.AsciiProtocol(port);

try
    % This example assumes we have a single-axis device in ASCII mode.
    % Create a representation of it and query the device for its
    % properties.
    device = Zaber.AsciiDevice.initialize(protocol, deviceAddress);
    fprintf('Device %d is a %s with firmware version %f\n', ...
            deviceAddress, device.Name, device.FirmwareVersion);

    choice = menu('OK to make the device move?','Yes','No');
    if (choice == 1)

        % Demonstrate the home command.
        fprintf('Homing %s...\n', device.Name);
        device.home();
        device.waitforidle();

        % Insert your commands here.
        % --------------------------

        % For example, to move five times in steps of 1 inch on a linear
        % stage:
        %inchInMeters = 0.0254;
        %inchInDeviceUnits = device.Units.positiontonative(inchInMeters);
        %for i = 1:5
        %    device.moverelative(inchInDeviceUnits);
        %    device.waitforidle();
        %end
    end

catch exception
    % Clean up the port if an error occurs, otherwise it remains locked.
    fclose(port);
    rethrow(exception);
end

fclose(port);
delete(port);
clear all;
