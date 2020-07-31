% non functional example class to be used as basis for new hardware interfacing
% class, as they alls should have similar structure and content

classdef VoiceCoilStage < BaseHardwareClass

  % Transient = true -> don't store these values, as these are read from the stage...
  properties (Transient = true)
    pos(1,1) {mustBeNumeric,mustBeFinite}; % [mm]
    vel(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm/s] not used in sine movement!!
    % acc(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm²/s] not used at all???
    SERIAL_PORT = 'COM5';
  end

  properties
    bScanRate(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [Hz] - B-scans per second for sin-move
      % this is the basis from which period, max-speed, etc. are calculated
    nBScans(1,1) {mustBeInteger,mustBeNonnegative,mustBeFinite} = 0;
    range(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm] range of full motion during sin_mov
    addedMass(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite} = 0.1; % [Kg]
      % see accMaxTheo
    sinOvershoot(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite} = 0.25; % [mm]
      % add this to the desired scan range when using position based triggering
      % i.e. when going to 10 mm, we actually aim for 10.5 mm to make sure
      % we def. reach our 10 mm target
  end

  % depended properties are calculated from other properties
  properties (Dependent = true)
    % maxVel; % current max speead
    isConnected;
    period(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [ms] - period of full b-scan movement
    nPeriods(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % number of full movement periods
    moveTime(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [s] time to complete nBscans at desired Bscan rate
    vMax(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm/s] max speed reached during sin-move
    accMax(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm²/s] max accel reached during sin-move
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
  properties (Constant)
    STEP_SIZE = 0.2*1e-3; % [mm] one microstep = 0.2 micron
    RANGE = [0 12]; % [mm] min / max travel range
    MAX_SPEED = 1500; % [mm/s] max speed limit = maxspeed setting of 12288000
  end

  properties (Constant, Hidden = true)
    % serial properties
    DEVICE_ADDRESS = 1;
    BAUD_RATE = 115200;
    DATA_BITS = 8;
    FLOW_CONTROL = 'none';
    PARITY = 'none';
    STOP_BITS = 1;
    TERMINATOR = 'CR/LF';

    DO_AUTO_CONNECT = true; % connect when object is initialized?
    DEFAULT_VEL = 50;

    POLLING_INTERVAL = 10;
      % ms, time to wait between polling device stage whilte waiting to finish move...

    % physical stage properties
    MAX_FORCE = 12; % [N] absolute max is a bit higher, but this is recommended
    BASE_MASS = 0.1; % [kg] mass of moving part of the stage when empty
  end

  % same as constant but now showing up as property
  properties (Hidden=true)
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % constructor, desctructor, save obj
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods
    % constructor, called when class is created
    function OBJ = VoiceCoilStage(doConnect)
      if nargin < 1
        doConnect = OBJ.DO_AUTO_CONNECT;
      end

      if nargin == 1 && ischar(doConnect)
        OBJ.SERIAL_PORT = doConnect;
        doConnect = true;
      end

      if doConnect && ~OBJ.isConnected
        OBJ.Connect;
        OBJ.vel = OBJ.DEFAULT_VEL;
      elseif ~OBJ.isConnected
        OBJ.VPrintF('[VCS] Initialized but not connected yet.\n');
      end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function delete(VCS)
      if ~isempty(VCS.Serial) && strcmp(VCS.Serial.Status,'open')
        VCS.Force_Off(); % make sure no constant force is applied to stage
        % VCS.Dev.stop(); % don't use, at it applies constant force
        VCS.Close();
      end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % when saved, hand over only properties stored in saveObj
    function SaveObj = saveobj(VCS)
      SaveObj = VCS; % just copy/save all for now
     end
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods % short methods, which are not worth putting in a file
    function [mm] = Steps_To_MM(VCS,steps)
      mm = steps.*VCS.STEP_SIZE;
    end

    function [steps] = MM_To_Steps(VCS,mm)
      steps = round(mm./VCS.STEP_SIZE); % max rounding error is 200 nm...
    end

    function [] = Wait_Ready(VCS)
      reply = VCS.Dev.waitforidle(VCS.POLLING_INTERVAL*1e-3);
      if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
        short_warn(reply.DataString);
      end
    end

    function [] = Stop(VCS)
      reply = VCS.Dev.stop();
      if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
        short_warn(reply.DataString);
      end
    end

    function [] = Stop_Sin(VCS)
      reply = VCS.Dev.request('move sin stop', []);
      if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
        short_warn(reply.DataString);
      end
    end

    function [] = Force_Off(VCS)
      reply = VCS.Dev.request('force off', []);
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
    % simple dependend variables -----------------------------------------------
    function [period] = get.period(VCS)
      period = 1./(VCS.bScanRate)*2;
      period = round(period*1000); % we need a ms, integer period
    end

    function [nPeriods] = get.nPeriods(VCS)
      nPeriods = ceil(VCS.nBScans./2); % ceil is just to be on the safe side
    end

    function [moveTime] = get.moveTime(VCS)
      moveTime = VCS.nPeriods*VCS.period*1e-3;
    end

    function [vMax] = get.vMax(VCS)
      vMax = VCS.range*pi/(VCS.period*1e-3);
    end

    function [accMax] = get.accMax(VCS)
      accMax = VCS.range./2*(2*pi/(VCS.period*1e-3)).^2;
    end

    function [accMaxTheo] = get.accMaxTheo(VCS)
      totalMass = VCS.BASE_MASS + VCS.addedMass; % [Kg]
      accMaxTheo = VCS.MAX_FORCE./totalMass*1e3; % [mm/s²]
    end

    % --------------------------------------------------------------------------
    function set.nBScans(VCS, nBScans)
      if mod(nBScans,2)
        short_warn('nBScans must be even number. Using next higher!');
        VCS.nBScans = nBScans + 1;
      else
        VCS.nBScans = nBScans;
      end
    end

    % --------------------------------------------------------------------------
    function set.range(VCS, range)
      if (VCS.pos + range/2) > max(VCS.RANGE) || (VCS.pos - range/2) < min(VCS.RANGE)
        short_warn('Requested sin_move range out of stage range!');
      else
        VCS.range = range; % convert to steps
      end
    end


    % --------------------------------------------------------------------------
    function set.pos(VCS, pos)
      if VCS.isConnected
        if pos > max(VCS.RANGE) || pos < min(VCS.RANGE)
          short_warn('Requested position out of range!');
        else
          pos = VCS.MM_To_Steps(pos); % convert to steps
          reply = VCS.Dev.moveabsolute(pos);
          VCS.Wait_Ready();
          if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
            short_warn(reply.DataString);
          end
        end
      else
        short_warn('Not connected to stage!');
      end
    end

    function [pos] = get.pos(VCS)
      if VCS.isConnected
        pos = VCS.Dev.get('pos');
        pos = VCS.Steps_To_MM(pos); % convert to steps
      else
        pos = [];
      end
    end

    % --------------------------------------------------------------------------
    function set.vel(VCS, vel)
      if VCS.isConnected
        % really sets the maximum allowed speed
        % NOTE does NOT apply for sin move...only for abs/rel move!
        if vel > max(VCS.MAX_SPEED)
          short_warn('Requested velocity out of range!');
        else
          vel = VCS.MM_To_Steps(vel); % convert to steps
          vel = vel*1.6384; % zaber stage has this weird conversion factor,
            % it's not explained why, we just accept it...
          if ~VCS.Dev.set('maxspeed', vel);
            error('error')
          end
        end
      else
        short_warn('Not connected to stage!');
      end
    end

    function [vel] = get.vel(VCS)
      if VCS.isConnected
        vel = VCS.Dev.get('maxspeed');
        vel = VCS.Steps_To_MM(vel); % convert to steps
        vel = vel./1.6384; % zaber stage has this weird conversion factor,
          % it's not explained why, we just accept it...
      else
        vel = [];
      end
    end

    % --------------------------------------------------------------------------
    function [isConnected] = get.isConnected(VCS)
      isConnected = ~isempty(VCS.Serial) && strcmp(VCS.Serial.Status,'open');
    end

  end % <<<<<<<< END SET?GET METHODS

end % <<<<<<<< END BASE CLASS
