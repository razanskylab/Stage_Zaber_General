function [] = Move_Relative(Obj,posDelta)
  import zaber.motion.Units;
  newPos = Obj.pos + posDelta;
  if Obj.isConnected
    isValidPos = Obj.Check_Valid_Pos(newPos);
    if isValidPos
      Obj.Axis.moveRelative(posDelta, Units.LENGTH_MILLIMETRES,true);
    end
  else
    short_warn('Not connected to stage!');
  end
end
