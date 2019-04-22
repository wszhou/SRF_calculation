%% Function for calculating the self-resonant frequency (SRF) of cylindrical solenoids with uniform pitches

%  Created by Wenshen Zhou on 14 Apr 2019

%  Introduction:
%  The code can be used for calculating the SRF of cylindrical solenoid 
%  coils with non-uniform pitches. Inductance (L) and capacitance (C) are 
%  calculated individually, then the SRF is calculated as 1/(2*pi*sqrt(L*C)).
%  The methods for calculating L and C are illustrated in the paper: W. Zhou,
%  and S. Y. Huang, "An accurate model for fast calculating the resonant
%  frequency of an irregular solenoid".

% Input:
% pitch:           1*N array, pitches of the N turns of the solenoid
% N:               number of turns of the solenoid
% f1:              frequecy for calculating inductance, a low f1 is usually used.
% r_w:             radius of the wire
% radius:          radius of the solenoid
% s:               number of segments of the coil
% step:            the step size for meshing the computation domain

% Output:
% L:               inductance of the solenoid        
% C:               capacitance of the solenoid
% f_res:           self resonant frequency of the solenoid

% An example of using the function:
% To calculate the resonant frequency of a 4 turn cylindrical solenoid coil
% with pitches of each turn to be 2 mm, 4 mm, 6 mm and 8 mm, respectively.
% It has a radius of 40 mm, wound with wire having a diameter of 1.024 mm. 
% The solenoid is divided into 200 segments and the step size for calculation
% is set to be 0.001 mm

% The command will be:
% [L, C, f_res] = func_SRF_calculation_cylindrical_varied_pitch([0.002 0.004 0.006 0.008], 4, 1e3, 1.024e-3/2, 0.04, 200, 0.001)


function [L, C, f_res] = func_SRF_calculation_cylindrical_varied_pitch(pitch, N, f1, r_w, radius, s, step)

L_separate = zeros(1,N);    % inductance of each turns

mu_0 = 4*pi*10^-7;
epsilon_0 = 8.854187817e-12;
mu_r = 1;
rho = 1.72e-8;           % resistivity of copper
sigma = 5.96e7;          % conductivity of copper
d = 2*r_w;               % diameter of wire
D = 2*radius;            % diameter of coil

    
l_coil = sqrt((2*pi*radius)^2+pitch.^2);    % length of the wire of each turn of the solenoid
height = sum(pitch);                        % height of the solenoid
L_int = mu_0*l_coil./(8*pi);                % internal inductance of each turn


%% Calculation of inductance of the solenoid
T = 1/f1;           % period
speed = 3e8;        % speed of EM wave
lambda = speed/f1;  % wavelength at frequency f1
phi0 = 0;           % initial phase

n = 0;
z0 = 0;
for it = 1:N
    for t = 0:2*N*pi/s:2*pi*(1-N/s)
        n = n+1;
        coil(n,1) = radius*cos(t);    % X coordinate of point n
        coil(n,2) = radius*sin(t);    % Y coordinate of point n
        coil(n,3) = z0 + pitch(it)*t/(2*pi);   % Z coordinate of point n
    end
    z0 = z0 + pitch(it);
end
n = n+1;
coil(n,1) = radius*cos(2*pi);    % X coordinate of point n
coil(n,2) = radius*sin(2*pi);    % Y coordinate of point n
coil(n,3) = z0;                  % Z coordinate of point n


dl = coil(2:s+1, :) - coil(1:s, :);           % vectors of the coil segments

% Current at each segment
time = 0;
l = 0;
Ic(1) = 1;
for ic = 2:s
    l = l + abs(dl(ic-1));
    Ic(ic) = cos(2*pi*f1*time-l/lambda+phi0);
end

B = [0 0 0];
n = 0;
boundary = 0.01;
% calculation domain in x, y, and z direction
x_start = -(radius+boundary);
x_stop = radius+boundary;
x_span = (x_stop-x_start)/step+1;
y_start = -(radius+boundary);
y_stop = radius+boundary;
y_span = (y_stop-y_start)/step+1;
z_start = -(0+boundary);
z_stop = height+boundary;
z_span = (z_stop-z_start)/step+1;

