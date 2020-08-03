function [] = Move_No_Wait(Obj,pos)
  isValidPos = Obj.Check_Valid_Pos(newPos);
  if isValidPos
    pos = Obj.MM_To_Steps(pos); % convert to steps
    Obj.Dev.moveabsolute(pos);
  end
end
