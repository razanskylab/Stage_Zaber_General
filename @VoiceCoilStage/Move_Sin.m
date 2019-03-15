% function [] = Move_Sin(VCS,amp,period,nMove)
% amp = movement amplitude in mm
% period = full period of movement in milliseconds
% nMove (optional) = number of requested movements
% see https://www.zaber.com/wiki/Manuals/ASCII_Protocol_Manual#move for details
% Johannes Rebling, (johannesrebling@gmail.com), 2019

% Additional NOTEs:
% - vmax = a*2*pi/T
% - accmax = a*(2*pi/T)^2
% NOTE use the above to get the period based on desired / realistic max velocity

function Move_Sin(VCS,amp,period,nMove)
  tic;
  period = period*1000; % convert from seconds to ms
  vmax = amp*2*pi/(period*1e-3);
  accmax = amp*(2*pi/(period*1e-3)).^2;

  amp = amp./2;
    % amp is half the movement range, see this picture:
    % https://www.zaber.com/wiki/File:Command_example_vector.png
    % i.e. we need to half the value we send if we want an overall oscilation of
    % 1 mm we have to request a 0.5 mm oscilation

  amp = VCS.MM_To_Steps(amp);

  % create asci message
  if nargin == 3 % move indefinately
    message = Zaber.AsciiMessage(...
        VCS.Dev.DeviceNo, 'move sin', [amp period], 'AxisNo', VCS.Dev.AxisNo);
    VCS.VPrintF('[VCS] Starting sine movement with\n');
  elseif nargin == 4  % move n-times
    message = Zaber.AsciiMessage(...
        VCS.Dev.DeviceNo, 'move sin', [amp period nMove], 'AxisNo', VCS.Dev.AxisNo);
    VCS.VPrintF('[VCS] Starting %i sine movements with\n',nMove);
  end

  VCS.VPrintF('      max. velocity = %3.1f mm/s\n',vmax);
  VCS.VPrintF('      max. accel.   = %3.0f mm2/s\n',accmax);

  % send message
  reply = VCS.Dev.Protocol.request(message);

  if (isa(reply, 'Zaber.AsciiMessage') && reply.IsError)
    short_warn(reply.DataString);
  end
end
