% non functional example class to be used as basis for new hardware interfacing
% class, as they alls should have similar structure and content

classdef ZaberStage < BaseHardwareClass
% classdef (Abstract) ZaberStage < BaseHardwareClass

  % Transient = true -> don't store these values, as these are read from the stage...
  properties (Abstract = true)
    serialPort char;
    % zaber defines devices via an address (1-99)
    address(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite} 
    % devices can have multiple axis, default is 1 with axisId = 1
    axisId(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
  end
  
  properties (Transient = true)
    pos(1,1) {mustBeNumeric,mustBeFinite}; % [mm]
    vel(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite}; % [mm/s]
    % ! no set/get right now for acc
    acc(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite}; % [mm/s²], 
  end

  properties
    addedMass(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite} = 0.1; % [Kg]
      % see accMaxTheo
  end

  % depended properties are calculated from other properties
  properties (Dependent = true)
    isConnected;
    accMaxTheo(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm²/s] maximum theoretical acceleration for given mass
      % see BASE_MASS and addedMass constants
    temperature; % read from stage controller
    warningFlags; % read warning flags
  end

  % things we don't want to accidently change but that still might be interesting
  properties (SetAccess = private,Transient = true)
    Serial; % serial port object, created in Connect, used by Dev
    % www.zaber.com/software/docs/motion-library/ascii/references/matlab/
    DeviceList; % Array of detected devices
    Dev; % selected device, i.e. stage
    Axis; % control of single axis
    Warnings; % read & clear warnings
    Identity; % device identification
  end

  % things we don't want to accidently change but that still might be interesting
  properties (Abstract = true, Constant)
    STEP_SIZE; % [mm] one microstep = 0.2 micron
    RANGE; % [mm] min / max travel range
    MAX_SPEED; % [mm/s] max speed limit
    DEFAULT_VEL;
  end

  properties (Abstract = true, Constant, Hidden = true)
    % physical stage properties
    MAX_FORCE; % [N] absolute max is a bit higher, but this is recommended
    BASE_MASS; % [kg] mass of moving part of the stage when empty
  end

  properties (Constant, Hidden = true)
    DO_AUTO_CONNECT = true; % connect when object is initialized?
    POLLING_INTERVAL = 10;
      % ms, time to wait between polling device stage whilte waiting to finish move...
  end

  % same as constant but now showing up as property
  properties (Hidden=true)
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % constructor, desctructor, save obj
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods
    % constructor, called when class is created
    function Obj = ZaberStage(varargin)
      % check for installer zaber toolbox
      instAddOn = matlab.addons.installedAddons;
      toolboxInstalled = any(strcmp(instAddOn.Name,"Zaber Motion Library"));
      if ~toolboxInstalled
        web('https://www.zaber.com/software/docs/motion-library/ascii/tutorials/introduction/'); 
        error('Zaber Motion Library not found, please download!');
      end

      if nargin < 1
        doConnect = Obj.DO_AUTO_CONNECT;
        Obj.Serial = [];
      end

      if (nargin == 2)
        doConnect = varargin{1};
        Obj.serialPort = varargin{2};
      end

      % className = class(Obj);
      if nargin
        inputArg = varargin{1};
        hasSerial = isprop(inputArg,'Serial');
        hasDevices = isprop(inputArg,'DeviceList');
        % if isa(inputArg,className) % input is zaber stage class
        if islogical(inputArg) % input is zaber stage class
          doConnect = inputArg;
          Obj.Serial = [];
        elseif hasSerial && hasDevices
          doConnect = false; % serial connection is already open
          Obj.Serial = inputArg.Serial;
          Obj.DeviceList = inputArg.DeviceList;
        else
          short_warn('This should not happen...');
          doConnect = false;
        end 
      end

      if doConnect && ~Obj.isConnected
        Obj.Connect_Serial();
        Obj.Connect_Device();
      elseif hasSerial && hasDevices % only connect to device using existing serial port
        Obj.Connect_Device();
      elseif ~Obj.isConnected
        Obj.VPrintF_With_ID('Initialized but not connected yet.\n');
      end
      Obj.vel = Obj.DEFAULT_VEL;
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function delete(Obj)
      if ~isempty(Obj.Serial)
        % Obj.Force_Off(); % make sure no constant force is applied to stage
        % Obj.Dev.stop(); % don't use, at it applies constant force
        Obj.Close();
      end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % when saved, hand over only properties stored in saveObj
    function SaveObj = saveobj(Obj)
      SaveObj = Obj; % just copy/save all for now
     end
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods % short methods, which are not worth putting in a file
    function Home_All_Devices(Obj)
      tic;
      Obj.VPrintF('Homing all Zaber stages...');
      
      nDevices = Obj.DeviceList.length;
      for iDev = 1:nDevices
        % send home, don't wait for stages
        device = Obj.DeviceList(iDev);
        Obj.Serial.genericCommand('home', device.getDeviceAddress(), Obj.axisId);
      end
      Obj.Wait_Ready_All();
      Obj.Done();
    end

    % --------------------------------------------------------------------------
    function [mm] = Steps_To_MM(Obj,steps)
      mm = steps.*Obj.STEP_SIZE;
    end

    % --------------------------------------------------------------------------
    function [steps] = MM_To_Steps(Obj,mm)
      steps = round(mm./Obj.STEP_SIZE); % max rounding error is 200 nm...
    end

    % --------------------------------------------------------------------------
    function Set_Setting(Obj,settingString,value)
      % settingString eg. 'system.led.enable'
      Obj.Dev.getSettings().set(settingString, value);
    end

    % --------------------------------------------------------------------------
    function [value] = Get_Setting(Obj,settingString)
      % settingString eg. 'system.led.enable'
      value = Obj.Dev.getSettings().get(settingString);
    end

    % --------------------------------------------------------------------------
    function [] = Wait_Ready(Obj)
      throwErrorOnFault = true;
      Obj.Axis.waitUntilIdle(throwErrorOnFault);
    end

    % --------------------------------------------------------------------------
    function [] = Wait_Ready_All(Obj)
      % wait for all stages to be ready
      nDevices = Obj.DeviceList.length;
      throwErrorOnFault = true;
      for iDev = 1:nDevices
        device = Obj.DeviceList(iDev);
        deviceAxis = device.getAxis(1);
        deviceAxis.waitUntilIdle(throwErrorOnFault);
      end
    end

    function [] = Stop(Obj)
      Obj.Axis.stop();
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods (Access = private)
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods % set / get methods
    function [accMaxTheo] = get.accMaxTheo(Obj)
      totalMass = Obj.BASE_MASS + Obj.addedMass; % [Kg]
      accMaxTheo = Obj.MAX_FORCE./totalMass*1e3; % [mm/s²]
    end

    % --------------------------------------------------------------------------
    function set.pos(Obj, pos)
      import zaber.motion.Units;

      if Obj.isConnected
        isValidPos = Obj.Check_Valid_Pos(pos);
        if isValidPos
          Obj.Axis.moveAbsolute(pos, Units.LENGTH_MILLIMETRES,true);
        end
      else
        short_warn('Not connected to stage!');
      end
    end

    function [pos] = get.pos(Obj)
      import zaber.motion.Units;
      if Obj.isConnected
        pos = Obj.Axis.getSettings().get('pos', Units.LENGTH_MILLIMETRES);
      else
        pos = [];
      end
    end

    % --------------------------------------------------------------------------
    function set.vel(Obj, vel)
      import zaber.motion.Units;
      if Obj.isConnected

        % sets the maximum allowed speed
        if vel > max(Obj.MAX_SPEED)
          short_warn('Requested velocity out of range!');
        else
          Obj.Axis.getSettings().set(...
            'maxspeed', vel, Units.VELOCITY_MILLIMETRES_PER_SECOND);
        end
      else
        short_warn('Not connected to stage!');
      end
    end

    function [vel] = get.vel(Obj)
      import zaber.motion.Units;
      if Obj.isConnected
        vel = Obj.Axis.getSettings().get('maxspeed', Units.VELOCITY_MILLIMETRES_PER_SECOND);
      else
        vel = [];
      end
    end

    % --------------------------------------------------------------------------
    function [temperature] = get.temperature(Obj)
      if Obj.isConnected
        temperature = Obj.Axis.getSettings().get('driver.temperature');
      else
        temperature = [];
      end
    end

    % --------------------------------------------------------------------------
    function [warningFlags] = get.warningFlags(Obj)
      if Obj.isConnected
        warningFlags = Obj.Warnings.getFlags();
      else
        warningFlags = [];
      end
    end

    % --------------------------------------------------------------------------
    function [isConnected] = get.isConnected(Obj)
      isConnected = ~isempty(Obj.Serial);
    end

  end % <<<<<<<< END SET?GET METHODS

end % <<<<<<<< END BASE CLASS

