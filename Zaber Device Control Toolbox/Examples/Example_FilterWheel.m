% This example shows how to use the Zaber Filter Wheel device,
% or other Zaber devices that have indexed positions.

% You may need to edit the values below to make this example work for your
% particular setup. 

portName = 'COM1'; % Name of the serial port to use.
baudRate = 115200; % Baud rate the Zaber device is configured to use.
deviceAddress = 1; % Address the Zaber device is configured to use.

% Note for simplicity this example does no error checking.


% Initialize port.
port = serial(portName);

% Set default serial port properties for the ASCII protocol.
set(port, ...
    'BaudRate', baudRate, ...
    'DataBits', 8, ...
    'FlowControl', 'none', ...
    'Parity', 'none', ...
    'StopBits', 1, ...
    'Terminator','CR/LF');

% There are cases where the Zaber toolbox deliberately waits for
% port reception to time out. To reduce the wait time and suppress
% timeout messages, use the following two commands.
set(port, 'Timeout', 0.5)
warning off MATLAB:serial:fgetl:unsuccessfulRead

% Open the port.
fopen(port);

% In this example we know we're using the ASCII protocol, so just
% instantiate it directly.
protocol = Zaber.AsciiProtocol(port);

try
    % This example assumes we have a device in ASCII mode.
    % Create a representation of it and query the device for its
    % properties.
    device = Zaber.AsciiDevice.initialize(protocol, deviceAddress);
    fprintf('Device %d is a %s with firmware version %f\n', ...
        deviceAddress, device.Name, device.FirmwareVersion);
    
    % Find out how many positions the device has.
    nPos = device.getnumindices();
    choice = -1;
    if (nPos > 1)
        fprintf('This device has %d indexed positions.\n', nPos);
        choice = menu('OK to make the device move?','Yes','No');
    else
        fprintf('This device does not support index moves. Terminating.\n');
    end

    if (choice == 1)
        fprintf('Homing the device...\n');
        device.home();
        device.waitforidle();
        
        fprintf('Moving to some random indices...\n');
        for (i = 1:20)
            index = randi(nPos);
            fprintf('%d\n', index);
            device.moveindexed(index);
            device.waitforidle();
        end
    end
    
catch exception
    % Clean up the port if an error occurs, otherwise it remains locked.
    fclose(port);
    rethrow(exception);
end

fclose(port);
delete(port);
clear all;
