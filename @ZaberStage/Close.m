function [] = Close(Obj)
  tic;
  Obj.VPrintF_With_ID('Closing connection to stage...');
  if ~isempty(Obj.Serial)
    Obj.Serial.close();
    Obj.Serial = [];
    Obj.Done();
  else
    Obj.VPrintF('was not open!\n');
  end

end
