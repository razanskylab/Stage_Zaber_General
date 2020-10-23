% non functional example class to be used as basis for new hardware interfacing
% class, as they alls should have similar structure and content

classdef VoiceCoilStage < ZaberStage

  % Transient = true -> don't store these values, as these are read from the stage...
  properties (Transient = true)
    serialPort char = 'COM3';
    axisId = 1; % voice coil stage only has one axis
    address = 1; % can be changed via zaber console, but should not be!
  end

  properties
    classId char = '[X-Stage]';

    % properties below are specific for voice-coil stage and Move_Sin methods
    bScanRate(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite} = 0.5;
      % [Hz] - B-scans per second for sin-move
      % this is the basis from which period, max-speed, etc. are calculated
    nBScans(1,1) {mustBeInteger,mustBeNonnegative,mustBeFinite} = 0;
    sinRange(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite} = 1;
      % [mm] range of full motion during sin_mov (2*amplitude)
    sinOvershoot(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite} = 0.25; % [mm]
      % add this to the desired scan range when using position based triggering
      % i.e. when going to 10 mm, we actually aim for 10.5 mm to make sure
      % we def. reach our 10 mm target
  end

  % depended properties are calculated from other properties
  properties (Dependent = true)
    period(1,1) {mustBeNumeric,mustBeNonnegative,mustBeFinite};
      % [ms] - period of full b-scan movement, 5s is safe default value
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
    function delete(Obj)
      Obj.Force_Off(); % make sure no constant force is applied to stage
      Obj.Close();
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % when saved, hand over only properties stored in saveObj
    % function SaveObj = saveobj(Obj)
    %   SaveObj = Obj; % just copy/save all for now
    %  end
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods % short methods, which are not worth putting in a file
    function [] = Stop_Sin(Obj)
      % reply = Obj.Dev.request('move sin stop', []);
      [failed,reply] = Obj.Send_Generic_Command('move sin stop');
      if failed
        short_warn('Force off command failed!');
      end
      Obj.Wait_Ready();
    end

    function [] = Force_Off(Obj)
      % disables driver for stage
      [failed,~] = Obj.Send_Generic_Command('force off');
      if failed
        short_warn('Force off command failed!');
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

    function [vMax] = get.vMax(Obj)
      vMax = Obj.sinRange*pi/(Obj.period*1e-3);
    end

    function [accMax] = get.accMax(Obj)
      accMax = Obj.sinRange./2*(2*pi/(Obj.period*1e-3)).^2;
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
      Obj.sinRange = sinRange;
    end

  end % <<<<<<<< END SET/GET METHODS

end % <<<<<<<< END BASE CLASS
