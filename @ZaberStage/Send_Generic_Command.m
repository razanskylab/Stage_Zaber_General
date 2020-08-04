function [failed, response] = Send_Generic_Command(Obj,genCommand)
  failed = false;
  try
    response = Obj.Serial.genericCommand(genCommand, Obj.address, Obj.axisId);
  catch
    response = [];
    failed = true;
  end

  if failed
    warnStr = sprintf('Command %s was rejected!',genCommand);
    short_warn(warnStr);
  elseif ~isempty(response) && ~strcmp(response.getReplyFlag(),'OK')
    warnStr = sprintf('Command %s was rejected!',genCommand);
    short_warn(warnStr);
    failed = true;
  else % looks like it worked...
    failed = false;
  end
end