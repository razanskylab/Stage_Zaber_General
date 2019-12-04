% function [] = Home(VCS)
% does something coole...
% Johannes Rebling, (johannesrebling@gmail.com), 2019

function [] = Home(VCS)
  tic;
  VCS.PrintF('[VCS] Homing stage...');
  VCS.Dev.home();
  VCS.Wait_Ready();
  VCS.Done();
end
