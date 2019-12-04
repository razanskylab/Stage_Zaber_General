% function [] = Move_Sin(VCS,amp,period,nMove)
% see https://www.zaber.com/wiki/Manuals/ASCII_Protocol_Manual#move for details
% Johannes Rebling, (johannesrebling@gmail.com), 2019

% Additional NOTEs:
% - VCS.vMax = a*2*pi/T
% - accmax = a*(2*pi/T)^2
% NOTE use the above to get the period based on desired / realistic max velocity

function Move_Sin(VCS)
  tic;
  if (VCS.bScanRate==0) || (VCS.range==0)
    error('Need valid range and period for Move_Sin!');
  end
  amp = VCS.range./2;
    % amp is half the movement range, see this picture:
    % https://www.zaber.com/wiki/File:Command_example_vector.png
    % i.e. we need to half the value we send if we want an overall oscilation of
    % 1 mm we have to request a 0.5 mm oscilation

  amp = VCS.MM_To_Steps(amp);
    % convert from mm to steps are required by stage

  if (VCS.nPeriods)  % move n-times
    message = Zaber.AsciiMessage(...
        VCS.Dev.DeviceNo, 'move sin', [amp VCS.period VCS.nPeriods], 'AxisNo', VCS.Dev.AxisNo);
    VCS.VPrintF('[VCS] Starting %i sine movements with\n',VCS.nPeriods);
  else % move indefinately
    message = Zaber.AsciiMessage(...
        VCS.Dev.DeviceNo, 'move sin', [amp VCS.period], 'AxisNo', VCS.Dev.AxisNo);
    VCS.VPrintF('[VCS] Starting sine movement with\n');
  end

  VCS.VPrintF('   max. velocity = %.1f mm/s\n',VCS.vMax);
  VCS.VPrintF('   max. accel.   = %.2f m2/s\n',VCS.accMax*1e-3);

  % send message
  reply = VCS.Dev.Protocol.request(message);

  if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
    short_warn(reply.DataString);
  end
end
