clc; clear all;
%% Input parameters
disp('Stopping at Error<10^-6');
Re=input('Enter Reynolds number (Re), e.g., 100: ');
p=input('U_wall:=p*X/l+q. Enter value for p, e.g., 0: '); q = input('Enter value for q, e.g., 0: ');
f_1=input('Enter value for f_1 between 0 and 1, e.g., 0.5: ');
f_2=input('Enter value for f_2>f_1 between 0 and 1, e.g., 0.7: ');
%% Mesh Generation
m=60;
w=4;
n=240;
l=10*w;

dx=l/(n-1);
dy=w/(m-1);

X=linspace(0,l,n);
Y=linspace(0,w,m);
[x,y]=meshgrid(Y,X);

%% Parameter Definition
dt=0.01;
Uinlet=1;
Lambda=(1/Re)*dt/min(dx,dy)^2;

%% Initialization
% Initial Velocity
Vold=zeros(n,m);
Uold=zeros(n,m);

H1=floor(f_1*m)+2;
H2=floor(f_2*m)-1;
fraction=10^-6;

for j=H1:H2
    Uold(1,j)=Uinlet;
    Vold(1,j)=0.0;
end
Unew=Uold;
Vnew=Vold;

% Initial StreamFunction
Psiold=zeros(n,m);
Sum=0;
Psiold(1,1:H1-1)=0;
for j=H1:H2
    Sum=Sum+Uold(1,j)*dy;
    Psiold(1,j)=Sum;
end
Psiold(1,H2+1:m)=Sum;
Psiold(:,m)=Sum;
Psinew=Psiold;

% Initial Vorticity
Omegaold=zeros(n,m);
for j=2:m-1
    Omegaold(1,j)=(Vold(3,j)-Vold(1,j))/(2*dx)-(Uold(1,j+1)-Uold(1,j-1))/(2*dy);
    Omegaold(n,j)=(Vold(n,j)-Vold(n-2,j))/(2*dx)-(Uold(n,j+1)-Uold(n,j-1))/(2*dy);
end
for i=2:n-1
    Omegaold(i,1)=(Vold(i+1,1)-Vold(i-1,1))/(2*dx)-(Uold(i,3)-Uold(i,1))/(2*dy);
    Omegaold(i,m)=(Vold(i+1,m)-Vold(i-1,m))/(2*dx)-(Uold(i,m)-Uold(i,m-2))/(2*dy);
end
Omegaold(1,1)=Omegaold(2,1);
Omegaold(1,m)=Omegaold(2,m);

for i=2:n-1
    for j=2:m-1
        Omegaold(i,j)=(Vold(i+1,j)-Vold(i-1,j))/(2*dx)-(Uold(i,j+1)-Uold(i,j-1))/(2*dy);
    end
end

Omeganew=Omegaold;
Omega_adv=Omegaold;

