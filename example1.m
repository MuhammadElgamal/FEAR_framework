clc; clear all; close all;
%% Example 1 Evaluation
% nodes are ordered begining from source in anticlock wise direction in
% Fig. 2
source=7; sink=10;            % Defining source and sink nodes 
directed=true;                % Defining the typr of network whether directed or not
nodes_neglected=true;         % if nodes are neglected then they are assumed to be prefectly reliable
terminals_excluded=true;      % terminals are not included in the minimal path lines
 
source_nodes=[7 8 8 9 7 9 ];    % defines all possible arcs
target_nodes=[8 10 9 8 9 10];   
net=reliability_net(source, sink, directed, nodes_neglected, ...
        terminals_excluded, source_nodes, target_nodes);
% if not specificed the number of units per components is presumed to be 1
plot(net);
%% _______________ Entering Maximal Capacity for each element _______________
% Taking the capacity probability distibution of each arc
CP=cell(1,6);           
CP{1}=[0.05 0.1 0.25 0.6]; 
CP{2}=[0.1 0.3 0.6];       
CP{3}=[0.1 0.9];           
CP{4}=CP{3};
CP{5}=CP{3};
CP{6}=[0.05 0.25 0.7];

net.take_capacity (CP);
net.flow_constraints={'flow=demand', 'less than Lj', 'maximal capacity constraint'};
%% Evaluating Reliability
figure;
% Check all possible constraints and make sure they are cleared
plot_curve = true;  maximal_cost = []; maximal_error = []; compute_fast = false;
net.evaluate_reliability(plot_curve, maximal_cost, maximal_error, compute_fast);
disp_flow(net, 3, maximal_cost, maximal_error);