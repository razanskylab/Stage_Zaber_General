% open Serial communcation to Zaber stages, this is shared between stages

function [] = Connect_Serial(Obj)
  import zaber.motion.Library; % creates Library class
  import zaber.motion.ascii.Connection; % creates Connection class.
  Library.enableDeviceDbStore();

  if ~isempty(Obj.Serial)
    Obj.VPrintF_With_ID('Stage already connected!\n');
  else
    tic;
    Obj.VPrintF_With_ID('Establishing serial connection...');
    % use zaber interface to ope Serial interface
    try
      Obj.Serial = Connection.openSerialPort(Obj.serialPort);
      Obj.Done();

      % find device list, we reuse this just as we reuse the serial port
      tic;
      Obj.VPrintF_With_ID('Finding devices...');
      Obj.DeviceList = Obj.Serial.detectDevices();
      Obj.VPrintF('found %d...', Obj.DeviceList.length);
      Obj.Done();
    catch 
      fprintf('\n');
      short_warn('Serial port blocked, wrong or not existing?');
      error('Opening Zaber serial connection failed!');
    end
  end
end
