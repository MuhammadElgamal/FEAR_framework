clc; clear all; close all;
%% Example 2 Evaluation
% nodes are ordered begining from source in anticlock wise direction in
% Fig.2
 
source=7; sink=9;          % Defining source and sink nodes 
directed=true;               % Defining the typr of network whether directed or not 
nodes_neglected=true;        % if nodes are neglected then they are assumed to be prefectly reliable
terminals_excluded=true;     % terminals are not included in the minimal path lines
 
source_nodes=[7 8 8 10 7 10];
target_nodes=[8 9 10 8 10 9];
net=reliability_net(source, sink, directed, nodes_neglected, ...
        terminals_excluded, source_nodes, target_nodes);
% if not specificed the number of units per components is presumed to be 1
plot(net); 
%% _______________ Entering Capacity Levels _________________________________
% Taking the capacity probability distibution of each arc
CP=cell(1,6);           
CP{1}=[0.05 0.1 0.25 0.6]; 
CP{2}=[0.1 0.2 0.7];       
CP{3}=[0.1 0.9];           
CP{4}=CP{3};
CP{5}=[0.2 0.8];
CP{6}=CP{2};
% Putting the cost of transmission accross each arc
net.cost=[2 3 1 1 3 3];
H = 18;   % Maximum cost
% H can be any of 6, 10, 14, 18 as in paper
net.take_capacity (CP);
net.flow_constraints={'flow=demand', 'less than Lj', 'maximal capacity constraint','cost'};
figure;
% Check all possible constraints and make sure they are cleared
plot_curve = true;  maximal_cost = H; maximal_error = []; compute_fast = false;
net.evaluate_reliability(plot_curve, maximal_cost, maximal_error, compute_fast);
disp(net);

