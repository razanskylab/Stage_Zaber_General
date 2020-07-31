function [] = Close(Obj)
  Obj.VPrintF('[Obj] Closing connection to stage...');

  if ~isempty(Obj.Serial) && strcmp(Obj.Serial.Status,'open')
    fclose(Obj.Serial);
    delete(Obj.Serial);
    Obj.Serial = [];
    Obj.Done();
  else
    Obj.VPrintF('was not open!\n');
  end

end