% Calculate the B field generated by the solenoid coil with Biot-Savart Law
for x = x_start:step:x_stop
    n = n+1;
    m = 0;
    l = 0;
    for y = y_start:step:y_stop
        m = m+1;
        l = 0;
        for z = z_start:step:z_stop
            l = l+1;
            [B_mag(n,m,l) Bz(n,m,l)]= calculateB(x, y, z, s, Ic, coil, dl);
        end
    end
end


n1 = (s/(2*N)):(s/N):((2*N-1)*s/(2*N));
z_O = coil(n1,3);  
z1 = zeros(x_span,y_span,N);    % z-coordinates of the points on calculation surface
z3_plot = zeros(x_span,y_span);
B_map = zeros(x_span,y_span,N); % matrix to decide whether a point is inside the coil, 1->'yes', 0->'no'

% Calculate the z-coordinates of the points on calculation surface
z_c = 0;
for k = 1:N
    n = 0;
    for x = x_start:step:x_stop
        n = n+1;
        m = 0;
        for y = y_start:step:y_stop
            m = m+1;
            if x==0 && y==0
                theta = pi;
            elseif y>=0
                theta = acos(x/sqrt(x^2+y^2));
            else
                theta = acos(-x/sqrt(x^2+y^2))+ pi;
            end
            
            Rc = radius;                  
            
            if x^2+y^2<=(Rc-r_w)^2
                B_map(n,m,k) = 1;
                z_R1 = z_c + pitch(k)*theta/(2*pi);      
                z1(n,m,k) = (z_R1-z_O(k))*sqrt(x^2+y^2)/Rc+z_O(k);
            else
                B_map(n,m,k) = 0;
            end
        end
    end
    z_c = z_c + pitch(k);
end

Area = pi*Rc.^2;                % area of the transverse-middle-planes
phi_area = zeros(1,N);          % magnetic flux of single calculation surfaces
phi_total = 0;                  % total magnetic flux
L_total = 0;                    % total inductance
B_area = zeros(x_span,y_span,N);% B field of single calculation surfaces



for k = 1:N
    % Calculate the magnetic flux at all the calculation surfaces
    for n = 1:x_span
        for m = 1:y_span
            for iz = 1:z_span
                z(iz) = z_start + step*(iz-1);
                if z(iz)>=z1(n,m,k)
                    B_area(n,m,k) = Bz(n,m,iz);
                    break;
                end
            end
            if B_map(n,m,k) == 1
                phi_area(k) = phi_area(k) + B_area(n,m,k)*step^2;
            end
        end
    end
    
    % Calculate the inductance of each loop
    Ic_area(k) = Ic((2*k-1)*s/(2*N)+1);             % current at the middle segment of each loop
    L_separate(k) = phi_area(k)/Ic_area(k);         % inductance of each loop
    L_total = L_total+L_separate(k)+L_int(k);       % total inductance of the kth loop
    phi_total = phi_total + phi_area(k);
end

L = L_total;


%% Calculation of capacitance of the solenoid
C_NN_total = 0;
C_2nd_NN_total = 0;

for n2 = 1:(N-1)                                    % calculate the nearest neighbour capacitance
   pitch_NN(n2) = 1/2*(pitch(n2)+pitch(n2+1));
   C_NN(n2) = epsilon_0*pi^2*D/(acosh(pitch_NN(n2)/d));
   C_NN_total = C_NN_total + 1/C_NN(n2);
end

for n3 = 1:(N-2)                                    % calculate the 2nd nearest neighbour capacitance
   pitch_2nd_NN(n3) = 1/2*((pitch(n3)+pitch(n3+1))+(pitch(n3+1)+pitch(n3+2)));
   C_2nd_NN(n3) = epsilon_0*pi^2*D/(acosh(pitch_2nd_NN(n3)/d));
   C_2nd_NN_total = C_2nd_NN_total + 1/C_2nd_NN(n3);
end

C = 1/C_NN_total + 1/C_2nd_NN_total;

%% Calculation of SRF
f_res = 1/(2*pi*sqrt(L*C));

end
