% general notes
60 000 microsteps = 12 mm
1 microstep = 200 nm
5 microstep = 1 um

%% maxspeed
- The actual speed is calculated as speed = maxspeed / 1.6384 microsteps/sec.
-> maxspeed = speed (microsteps/sec) * 1.6384
-> maxspeed = speed (um/sec) * 1.6384 * 5
-> maxspeed = speed (mm/sec) * 1.6384 * 5000


%% accel
- https://www.zaber.com/wiki/Manuals/ASCII_Protocol_Manual#accel
- A value of 0 specifies infinite acceleration

%% move sin
- /move sin a T
- a = amplitude, a is half the movement range, see this picture:
  https://www.zaber.com/wiki/File:Command_example_vector.png
- T = period = in ms

- vmax = a * 2*pi/T
- accmax = a * (2*pi/T)^2
- sin stop ends a sinusoidal motion when its current cycle completes.
