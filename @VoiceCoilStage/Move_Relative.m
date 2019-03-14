% function [] = Move_Relative(VCS)
% Johannes Rebling, (johannesrebling@gmail.com), 2019

function [] = Move_Relative(VCS,posDelta)
  % NOTE does NOT apply for sin move...only for abs/rel move!
  newPos = VCS.pos + posDelta;
  if newPos > max(VCS.RANGE) || newPos < min(VCS.RANGE)
    short_warn('Requested position out of range!');
  else
    posDelta = VCS.MM_To_Steps(posDelta); % convert to steps
    VCS.Dev.moverelative(posDelta);
  end
end
