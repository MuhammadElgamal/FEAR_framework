close all; clc; clear all;
%% Description
% This code implements section 4.3 in the following paper: "Theory and applications of 
% an integrated model for capacitated-flow network reliability analysis" by
% Ping-Chen Chang
 
%% Defining the network geometry
source=7; sink=10;            % Defining source and sink nodes 
directed=true;                % Defining the typr of network whether directed or not
nodes_neglected=true;         % if nodes are neglected then they are assumed to be prefectly reliable
terminals_excluded=true;      % terminals are not included in the minimal path lines
 
source_nodes=[7 8 8 9 7 9 ];   % defines all possible arcs
target_nodes=[8 10 9 8 9 10];
net=reliability_net(source, sink, directed, nodes_neglected, ...
    terminals_excluded, source_nodes, target_nodes);
sort_output = true;
net.shortest_paths (sort_output);
net.flow_constraints={'flow=demand', 'maximal capacity constraint'};
%% Defining dynamic demand
D = 2400;
completion_time = 40;
demand_rate = D ./ completion_time;
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
alpha  = alpha(order_vec);
beta  = beta(order_vec);
net.k = k;
%% ---------------- Defining reliability functions ------------------
% building arc reliability matrix
dist = repmat("weibull", 1,6);
parameters = cell(1, 6);
for i=1:6
    parameters{i} = [alpha(i) beta(i)];
end

%------------ Doing simulation for different completion times ------
% system reliability at the end of completion time for a constant data rate
% is equivalent to evaluating reliabity for a staircase demand rate as the
% ceil of float deamand rate, the range of time is detrmined by minimum
% flow rates at source and sink nodes
net.time = completion_time;
net.demand_in_time = ceil(demand_rate);
net.reliability_dependent_time (c, dist, parameters);
%% Displaying Information
disp (" Analysis at t= 40 hr");
disp_flow(net, 60, [], []);
plot(net); % plotting must be done after taking CP because arc thikness is proportional to average capacity per arc


