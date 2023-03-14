clc; clear all; close all;
%% Example 4 for TANET network with both cost and error constraints
% The source example is found in A. Aissou, A. Daamouche, and M. R. Hassan, 
% “Components Assignment Problem for Flow Networks Using MOPSO,” 
% IAENG Int. J. Comput. Sci., vol. 48, no. 1, 2021
source=31; sink=56;            % Defining source and sink nodes 
directed=true;                % Defining the typr of network whether directed or not
nodes_neglected=true;         % if nodes are neglected then they are assumed to be prefectly reliable
terminals_excluded=true;      % terminals are not included in the minimal path lines
 

% source and sink are named 35,  36
source_nodes=[31:43 31 44:46 39 47:48 33 31 49:54 53 55];       % defines all possible arcs
target_nodes=[32:43 56 44:46 39 47:48 56 44 49:54 56 55 56];
net=reliability_net(source, sink, directed, nodes_neglected, terminals_excluded, source_nodes, target_nodes);
% if not specificed the number of units per components is presumed to be 1
plot(net);
%% Reading Capacity Distributions from attached files
% Taking the capacity probability distibution of each arc
% as the size of the network is very huge the data is taken from a textfile
c=readmatrix('Aissou_TANET_capacity_distrubution.txt');
selected_components= [47 4 48 3 21 6 15 39 53 61 60 64 80 ...
                      37 20 65 17 79 58 44 7 51 1 77 8 2 33 54 5 14]; % according to the choice of R_(d=4,T=16) in the refernce paper
c=c(selected_components, :);  % delete other elements
c(:, [1 end-1:end])=[];
CP=cell(1,size(c,1));
for i=1:size(c,1)
    for j=1:size(c,2)
        if c(i,j)~=0
            CP{i}(j)=c(i,j);
        elseif j+1<=size(c,2)
            if c(i,j+1)~=0
                CP{i}(j)=0;                
            end
        end
    end
end
% defining error and cost constraints
net.error=[4 8 6 5 5 5 5 7 3 2 5 7 5 8 5 6 2 5 5 5 5 5 5 5 4 3 2 1 3 6]/1000; 
net.cost=[4 3 1 2 5 4 5 5 2 2 2 3 2 6 4 5 3 2 1 1 1 2 1 4 2 1 5 4 2 3];

net.take_capacity (CP);
net.flow_constraints={'flow=demand', 'maximal capacity constraint', 'cost', 'error'};
plot_curve = true;  maximal_cost = 120; maximal_error = 0.04; compute_fast = false;
% maximal_cost can be 120, 80, 60 to match with paper
% maximal_error can be 0.03, 0.035, 0.04, 1 to match with the paper
figure;
% Check all possible constraints and make sure they are cleared
net.evaluate_reliability(plot_curve, maximal_cost, maximal_error, compute_fast);
disp_flow(net, 3, maximal_cost, maximal_error)
