function [] = Home(Obj)
  tic;
  Obj.VPrintF_With_ID('Homing stage...');
  Obj.Dev.home();
  Obj.Wait_Ready();
  Obj.Done();
end
