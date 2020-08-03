function [] = Move_Relative(Obj,posDelta)
  newPos = Obj.pos + posDelta;
  isValidPos = Obj.Check_Valid_Pos(newPos);
  if isValidPos
    posDelta = Obj.MM_To_Steps(posDelta); % convert to steps
    Obj.Dev.moverelative(posDelta);
  end
end
