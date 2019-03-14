% function [] = Close(VCS)
% does something coole...
% Johannes Rebling, (johannesrebling@gmail.com), 2019

function [] = Close(VCS)
  tic;
  VCS.VPrintF('[VCS] Closing connection to stage...');

  if ~isempty(VCS.Serial) && strcmp(VCS.Serial.Status,'open')
    fclose(VCS.Serial);
    delete(VCS.Serial);
    VCS.Serial = [];
    VCS.Done();
  else
    VCS.VPrintF('was not open!\n');
  end

end
