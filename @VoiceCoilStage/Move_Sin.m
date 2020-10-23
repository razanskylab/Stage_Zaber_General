%NOTE:
% starts sine-movement from current position towards positive direction, with 
% center of movement (of sine curve) at current pos + Obj.sinRange/2
% vMax = a*2*pi/T
% accmax = a*(2*pi/T)^2
% NOTE use the above to get the period based on desired / realistic max velocity
% https://www.zaber.com/protocol-manual#topic_command_move_sin 

function Move_Sin(Obj)
  tic;
  if (Obj.bScanRate==0) || (Obj.sinRange==0)
    error('Need valid range and period for Move_Sin!');
  end

  % check if sinus movement range possible from current position
  topEnd = Obj.pos + Obj.sinRange;
  lowEnd = Obj.pos;
  if topEnd > max(Obj.RANGE) || lowEnd < min(Obj.RANGE)
    warnStr = sprintf('%s Requested sinRange (%2.2f<->%2.2f mm) not possible!',...
      Obj.classId,lowEnd,topEnd); 
    short_warn(warnStr);
    warnStr = sprintf('%s Allowed range: %2.2f<->%2.2f mm!',Obj.classId,minmax(Obj.RANGE)); 
    short_warn(warnStr);
    short_warn('Move_Sin cancelled!');
    return;
  end

  amp = Obj.sinRange./2;
    % amp is half the movement range, see this picture:
    % https://www.zaber.com/wiki/File:Command_example_vector.png
    % i.e. we need to half the value we send if we want an overall oscilation of
    % 1 mm we have to request a 0.5 mm oscilation

  ampSteps = Obj.MM_To_Steps(amp);
    % convert from mm to steps are required by stage

  % move sin amplitude period [count]
  if (Obj.nPeriods)  % move n-times
    sinCommand = sprintf('move sin %i %i %i',ampSteps,Obj.period,Obj.nPeriods);
    Obj.VPrintF('[Obj] Starting %i sine movements with\n',Obj.nPeriods);
  else % move indefinately
    sinCommand = sprintf('move sin %i %i',ampSteps,Obj.period);
    Obj.VPrintF('[Obj] Starting sine movement with\n');
  end

  Obj.VPrintF('   max. velocity = %.1f mm/s\n',Obj.vMax);
  Obj.VPrintF('   max. accel.   = %.2f m2/s\n',Obj.accMax*1e-3);

  Send_Generic_Command(Obj,sinCommand);
end
