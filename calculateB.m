function [B_mag, Bz] = calculateB(x, y, z, s, I, coil, dl)
% ---- Calculate the field at point (x, y, z)----------------------------%
B = [0 0 0];        % Initialize B field at point to zero
point = [x y z];    % set the point coordinates
mu0 = 4*pi*1e-7;  

for i = 1:s
    % calculate r, magnitude r and unit vector
    r = point - coil(i,:);
    r_mag = sqrt(r(1)^2 + r(2)^2 + r(3)^2);
    r_unit = r/r_mag;
    % Calculate B
    c = mu0*I(i)/(4*pi*r_mag^2);
    B = B + c*cross(dl(i,:), r_unit);
end
% calculate magnitude of B
B_mag = sqrt(B(1)^2 + B(2)^2 + B(3)^2);
Bz = B(3);
end