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
D = 600;
completion_time = linspace(120, 300, 40);
demand_rate = D ./ completion_time;
c = [3 2 2 2 3];            % maximal component per each arc
k = [1 1 3 2 1];            % maximal capacity per each component
lambda = [1 3 2 1 3]/1000;       % exponential distribution parameter for each arc
order_vec = [4 5 3  3 1 2];  % because the order in which components are defined in Chang's 
                             % paper is differnt than ours
c = c(order_vec);
k = k(order_vec);
lambda = lambda(order_vec);
net.k = k;
%%---------------- Defining reliability functions ------------------
% building arc reliability matrix
dist = repmat("exponential", 1,6);
parameters = cell(1, 6);
for i=1:6
    parameters{i} = lambda(i);
end

%------------ Doing simulation for different completion times ------
% system reliability at the end of completion time for a constant data rate
% is equivalent to evaluating reliabity for a staircase demand rate as the
% ceil of float deamand rate, the range of time is detrmined by minimum
% flow rates at source and sink nodes
final_reliability = zeros(size(demand_rate));
net.time = completion_time;
net.demand_in_time = ceil(demand_rate);
net.reliability_dependent_time (c, dist, parameters);
net.plot_time_reliablity();
plot(net); % plotting must be done after taking CP because arc thikness is proportional to average capacity per arc

