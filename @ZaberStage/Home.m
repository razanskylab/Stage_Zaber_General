function [] = Home(Obj,waitReady)
  if (nargin == 1)
    waitReady = true;
  end

  if waitReady
    tic;
    Obj.VPrintF_With_ID('Homing stage...');
    Obj.Axis.home(); % waits for stage to be home before continue...
    Obj.Done();
  else
    Obj.VPrintF_With_ID('Homing stage (no-wait).\n');
    Obj.Send_Generic_Command('home');
  end
end
