function [] = Move_No_Wait(Obj,pos)
  % move stage to new absolute position
  % will override last Move_No_Wait if stage has not finished moving

  import zaber.motion.Units;

  if Obj.isConnected
    isValidPos = Obj.Check_Valid_Pos(pos);
    if isValidPos
      Obj.Axis.moveAbsolute(pos, Units.LENGTH_MILLIMETRES,false);
    end
  else
    short_warn('Not connected to stage!');
  end
end
