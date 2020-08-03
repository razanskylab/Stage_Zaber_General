% function [] = Connect(Obj)
% does something coole...
% Johannes Rebling, (johannesrebling@gmail.com), 2019

function [] = Connect(Obj)
  import zaber.motion.Library; % creates Library class
  import zaber.motion.ascii.Connection; % creates Connection class.
  Library.enableDeviceDbStore();

  if ~isempty(Obj.Serial) && strcmp(Obj.Serial.Status,'open')
    Obj.VPrintF_With_ID('Stage already connected!\n');
  else
    tic;
    Obj.VPrintF_With_ID('Establishing serial connection...');
    % use zaber interface to ope Serial interface
    try
        Obj.Serial = Connection.openSerialPort(Obj.serialPort);
        Obj.Done();
    catch 
        fprintf('\n');
        short_warn('Serial port blocked, wrong or not existing?');
        error('Opening Zaber serial connection failed!');
    end
    tic;
    Obj.VPrintF_With_ID('Finding devices...');
    deviceList = Obj.Serial.detectDevices();
    Obj.VPrintF('found %d...', deviceList.length);
    Obj.Done();
      
    tic;
    Obj.VPrintF_With_ID('Connecting to device %i - ',Obj.address);
    Obj.Dev = deviceList(Obj.address);
    Obj.Axis = Obj.Dev.getAxis(Obj.axisId);

    Obj.VPrintF('%s done!\n', ...
      Obj.Dev.getName());
  end
end
