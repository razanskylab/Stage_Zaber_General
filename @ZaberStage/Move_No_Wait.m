function [] = Move_No_Wait(Obj,pos)
  if pos > max(Obj.RANGE) || pos < min(Obj.RANGE)
    short_warn('Requested position out of range!');
  else
    pos = Obj.MM_To_Steps(pos); % convert to steps
    Obj.Dev.moveabsolute(pos);
  end
end
