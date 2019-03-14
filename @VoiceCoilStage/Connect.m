% function [] = Connect(VCS)
% does something coole...
% Johannes Rebling, (johannesrebling@gmail.com), 2019

function [] = Connect(VCS)
  if ~isempty(VCS.Serial) && strcmp(VCS.Serial.Status,'open')
    VCS.VPrintF('[VCS] Stage already connected!\n');
  else
    tic;
    VCS.VPrintF('[VCS] Connecting to stage...');

    Serial = serial(VCS.SERIAL_PORT);
    Serial.BaudRate = VCS.BAUD_RATE;
    Serial.DataBits = VCS.DATA_BITS;
    Serial.FlowControl = VCS.FLOW_CONTROL;
    Serial.Parity = VCS.PARITY;
    Serial.StopBits = VCS.STOP_BITS;
    Serial.Terminator = VCS.TERMINATOR;

    % There are cases where the Zaber toolbox deliberately waits for
    % Serial reception to time out. To reduce the wait time and suppress
    % timeout messages, use the following two commands.
    Serial.Timeout = 0.5;
    warning off MATLAB:serial:fgetl:unsuccessfulRead

    VCS.Serial = Serial;
    fopen(VCS.Serial);
    VCS.Done();

    % Init device, using ASCII Protocol
    tic;
    VCS.VPrintF('[VCS] Initialize device & protocol...');
    Protocol = Zaber.AsciiProtocol(Serial);
    VCS.Dev = Zaber.AsciiDevice.initialize(Protocol, VCS.DEVICE_ADDRESS);
    VCS.Done();

    VCS.VPrintF('[VCS] Found stage %s (firmware version %2.3f)\n', ...
      VCS.Dev.Name, VCS.Dev.FirmwareVersion);
  end
end
