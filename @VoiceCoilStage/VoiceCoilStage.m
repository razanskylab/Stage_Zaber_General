% non functional example class to be used as basis for new hardware interfacing
% class, as they alls should have similar structure and content

classdef VoiceCoilStage < BaseHardwareClass

  properties
    pos(1,1) {mustBeNumeric,mustBeFinite}; % [mm]
    vel(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm/s] not used in sine movement!!
    acc(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm²/s] not used in sine movement!!
    bScanRate(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [Hz] - B-scans per second for sin-move
      % this is the basis from which period, max-speed, etc. are calculated
    nBScans(1,1) {mustBeInteger,mustBeNonnegative,mustBeFinite} = 0;
    range(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm] range of full motion during sin_mov
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
  end

  % things we don't want to accidently change but that still might be interesting
  properties (SetAccess = private)
    Dev; % zaber AsciiDevice, this is the zaber class used for all communication
    Serial; % serial port object, created in Connect, used by Dev
  end

  % things we don't want to accidently change but that still might be interesting
  properties (Constant)

    % serial properties
    SERIAL_PORT = 'COM5';
    DEVICE_ADDRESS = 1;
    BAUD_RATE = 115200;
    DATA_BITS = 8;
    FLOW_CONTROL = 'none';
    PARITY = 'none';
    STOP_BITS = 1;
    TERMINATOR = 'CR/LF';

    STEP_SIZE = 0.2*1e-3; % [mm] one microstep = 0.2 micron
    RANGE = [0 12]; % [mm] min / max travel range

    MAX_SPEED = 1500; % [mm/s] max speed limit = maxspeed setting of 12288000

    DO_AUTO_CONNECT = true; % connect when object is initialized?

    POLLING_INTERVAL = 10;
      % ms, time to wait between polling device stage whilte waiting to finish move...

    % physical stage properties
    MAX_FORCE = 12; % [N] absolute max is a bit higher, but this is recommended
    BASE_MASS = 0.1; % [kg] mass of moving part of the stage when empty
    ADDED_MASS = 0.1; % [kg] measured ~60g, without fiber, probably around this
  end

  % same as constant but now showing up as property
  properties (Hidden=true)
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % constructor, desctructor, save obj
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods
    % constructor, called when class is created
    function VCS = VoiceCoilStage(doConnect)
      if nargin < 1
        doConnect = VCS.DO_AUTO_CONNECT;
      end

      if doConnect && ~VCS.isConnected
        VCS.Connect;
      elseif ~VCS.isConnected
        VCS.VPrintF('[VCS] Initialized but not connected yet.\n');
      end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function delete(VCS)
      if ~isempty(VCS.Serial) && strcmp(VCS.Serial.Status,'open')
        VCS.Dev.stop();
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
      vMax = VCS.range*2*pi/(VCS.period*1e-3);
    end

    function [accMax] = get.accMax(VCS)
      accMax = VCS.range*(2*pi/(VCS.period*1e-3)).^2;
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
      if range + VCS.pos > max(VCS.RANGE) || range < min(VCS.RANGE)
        short_warn('Requested sin_move range out of stage range!');
      else
        VCS.range = range; % convert to steps
      end
    end


    % --------------------------------------------------------------------------
    function set.pos(VCS, pos)
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
    end

    function [pos] = get.pos(VCS)
      pos = VCS.Dev.get('pos');
      pos = VCS.Steps_To_MM(pos); % convert to steps
    end

    % --------------------------------------------------------------------------
    function set.vel(VCS, vel)
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
    end

    function [vel] = get.vel(VCS)
      vel = VCS.Dev.get('maxspeed');
      vel = VCS.Steps_To_MM(vel); % convert to steps
      vel = vel./1.6384; % zaber stage has this weird conversion factor,
        % it's not explained why, we just accept it...
    end

    % --------------------------------------------------------------------------
    function [isConnected] = get.isConnected(VCS)
      isConnected = ~isempty(VCS.Serial) && strcmp(VCS.Serial.Status,'open');
    end

  end % <<<<<<<< END SET?GET METHODS

end % <<<<<<<< END BASE CLASS
