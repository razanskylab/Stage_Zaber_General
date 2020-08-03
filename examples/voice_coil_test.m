clja
VC = VoiceCoilStage();
VC.Home();

fprintf('Current position = %2.2f mm\n',VC.pos);
fprintf('Current veloction = %2.2f mm/s\n',VC.vel);

newPos = 10;
fprintf('Moving to position = %2.2f mm\n',newPos);
VC.pos = newPos;
fprintf('Current position = %2.2f mm\n',VC.pos);


fprintf('Current position = %2.2f mm\n',VC.pos);
fprintf('Current position = %2.2f mm\n',VC.pos);
fprintf('Current position = %2.2f mm\n',VC.pos);



