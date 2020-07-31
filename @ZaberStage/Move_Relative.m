function [] = Move_Relative(Obj,posDelta)
  % NOTE does NOT apply for sin move...only for abs/rel move!
  newPos = Obj.pos + posDelta;
  if newPos > max(Obj.RANGE) || newPos < min(Obj.RANGE)
    short_warn('Requested position out of range!');
  else
    posDelta = Obj.MM_To_Steps(posDelta); % convert to steps
    Obj.Dev.moverelative(posDelta);
  end
end
