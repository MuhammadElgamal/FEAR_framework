classdef reliability_net<handle
    properties
        source;    % [charcter array] positive integer for instance '1'
        target;    % [charcter array] positive integer for instance '7'
        % Network Specs
        directed=true;              % [logical variable] specifies if arcs are directed or not
        nodes_neglected=false;      % [logical variable] if nodes are perfectly reliable then set nodes_negelected to true
        terminals_excluded=false;   % [logical variable]  if terminals are perfectly reliable then set this to true; this property is useful when nodes are not reliable and only terminals are reliable
        source_nodes; % [cell array of charcters] for instance {'1', '2'}
        target_nodes; % [cell array of charcters] for instance {'1', '2'}
        graph;        % a graph object containing netwrok structure
        P;            % [struct] has fields 'arcs' and 'components' (both of them is cell array) and it contains minimal paths of the network. 'arcs' is the indices of arcs of the minimal path. 'components' contains nodes if nodes ae unreliable
        cyclic;       % [logical variable] that checks network cyclicity
        % Parameters associated to components
        demand; % [row matrix] probability distribution of demand levels
        CP;     % [cell array] cost probability density function from capacity 0 to final capacity
        cost;   % [row matrix] cost per transmission
        error;  % [row matrix] Error per transmission
        k;      % [row matrix] capacity of number of components in the connected arc.
        % Evaluated Reliability
        reliability;   % [struct] with fields rel,demand: this property is useful for static SFNs, rel is a row containg reliability values against demand stored at demand field
        % Available Constarints
        flow_constraints={'flow=demand', 'less than Lj', 'maximal capacity constraint', 'cost', 'error'}; % [cell array: each element is a charceter array]these are all possible constraints considered within our work
        % Time dependent objects
        time;                       % [row matrix] contains time instances at which dynamic reliability is evaluated
        demand_in_time;             % [row matrix] contains demand in time instances intially, then it  is updated throughout the code at each instance of simulating dynamic reliability
        reliability_in_time;        % [row matrix] contains reliability against time instnaces
        arc_reliability;            % [float matrix] each row is reliability against time for arc i
        % Maintenece Parameters
    end

    methods
        function net=reliability_net(source, target, directed, nodes_neglected, terminals_excluded, source_nodes, target_nodes)
            % source, target, source nodes, target nodes are integer row
            % vectors
            net.source=num2str(source);
            net.target=num2str(target);
            net.directed=directed;
            net.terminals_excluded=terminals_excluded;
            net.nodes_neglected=nodes_neglected;
            if length(source_nodes)~=length(target_nodes)
                error('Enter same number of source/target nodes');
            else
                net.source_nodes=cell(size(source_nodes));
                net.target_nodes=net.source_nodes;
                for i=1:length(source_nodes)
                    net.source_nodes{i}=num2str(source_nodes(i));
                    net.target_nodes{i}=num2str(target_nodes(i));
                end
                % Building network graph object
                edge_weight = ones(size(source_nodes));
                % digraph is used for directed graphs
                if directed
                    net.graph = digraph(net.source_nodes, net.target_nodes, edge_weight);
                    net.cyclic = not(isdag(net.graph));
                else
                    src = [net.source_nodes net.target_nodes];
                    tar = [net.target_nodes net.source_nodes];
                    net.graph = graph(net.source_nodes, net.target_nodes, edge_weight );
                    g = digraph(src, tar, [edge_weight edge_weight]);
                    net.cyclic = not(isdag(g));
                end
            end
            if nodes_neglected
                net.k = ones(size(source_nodes));
            else
                node_count = length(unique([source_nodes target_nodes]));
                if terminals_excluded
                    node_count = node_count -2;
                end
                net.k = ones(1, node_count + length(source_nodes));
            end
        end
        function take_capacity (net, CP, demand)
            % CP is  a cell array containing capacities of all elements.
            if isempty(CP)
                n=length(net.source_nodes);
                if ~net.nodes_neglected
                    n=n+ length(unique(cellfun(@(x) str2num(x), [net.source_nodes net.target_nodes])));
                end
                net.CP=cell(1,n);           % a cell array that contains probability distribution for each arc capacity, each cell has maximal_cap(i)+1 length and sums to one
                for i=1:n
                    net.CP{i}=input(sprintf('Enter Capacity Distribution for component %d: ', i));
                    while sum (net.CP{i})~=1 || any(net.CP{i}<0)
                        net.CP{i}=input(sprintf('Enter Capacity Distribution for component %d: ', i));
                    end
                end
                celldisp(net.CP);
            else
                net.CP=CP;
                if (nargin==3)
                    net.demand=demand;
                else
                    % Assuming random demand distribution
                    demand=randi([1 10], 1, max(cellfun(@(h) length(h), net.CP)));
                    demand=demand/sum(demand);
                    net.demand=demand;
                end
            end
        end
        function shortest_paths (net, sort_output)
            % finds minimal paths through the network, sort_output makes
            % sure that within the same minimal paths elements are sorted
            % ascendingly. It updates net.P
            if net.directed
                g=net.graph;
                % From contains all source nodes as numbers
                % To contains all target nodes as numbers
                from=g.Edges.EndNodes(:,1); to=g.Edges.EndNodes(:,2);
                from2=zeros(size(from)); to2=from2;
                for i=1:length(from)
                    from2(i)=str2num(from{i});
                    to2(i)=str2num(to{i});
                end
                from=from2; to=to2;
                P=cell(1);
                s=net.source;
                t=net.target;
                sn=str2num(s);
                tn=str2num(t);
                % Loop Intialisation
                P{1}(1)=tn;
                % Update Path Vectors
                path_id=1;
                while path_id<=length(P)
                    while P{path_id}(end)~=sn
                        loc_to=find(to==P{path_id}(end));
                        loc_from=[];
                        [P,~]=update_path_vectors(P,path_id,loc_to,loc_from, to,from);
                        % Ad hoc solution to fix the nsfnet problem
                        if path_id> length(P)
                            break;
                        end
                    end
                    path_id=path_id+1;
                end
                f=@(key, pool) cellfun(@(x) strcmp(x,num2str(key)),pool);
                FindEdge1=@(a,i) find( f(a(i),net.source_nodes) &  f(a(i+1),net.target_nodes));
                FindEdge2=@(a,i) find( f(a(i),net.target_nodes) &  f(a(i+1),net.source_nodes));

                for i=1:length(P)
                    P{i}=fliplr(P{i});
                    % We need to insert arc numbers between nodes to account for node
                    % reliability
                    b=[];
                    c=b;
                    for index=1:length(P{i})-1
                        b=[b,P{i}(index), FindEdge1(P{i},index)];
                        c=[c,FindEdge1(P{i},index)];
                        if ~net.directed
                            b=[b, FindEdge2(P{i},index)];
                            c=[c, FindEdge2(P{i},index)];
                        end
                    end
                    if ~net.nodes_neglected
                        P{i}=[b P{i}(end)];
                    end
                    net.P.arcs{i}=c;

                end
                net.P.components=P;
                if net.nodes_neglected
                    net.P.components=net.P.arcs;
                elseif(net.terminals_excluded)
                    for l=1:length(net.P.components)
                        net.P.components{l}([1 end])=[];
                    end
                end
                if sort_output
                    net.P.components=cellfun(@(x) sort(x), net.P.components, 'UniformOutput', false);
                    last_index=min(cellfun(@(x) length(x), net.P.components));
                    mat=cellfun(@(x) x(1:last_index), net.P.components, 'UniformOutput', false);
                    mat=cell2mat(mat);
                    mat=reshape(mat', last_index,length(mat)/last_index)';
                    [~, I]=sortrows(mat,1:last_index);
                    P2=net.P.components;
                    for i=1:length(I)
                        net.P.components{i}=P2{I(i)};
                    end
                end
            else
                source_nodes=[cellfun(@(x) str2num(x), net.source_nodes) cellfun(@(x) str2num(x), net.target_nodes)];
                target_nodes=[cellfun(@(x) str2num(x), net.target_nodes) cellfun(@(x) str2num(x), net.source_nodes)];
                a=reliability_net(str2num(net.source), str2num(net.target), true, net.nodes_neglected, net.terminals_excluded, source_nodes, target_nodes);
                shortest_paths (a, sort_output);
                v=length(net.source_nodes);
                a.P.arcs=cellfun(@(x) threshold(x,v), a.P.arcs, 'UniformOutput',false);
                if sort_output
                    a.P.arcs=cellfun(@(x) sort(x), a.P.arcs, 'UniformOutput',false);
                end
                if a.nodes_neglected
                    a.P.components=a.P.arcs;
                else
                    sorted_arcs=cellfun(@(x) sort(x), a.P.arcs, 'UniformOutput',false);
                    source_nodes=cellfun(@(x) str2num(x), net.source_nodes);
                    target_nodes=cellfun(@(x) str2num(x), net.target_nodes);
                    comps=cell(size(sorted_arcs));
                    for i=1:length(sorted_arcs)
                        for j=1:length(sorted_arcs{i})
                            comps{i}=[comps{i} source_nodes(sorted_arcs{i}(j)) sorted_arcs{i}(j) target_nodes(sorted_arcs{i}(j))];
                        end
                        comps{i}=unique(comps{i});

                        if a.terminals_excluded
                            comps{i}(comps{i}==str2double(net.source) | comps{i}==str2double(net.target))=[];
                        end
                    end
                    a.P.components=comps;
                end
                net.P=a.P;
            end



        end
        function valid=check_flow(net,f, demand, maximal_cost, maximal_error)
            % this method checks if a specific flow vector [row matrix]
            % follows specific constraints. f has flow in each minimal path
            % as ordered in net.P.arcs. demand is is the amount required by 
            % each component within an arc in order to have a specifc flow 
            % so it is not passage of number of components but passage of 
            % number of units by each component. maximal_cost and
            % maximal_error are set to empty arrays in case they are not
            % used
            if length(f)~=length(net.P.components)
                error('Size of flow vector is not same as count of minimal paths');
            end
            valid=1;
            %____ Intermediate Variables__________________
            maximal_cap=cellfun(@(x) length(x), net.CP)-1;
            maximal_cap= maximal_cap.*net.k;
            %____________ Checking Constraints
            if ismember(1,strcmp(net.flow_constraints,'flow=demand'))
                if sum(f)~=demand
                    valid=0;
                    return ;
                end
            end
            if ismember(1,strcmp(net.flow_constraints,'less than Lj'))
                for i=1:length(f)
                    if f(i)> min([demand maximal_cap(net.P.components{i})])
                        valid=0;
                        return;
                    end
                end
            end
            if ismember(1,strcmp(net.flow_constraints,'maximal capacity constraint'))
                for i=1:length(maximal_cap)
                    % if i is a specific MPj then add its flow vector
                    s=0;
                    for j=1:length(net.P.components)
                        if ~isempty(find(net.P.components{j}==i, 1))
                            s=s+f(j);
                        end
                    end
                    if s>maximal_cap(i)
                        valid=0;
                        return;
                    end
                end
            end
            if ismember(1,strcmp(net.flow_constraints,'cost'))
                s=0;
                for j=1:length(net.P.components)
                    uj=sum(net.cost(net.P.components{j}));
                    s=s+uj*f(j);
                end
                if s> maximal_cost
                    valid=0;
                    return;
                end
            end
            if ismember(1,strcmp(net.flow_constraints,'error'))
                u=zeros(size(f));
                for j=1:length(f)
                    u(j)=prod(1-net.error(net.P.components{j}));
                end
                s=sum(u.*f);
                if s< demand*(1-maximal_error)
                    valid=0;
                    return;
                end
            end

        end
        function [lb, ub, A, b, C, d]=generate_constraints(net, demand, maximal_cost, maximal_error)
            % generates constraint matrices so flow is between lb, ub
            % A F' <= b such that F is row vector represents flow vector
            % C F' = d is an equation applied on F
            lb=zeros(1, length(net.P.arcs));
            ub=lb+demand;
            A=[]; b=[]; C=[]; d=[];
            if ismember(1,strcmp(net.flow_constraints,'flow=demand'))
                C=[C; ones(1, length(net.P.arcs))];
                d=[d; demand];
            end
            if ismember(1,strcmp(net.flow_constraints,'less than Lj'))
                maximal_cap=cellfun(@(x) length(x), net.CP)-1;
                maximal_cap=maximal_cap.*net.k;
                v=[];
                for i=1:length(net.P.arcs)
                    v=[v min([demand maximal_cap(net.P.components{i})])];
                end
                ub=[ub; v];
            end
            if ismember(1,strcmp(net.flow_constraints,'maximal capacity constraint'))
                maximal_cap=cellfun(@(x) length(x), net.CP)-1;
                maximal_cap=maximal_cap.*net.k;
                b=[b; maximal_cap'];
                for i=1:length(maximal_cap)
                    v=zeros(1, length(net.P.arcs));
                    for j=1:length(v)
                        if ~isempty(find(net.P.components{j}==i, 1))
                            v(j)=1;
                        end
                    end
                    A=[A; v];
                end

            end
            if ismember(1,strcmp(net.flow_constraints,'cost'))
                u=zeros(1, length(net.P.arcs));
                for j=1:length(net.P.components)
                    u(j)=sum(net.cost(net.P.components{j}));
                end
                A=[A; u];
                b=[b; maximal_cost];
            end
            if ismember(1,strcmp(net.flow_constraints,'error'))
                u=zeros(1, length(net.P.arcs));
                for j=1:length(net.P.components)
                    u(j)=prod(1-net.error(net.P.components{j}));
                end
                u=-u;
                A=[A; u];
                b=[b; -demand*(1-maximal_error)];

            end
            lb=max(lb, [], 1);
            ub=min(ub, [], 1);
        end
        function X=make_state(net, f)
            % converts a flow matrix (each row is a flow vector) to a state
            % matrix where each row is a state vector
            %% F to X transformation
            maximal_cap=cellfun(@(x) length(x), net.CP)-1;
            n=length(maximal_cap); % no. of active elements whether arcs/nodes
            m=length(net.P.components);           % no. of minimal paths
            if length(f)~=m
                error('Enter right size of flow vector');
            end
            MPs=net.P.components;
            X=zeros(1,n);
            for i=1:n
                for j=1:m
                    if any(MPs{j}==i)
                        X(i)=X(i)+f(j);
                    end
                end
            end
            X = ceil(X./net.k);   % to genralise for the sake of 2022 paper
        end
        function F=generate_flows(net, demand, maximal_cost, maximal_error, method)
            % method contains a number either 1 or 2 to indicate used
            % function to find all combinations of flow vectors befor
            % applying constraints on them
            switch(method)
                case 1
                    F=find_combinations(0:demand, length(net.P.components));
                    validity=zeros(size(F,1),1);
                    for i=1:size(F,1)
                        validity(i)=net.check_flow(F(i, :),demand, maximal_cost, maximal_error);
                    end
                    F=F(validity==1, :);
                    F=sortrows(F);
                case 2
                    [lb, ub, A, b, C, d]=generate_constraints(net, demand, maximal_cost, maximal_error);
                    F = combinations(lb, ub, A, b, C,d);
                    F=full(F);
                    validity=zeros(size(F,1),1);
                    for i=1:size(F,1)
                        validity(i)=net.check_flow(F(i, :),demand, maximal_cost, maximal_error);
                    end
                    F=F(validity==1, :);
                    F=sortrows(F);
            end

        end
        function [X,F]=update_state_vectors(net, F)
            % keeps only lower boundary points
            X=[];
            for i=1:size(F,1)
                X=[X; net.make_state(F(i, :))];
            end
            [X,I, ~]=unique(X,'rows');
            F=F(I,:);

            if net.cyclic
                X_new=[]; F_new=[];
                for i=1:size(F,1)
                    big=0;
                    for j=1:size(F,1)
                        if i~=j
                            if all(X(i,:)>=X(j,:)) && any(X(i,:)>X(j,:))
                                big=1;
                                break;
                            end
                        end
                    end
                    if big==0
                        X_new=[X_new; X(i,:)];
                        F_new=[F_new; F(i,:)];
                    end
                end
                X=X_new; F=F_new;
            end
            [F,I]=sortrows(F);
            X=X(I, :);

        end
        function [r, X, F]=calculate_reliability(net,demand, maximal_cost, maximal_error, fast, varargin)
            % varargin contains k which is the number of components per arc
            % which if not passed it is assumed to be one. 
            %% Data Preparation
            F=generate_flows(net, demand, maximal_cost, maximal_error, 2);
            [X,F]=update_state_vectors(net, F);
            if length(varargin) > 0
                k = varargin{1};
                X = X.*k;
            end
            r=rel(net, X,fast);
        end
        function r=rel(net, X,fast)
            % applies RSDP recursively to evaluate reliability
            %% Updating X at each state
            X_new=[];
            for i=1:size(X,1)
                big=0;
                for j=1:size(X,1)
                    if i~=j
                        if all(X(i,:)>=X(j,:)) && any(X(i,:)>X(j,:))
                            big=1;
                            break;
                        end
                    end
                end
                if big==0
                    X_new=[X_new; X(i,:)];
                end
            end
            X=X_new;
            %% Reliablility Estimation
            % Make some error firing messages to match lengths or sum of probability
            % distibutions
            CP=net.CP;
            if ~fast
                TM=zeros(1,size(X,1));
                for i=1:size(X,1)
                    if (i==1)
                        TM(i)=pr_great(X(i,:),CP);
                    else
                        X_dash=zeros(size(X(1:i-1,:)));
                        for j=1:i-1
                            X_dash(j,:)=max([X(i,:);X(j,:)], [],1);
                        end
                        TM(i)=pr_great(X(i,:),CP)-rel(net, X_dash,fast);
                    end
                end
                r=sum(TM);
            else
                Rel=0;
                I=1:size(X,1);
                for k=1:length(I)
                    intersections=nchoosek(I,k); % to find all possible combinations of a specific length
                    parfor j=1:size(intersections,1)
                        target_vec=max(X(intersections(j,:),:),[],1);
                        change=((-1).^(k+1))*prob_state_greater_or_eq(target_vec,CP);
                        Rel=Rel+change;
                    end
                end
                r=Rel;
            end
        end
        function plot(net)
            % plots the network graphically to show its topology etc
            g=net.graph;
            weights = cellfun(@(x) length(x)-1, net.CP);
            weights = weights(1:length(net.source_nodes));
            weights_ordered = weights;
            p = plot(g);
            legend("Width of arcs is proportional to maximal capacity")
            p.MarkerSize=6;
            p.ArrowSize=10;
            p.EdgeFontSize=10;
            p.NodeFontSize=14;
            p.LineWidth=g.Edges.Weight*1.5;
            p.EdgeFontWeight='bold';
            p.NodeFontWeight='bold';
            edge_label = cell(1,length(net.source_nodes));
            for i = 1:length(net.source_nodes)
                for j = 1:length(net.source_nodes)
                    a = net.graph.Edges(j,1).EndNodes;
                    if (a{1} == net.source_nodes{i} & ...
                            a{2} == net.target_nodes{i})
                         edge_label{j} = char("e_{" + num2str(i)+"}");
                         weights_ordered(j) = weights(i);
                    end
                end

            end
            p.EdgeLabel = edge_label;
            p.LineWidth = 6 * weights_ordered / max(weights_ordered);
            % Differentiating between Terminals and Non-Terminals
            s=net.source;
            t=net.target;
            Terminals=[findnode(g,s) findnode(g,t)];
            p.NodeLabel{Terminals(1)} = char(p.NodeLabel{Terminals(1)} + " source");
            p.NodeLabel{Terminals(2)} = char(p.NodeLabel{Terminals(2)} + " sink");
            terminal_color=[1 1 0];
            node_coloring=zeros(size(g.Nodes,1),3);
            node_coloring(Terminals,:)=repmat(terminal_color,length(Terminals),1);
            p.NodeColor=node_coloring;
        end
        function evaluate_reliability(net, plot_curve, maximal_cost, maximal_error, fast, varargin)
            % if varargin is not passed the reliability is evaluated from 0
            % to maximal capacity of all arcs. otherwise it will be
            % evaluated at specific demands specified by demand variable
            % plot_curve is logical variable.
            % maximal_cost and maximal_error can be passed as empty arrays
            % if not used
            sort_output = true;                 % to keep MPs has sorted elements so if MP1= {1, 3, 2} it becomed MP1 ={1, 2, 3}
            net.shortest_paths (sort_output);
            if length(varargin) < 1
                d=0:length(net.demand)-1;
            else
                d = varargin{1};
                plot_curve = false;
            end
            R=[];
            net.reliability.X=cell(1,length(d));
            net.reliability.F=cell(1,length(d));

            for i=1:length(d)
                [net.reliability.rel(i),net.reliability.X{i}, net.reliability.F{i}]=net.calculate_reliability(d(i), maximal_cost, maximal_error, fast);
                [net.reliability.F{i}, I]=sortrows(net.reliability.F{i});
                net.reliability.X{i}=net.reliability.X{i}(I,:);
            end

            net.reliability.demand=d;
            if plot_curve
                plot(net.reliability.demand,net.reliability.rel);
                xlabel('Demand');
                ylabel('Reliability')
            end
            net.reliability.maximal_flow=sum(net.reliability.rel(2:end));
            if length(varargin) < 1
                net.reliability.system_rel=net.reliability.rel*net.demand';
            end
        end
       function disp_flow(net, required_demand, maximal_cost, maximal_error)
            % displays all the steps used within the FEAR algorithm at
            % specific demand. maximal_cost and maximal_error can be passed as empty arrays
            % if not used. the required demand is not effective in case you
            % show the flow for a dynamic network. In such case, the demand
            % is at the last time instance.
            disp("_____________________________");
            disp("Problem Specifcations");
            fprintf("d = %d\n", required_demand);
            if ~isempty(maximal_cost)
                fprintf("H = %d\n", maximal_cost);
            end
            if ~isempty(maximal_error)
                fprintf("E = %d\n", maximal_error);
            end
            
            disp("_____________________________");
            mc = cellfun(@(x) length(x)-1, net.CP);
            disp("STEP 0");
            fprintf('Source node = %s\nTarget node = %s\n', net.source, net.target);
            fprintf('Required Demand [d] = %d\n', required_demand);
            fprintf('Maximal Capacity [C] = (%s)\n', num2str(mc));
            fprintf('Number of nodes [n] = %d\nNumber of arcs [a] = %d\n',length(unique([net.source_nodes, net.target_nodes])), length(net.source_nodes));
            if net.directed
                disp('Arcs are unidirectional');
            else
                disp('Arcs are bidirectional');
            end
            if net.nodes_neglected
                disp('Nodes are perfectly reilable');
            elseif net.terminals_excluded
                disp('All nodes are unreilable (has capacity distribution) EXCEPT source and target nodes');
            else
                disp('All nodes are unreilable (has capacity distribution)');
            end
            disp("----");
            disp('Capacity Distribution');
            disp("demand: each level is multiple of components in element i");
            print_row(0: max(mc), max(mc)+1);
            disp("Capacity: each row represents an element");
            for i = 1: length(net.CP)
                print_row(net.CP{i}, max(mc) + 1);
            end
            if ~isempty(maximal_cost)
                fprintf('Maximal cost per element is %s\n', num2str(net.cost));
            end
            if ~isempty(maximal_error)
                fprintf('Maximal error per element is %s\n', num2str(net.error));
            end
            
            % ---------------------
            disp("_____________________________");
            disp("STEP 1");
            disp("Minimal Paths");
            cellfun(@(x) disp(x), net.P.components);
            if net.cyclic
                disp("Network is cyclic")
            else
                disp("Network is NOT cyclic")
            end
            %---------------------
            disp("_____________________________");
            disp("STEP 2");
            fprintf('Constraints\n');
            cellfun(@(x) fprintf("'%s'\n",x), net.flow_constraints);
            disp("----");
            [lb, ub, A, b, C, d]=generate_constraints(net, required_demand, maximal_cost, maximal_error);
            disp("The order of the columns is same as order of minimal paths shown earlier")

            fprintf("Lower bound for flow = (%s) \nUpper bound for flow = (%s)\n", num2str(lb), num2str(ub));
            disp("----");

            fprintf("Inequality Constraints for flow A F' <= b (F is a row vector)\n");
            disp("A = ");
            print_matrix(A);
            fprintf("\nb = \n");
            print_matrix(b);
            disp("----");

            fprintf("Equality Constraints for flow C F' = d' (F is a row vector)\n");
            disp("C = ");
            print_matrix(C);
            fprintf("\nd' = \n");
            print_matrix(d');

            %------------------
            disp("_____________________________");
            disp("STEP 3, 4");
            disp("Acceptable flow vectors (row vectors)");
            if required_demand + 1 <= length(net.reliability.F)
                W = net.reliability.F{required_demand+1}
                disp("Acceptable state vectors (row vectors)");
                fprintf("psi(T[W]) = ")
                net.reliability.X{required_demand+1}
            else
                W = net.reliability.F{1}
                disp("Acceptable state vectors (row vectors)");
                fprintf("psi(T[W]) = ")
                net.reliability.X{1}
            end
            %------------------
            disp("_____________________________");
            disp("STEP 5");
            if required_demand + 1 <= length(net.reliability.F)
                R = net.reliability.rel(required_demand+1)
            else
                R = net.reliability.rel(1)
            end

            %% Functions
            function print_row(x, l)
                for i = 1: length(x)
                    fprintf("%-10.4f",x(i));
                end
                for i = length(x)+1:l
                    fprintf("%-10s","-");
                end
                fprintf("\n");
            end
            function print_matrix(x)
                l = size(x, 2);
                for i = 1:size(x, 1)
                    print_row(x(i,:), l);
                end
            end


        end
        function reliability_dependent_time (net, w, dist, parameters, varargin)
            % w is maximal capacity vector [row matrix], dist is a cell
            % array of strings where each string can be any of 'weibull',
            % 'normal' or 'exponential', parameters is a cell array of
            % parameters required for each distribution. In case there is
            % an additional input varargin, then the reliability matrix of
            % each arc is taken directly
            R = zeros(size(net.time));
            t = net.time;
            d = net.demand_in_time;
            if isempty(varargin)
                r = reliability_matrix(t,dist, parameters);
            else
                r = varargin{1};
            end
            %------- this is the probability for demand i for all arcs as first index
            %and at all times as second index
            pr = @(arc, time_index ,demand, w) nchoosek(w(arc), demand) .* (r(arc,time_index).^demand).*(1-r(arc,time_index)).^(w(arc)-demand);
            %% -----------------------------------------------------------------
            plot_curve = false;  maximal_cost = []; maximal_error = []; compute_fast = false;

            for moment = 1: length(t)
                CP=cell(1,length(w));
                for arc=1:length(w)
                    for demand = 0 : w(arc)
                        CP{arc}(demand + 1) = pr(arc, moment ,demand, w);
                    end
                end
                net.take_capacity (CP);
                net.evaluate_reliability(plot_curve, maximal_cost, maximal_error, compute_fast,d(moment));
                R(moment) = net.reliability.rel;
            end
            net.reliability_in_time = R;
            net.arc_reliability = r;
        end
        function plot_time_reliablity(net)
            t = net.time;
            R = net.reliability_in_time;
            r = net.arc_reliability;
            a = [];
            figure;
            for i = 1:size(r,1)
                plot(t, r(i,:));
                hold on;
                a =[a, "arc "+i];
            end
            legend(a);
            xlabel("time");
            ylabel("Arc Reliability");
            figure;
            plot(t,R);
            xlabel("time");
            ylabel("System Reliability");
            figure;
            plot(t, net.demand_in_time);
            xlabel("time");
            ylabel("Demand");
        end
        function [arcs_maintained,simulation_count] = minimum_arc_maintainence(net, maintainence_period, service_level, maximum_arcs_maintained, c)
            % implements our maintenence algorithm and returns  a cell
            % array of maintained arcs at each maintenece period and the
            % number of resimulations needed.
            % this method updates the property arc_reliability.
            time = net.time;
            demand_in_time = net.demand_in_time;
            r_original = net.arc_reliability;
            editted_arc_reliability = r_original;
            time_dependent_reliability = ones(size(time));
            % move sequentially through out time whenever reliability falls below
            % srvice level, then do a maintence action for each maintenece period.
            % then do simulation for only maintence period
            simulation_count = ceil(range(time) / maintainence_period);
            arcs_maintained= cell(1, simulation_count);
            for i = 1:simulation_count
                time_window = find(time >= (i-1)*maintainence_period  & time <= i * maintainence_period);
                net.time = time(time_window);
                net.demand_in_time = demand_in_time(time_window);

                arc_reliability = editted_arc_reliability(:, time_window);         % arc eliability that can be maintained
                net.reliability_dependent_time(c, [], [], arc_reliability);
                time_dependent_reliability(time_window) = net.reliability_in_time; % system reliability to be affected
                if i > 1
                    differnce = (arc_reliability(:,1) - arc_reliability(:,end));
                    [~, I] = sort(differnce);
                    [~, maintained_arc] = min(differnce);
                    if any(time_dependent_reliability(time_window) < service_level)
                        % Find arc with highest difference thenmaintain it
                        % maintaining arc means changing its reliability strting from
                        % this period and so on
                        % resimulation is done
                        for j = 1:maximum_arcs_maintained
                            maintained_arc = I(1:j);
                            arcs_maintained{i} = maintained_arc;
                            x = time_window(1):length(time);
                            editted_arc_reliability(maintained_arc, x) = r_original(maintained_arc, 1:length(x));

                            arc_reliability = editted_arc_reliability(:, time_window);         % arc eliability that can be maintained
                            net.reliability_dependent_time(c, [], [], arc_reliability);
                            time_dependent_reliability(time_window) = net.reliability_in_time; % system reliability to be affected
                            if all(time_dependent_reliability(time_window) > service_level)
                                break
                            end
                        end
                    end
                end
            end
            net.time = time;
            net.reliability_in_time = time_dependent_reliability;
            net.arc_reliability = editted_arc_reliability;
        end

    end
end
%% Used Functions
function F=find_combinations(f,deg)
str1='[';
str2=str1;
for i=1:deg
    str1=[str1,sprintf('h%d, ',i)];
    str2=[str2, sprintf('h%d(:), ',i)];
end
str1(end-1:end)=[];
str1=[str1,']'];
str2(end-1:end)=[];
str2=[str2,']'];
eval([str1,'=ndgrid(f);']);
eval(['F=',str2,';']);
end
function y=pr_great(x,CP)
% Make some error firing messages to match lengths or sum of probability
% distibutions
h=zeros(size(x));
for i=1:length(x)
    h(i)=sum(CP{i}(x(i)+1:end));
end
y=prod(h);
end
function [Pout, cyclic]=update_path_vectors(P,path_id,loc_to,loc_from,to,from)
insert_to=cellmat(1,length(loc_to), 1,length(P{path_id}));
for i=1:length(loc_to)
    insert_to{i}=P{path_id};
    insert_to{i}(end+1)=from(loc_to(i));
end
if ~isempty(loc_from)
    insert_from=cellmat(1,length(loc_from), 1,length(P{path_id}));
    for i=1:length(loc_from)
        insert_from{i}=P{path_id};
        insert_from{i}(end+1)=to(loc_from(i));
    end
else, insert_from=[];
end
insert=[insert_to insert_from];
try
    Pout=[P{1:path_id-1} insert P{path_id+1:end}];
catch
    try
        Pout=[insert  P{path_id+1:end}];
    catch
        Pout=insert;
    end
end
rm=[];
cyclic=0;
for i=1:length(Pout)
    if length(unique(Pout{i}))<length(Pout{i})
        rm=[rm i];
        cyclic=1;
    end
end
Pout(rm)=[];
end
function p=prob_state_greater_or_eq(target_state,CP)
maximal_cap=cellfun(@(x) length(x), CP)-1;
if length(target_state)~=length(maximal_cap) || length(target_state)~=length(CP)
    error('Some Arc Data are missing')
end
p=1;
for i=1:length(target_state)
    p=p*sum(CP{i}(target_state(i)+1:end));
end
end
function x_out=threshold(x,v)
x(x>v)=x(x>v)-v;
x_out=x;
end
function X = combinations(lb, ub, A, b, C,d)
if length(lb)~=length(ub)
    error('Bounds a, b must be same length as x')
end
if any(ub<lb)
    error('b is not the upper bound')
end
x=cell(size(lb));
str3=[];
for i=1:length(lb)
    x{i}=lb(i):ub(i);
    str3=[str3, 'x{', num2str(i), '}, '];
end
str3(end-1:end)=[];
eval(sprintf('X=cartprod(A, b, C,d, %s);',str3));

end
function X = cartprod(A,b,C,d,varargin)
%CARTPROD Cartesian product of multiple sets.
%
%   X = CARTPROD(A,B,C,...) returns the cartesian product of the sets
%   A,B,C, etc, where A,B,C, are numerical vectors.
%
%   Example: A = [-1 -3 -5];   B = [10 11];   C = [0 1];
%
%   X = cartprod(A,B,C)
%   X =
%
%     -5    10     0
%     -3    10     0
%     -1    10     0
%     -5    11     0
%     -3    11     0
%     -1    11     0
%     -5    10     1
%     -3    10     1
%     -1    10     1
%     -5    11     1
%     -3    11     1
%     -1    11     1
%
%   This function requires IND2SUBVECT, also available (I hope) on the MathWorks
%   File Exchange site.
numSets = length(varargin);
for i = 1:numSets
    thisSet = sort(varargin{i});
    if ~isequal(prod(size(thisSet)),length(thisSet))
        error('All inputs must be vectors.')
    end
    if ~isnumeric(thisSet)
        error('All inputs must be numeric.')
    end
    if ~isequal(thisSet,unique(thisSet))
        error(['Input set' ' ' num2str(i) ' ' 'contains duplicated elements.'])
    end
    sizeThisSet(i) = length(thisSet);
    varargin{i} = thisSet;
end
% X = zeros(prod(sizeThisSet),numSets);
X=sparse(0,0);
parfor i = 1:prod(sizeThisSet)
    h=sparse(1, numSets);
    % Envision imaginary n-d array with dimension "sizeThisSet" ...
    % = length(varargin{1}) x length(varargin{2}) x ...

    ixVect = ind2subVect(sizeThisSet,i);

    for j = 1:numSets
        h(1,j) = varargin{j}(ixVect(j));
    end
    if full(all(A*h'<=b)) && full(all(C*h'==d))
        X=[X; h];
    end
end
end
function X = ind2subVect(siz,ndx)
%IND2SUBVECT Multiple subscripts from linear index.
%   IND2SUBVECT is used to determine the equivalent subscript values
%   corresponding to a given single index into an array.
%
%   X = IND2SUBVECT(SIZ,IND) returns the matrix X = [I J] containing the
%   equivalent row and column subscripts corresponding to the index
%   matrix IND for a matrix of size SIZ.
%
%   For N-D arrays, X = IND2SUBVECT(SIZ,IND) returns matrix X = [I J K ...]
%   containing the equivalent N-D array subscripts equivalent to IND for
%   an array of size SIZ.
%
%   See also IND2SUB.  (IND2SUBVECT makes a one-line change to IND2SUB so as
%   to return a vector of N indices rather than retuning N individual
%   variables.)%IND2SUBVECT Multiple subscripts from linear index.
%   IND2SUBVECT is used to determine the equivalent subscript values
%   corresponding to a given single index into an array.
%
%   X = IND2SUBVECT(SIZ,IND) returns the matrix X = [I J] containing the
%   equivalent row and column subscripts corresponding to the index
%   matrix IND for a matrix of size SIZ.
%
%   For N-D arrays, X = IND2SUBVECT(SIZ,IND) returns matrix X = [I J K ...]
%   containing the equivalent N-D array subscripts equivalent to IND for
%   an array of size SIZ.
%
%   See also IND2SUB.  (IND2SUBVECT makes a one-line change to IND2SUB so as
%   to return a vector of N indices rather than returning N individual
%   variables.)

% All MathWorks' code from IND2SUB, except as noted:
n = length(siz);
k = [1 cumprod(siz(1:end-1))];
ndx = ndx - 1;
for i = n:-1:1,
    X(i) = floor(ndx/k(i))+1;      % replaced "varargout{i}" with "X(i)"
    ndx = rem(ndx,k(i));
end
end
function r = reliability_matrix(t,dist, parameters)
% t:         time
% dist:      used distributions
% parameters:used parameters for each which is a cell containing parameter
% for each arc
% each row in r represents arc
% each column represents point in time t
r = zeros(length(dist), length(t));
for arc = 1:length(dist)
    switch (dist(arc))
        case "normal"
            mu = parameters{arc}(1);
            sigma = parameters{arc}(2);
            r(arc,:) = exp(-0.5 * ((t-mu)/sigma).^2);
        case "weibull"
            alpha = parameters{arc}(1);
            beta = parameters{arc}(2);
            r(arc,:) = exp(-(t/alpha).^beta);
        case "exponential"
            lambda = parameters{arc}(1);
            r(arc,:) = exp(-lambda * t);
    end
end
end
