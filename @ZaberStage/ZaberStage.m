% non functional example class to be used as basis for new hardware interfacing
% class, as they alls should have similar structure and content

classdef ZaberStage < BaseHardwareClass
% classdef (Abstract) ZaberStage < BaseHardwareClass

  % Transient = true -> don't store these values, as these are read from the stage...
  properties (Abstract = true)
    serialPort char;
    axisId(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
  end
  
  properties (Transient = true)
    pos(1,1) {mustBeNumeric,mustBeFinite}; % [mm]
    vel(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
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
    Dev; % zaber AsciiDevice, this is the zaber class used for all communication
    Serial; % serial port object, created in Connect, used by Dev
  end

  % things we don't want to accidently change but that still might be interesting
  properties (Abstract = true, Constant)
    STEP_SIZE; % [mm] one microstep = 0.2 micron
    RANGE; % [mm] min / max travel range
    MAX_SPEED; % [mm/s] max speed limit = maxspeed setting of 12288000
    DEFAULT_VEL;
  end

  properties (Abstract = true, Constant, Hidden = true)
    % physical stage properties
    MAX_FORCE; % [N] absolute max is a bit higher, but this is recommended
    BASE_MASS; % [kg] mass of moving part of the stage when empty
  end

  properties (Constant, Hidden = true)
    BAUD_RATE = 115200;
    DATA_BITS = 8;
    FLOW_CONTROL = 'none';
    PARITY = 'none';
    STOP_BITS = 1;
    TERMINATOR = 'CR/LF';

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
        Obj.VPrintF('[Obj] Initialized but not connected yet.\n');
      end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function delete(Obj)
      if ~isempty(Obj.Serial) && strcmp(Obj.Serial.Status,'open')
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
      if Obj.isConnected
        isValidPos = Obj.Check_Valid_Pos(pos);
        if isValidPos
          pos = Obj.MM_To_Steps(pos); % convert to steps
          reply = Obj.Dev.moveabsolute(pos);
          Obj.Wait_Ready();
          if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
            short_warn(reply.DataString);
          end
        end
      else
        short_warn('Not connected to stage!');
      end
    end

    function [pos] = get.pos(Obj)
      if Obj.isConnected
        pos = Obj.Dev.get('pos');
        pos = Obj.Steps_To_MM(pos); % convert to steps
      else
        pos = [];
      end
    end

    % --------------------------------------------------------------------------
    function set.vel(Obj, vel)
      if Obj.isConnected
        % really sets the maximum allowed speed
        % NOTE does NOT apply for sin move...only for abs/rel move!
        if vel > max(Obj.MAX_SPEED)
          short_warn('Requested velocity out of range!');
        else
          vel = Obj.MM_To_Steps(vel); % convert to steps
          vel = vel*1.6384; % zaber stage has this weird conversion factor,
            % it's not explained why, we just accept it...
          if ~Obj.Dev.set('maxspeed', vel);
            error('error')
          end
        end
      else
        short_warn('Not connected to stage!');
      end
    end

    function [vel] = get.vel(Obj)
      if Obj.isConnected
        vel = Obj.Dev.get('maxspeed');
        vel = Obj.Steps_To_MM(vel); % convert to steps
        vel = vel./1.6384; % zaber stage has this weird conversion factor,
          % it's not explained why, we just accept it...
      else
        vel = [];
      end
    end

    % --------------------------------------------------------------------------
    function [isConnected] = get.isConnected(Obj)
      isConnected = ~isempty(Obj.Serial) && strcmp(Obj.Serial.Status,'open');
    end

  end % <<<<<<<< END SET?GET METHODS

end % <<<<<<<< END BASE CLASS
