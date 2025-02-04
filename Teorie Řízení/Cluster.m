L_i = 1.2e-3;        % H
L_g = 0.7e-3;        % H
C_f = 9e-6;          % F
R_d = 8;             % Ohms

s = tf('s');
T_S = 1e-6;          % s
G_D = (1/(1+T_S*s));
G = ((1/(L_i*s))*(((s^2)+(s*R_d/L_g)+(1/(L_g*C_f)))/((s^2)+(s*((L_i*R_d+L_g*R_d)/(L_i*L_g)))+((L_i+L_g)/(L_i*L_g*C_f)))))*G_D;

parfor it = 1:1000
disp("Hodnoty: ")
disp(PRPH357tune(G,[randi([1 10000]) randi([1 10000]) randi([1 10000]) randi([1 10000]) randi([1 10000])]));
end

disp(K);

function K = PRPH357tune(G,K0)
omega_0 = 2*pi*50;   % rad/sec
omega_c = 0.5;       % rad/sec
omega_c3 = 2.5;      % rad/sec
omega_c5 = 4.5;      % rad/sec
omega_c7 = 10;       % rad/sec

% Umělý obdélníkový signál pro optimalizaci THD
f0 = 50*2*pi;           % hlavní frekvence signálu
fs = f0*1e6;            % vzorkovací frekvence
t = 0:(1/fs):(1/f0);    % časový vektor
% Vytvoření základního sinusového signálu
x = sin(2*pi*f0*t);
% Přidání harmonického zkreslení
for n = 3:2:7
    x = x + ((1/n))*sin(2*pi*n*f0*t);
end

s = tf('s');

% Regulator:
C = @(K) K(1) + ...
         K(2)*((2*omega_c*s)/((s^2) + (2*omega_c*s) + (omega_0^2))) + ...
         K(3)*((2*omega_c3*s)/((s^2) + (2*omega_c3*s) + ((3*omega_0)^2))) + ...
         K(4)*((2*omega_c5*s)/((s^2) + (2*omega_c5*s) + ((5*omega_0)^2))) + ...
         K(5)*((2*omega_c7*s)/((s^2) + (2*omega_c7*s) + ((7*omega_0)^2)));

% Close loop:
G_cl = @(K) feedback(G*C(K),1);

% normalizace hodnot
W = [2000 0.1 50 0.1]; 
% Rise time: 0.5 ms = 1, 
% Overshoot: 10% = 1 
% Transient time: 20ms = 1
% H - inf norma: 10 = 1 

% Objective function
obj = @(K)  W(1)  * (abs(stepinfo(G_cl(K)).RiseTime)) ... % doba náběhu
          + W(2)  * (abs(stepinfo(G_cl(K)).Overshoot)) ... % překmit
          + W(3)  * (abs(stepinfo(G_cl(K)).TransientTime)) ... % doba ustálení
          + W(4)  * (norm(G_cl(K),inf))... % Robustnost při vysokých frekvencích; stejne jako: max(abs(G))
          ;

% Condition function
nonlcon = @(K) mynonlcon(K,G_cl,x,t,fs,4);

% Ohraničení konstant K
lb = [0,0,0,0,0];
ub = [10000,10000,10000,10000,10000];
% Nastavení funkce fmincon
options = optimoptions('fmincon','Display','iter','MaxIter',100,'TolFun',1e-12);
% Výpočet koeficientů pomocí funkce fmincon
K = fmincon(obj,K0,[],[],[],[],lb,ub,nonlcon,options);
end


% Funkce na výpočet spektrální hustoty signálu na dané frekvenci
function thd = spectral_density(sys, x,  t, fs, n)
% průchod vstupu "x" lineárním systémem sys
y = lsim(sys,x,t);
% výpočet spektrální hustoty signálu
pxx = periodogram(y,[],length(x),fs);
% normalizace hodnot na procenta
pxx = 100*(pxx)/(max(pxx)); 
% vyčíselní vyšších harmonických složek signálu 
thd = 0;
for nn = n
    thd = thd + pxx(nn);
end
end
% funkce ohraničující řešení pouze na regulátory které splnují normy THD
function [c,ceq] = mynonlcon(K,G_cl,x,t,fs,h)
c = spectral_density(G_cl(K),x,t,fs,4:2:8) - h;
ceq = [];
end