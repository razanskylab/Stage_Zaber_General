% This example shows how to determine if a Zaber device has I/O ports, and
% make use of them if so.

% You may need to edit the values below to make this example work for your
% particular setup.

portName = 'COM8'; % Name of the serial port to use.
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
    device = Zaber.Device.initialize(protocol, deviceAddress);
    fprintf('Device %d is a %s with firmware version %f\n', ...
        deviceAddress, device.Name, device.FirmwareVersion);

    % Report on the I/O ports available on this device.
    if (isempty(device.IO))
        fprintf('This device has no I/O ports.\n');
    else
        io = device.IO;
        fprintf('This device has:\n');
        fprintf('- %d analog inputs\n', io.AnalogInputCount);
        fprintf('- %d analog outputs\n', io.AnalogOutputCount);
        fprintf('- %d digital input bits\n', io.DigitalInputCount);
        fprintf('- %d digital output bits\n', io.DigitalOutputCount);

        if ((io.AnalogInputCount > 0) || (io.DigitalInputCount > 0))
            fprintf('\nDisplaying input values for a few seconds:\n');
            pause(3.0);

            for (i = 1:100)

                if (io.DigitalInputCount > 0)
                    fprintf('Digital: %s ', mat2str(io.readdigitalinput()));
                end

                if (io.AnalogInputCount > 0)
                    ai = zeros(1,io.AnalogInputCount);
                    for (j = 1:io.AnalogInputCount)
                        ai(j) = io.readanaloginput(j);
                    end

                    fprintf('Analog: %s', mat2str(ai));
                end

                fprintf('\n');
            end

            fprintf('\nFinished.\n');

        else
            fprintf('\nThere are no inputs to display, so exiting.\n');
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
