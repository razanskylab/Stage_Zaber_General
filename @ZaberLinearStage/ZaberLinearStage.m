% non functional example class to be used as basis for new hardware interfacing
% class, as they alls should have similar structure and content

classdef ZaberLinearStage < ZaberStage

  % Transient = true -> don't store these values, as these are read from the stage...
  properties (Transient = true)
    serialPort char = 'COM3';
    address = 2; % device address, used to select what to connect to... 
    % can be changed via zaber console, but should not be!
    axisId = 1; % voice coil stage only has one axis
  end

  properties
    classId char = '[Y-Stage]';
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
    STEP_SIZE = 0.1*1e-3; % [mm] one microstep = 0.1 micron
    RANGE = [0 75]; % [mm] min / max travel range
    MAX_SPEED = 40; % [mm/s] max speed limit = maxspeed setting of 12288000
    DEFAULT_VEL = 20; % [mm/s]
  end

  properties (Constant, Hidden = true)
    MAX_FORCE = 110; % [N] absolute max is a bit higher, but this is recommended
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

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods (Access = private)
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods % set / get methods
  end % <<<<<<<< END SET/GET METHODS

end % <<<<<<<< END BASE CLASS
