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
  end

  % things we don't want to accidently change but that still might be interesting
  properties (SetAccess = private,Transient = true)
    Serial; % serial port object, created in Connect, used by Dev
    % Zaber motion libary uses both device and axis objects for control
    Dev;
    Axis;
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
    function Obj = ZaberStage(doConnect)
      % check for installer zaber toolbox
      instAddOn = matlab.addons.installedAddons;
      toolboxInstalled = any(strcmp(instAddOn.Name,"Zaber Motion Library"));
      if ~toolboxInstalled
        web('https://www.zaber.com/software/docs/motion-library/ascii/tutorials/introduction/'); 
        error('Zaber Motion Library not found, please download!');
      end


      if nargin < 1
        doConnect = Obj.DO_AUTO_CONNECT;
      end

      if nargin == 1 && ischar(doConnect)
        Obj.SERIAL_PORT = doConnect;
        doConnect = true;
      end

      if doConnect && ~Obj.isConnected
        Obj.Connect;
        Obj.vel = Obj.DEFAULT_VEL;
      elseif ~Obj.isConnected
        Obj.VPrintF_With_ID('Initialized but not connected yet.\n');
      end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function delete(Obj)
      if ~isempty(Obj.Serial)
        Obj.Force_Off(); % make sure no constant force is applied to stage
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
    function [mm] = Steps_To_MM(Obj,steps)
      mm = steps.*Obj.STEP_SIZE;
    end

    function [steps] = MM_To_Steps(Obj,mm)
      steps = round(mm./Obj.STEP_SIZE); % max rounding error is 200 nm...
    end

    function [] = Wait_Ready(Obj)
      reply = Obj.Dev.waitforidle(Obj.POLLING_INTERVAL*1e-3);
      if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
        short_warn(reply.DataString);
      end
    end

    function [] = Stop(Obj)
      reply = Obj.Dev.stop();
      if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
        short_warn(reply.DataString);
      end
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
    function [isConnected] = get.isConnected(Obj)
      isConnected = ~isempty(Obj.Serial);
    end

  end % <<<<<<<< END SET?GET METHODS

end % <<<<<<<< END BASE CLASS
