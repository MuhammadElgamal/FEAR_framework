close all; clc; clear all;
%% Description
% This code implements a network with dynamic demand
 
%% Defining the network geometry
source=7; sink=10;            % Defining source and sink nodes 
directed=true;                % Defining the typr of network whether directed or not
nodes_neglected=true;         % if nodes are neglected then they are assumed to be prefectly reliable
terminals_excluded=true;      % terminals are not included in the minimal path lines
 
source_nodes=[7 8 8 9 7 9 ];   % defines all possible arcs
target_nodes=[8 10 9 8 9 10];
net=reliability_net(source, sink, directed, nodes_neglected, ...
    terminals_excluded, source_nodes, target_nodes);
net.flow_constraints={'flow=demand', 'maximal capacity constraint'};
%% Defining Arc Reliabilities
% all arcs follow weibull arc reliability
c = [4 3 2 3 2];                    % maximal component per each arc
k = [10 15 25 15 20];               % maximal capacity per each component
alpha = [300 180 200  350 250];     % parameters for Weibull distribution used in this example
beta = [1 1 0.8 1.1 1];

%----------------- Reordering parameters as they are different in the paper
% than ours
order_vec = [4 5 3  3 1 2];  % because the order in which components are defined in Chang's 
                             % paper is differnt than ours
c = c(order_vec);
k = k(order_vec);
alpha  = alpha(order_vec)/4;
beta  = beta(order_vec);
net.k = k;
% building arc reliability matrix
dist = repmat("weibull", 1,6);
parameters = cell(1, 6);
for i=1:6
    parameters{i} = [alpha(i) beta(i)];
end

%% Defining Weekly demand and daily demand
day = 1:7;      % corresponds to first day up to seventh day of the week
Demand = [2400 2400 1500 2600 2800 4400 4800]; % fictious data as we assume the weekend to have heighst demand
Demand = round(Demand /50);
figure;
stem(day, Demand);
xlabel("day");
ylabel("required demand");
%% ---------------------------------- Defining daily demand ----------------
Td = 24;    % demand is required everyday  
Ps = 12;    % the peak always occur at 12 pm
d = @(t, del) round(del*cos(pi/Td*(t-Ps)).^2);
Alpha = @(t) round(1/(4*pi)*(2*pi*t+Td*(sin(2*pi*Ps/Td)-sin(2*pi/Td*(Ps-t))))); % expression for coeffcient near delta_n within demand
D = @(t, del) Alpha(t)*del;
alpha = @(n) Alpha(n*Td) - Alpha ((n-1)*Td);

% ------------ Finding maximum demand at each day --------------------------
daily_maximum_demand = round(Demand ./ alpha(day));
% --------------- Defining time axis to which we will do our simulation ----
number_of_points = 24*7; % increasing this number increases accuracy but also simulation time
net.time = linspace(0, 24*7, number_of_points);
demand = zeros(size(net.time));
for moment = 1:length(net.time)
    for day = 1:7
        t = net.time(moment) - (day-1)*24;
        if net.time(moment) < day *24 && net.time(moment)>= (day-1)*24
            demand(moment)=d(t, daily_maximum_demand(day));
        end
    end
end
net.demand_in_time = demand;
% plotting Expected demand
stem(net.time,demand);
xlabel("time [hr]");
ylabel("Expected Instantenous Demand");
%% Simulating Reliability without maintenece
net.reliability_dependent_time (c, dist, parameters);
unmaintained_R = net.reliability_in_time;
%% Maintence Algorithm
maintainence_period = 24*2;               % Two days to maintain the network above specific service level
service_level = 0.8;                    % Accepted service level
maximum_arcs_maintained = 5;            % maximum number of maintained arcs
[arcs_maintained,simulation_count] = net.minimum_arc_maintainence(maintainence_period, service_level, maximum_arcs_maintained, c);
%% Increasing maximum number of maintained arcs
maintained_R1 = net.reliability_in_time;
%% Increasing
plot(net.time, unmaintained_R, 'k');
hold on;
plot(net.time, maintained_R1, 'k-.');
hold on;
plot(net.time, service_level * ones(size(net.time)), 'k--');
hold on;
stem((1:simulation_count)*maintainence_period, 2*ones(1, simulation_count), 'k:', 'HandleVisibility','off');
xlabel('Time [hr]')
ylabel('System Reliability')
ylim([0, 1.02])
xlim([0, 170])
legend('Unmaintained Network', 'Maintained Network with 3 maintained arcs at most','Service Level \theta')
figure;
plot(net); % plotting must be done after taking CP because arc thikness is proportional to average capacity per arc

