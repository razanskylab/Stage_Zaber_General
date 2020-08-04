function Move_Sin_Vel(Obj,velocity)
  % move with a specific max. velocity instead of a period
  % see https://www.zaber.com/protocol-manual#topic_command_move_sin
  period = Obj.sinRange*pi/velocity; % amp and vel in mm -> period im ms
  Obj.bScanRate = 1./period*2; 
    % NOTE factor 2 because 1 period = back and forth = 2 bscans
  Obj.Move_Sin();
end
