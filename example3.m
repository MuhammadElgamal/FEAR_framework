clc; clear all; close all;
%% Example 3 Evaluation
% The following paper { Y. K. Lin and C. F. Huang, "Stochastic flow 
% network reliability with tolerable error rate,” Qual. Technol. Quant. Manag., 
% vol. 10, no. 1, pp. 57–73, 2013, doi: 10.1080/16843703.2013.11673308}.
% nodes are ordered begining from source in anticlock wise direction in
% Fig.5

source=12; sink=13;            % Defining source and sink nodes 
directed=true;                 % Defining the typr of network whether directed or not
nodes_neglected=false;         % if nodes are neglected then they are assumed to be prefectly reliable
terminals_excluded=true;       % terminals are not included in the minimal path lines
 
source_nodes=[12  9   12  9  9  10 10 11];      % defines all possible arcs
target_nodes=[9   10  10  13 11 13 11 13] ;
net=reliability_net(source, sink, directed, nodes_neglected, ...
        terminals_excluded, source_nodes, target_nodes);
% if not specificed the number of units per components is presumed to be 1
%% _______________   Entering Capacity ______________________________________
% Taking the capacity probability distibution of each arc
CP=cell(1,6);           % a cell array that contains probability distribution for each arc capacity, each cell has maximal_cap(i)+1 length and sums to one 
CP{1}=[5 5 10 10 70]; 
CP{2}=[5 5 10 20 60];       
CP{3}=[10 15 20 20 35];           
CP{4}=[5 10 20 65];
CP{5}=[5 5 5 15 70];
CP{6}=[20 20 30 30];
CP{7}=[5 10 10 10 10 55];
CP{8}=[10 10 10 10 60];
CP{9}=[5 5 5 10 15 60];
CP{10}=[10 25 25 40];
CP{11}=[5 10 10 20 55];
% Dividing all capacity distribution by 100 to be as areatio not a
% percentage
CP=cellfun(@(x) x./100, CP, 'UniformOutput', false);

% error per each network element
net.error=[5 3 6 2 8 4 4 5 8 6 7]/1000;
net.take_capacity (CP);
plot(net); % plotting must be done after taking CP because arc thikness is proportional to average capacity per arc

net.flow_constraints={'flow=demand', 'maximal capacity constraint','error'};
%% Estimating Reliability
% change maximal_error to be 0.02, 0.03 to match with paper
figure;
% Check all possible constraints and make sure they are cleared
plot_curve = true;  maximal_cost = []; maximal_error = 0.03; compute_fast = false;
net.evaluate_reliability(plot_curve, maximal_cost, maximal_error, compute_fast);
disp_flow(net, 4, maximal_cost, maximal_error)


