% function [] = Move_No_Wait(VCS)
% does something coole...
% Johannes Rebling, (johannesrebling@gmail.com), 2019

function [] = Move_No_Wait(VCS,pos)
  if pos > max(VCS.RANGE) || pos < min(VCS.RANGE)
    short_warn('Requested position out of range!');
  else
    pos = VCS.MM_To_Steps(pos); % convert to steps
    VCS.Dev.moveabsolute(pos);
  end
end
