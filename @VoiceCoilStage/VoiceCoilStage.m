% non functional example class to be used as basis for new hardware interfacing
% class, as they alls should have similar structure and content

classdef VoiceCoilStage < ZaberStage

  % Transient = true -> don't store these values, as these are read from the stage...
  properties (Transient = true)
    serialPort char = 'COM3';
    axisId = 1;
  end

  properties
    classId char = '[X-Stage]';

    bScanRate(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [Hz] - B-scans per second for sin-move
      % this is the basis from which period, max-speed, etc. are calculated
    nBScans(1,1) {mustBeInteger,mustBeNonnegative,mustBeFinite} = 0;
    sinRange(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [mm] range of full motion during sin_mov
    sinOvershoot(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite} = 0.25; % [mm]
      % add this to the desired scan range when using position based triggering
      % i.e. when going to 10 mm, we actually aim for 10.5 mm to make sure
      % we def. reach our 10 mm target
  end

  % depended properties are calculated from other properties
  properties (Dependent = true)
    period(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [ms] - period of full b-scan movement
    nPeriods(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % number of full movement periods
    moveTime(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [s] time to complete nBscans at desired Bscan rate
  end

  % things we don't want to accidently change but that still might be interesting
  properties (Constant)
    STEP_SIZE = 0.2*1e-3; % [mm] one microstep = 0.2 micron
    RANGE = [0 12]; % [mm] min / max travel range
    MAX_SPEED = 1500; % [mm/s] max speed limit = maxspeed setting of 12288000
    DEFAULT_VEL = 10; % [mm/s]
  end

  properties (Constant, Hidden = true)
    MAX_FORCE = 12; % [N] absolute max is a bit higher, but this is recommended
    BASE_MASS = 0.1; % [kg] mass of moving part of the stage when empty
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % constructor, desctructor, save obj
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods
    % constructor, called when class is created
    % function OBJ = VoiceCoilStage(doConnect)
    % end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % function delete(Obj)
    % end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % when saved, hand over only properties stored in saveObj
    % function SaveObj = saveobj(Obj)
    %   SaveObj = Obj; % just copy/save all for now
    %  end
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods % short methods, which are not worth putting in a file
    function [] = Stop_Sin(Obj)
      reply = Obj.Dev.request('move sin stop', []);
      if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
        short_warn(reply.DataString);
      end
    end

    function [] = Force_Off(Obj)
      reply = Obj.Dev.request('force off', []);
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
    function [period] = get.period(Obj)
      period = 1./(Obj.bScanRate)*2;
      period = round(period*1000); % we need a ms, integer period
    end

    function [nPeriods] = get.nPeriods(Obj)
      nPeriods = ceil(Obj.nBScans./2); % ceil is just to be on the safe side
    end

    function [moveTime] = get.moveTime(Obj)
      moveTime = Obj.nPeriods*Obj.period*1e-3;
    end
    % --------------------------------------------------------------------------
    function set.nBScans(Obj, nBScans)
      if mod(nBScans,2)
        short_warn('nBScans must be even number. Using next higher!');
        Obj.nBScans = nBScans + 1;
      else
        Obj.nBScans = nBScans;
      end
    end

    % --------------------------------------------------------------------------
    function set.sinRange(Obj, sinRange)
      if (Obj.pos + sinRange/2) > max(Obj.RANGE) || (Obj.pos - sinRange/2) < min(Obj.RANGE)
        short_warn('Requested sin_move range out of stage range!');
      else
        Obj.sinRange = sinRange;
      end
    end

  end % <<<<<<<< END SET/GET METHODS

end % <<<<<<<< END BASE CLASS