%% Solution Algorithm
tic
Iteration=Re*10^4;count=0;
Time=zeros(Iteration,1);Err=zeros(Iteration,1);
for time=1:Iteration
    time;
    count=count+1;
    Time(count,1)=time;
    % Backtrace positions for semi-Lagrangian advection
    X_back=x-Vold*dt;
    Y_back=y-Uold*dt;
    X_back=max(min(X_back,w), 0);
    Y_back=max(min(Y_back,l), 0);
    
    % Interpolate omega for advection
    omega_adv = interp2(x, y, Omegaold, X_back, Y_back, 'linear', 0);
    
    % Omega resolution-Predictor
    for i = 2:n-1
        for j = 2:m-1
            A=(-2/Re)/dx^2+(-2/Re)/dy^2;
            B=(1/Re)*((omega_adv(i, j+1) + omega_adv(i,j-1)) / dy^2 + ...
                (omega_adv(i+1,j) + omega_adv(i-1, j)) / dx^2);
            Omeganew(i, j)=(omega_adv(i, j)+B/A)*exp(A*dt)-B/A;
        end
    end
    
    for j=2:m-1
        Omeganew(1,j)=(Vold(3,j)-Vold(1,j))/(2*dx)-(Uold(1,j+1)-Uold(1,j-1))/(2*dy);
        Omeganew(n,j)=(Vold(n,j)-Vold(n-2,j))/(2*dx)-(Uold(n,j+1)-Uold(n,j-1))/(2*dy);
    end
    for i=2:n-1
        Omeganew(i,1)=(Vold(i+1,1)-Vold(i-1,1))/(2*dx)-(Uold(i,3)-Uold(i,1))/(2*dy);
        Omeganew(i,m)=(Vold(i+1,m)-Vold(i-1,m))/(2*dx)-(Uold(i,m)-Uold(i,m-2))/(2*dy);
    end
    Omeganew(1,1)=Omeganew(2,1);
    Omeganew(1,m)=Omeganew(2,m);
   
    % Omega resolution-Corrector
    for i = 2:n-1
        for j = 2:m-1
            Un=(omega_adv(i,j+1)+omega_adv(i,j-1))/dy^2+...
                (omega_adv(i+1,j)+omega_adv(i-1,j))/dx^2;
            Un1=(Omeganew(i,j+1)+Omeganew(i,j-1))/dy^2+...
                (Omeganew(i+1,j)+Omeganew(i-1,j))/dx^2;
            a0=Un;
            a1=(Un1-Un)/dt;
            d=1/Re;
            a=(d)*(1/dx^2+1/dy^2);
            Omeganew(i, j)=(omega_adv(i, j)-(d/a)*(a0/2-a1/(4*a)))*exp(-2*a*dt)+...
                (d/a)*(a0/2+(a1/2)*(dt-1/(2*a)));
        end
    end
    
    % Psi resolution
    for i=2:n-1
        for j=2:m-1
            RHS=(dy^2)*(Psiold(i+1,j)+Psiold(i-1,j))+(dx^2)*(Psiold(i,j+1)+Psiold(i,j-1));
            Psinew(i,j)=(((dx*dy)^2)*Omeganew(i,j)+RHS)/(2*(dx^2+dy^2));
        end
        
    end
    Psinew(n,2:m-1)=Psinew(n-1,2:m-1);    
    Psiold=Psinew;
    
    %Velocity Update
    for i=2:n-1
        for j=2:m-1
            Unew(i,j)=(Psinew(i,j+1)-Psinew(i,j-1))/(2*dy);
        end
    end
    Unew(n,:)=Unew(n-1,:);    
    for i=2:n-1
        for j=2:m-1
            Vnew(i,j)=-(Psinew(i+1,j)-Psinew(i-1,j))/(2*dx);
        end
    end
    Vnew(n,:)=Vnew(n-1,:);
    
    % Bottom wall update...................................................
    for i=1:n
        Unew(i,1)=p*X(1,i)/l+q;
    end
    % .....................................................................
    
    Error=(sum(sum(abs(Uold-Unew))))
    Err(count,1)=Error;
    if Error<fraction*Uinlet
        break
    end
    
    Uold=Unew;
    Vold=Vnew;
    
    % Omega update
    Omegaold=Omeganew;   
    for j=2:m-1
        Omegaold(1,j)=(Vnew(3,j)-Vnew(1,j))/(2*dx)-(Unew(1,j+1)-Unew(1,j-1))/(2*dy);
        Omegaold(n,j)=(Vnew(n,j)-Vnew(n-2,j))/(2*dx)-(Unew(n,j+1)-Unew(n,j-1))/(2*dy);
    end
    for i=2:n-1
        Omegaold(i,1)=(Vnew(i+1,1)-Vnew(i-1,1))/(2*dx)-(Unew(i,3)-Unew(i,1))/(2*dy);
        Omegaold(i,m)=(Vnew(i+1,m)-Vnew(i-1,m))/(2*dx)-(Unew(i,m)-Unew(i,m-2))/(2*dy);
    end
    Omegaold(1,1)=Omegaold(2,1);
    Omegaold(1,m)=Omegaold(2,m);
end
toc

%% Visualization
figure(10)
contourf(y / w, x / w, Unew, 100, 'LineColor', 'none')
colormap(jet)
colorbar
xlabel('Normalized x-axis (x / w)', 'FontSize', 12, 'FontWeight', 'bold')
ylabel('Normalized y-axis (y / w)', 'FontSize', 12, 'FontWeight', 'bold')
title('Contour Plot of U(x, y)', 'FontSize', 14, 'FontWeight', 'bold')
grid on

figure(2)
semilogy(Time, Err)
xlabel('Iteration')
ylabel('Error')
title('Error vs Iteration')
grid on
hold on

figure(30)
contour_handle = contour(y / w, x / w, Psinew, 100,'LineWidth', 2);
colormap(hsv);
colorbar;