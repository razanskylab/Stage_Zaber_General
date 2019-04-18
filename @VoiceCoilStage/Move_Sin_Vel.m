% function [] = Move_Sin_Vel(VCS,amp,velocity,nMove)
% uses Move_Sin method, but calculates period based on desired max velocity
% Johannes Rebling, (johannesrebling@gmail.com), 2019

function Move_Sin_Vel(VCS,amp,velocity,nMove)
  period = amp*2*pi/velocity; % amp and vel in mm -> period im s
  if (nargin == 4)
    VCS.Move_Sin(amp,period,nMove);
  else nargin == 3
    VCS.Move_Sin(amp,period);
  end
end
