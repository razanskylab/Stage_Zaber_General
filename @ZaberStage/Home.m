function [] = Home(Obj)
  tic;
  Obj.VPrintF_With_ID('Homing stage...');
  Obj.Axis.home(); % waits for stage to be home before continue...
  Obj.Done();
end
