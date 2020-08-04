% requires opened Serial object, see 
function [] = Connect_Device(Obj)
  import zaber.motion.Library; % creates Library class
  import zaber.motion.ascii.Connection; % creates Connection class.
  import zaber.motion.ascii.Warnings;
  import zaber.motion.ascii.DeviceIdentity;

  if isempty(Obj.Serial) 
    error('Need to Connect_Serial first!');
  else
     
    tic;
    Obj.VPrintF_With_ID('Connecting to device %i - ',Obj.address);
    Obj.Dev = Obj.DeviceList(Obj.address);
    Obj.Axis = Obj.Dev.getAxis(Obj.axisId);
    Obj.Warnings = Obj.Dev.getWarnings();
    Obj.Identity = Obj.Dev.getIdentity();

    Obj.VPrintF('%s done!\n', Obj.Dev.getName());
  end
end
