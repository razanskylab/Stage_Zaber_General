% function [] = Connect(Obj)
% does something coole...
% Johannes Rebling, (johannesrebling@gmail.com), 2019

function [] = Connect(Obj)
  if ~isempty(Obj.Serial) && strcmp(Obj.Serial.Status,'open')
    Obj.VPrintF_With_ID('Stage already connected!\n');
  else
    tic;
    Obj.VPrintF_With_ID('Connecting to stage...');

    Serial = serial(Obj.serialPort);
    Serial.BaudRate = Obj.BAUD_RATE;
    Serial.DataBits = Obj.DATA_BITS;
    Serial.FlowControl = Obj.FLOW_CONTROL;
    Serial.Parity = Obj.PARITY;
    Serial.StopBits = Obj.STOP_BITS;
    Serial.Terminator = Obj.TERMINATOR;

    % There are cases where the Zaber toolbox deliberately waits for
    % Serial reception to time out. To reduce the wait time and suppress
    % timeout messages, use the following two commands.
    Serial.Timeout = 0.5;
    warning off MATLAB:serial:fgetl:unsuccessfulRead

    Obj.Serial = Serial;
    fopen(Obj.Serial);
    Obj.Done();

    % Init device, using ASCII Protocol
    tic;
    Obj.VPrintF_With_ID('Initialize device & protocol...');
    Protocol = Zaber.AsciiProtocol(Serial);
    Obj.Dev = Zaber.AsciiDevice.initialize(Protocol, Obj.axisId);
    Obj.Done();

    Obj.VPrintF_With_ID('Found %s (firmware version %2.3f)\n', ...
      Obj.Dev.Name, Obj.Dev.FirmwareVersion);
  end
end
