function [isValidPos] = Check_Valid_Pos(Obj,newPos)
  isValidPos = newPos <= max(Obj.RANGE) && newPos >= min(Obj.RANGE);
  if ~isValidPos
    warnStr = sprintf('%s Requested position (%2.2f) out of range!',Obj.classId, newPos); 
    short_warn(warnStr);
    warnStr = sprintf('%s Allowed range: %2.2f<->%2.2f!',Obj.classId,minmax(Obj.RANGE)); 
    short_warn(warnStr);
  end
end
