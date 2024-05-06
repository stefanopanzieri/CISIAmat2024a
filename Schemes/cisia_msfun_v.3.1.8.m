function cisia_msfun(block)
%MSFUNTMPL A Template for a MATLAB S-Function
%   The MATLAB S-function is written as a MATLAB function with the
%   same name as the S-function. Replace 'msfuntmpl' with the name
%   of your S-function.  
%
%   It should be noted that the MATLAB S-function is very similar
%   to Level-2 C-Mex S-functions. You should be able to get more 
%   information for each of the block methods by referring to the
%   documentation for C-Mex S-functions.
%  
%   Copyright 2003-2010 The MathWorks, Inc.
  
%
% The setup method is used to setup the basic attributes of the
% S-function such as ports, parameters, etc. Do not add any other
% calls to the main body of the function.  
%
%
% VER. 3.1.8
% DATE 31/01/2023 
% AUTHOR: Stefano Panzieri - Roma Tre University
%
%



setup(block);


%endfunction

% Function: setup ===================================================
% Abstract:
%   Set up the S-function block's basic characteristics such as:
%   - Input ports
%   - Output ports
%   - Dialog parameters
%   - Options
% 
%   Required         : Yes
%   C-Mex counterpart: mdlInitializeSizes
%

%% 
function setup(block)

global cisia;

cisia.gcs=extractBefore(gcs,'/');
if strcmp(cisia.gcs,'')
    cisia.gcs=gcs;
end



cisia.offset=15;
%cisia.major_sampling_time=block.DialogPrm(2).Data;
cisia.last_input_update=1;
cisia.first_run=1;
cisia.last_major_timehit=0;
cisia.major_time=0;
cisia.force_major_timehit=0;
cisia.force_major_update=0;
cisia.last_minor_timehit=0;
cisia.time_past_sec=0;
%cisia.colors=0;
%cisia.phase=0;
cisia.savetofile=0;


if strcmp(get_param(cisia.gcs,'SimulationStatus'),'initializing')
    cisia.num_blocks=0;
    cisia.max_blocks=0;
end
    

if ~isfield(cisia,'phase') 
    disp('PHASE: Setup')
    cisia.phase=1;
    cisia.tic=tic;
elseif cisia.phase==2
    disp('PHASE: Setup')
    cisia.phase=1;
    cisia.tic=tic;
end



if strcmp(get_param(cisia.gcs,'SimulationStatus'),'stopped') || strcmp(get_param(cisia.gcs,'SimulationStatus'),'initializing')
    

    load cisia_init.mat connection
    
    
    if ~exist('mask_values','var')
        
        curr_sys=strsplit(gcs,{'/'});
        
        mask_values=get_param(strcat(curr_sys{1},'/CISIA_MASTER (0)'),'MaskValues');
        
        cisia.loadfromfile=0;
        if strcmp(mask_values{6},'on')
            cisia.loadfromfile=1;
        end
        
        cisia.loadfrommask=0;
        if strcmp(mask_values{7},'on')
            cisia.loadfrommask=1;
        end
        
    end
    

    
    if ~isfield(cisia,'conn')
        cisia.conn = database(connection.databasename,connection.user,connection.password,connection.driver,connection.url);
        execute(cisia.conn,['USE ' connection.schema])
        disp(strcat('Connected to database and schema:',connection.schema))
        
    elseif ~isopen(cisia.conn)
        cisia.conn = database(connection.databasename,connection.user,connection.password,connection.driver,connection.url);
        execute(cisia.conn,['USE ' connection.schema])
        disp(strcat('Connected to database and schema:',connection.schema))
        
    else
        execute(cisia.conn,['USE ' connection.schema])
    end
    
    
end

    

name_entity=block.DialogPrm(1).Data;

% Use the project specified in MASTER block

if ~isfield(cisia,'id_project') 

    if ~strcmp(name_entity,'CISIA_MASTER')

        a=[cisia.gcs '/CISIA_MASTER (0)'];
        DP=get_param(a,'Parameter3');
        DP=strrep(DP,'''','');

    else
        DP=block.DialogPrm(3).Data;
    end
    


    % let's go searching for id_project
    query=strcat('SELECT * FROM projects WHERE name_project=''',DP,'''');
    data_project=fetch(cisia.conn, query);

    if height(data_project)==0
        disp(strcat('Project does not exist:',block.DialogPrm(3).Data))
        errorStruct.message = 'name of Project doesn''t exist!';
        errorStruct.identifier = 'CISIA:wrong_project';  
        error(errorStruct) 
        return
    end
    cisia.id_project=data_project.id_project(1);

 
end

  
%% --------------------------------------------
  if strcmp(name_entity,'CISIA_MASTER')
      
   

    disp('MASTER SETUP')
    drawnow('update')
    cisia.minor_sampling_time=block.DialogPrm(9).Data;
    cisia.major_sampling_time=block.DialogPrm(2).Data;
    cisia.time_index=0;
    
    cisia.save_major_hits=block.DialogPrm(4).Data;

    
    
    if strcmp(get_param(cisia.gcs,'SimulationStatus'),'initializing')
        cisia.skipsaving=block.DialogPrm(10).Data;
    end
       
    
    id_entity=0;
    % Register the number of ports.
    % One for each resource
    block.NumInputPorts  = 0; 
    block.NumOutputPorts = 4; 
    % Imposta il nome del blocco Simulink  
    PortHandles=get_param(gcb,'PortHandles');
    set_param(PortHandles.Outport(1),'Name','MINOR HITS');
    set_param(PortHandles.Outport(2),'Name','MAJOR HITS');
    set_param(PortHandles.Outport(3),'Name','DELTA TIME');
    set_param(PortHandles.Outport(4),'Name','TIME PAST');
    
    set_param(gcb,'Name',[name_entity ' (' num2str(id_entity) ')']);
    h=Simulink.Mask.get(gcb);
    set(h,'Display','disp(''MASTER BLOCK'')');
    
    % Set up the port properties to be inherited or dynamic.
    %block.SetPreCompInpPortInfoToDynamic;
    %block.SetPreCompOutPortInfoToDynamic;

    
  
    % Override the output port properties.
    block.OutputPort(1).DatatypeID  = 0; % double
    block.OutputPort(1).Complexity  = 'Real';
    block.OutputPort(1).Dimensions = 1;
    block.OutputPort(1).SamplingMode = 'Sample';
      
    block.OutputPort(2).DatatypeID  = 0; % double
    block.OutputPort(2).Complexity  = 'Real';
    block.OutputPort(2).Dimensions = 1;
    block.OutputPort(2).SamplingMode = 'Sample';
    
    block.OutputPort(3).DatatypeID  = 0; % double
    block.OutputPort(3).Complexity  = 'Real';
    block.OutputPort(3).Dimensions = 1;
    block.OutputPort(3).SamplingMode = 'Sample';
    
    block.OutputPort(4).DatatypeID  = 0; % double
    block.OutputPort(4).Complexity  = 'Real';
    block.OutputPort(4).Dimensions = 1;
    block.OutputPort(4).SamplingMode = 'Sample';
    
    block.NumContStates = 0;
    
    block.NumDialogPrms     = 10;
    block.DialogPrmsTunable = {'Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable'};

    block.SampleTimes=[-2 0];
    
    
    
    set_param(gcb,'BackgroundColor','cyan')
    
    cisia.colors=block.DialogPrm(5).Data;
    cisia.colormap=hsv(60);
    
    
    
    
%% --------------------------------------------    
  elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'LINK')),'1') % if CISIA LINK
      
    % disp(strcat('LINK Setup:',block.DialogPrm(1).Data))    
    
      
  % Trova id_link
  query=strcat('SELECT * FROM dynamic_links WHERE link_name=''',name_entity,''' AND id_project=',num2str(cisia.id_project));
  data_link=fetch(cisia.conn, query);
  
  if height(data_link)==0
    disp(strcat('Link does not exist:',block.DialogPrm(1).Data))
    errorStruct.message = 'name of Link doesn''t exist!';
    errorStruct.identifier = 'CISIA:wrong_link';  
    error(errorStruct) 
    return
  end
  
  id_link=data_link.id_link(1);
  
  
  cisia.id_link=id_link; % only for check parameters when simulation is stopped
 
  if block.DialogPrm(7).Data
    num_inputs=2;    
  else
    num_inputs=1;
  end
  
  
  num_outputs=block.DialogPrm(4).Data;
  
  % Register the number of ports.
  % One for each resource
  block.NumInputPorts  = num_inputs; 
  block.NumOutputPorts = num_outputs; 

  
  
  
  % Imposta il nome del blocco e della maschera e il colore
  h=Simulink.Mask.get(gcb);
  set(h,'Display',strcat('disp(''','D LINK',''')'));
  set_param(gcb,'Name',[data_link.link_name{1} ' (' num2str(data_link.id_link(1)) ')']);
  set_param(gcb,'BackgroundColor','[0 0.6 0.9]')   
  
  % Imposta i nomi dei segnali in uscita  
  PortHandles=get_param(gcb,'PortHandles');
  if num_outputs>0
  for i=1:num_outputs
    set_param(PortHandles.Outport(i),'Name',get(PortHandles.Inport(1),'Name'));
  end
  end  
  
  
  %disp('Port Setup')
  
  
  % Set up the port properties to be inherited or dynamic.
  block.SetPreCompInpPortInfoToDynamic;
  block.SetPreCompOutPortInfoToDynamic;

  % Override the input port properties.
  block.InputPort(1).DatatypeID  = 0;  % double
  block.InputPort(1).Complexity  = 'Real';
  block.InputPort(1).Dimensions = block.DialogPrm(6).Data ;
  
  
  if block.DialogPrm(7).Data
      
    block.InputPort(2).DatatypeID  = 0;  % double
    block.InputPort(2).Complexity  = 'Real';
    block.InputPort(2).Dimensions = 1 ; 
    
  end
  
  % Override the output port properties.
  if block.NumOutputPorts>0
      for i=1:block.NumOutputPorts
        block.OutputPort(i).DatatypeID  = 0; % double
        block.OutputPort(i).Complexity  = 'Real';
        block.OutputPort(i).Dimensions = block.DialogPrm(6).Data;
      end
  end
  
  
  % Register the parameters.
  % Parameters: 
  % - name of the entity
  
  block.NumDialogPrms     = 7;
  block.DialogPrmsTunable = {'Tunable', 'Tunable','Tunable','Tunable','Tunable','Tunable','Tunable'};
  
  % Set up the continuous states.
  % this must be done before defiing Sample Times
  
  %disp('Setup continuous states')
  
  block.NumContStates = 0;
  
  % Register the sample times.
  %  [0 offset]            : Continuous sample time
  %  [positive_num offset] : Discrete sample time
  %
  %  [-1, 0]               : Inherited sample time
  %  [-2, 0]               : Variable sample time
  
  % block.SampleTimes = [0 0]; tempo continuo
  
  block.SampleTimes=[-2 0]; % VERSIONE ORIGINALE
  
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'ROUTE')),'1') % if CISIA ROUTE
      
    % disp(strcat('ROUTE Setup:',block.DialogPrm(1).Data))    
    % drawnow('update')
      
  % Trova id_link
  query=strcat('SELECT * FROM route_link WHERE routing_name=''',name_entity,''' AND id_project=',num2str(cisia.id_project));
  data_routing=fetch(cisia.conn, query);
  
  if height(data_routing)==0
    disp(strcat('Routing Link does not exist:',block.DialogPrm(1).Data))
    errorStruct.message = 'name of Routing Link doesn''t exist!';
    errorStruct.identifier = 'CISIA:wrong_routing';  
    error(errorStruct) 
    return
  end
  
  id_routing=data_routing.id_routing(1);
  
  
  cisia.id_routing=id_routing; % only for check parameters when simulation is stopped
 
  if block.DialogPrm(7).Data
    num_inputs=2;    
  else
    num_inputs=1;
  end
  
  
  num_outputs=block.DialogPrm(4).Data;
  
  % Register the number of ports.
  % One for each resource
  block.NumInputPorts  = num_inputs; 
  block.NumOutputPorts = num_outputs; 

  
  
  
  % Imposta il nome del blocco e della maschera e il colore
  h=Simulink.Mask.get(gcb);
  set(h,'Display',strcat('disp(''','ROUTE',''')'));
  set_param(gcb,'Name',[data_routing.routing_name{1} ' (' num2str(data_routing.id_routing(1)) ')']);
  set_param(gcb,'BackgroundColor','[0.8784    0.7294    0.8510]')   
  
  % Imposta i nomi dei segnali in uscita  
  PortHandles=get_param(gcb,'PortHandles');
  if num_outputs>0
  for i=1:num_outputs
    set_param(PortHandles.Outport(i),'Name',get(PortHandles.Inport(1),'Name'));
  end
  end  
  
  
  %disp('Port Setup')
  %drawnow('update')
  
  
  % Set up the port properties to be inherited or dynamic.
  block.SetPreCompInpPortInfoToDynamic;
  block.SetPreCompOutPortInfoToDynamic;

  % Override the input port properties.
  block.InputPort(1).DatatypeID  = 0;  % double
  block.InputPort(1).Complexity  = 'Real';
  block.InputPort(1).Dimensions = block.DialogPrm(6).Data ;
  
  
  if block.DialogPrm(7).Data
      
    query=strcat('SELECT * FROM route_link AS a JOIN resources AS c WHERE  a.id_project=c.id_project AND a.id_res=c.id_res AND a.routing_name=''', block.DialogPrm(1).Data,  ''' AND a.id_project=',string(cisia.id_project));
    data_route=fetch(cisia.conn,query);
    
    % resource elements (vettore a n dimensioni di 0 e 1)
    block.InputPort(2).DatatypeID  = 0;  % double
    block.InputPort(2).Complexity  = 'Real';
    block.InputPort(2).Dimensions = block.DialogPrm(4).Data*data_route.dim_res(1); 
    
    
  end
  
  % Override the output port properties.
  if block.NumOutputPorts>0
      for i=1:block.NumOutputPorts
        block.OutputPort(i).DatatypeID  = 0; % double
        block.OutputPort(i).Complexity  = 'Real';
        block.OutputPort(i).Dimensions = block.DialogPrm(6).Data;
      end
  end
  
  
  % Register the parameters.
  % Parameters: 
  % - name of the entity
  
  block.NumDialogPrms     = 7;
  block.DialogPrmsTunable = {'Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable'};
  
  % Set up the continuous states.
  % this must be done before defiing Sample Times
  
  %disp('Setup continuous states')
  
  block.NumContStates = 0;
  
  % Register the sample times.
  %  [0 offset]            : Continuous sample time
  %  [positive_num offset] : Discrete sample time
  %
  %  [-1, 0]               : Inherited sample time
  %  [-2, 0]               : Variable sample time
  
  % block.SampleTimes = [0 0]; tempo continuo
  
  block.SampleTimes=[-2 0]; % VERSIONE ORIGINALE
  
 %% CISIA SAVE
  elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'SAVE')),'1') % if CISIA SAVE
      
    % disp(strcat('SAVE Setup:',block.DialogPrm(1).Data))    
    % drawnow('update')
      
  % Trova id_save2db
  
  query=strcat('SELECT * FROM save2db AS a JOIN resources AS b WHERE a.id_res=b.id_res AND save_name=''',name_entity,''' AND a.id_project=',num2str(cisia.id_project));
  data_save=fetch(cisia.conn, query);
  
  if height(data_save)==0
    disp(strcat('Save2DB does not exist:',block.DialogPrm(1).Data))
    errorStruct.message = 'name of Save2DB doesn''t exist!';
    errorStruct.identifier = 'CISIA:wrong_save2db';  
    error(errorStruct) 
    return
  end
  
  id_save2db=data_save.id_save2db(1);
  
  
  cisia.id_save2db=id_save2db; % only for check parameters when simulation is stopped
 
  num_inputs=1;
  num_outputs=0;
  
  % Register the number of ports.
  % One for each resource
  block.NumInputPorts  = num_inputs; 
  block.NumOutputPorts = num_outputs; 

  
  
  
  % Imposta il nome del blocco e della maschera e il colore
  h=Simulink.Mask.get(gcb);
  %set(h,'Display',strcat('disp(''','SAVE',''')'));
  set_param(gcb,'Name',[data_save.save_name{1} ' (' num2str(data_save.id_save2db(1)) ')']);
  set_param(gcb,'BackgroundColor','[0.7 1 0]')   
  
  
  % Imposta i nomi dei segnali in uscita  
  
  
  %disp('Port Setup')
  
  
  % Set up the port properties to be inherited or dynamic.
  block.SetPreCompInpPortInfoToDynamic;
  block.SetPreCompOutPortInfoToDynamic;

  % Override the input port properties.
  block.InputPort(1).DatatypeID  = 0;  % double
  block.InputPort(1).Complexity  = 'Real';
  block.InputPort(1).Dimensions = data_save.dim_res(1);
  
  
  % Register the parameters.
  % Parameters: 
  % - name of the entity
  
  block.NumDialogPrms     = 7;
  block.DialogPrmsTunable = {'Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable'};
  
  % Set up the continuous states.
  % this must be done before defiing Sample Times
  
  %disp('Setup continuous states')
  
  block.NumContStates = 0;
  
  % Register the sample times.
  %  [0 offset]            : Continuous sample time
  %  [positive_num offset] : Discrete sample time
  %
  %  [-1, 0]               : Inherited sample time
  %  [-2, 0]               : Variable sample time
  
  % block.SampleTimes = [0 0]; tempo continuo
  
  block.SampleTimes=[-2 0];
  %block.SampleTimes=[-1 0];
      
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'RFDB')),'1') % if CISIA Read From Data Base RFDB
      
    
      
  % Trova id_rfdb
  query=strcat('SELECT * FROM rfdb_node WHERE rfdb_name=''',name_entity,''' AND id_project=',num2str(cisia.id_project));
  data_rfdb=fetch(cisia.conn, query);
  
  if height(data_rfdb)==0
    disp(strcat('RFDB does not exist:',block.DialogPrm(1).Data))
    errorStruct.message = 'name of RFDB doesn''t exist!';
    errorStruct.identifier = 'CISIA:wrong_rfdb';  
    error(errorStruct) 
    return
  end
  
  id_rfdb=data_rfdb.id_rfdb(1);
  
  % Register the number of ports.
  % One for each resource
  block.NumInputPorts  = 0; 
  block.NumOutputPorts = 1; 

  
  % Imposta il nome del blocco e della maschera e il colore
  h=Simulink.Mask.get(gcb);
  set(h,'Display',strcat('disp(''','RFDB',''')'));
  set_param(gcb,'Name',[data_rfdb.rfdb_name{1} ' (' num2str(data_rfdb.id_rfdb(1)) ')']);
  set_param(gcb,'BackgroundColor','[0.4 0.6 0.1]')   
  
  % Imposta i nomi dei segnali in uscita  
  PortHandles=get_param(gcb,'PortHandles');
  set_param(PortHandles.Outport(1),'Name',block.DialogPrm(4).Data);

  
  
  %disp('Port Setup')
  
  
  % Set up the port properties to be inherited or dynamic.
  block.SetPreCompInpPortInfoToDynamic;
  block.SetPreCompOutPortInfoToDynamic;

  
  % Override the output port properties.
    block.OutputPort(1).DatatypeID  = 0; % double
    block.OutputPort(1).Complexity  = 'Real';
    block.OutputPort(1).Dimensions = 1;
    block.OutputPort(1).SamplingMode = 'Sample';
       
  
  % Register the parameters.
  % Parameters: 
  % - name of the entity
  
  block.NumDialogPrms     = 5;
  block.DialogPrmsTunable = {'Tunable', 'Tunable','Tunable','Tunable','Tunable'};
  
  % Set up the continuous states.
  % this must be done before defiing Sample Times
  
  %disp('Setup continuous states')
  
  block.NumContStates = 0;
  
  % Register the sample times.
  %  [0 offset]            : Continuous sample time
  %  [positive_num offset] : Discrete sample time
  %
  %  [-1, 0]               : Inherited sample time
  %  [-2, 0]               : Variable sample time
  
  % block.SampleTimes = [0 0]; tempo continuo
  
  block.SampleTimes=[-2 0]; % VERSIONE ORIGINALE
  
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 else %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NORMAL ENTITY %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
  %disp(strcat('ENTITY Setup:',block.DialogPrm(1).Data))
  drawnow('update')
  
  filename=strcat(gcs,'/',name_entity);
  directory=strcat(gcs);
  
  if ~exist(directory, 'dir')
      mkdir(directory)
  end
  
  
  if cisia.loadfromfile==1
    load(filename)
  end
      
  % disp(['reading information from database for entity ' string(id_entity)])
  %conn = database('cisia','root','cisia_mat');
  
   
  
  % Trova id_entity
  if cisia.loadfromfile==0
    query=strcat('SELECT * FROM entity WHERE name_entity=''',name_entity,''' AND id_project=''',num2str(cisia.id_project),'''');
    data_entity=fetch(cisia.conn, query);
  end
    
  
  if height(data_entity)==0
    disp(strcat('Entity does not exist:',block.DialogPrm(1).Data))
    errorStruct.message = 'name of Entity doesn''t exist!';
    errorStruct.identifier = 'CISIA:wrong_entity';  
    error(errorStruct) 
    return
  end
  
  id_entity=data_entity.id_entity(1);
  id_type=data_entity.id_type;
  
  cisia.id_type=id_type; % only for check parameters when simulation is stopped
  
  
  %Numero di Input e di output
  
  if cisia.loadfromfile==0
    query=strcat('SELECT * FROM entity_port WHERE id_entity=',string(id_entity),' AND id_project=',num2str(cisia.id_project));
    data_port=fetch(cisia.conn, query);
  end
  
  input=data_port(data_port.type_port=="INPUT",'id_port');
  num_inputs=height(input);
  
  output=data_port(data_port.type_port=="OUTPUT",'id_port');
  num_outputs=height(output);

  
  state_in_output=0; % bring state variables to output
  if block.DialogPrm(5).Data
      state_in_output=1;
      if cisia.loadfromfile==0
        query=strcat('SELECT * FROM status WHERE id_entity=', num2str(id_entity),' AND id_project=',num2str(cisia.id_project), ' ORDER BY id_var');
        data3=fetch(cisia.conn, query);
      end
      num_state_var=height(data3);
  end
    
  % Register the number of ports.
  % One for each resource
  block.NumInputPorts  = num_inputs; 
  block.NumOutputPorts = num_outputs+state_in_output; 

  
  
  % Imposta il nome del blocco Simulink  
  
  
  % Imposta il nome del blocco e della maschera
  if cisia.loadfromfile==0
    query2=strcat('SELECT * FROM entity_type WHERE id_type=',string(id_type),' AND id_project=',num2str(cisia.id_project));
    data_entity_type=fetch(cisia.conn, query2);
  end
  
  
  h=Simulink.Mask.get(gcb);
  
  found=0;
  
  imagefile=strcat('Icons/',name_entity,'.png'); %MAC OSx
  if exist(imagefile,'file')
    set(h,'Display',strcat('image(''',imagefile,''')'));
    found=1;
  else
    imagefile=strcat('Icons/',name_entity,'.png'); % WIN64
    if exist(imagefile,'file')
        set(h,'Display',strcat('image(''',imagefile,''')'));
        found=1;
    end
  end
  
  
  if found==0
      imagefile=strcat('Icons/',data_entity_type.name_type{1},'.png'); %MAC OSx
      if exist(imagefile,'file')
        set(h,'Display',strcat('image(''',imagefile,''')'));
        found=1;
      else
        imagefile=strcat('Icons/',data_entity_type.name_type{1},'.png'); % WIN64
        if exist(imagefile,'file')
            set(h,'Display',strcat('image(''',imagefile,''')'));
            found=1;
        else
            set(h,'Display',strcat('disp(''',data_entity_type.name_type{1},''')'));
        end
      end
  end  
  
  set_param(gcb,'Name',[name_entity ' (' num2str(id_entity) ')']);
  
  % Imposta il colore della maschera
  col=data_entity_type.color{1};
  color=[hex2dec(col(2:3)) hex2dec(col(4:5)) hex2dec(col(6:7))]/255;
  color=['[' num2str(color) ']'];
   
  set_param(gcb,'BackgroundColor',color)  
  
  
  
%% Controllo correttezza variabili di ingresso 
   % recupera i nomi delle risorse in ingresso
   if cisia.loadfromfile==0
     query=strcat('SELECT * FROM entity_port AS a JOIN resources AS b ON a.id_res=b.id_res where a.id_entity=', num2str(id_entity), ' AND type_port=''INPUT''', ' AND a.id_project=',num2str(cisia.id_project), ' ORDER BY a.id_res');
     data_input_port=fetch(cisia.conn, query);
   end
   
   inp_port_dim=data_input_port.dim_res;
   
   
  %disp('Nomi in ingresso')
  
  
  % Imposta i nomi dei segnali in uscita  
  if cisia.loadfromfile==0
      query=strcat('SELECT * FROM entity_port AS a JOIN resources AS b ON a.id_res=b.id_res where a.id_entity=', num2str(id_entity), ' AND a.id_project=',num2str(cisia.id_project) ,' AND type_port=''OUTPUT'' ORDER BY a.id_res');
      data_output_port=fetch(cisia.conn, query);
  end
  
  out_port_dim=data_output_port.dim_res;
   
  PortHandles=get_param(gcb,'PortHandles');
  
  if num_outputs>0
  for i=1:num_outputs
    set_param(PortHandles.Outport(i),'Name',data_output_port.name_res{i});
  end
  end  
 
  if state_in_output>0
      set_param(PortHandles.Outport(num_outputs+1),'Name','STATE');
  end
  
  
  %% Port Setup
  %disp('Port Setup')
  %drawnow('update')
  
  % Set up the port properties to be inherited or dynamic.
  block.SetPreCompInpPortInfoToDynamic;
  block.SetPreCompOutPortInfoToDynamic;

  % Override the input port properties.
  if block.NumInputPorts>0
      %a=block.DialogPrm(1).Data
      %b=block.NumInputPorts
      %c=size(inp_port_dim)
      
      
  for i=1:block.NumInputPorts
     
      
    block.InputPort(i).DatatypeID  = 0;  % double
    block.InputPort(i).Complexity  = 'Real';
    block.InputPort(i).Dimensions = inp_port_dim(i);
    block.InputPort(i).DirectFeedthrough = false;
  end 
  end  
  
  % Override the output port properties.
  if block.NumOutputPorts>0
  for i=1:block.NumOutputPorts-state_in_output
    block.OutputPort(i).DatatypeID  = 0; % double
    block.OutputPort(i).Complexity  = 'Real';
    block.OutputPort(i).Dimensions = out_port_dim(i);
    block.OutputPort(i).SamplingMode = 'Sample';
  end
  end
  
  if state_in_output>0
    block.OutputPort(block.NumOutputPorts).DatatypeID  = 0; % double
    block.OutputPort(block.NumOutputPorts).Complexity  = 'Real';
    block.OutputPort(block.NumOutputPorts).Dimensions = num_state_var;
    block.OutputPort(block.NumOutputPorts).SamplingMode = 'Sample';
  end
  
  
  
  % Register the parameters.
  % Parameters: 
  % - name of the entity
  
  block.NumDialogPrms     = 15;
  block.DialogPrmsTunable = {'Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable','Tunable'};
  
  % Set up the continuous states.
  % this must be done before defiing Sample Times
  
  %disp('Setup continuous states')
  if cisia.loadfromfile==0
      query=strcat('SELECT * FROM status WHERE id_entity=', num2str(id_entity), ' AND val_type=''CONTINUOUS''', ' AND id_project=',num2str(cisia.id_project), ' ORDER BY id_var');
      data_status=fetch(cisia.conn, query);
  end
  
  num_cont_states = height(data_status);
  
  block.NumContStates = num_cont_states;
  
  

  % Register the sample times.
  %  [0 offset]            : Continuous sample time
  %  [positive_num offset] : Discrete sample time
  %
  %  [-1, 0]               : Inherited sample time
  %  [-2, 0]               : Variable sample time
  
  % block.SampleTimes = [0 0]; tempo continuo
  
  if block.NumContStates>0
    block.SampleTimes=[0 0];
  else
    block.SampleTimes=[-2 0];
  end
  
  
  % salva in un file i vari fetch
  
  if cisia.loadfromfile==0
      
      if cisia.savetofile==1
      
          if state_in_output==1
            save_variables='save(filename,''data_entity'', ''data_port'',''data3'', ''data_entity_type'', ''data_input_port'', ''data_output_port'', ''data_status'')';
          else
            save_variables='save(filename,''data_entity'', ''data_port'', ''data_entity_type'', ''data_input_port'', ''data_output_port'', ''data_status'')';  
          end
          eval(save_variables)

      end
      
      
  end
  
  
  
  %block.SampleTimes = [block.DialogPrm(2).Data 0];
  
  end % if NOT MASTER OR LINK OR SAVE
  

  

  
  % -----------------------------------------------------------------
  % Options
  % -----------------------------------------------------------------
  % Specify if Accelerator should use TLC or call back to the 
  % MATLAB file
  block.SetAccelRunOnTLC(false);
  
  % Specify the block simStateCompliance. The allowed values are:
  %    'UnknownSimState', < The default setting; warn and assume DefaultSimState
  %    'DefaultSimState', < Same SimState as a built-in block
  %    'HasNoSimState',   < No SimState
  %    'CustomSimState',  < Has GetSimState and SetSimState methods
  %    'DisallowSimState' < Errors out when saving or restoring the SimState
  block.SimStateCompliance = 'DefaultSimState';
  
  % -----------------------------------------------------------------
  % The MATLAB S-function uses an internal registry for all
  % block methods. You should register all relevant methods
  % (optional and required) as illustrated below. You may choose
  % any suitable name for the methods and implement these methods
  % as local functions within the same file.
  % -----------------------------------------------------------------
   
  % -----------------------------------------------------------------
  % Register the methods called during update diagram/compilation.
  % -----------------------------------------------------------------
  
  % 
  % CheckParameters:
  %   Functionality    : Called in order to allow validation of the
  %                      block dialog parameters. You are 
  %                      responsible for calling this method
  %                      explicitly at the start of the setup method.
  %   C-Mex counterpart: mdlCheckParameters
  %
  block.RegBlockMethod('CheckParameters', @CheckPrms);

  %
  % SetInputPortSamplingMode:
  %   Functionality    : Check and set input and output port 
  %                      attributes and specify whether the port is operating 
  %                      in sample-based or frame-based mode
  %   C-Mex counterpart: mdlSetInputPortFrameData.
  %   (The DSP System Toolbox is required to set a port as frame-based)
  %
  block.RegBlockMethod('SetInputPortSamplingMode', @SetInpPortFrameData);
  
  %
  % SetInputPortDimensions:
  %   Functionality    : Check and set the input and optionally the output
  %                      port dimensions.
  %   C-Mex counterpart: mdlSetInputPortDimensionInfo
  %
  block.RegBlockMethod('SetInputPortDimensions', @SetInpPortDims);

  
  block.RegBlockMethod('SetInputPortDimensionsMode',  @SetInputDimsMode);
  
  
  %
  % SetOutputPortDimensions:
  %   Functionality    : Check and set the output and optionally the input
  %                      port dimensions.
  %   C-Mex counterpart: mdlSetOutputPortDimensionInfo
  %
  block.RegBlockMethod('SetOutputPortDimensions', @SetOutPortDims);
  
  %
  % SetInputPortDatatype:
  %   Functionality    : Check and set the input and optionally the output
  %                      port datatypes.
  %   C-Mex counterpart: mdlSetInputPortDataType
  %
  block.RegBlockMethod('SetInputPortDataType', @SetInpPortDataType);
  
  %
  % SetOutputPortDatatype:
  %   Functionality    : Check and set the output and optionally the input
  %                      port datatypes.
  %   C-Mex counterpart: mdlSetOutputPortDataType
  %
  block.RegBlockMethod('SetOutputPortDataType', @SetOutPortDataType);
  
  %
  % SetInputPortComplexSignal:
  %   Functionality    : Check and set the input and optionally the output
  %                      port complexity attributes.
  %   C-Mex counterpart: mdlSetInputPortComplexSignal
  %
  block.RegBlockMethod('SetInputPortComplexSignal', @SetInpPortComplexSig);
  
  %
  % SetOutputPortComplexSignal:
  %   Functionality    : Check and set the output and optionally the input
  %                      port complexity attributes.
  %   C-Mex counterpart: mdlSetOutputPortComplexSignal
  %
  block.RegBlockMethod('SetOutputPortComplexSignal', @SetOutPortComplexSig);
  
  %
  % PostPropagationSetup:
  %   Functionality    : Set up the work areas and the state variables. You can
  %                      also register run-time methods here.
  %   C-Mex counterpart: mdlSetWorkWidths
  %
  block.RegBlockMethod('PostPropagationSetup', @DoPostPropSetup);

  % -----------------------------------------------------------------
  % Register methods called at run-time
  % -----------------------------------------------------------------
  
  % 
  % ProcessParameters:
  %   Functionality    : Call to allow an update of run-time parameters.
  %   C-Mex counterpart: mdlProcessParameters
  %  
  block.RegBlockMethod('ProcessParameters', @ProcessPrms);

  % 
  % InitializeConditions:
  %   Functionality    : Call to initialize the state and the work
  %                      area values.
  %   C-Mex counterpart: mdlInitializeConditions
  % 
  block.RegBlockMethod('InitializeConditions', @InitializeConditions);
  
  % 
  % Start:
  %   Functionality    : Call to initialize the state and the work
  %                      area values.
  %   C-Mex counterpart: mdlStart
  %
  block.RegBlockMethod('Start', @Start);

  % 
  % Outputs:
  %   Functionality    : Call to generate the block outputs during a
  %                      simulation step.
  %   C-Mex counterpart: mdlOutputs
  %
  block.RegBlockMethod('Outputs', @Outputs);

  % 
  % Update:
  %   Functionality    : Call to update the discrete states
  %                      during a simulation step.
  %   C-Mex counterpart: mdlUpdate
  %
  block.RegBlockMethod('Update', @Update);

  % 
  % Derivatives:
  %   Functionality    : Call to update the derivatives of the
  %                      continuous states during a simulation step.
  %   C-Mex counterpart: mdlDerivatives
  %
  block.RegBlockMethod('Derivatives', @Derivatives);
  
  % 
  % Projection:
  %   Functionality    : Call to update the projections during a
  %                      simulation step.
  %   C-Mex counterpart: mdlProjections
  %
  block.RegBlockMethod('Projection', @Projection);
  
  % 
  % SimStatusChange:
  %   Functionality    : Call when simulation enters pause mode
  %                      or leaves pause mode.
  %   C-Mex counterpart: mdlSimStatusChange
  %
  block.RegBlockMethod('SimStatusChange', @SimStatusChange);
  
  % 
  % Terminate:
  %   Functionality    : Call at the end of a simulation for cleanup.
  %   C-Mex counterpart: mdlTerminate
  %
  block.RegBlockMethod('Terminate', @Terminate);

  %
  % GetSimState:
  %   Functionality    : Return the SimState of the block.
  %   C-Mex counterpart: mdlGetSimState
  %
  block.RegBlockMethod('GetSimState', @GetSimState);
  
  %
  % SetSimState:
  %   Functionality    : Set the SimState of the block using a given value.
  %   C-Mex counterpart: mdlSetSimState
  %
  block.RegBlockMethod('SetSimState', @SetSimState);

  % -----------------------------------------------------------------
  % Register the methods called during code generation.
  % -----------------------------------------------------------------
  
  %
  % WriteRTW:
  %   Functionality    : Write specific information to model.rtw file.
  %   C-Mex counterpart: mdlRTW
  %
  block.RegBlockMethod('WriteRTW', @WriteRTW);
  
  
%endfunction

% -------------------------------------------------------------------
% The local functions below are provided to illustrate how you may implement
% the various block methods listed above.
% -------------------------------------------------------------------

function CheckPrms(block)
  
global cisia;

   %disp(strcat('Check and Reading Parameters:',block.DialogPrm(1).Data))
   drawnow('update')
   
   %a=block.DialogPrm(4)
   %get(a) 
   
   name = block.DialogPrm(1).Data;
   if ~strcmp(class(name), 'char')
     me = MSLException(block.BlockHandle, message(['Simulink:blocks:invalidParameter']));
     throw(me);
   end
 
     
  id_entity = block.DialogPrm(2).Data;
  if ~strcmp(class(id_entity), 'double')
    me = MSLException(block.BlockHandle, message('Simulink:blocks:invalidParameter'));
    throw(me);
  end
  
  % Verify project if it is the MASTER
  if strcmp(block.DialogPrm(1).Data, 'CISIA_MASTER')
    a = block.DialogPrm(3).Data;
    if ~strcmp(class(a), 'char')
        me = MSLException(block.BlockHandle, message('Simulink:blocks:invalidParameter'));
        throw(me);
    end
  end
  
  
  
  if ~strcmp(block.DialogPrm(1).Data, 'CISIA_MASTER') &&  isempty(strfind(block.DialogPrm(1).Data,'LINK')) &&  isempty(strfind(block.DialogPrm(1).Data,'SAVE')) &&  isempty(strfind(block.DialogPrm(1).Data,'ROUTE')) &&  isempty(strfind(block.DialogPrm(1).Data,'RFDB'))
    % è una normale entity
      
  if strcmp(get_param(cisia.gcs,'SimulationStatus'),'stopped') && block.DialogPrm(6).Data==1
         
    %conn = database('cisia','root','cisia_mat');
    query=strcat('UPDATE entity_type SET step_received=''', block.DialogPrm(7).Data  ,''' WHERE id_type=',num2str(cisia.id_type), ' AND id_project=',num2str(cisia.id_project) );
    execute(cisia.conn, query)
    
    query=strcat('UPDATE entity_type SET step_computed=''', block.DialogPrm(8).Data  ,''' WHERE id_type=',num2str(cisia.id_type), ' AND id_project=',num2str(cisia.id_project));
    execute(cisia.conn, query)
    
    query=strcat('UPDATE entity_type SET dynamic_computed=''', block.DialogPrm(9).Data  ,''' WHERE id_type=',num2str(cisia.id_type), ' AND id_project=',num2str(cisia.id_project));
    execute(cisia.conn, query)
    
    query=strcat('UPDATE entity_type SET step_sended=''', block.DialogPrm(10).Data  ,''' WHERE id_type=',num2str(cisia.id_type), ' AND id_project=',num2str(cisia.id_project));
    execute(cisia.conn, query)
    
    %close(cisia.conn)
      
  end
   
  end
  
   
   
 
    
  
%endfunction

function ProcessPrms(block)

  block.AutoUpdateRuntimePrms;
 
%endfunction


% -------------------------------------------------------------------------
function SetInputDimsMode(block, port, dm)
% Set dimension mode
block.InputPort(port).DimensionsMode = dm;
block.OutputPort(port).DimensionsMode = dm;



function SetInpPortFrameData(block, idx, fd)
  
  block.InputPort(idx).SamplingMode = fd;
  
  for i=1:block.NumOutputPorts
    block.OutputPort(i).SamplingMode  = fd;
  end
  
  
%endfunction

function SetInpPortDims(block, idx, di)
  
  block.InputPort(idx).Dimensions = di;
  

%endfunction

function SetOutPortDims(block, idx, di)
  
  block.OutputPort(idx).Dimensions = di;
  

%endfunction

function SetInpPortDataType(block, idx, dt)
  
  block.InputPort(idx).DataTypeID = dt;
  

%endfunction
  
function SetOutPortDataType(block, idx, dt)

  block.OutputPort(idx).DataTypeID  = dt;
  

%endfunction  

function SetInpPortComplexSig(block, idx, c)
  
  block.InputPort(idx).Complexity = c;
  

%endfunction 
  
function SetOutPortComplexSig(block, idx, c)

  block.OutputPort(idx).Complexity = c;
  

%endfunction 
    

% State Variables
function DoPostPropSetup(block) 

global cisia

if cisia.phase==1
    disp('PHASE: Post Prop Setup')
    cisia.phase=2;
end

%disp(strcat('Post Setup:',block.DialogPrm(1).Data))


cisia.num_blocks=cisia.num_blocks+1;
if cisia.num_blocks>cisia.max_blocks
    cisia.max_blocks=cisia.num_blocks;
end

name_entity=block.DialogPrm(1).Data;


if strcmp(name_entity,'CISIA_MASTER')
  block.NumDworks = 5;
   
  
  % offset
  block.Dwork(1).Name            = 'minor_hits_number';
  block.Dwork(1).Dimensions      = 1;
  block.Dwork(1).DatatypeID      = 0;      % double
  block.Dwork(1).Complexity      = 'Real'; % real
  block.Dwork(1).UsedAsDiscState = false;
  
  % id_entity
  block.Dwork(2).Name            = 'major_hits_number';
  block.Dwork(2).Dimensions      = 1;
  block.Dwork(2).DatatypeID      = 0;      % double
  block.Dwork(2).Complexity      = 'Real'; % real
  block.Dwork(2).UsedAsDiscState = false;
  
  % conn
  block.Dwork(3).Name            = 'tre';
  block.Dwork(3).Dimensions      = 1;
  block.Dwork(3).DatatypeID      = 0;      % double
  block.Dwork(3).Complexity      = 'Real'; % real
  block.Dwork(3).UsedAsDiscState = false;
  
  % id_project
  block.Dwork(4).Name            = 'quattro';
  block.Dwork(4).Dimensions      = 1;
  block.Dwork(4).DatatypeID      = 0;      % double
  block.Dwork(4).Complexity      = 'Real'; % real
  block.Dwork(4).UsedAsDiscState = false;
  
  % num_state_var
  block.Dwork(5).Name            = 'cinque';
  block.Dwork(5).Dimensions      = 1;
  block.Dwork(5).DatatypeID      = 0;      % double
  block.Dwork(5).Complexity      = 'Real'; % real
  block.Dwork(5).UsedAsDiscState = false;
  
  %set_param(gcb,'BackgroundColor','red')
   
%% --------------
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'LINK')),'1') % blocco LINK
    
  %disp(strcat('Post Setup:',block.DialogPrm(1).Data))
  block.NumDworks = 2;
   
  
  % 
  block.Dwork(1).Name            = 'link_value';
  block.Dwork(1).Dimensions      = 1;
  block.Dwork(1).DatatypeID      = 0;      % double
  block.Dwork(1).Complexity      = 'Real'; % real
  block.Dwork(1).UsedAsDiscState = false;
  
  %   
  block.Dwork(2).Name            = 'major_hit';
  block.Dwork(2).Dimensions      = 1; 
  block.Dwork(2).DatatypeID      = 0;      % double
  block.Dwork(2).Complexity      = 'Real'; % real
  block.Dwork(2).UsedAsDiscState = false;
%-------------------------------------------------------------------------------  
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'ROUTE')),'1') % blocco ROUTE
    
  %disp(strcat('Post Setup:',block.DialogPrm(1).Data))
  block.NumDworks = 3;
  
  % bisogna determinare name_res in input
  
  %PortHandles=get_param(gcb,'PortHandles');
  %name_res=get_param(PortHandles.Inport(1),'Name');
  
  %query=strcat('SELECT * FROM route_link AS a JOIN resources AS c WHERE  a.id_project=c.id_project AND c.name_res=''', name_res ,''' AND a.routing_name=''', block.DialogPrm(1).Data,  ''' AND a.id_project=',string(cisia.id_project));
  query=strcat('SELECT * FROM route_link AS a JOIN resources AS c WHERE  a.id_project=c.id_project AND c.id_res=a.id_res AND a.routing_name=''', block.DialogPrm(1).Data,  ''' AND a.id_project=',string(cisia.id_project));
  data_route=fetch(cisia.conn,query);
  
  % offset
  block.Dwork(1).Name            = 'route_values';
  block.Dwork(1).Dimensions      = data_route.dim_res(1)*block.DialogPrm(4).Data; % uno per ogni dimensione della risorsa in ingresso x numero di porte
  block.Dwork(1).DatatypeID      = 0;      % double
  block.Dwork(1).Complexity      = 'Real'; % real
  block.Dwork(1).UsedAsDiscState = false;
  
  % cont_initial_state  
  block.Dwork(2).Name            = 'major_hit';
  block.Dwork(2).Dimensions      = 1; 
  block.Dwork(2).DatatypeID      = 0;      % double
  block.Dwork(2).Complexity      = 'Real'; % real
  block.Dwork(2).UsedAsDiscState = false;
  
  % 
  block.Dwork(3).Name            = 'dim_output';
  block.Dwork(3).Dimensions      = 1; 
  block.Dwork(3).DatatypeID      = 0;      % double
  block.Dwork(3).Complexity      = 'Real'; % real
  block.Dwork(3).UsedAsDiscState = false;
  
%-------------------------------------------------------------------------------  
  
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'SAVE')),'1') % blocco SAVE
  %disp(strcat('Post Setup:',block.DialogPrm(1).Data))
  block.NumDworks = 4;
  
  query=strcat('SELECT * FROM save2db AS a JOIN resources AS b WHERE a.id_res=b.id_res AND save_name=''',block.DialogPrm(1).Data,''' AND a.id_project=',num2str(cisia.id_project));    
  data_save2db=fetch(cisia.conn,query);
  
  % offset
  block.Dwork(1).Name            = 'res_name';
  block.Dwork(1).Dimensions      = 20;
  block.Dwork(1).DatatypeID      = 3;      % uint8
  block.Dwork(1).Complexity      = 'Real'; % real
  block.Dwork(1).UsedAsDiscState = false;
  
  % cont_initial_state  
  block.Dwork(2).Name            = 'major_hit';
  block.Dwork(2).Dimensions      = 1; 
  block.Dwork(2).DatatypeID      = 0;      % double
  block.Dwork(2).Complexity      = 'Real'; % real
  block.Dwork(2).UsedAsDiscState = false;
  
  block.Dwork(3).Name            = 'dim_res';
  block.Dwork(3).Dimensions      = 1;
  block.Dwork(3).DatatypeID      = 0;      % double
  block.Dwork(3).Complexity      = 'Real'; % real
  block.Dwork(3).UsedAsDiscState = false;
  
  block.Dwork(4).Name            = 'actual_value';
  block.Dwork(4).Dimensions      = data_save2db.dim_res(1);
  block.Dwork(4).DatatypeID      = 0;      % double
  block.Dwork(4).Complexity      = 'Real'; % real
  block.Dwork(4).UsedAsDiscState = false;
  
  
%-------------------------------------------------------------------------------  
  
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'RFDB')),'1') % blocco RFDB
    
  %disp(strcat('Post Setup:',block.DialogPrm(1).Data))
  block.NumDworks = 2;
   
  
  % rfbd_value
  block.Dwork(1).Name            = block.DialogPrm(4).Data;
  block.Dwork(1).Dimensions      = 1;
  block.Dwork(1).DatatypeID      = 0;      % double
  block.Dwork(1).Complexity      = 'Real'; % real
  block.Dwork(1).UsedAsDiscState = false;
  
  % 
  block.Dwork(2).Name            = 'major_hit';
  block.Dwork(2).Dimensions      = 1; 
  block.Dwork(2).DatatypeID      = 0;      % double
  block.Dwork(2).Complexity      = 'Real'; % real
  block.Dwork(2).UsedAsDiscState = false; 
    
else % NORMAL ENTITY %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%disp('Reading Basic data')

  filename=strcat(gcs,'/',name_entity,'_2');
  
  if cisia.loadfromfile==1
    load(filename)
  end


%%

  
  % Troviamo id_entity
  if cisia.loadfromfile==0
    query=strcat('SELECT * FROM entity WHERE name_entity=''',name_entity,''' AND id_project=''',num2str(cisia.id_project),'''');
    data_entity=fetch(cisia.conn, query);
  end
  
    id_entity=data_entity.id_entity(1);
  
  
  if cisia.loadfromfile==0
    query=strcat('SELECT * FROM entity_port AS a JOIN resources AS b ON a.id_res=b.id_res where a.id_entity=', num2str(id_entity), ' AND a.id_project=',num2str(cisia.id_project));  
    data_entity_port=fetch(cisia.conn, query);
  end
  
  input=data_entity_port(data_entity_port.type_port=="INPUT",'dim_res');
  real_num_inputs=sum(input.dim_res);
  num_inputs=height(input);
  

%% Controllo correttezza variabili di ingresso
  % recupera i nomi delle risorse in ingresso
  if cisia.loadfromfile==0
    query=strcat('SELECT * FROM entity_port AS a JOIN resources AS b ON a.id_res=b.id_res where a.id_entity=', num2str(id_entity), ' AND type_port=''INPUT''', ' AND a.id_project=',num2str(cisia.id_project), ' ORDER BY a.id_res');
    data_input_port=fetch(cisia.conn, query);
  end
  
  %inp_port_dim=data_input_port.dim_res;
  
  PortHandles=get_param(gcb,'PortHandles');
  
  %disp('nomi in ingresso')
  a=get_param(PortHandles.Inport,'Name');
  
  
  
  if num_inputs>0
  for i=1:num_inputs
      
      if iscell(a)
          if length(a)>=i
            b=a{i};
          else
            b='';
          end
      else
          b=a;
      end
      
      if strcmp(b,'')
        errorStruct.message = strcat('Please connect all input ports (#',string(i),' missing) of block of: ',gcb);
        errorStruct.identifier = 'CISIA:unconnected_port';  
        error(errorStruct) 
        % here we can set a default value
        % https://it.mathworks.com/help/simulink/slref/simulink.blockdata.html#f29-107150
      end
      
      if ~strcmp(data_input_port.name_res{i},b)
         disp(strcat('ERROR: Input ', num2str(i), ' of entity:', name_entity, ' is not the required resource: ', data_input_port.name_res(i)))
         
         errorStruct.message ='Wrong Input Resource';
         for j=1:num_inputs
             errorStruct.message=strcat(errorStruct.message, ':',  data_input_port.name_res(j));
         end
         errorStruct.message=errorStruct.message{1};
         errorStruct.identifier = 'CISIA:uncorrect_resource';  
         error(errorStruct)
     end
      
      
  end
  end



%%



%disp('Reading State Variables');
  if cisia.loadfromfile==0
    query=strcat('SELECT * FROM status AS a JOIN variables AS b ON a.id_var=b.id_var where a.id_entity=', num2str(id_entity), ' AND a.id_project=',num2str(cisia.id_project),' ORDER BY a.id_var');
    data_status=fetch(cisia.conn, query);
  end
  
  
  num_state_var=height(data_status);
    
  offset=cisia.offset;
  block.NumDworks = num_state_var+offset;
  

  % offset
  block.Dwork(1).Name            = 'offset';
  block.Dwork(1).Dimensions      = 1;
  block.Dwork(1).DatatypeID      = 0;      % double
  block.Dwork(1).Complexity      = 'Real'; % real
  block.Dwork(1).UsedAsDiscState = false;
  %block.Dwork(1).Data            = offset;
  
  % id_entity
  block.Dwork(2).Name            = 'id_entity';
  block.Dwork(2).Dimensions      = 1;
  block.Dwork(2).DatatypeID      = 0;      % double
  block.Dwork(2).Complexity      = 'Real'; % real
  block.Dwork(2).UsedAsDiscState = false;
  %block.Dwork(2).Data            = id_entity;
  
  % conn
  block.Dwork(3).Name            = 'conn';
  block.Dwork(3).Dimensions      = 1;
  block.Dwork(3).DatatypeID      = 0;      % double
  block.Dwork(3).Complexity      = 'Real'; % real
  block.Dwork(3).UsedAsDiscState = false;
  %block.Dwork(3).Data            = conn;
  
  % id_project
  block.Dwork(4).Name            = 'id_project';
  block.Dwork(4).Dimensions      = 1;
  block.Dwork(4).DatatypeID      = 0;      % double
  block.Dwork(4).Complexity      = 'Real'; % real
  block.Dwork(4).UsedAsDiscState = false;
  %block.Dwork(4).Data            = id_project;
  
  % num_state_var
  block.Dwork(5).Name            = 'num_state_var';
  block.Dwork(5).Dimensions      = 1;
  block.Dwork(5).DatatypeID      = 0;      % double
  block.Dwork(5).Complexity      = 'Real'; % real
  block.Dwork(5).UsedAsDiscState = false;
  %block.Dwork(5).Data            = num_state_var;
  
  
 
  
  name_var=cell(num_state_var,1);
  %id_var=zeros(num_state_var,1);

  %% PARALLEL TOOLBOX
  for i=1:num_state_var
    
    k=i+offset;
    name_var{i}=strrep(data_status.name_var{i},' ','_');
             
    if strcmp(data_status.val_type(i),'CONTINUOUS')
        %disp('CONTINUOUS')
        block.Dwork(k).Name            = name_var{i};
        block.Dwork(k).Dimensions      = 1;
        block.Dwork(k).DatatypeID      = 0;      % double
        block.Dwork(k).Complexity      = 'Real'; % real
        block.Dwork(k).UsedAsDiscState = false;
    
    elseif strcmp(data_status.val_type(i),'NUMERIC') % Discrete states
        %disp('NUMERIC')
        block.Dwork(k).Name            = name_var{i};
        block.Dwork(k).Dimensions      = 1;
        block.Dwork(k).DatatypeID      = 0;      % double
        block.Dwork(k).Complexity      = 'Real'; % real
        block.Dwork(k).UsedAsDiscState = true;
        
   
    elseif strcmp(data_status.val_type(i),'STRING')
        %disp('STRING')
        %var_type(i)=2;
        block.Dwork(k).Name            = name_var{i};
        block.Dwork(k).Dimensions      = 100;
        block.Dwork(k).DatatypeID      = 3;      % uint8
        block.Dwork(k).Complexity      = 'Real'; % real
        block.Dwork(k).UsedAsDiscState = false;
   
    elseif strcmp(data_status.val_type(i),'NUMERIC_ARRAY') % vector of discrete states
        %disp('NUMERIC_ARRAY')
        
        block.Dwork(k).Name            = name_var{i};
        block.Dwork(k).Dimensions      = data_status.var_dim(i);
        block.Dwork(k).DatatypeID      = 0;      % double
        block.Dwork(k).Complexity      = 'Real'; % real
        block.Dwork(k).UsedAsDiscState = true;
    
    
    else
        disp(strcat('UNRECOGNIZED TYPE STATE VAR:',data_status.val_type(i)))
        block.Dwork(k).Name            = name_var{i};
        block.Dwork(k).Dimensions      = 1;
        block.Dwork(k).DatatypeID      = 1;      % ????
        block.Dwork(k).Complexity      = 'Real'; % real        
        block.Dwork(k).UsedAsDiscState = false;
   
    end
    
  
  end  
    
    % var_type  0: continuous; 1: discrete; 2: string; 3: array
  block.Dwork(6).Name            = 'var_type';
  block.Dwork(6).Dimensions      = num_state_var;
  block.Dwork(6).DatatypeID      = 0;      % double
  block.Dwork(6).Complexity      = 'Real'; % real
  block.Dwork(6).UsedAsDiscState = false;
  %block.Dwork(6).Data            = var_type;

  % initial_state  
  block.Dwork(7).Name            = 'initial_state';
  block.Dwork(7).Dimensions      = num_state_var;
  block.Dwork(7).DatatypeID      = 0;      % double
  block.Dwork(7).Complexity      = 'Real'; % real
  block.Dwork(7).UsedAsDiscState = false;
  %block.Dwork(7).Data            = initial_state;

  % cont_initial_state  
  block.Dwork(8).Name            = 'cont_initial_state';
  block.Dwork(8).Dimensions      = num_state_var;
  block.Dwork(8).DatatypeID      = 0;      % double
  block.Dwork(8).Complexity      = 'Real'; % real
  block.Dwork(8).UsedAsDiscState = false;
  %block.Dwork(8).Data            = cont_initial_state;
  
  
  % cont_initial_state  
  block.Dwork(9).Name            = 'last_input_values';
  if real_num_inputs==0
    block.Dwork(9).Dimensions      = 1; %;
  else
    block.Dwork(9).Dimensions      = real_num_inputs; %;
  end
  block.Dwork(9).DatatypeID      = 0;      % double
  block.Dwork(9).Complexity      = 'Real'; % real
  block.Dwork(9).UsedAsDiscState = false;
  
  % cont_initial_state  
  block.Dwork(10).Name            = 'major_hit';
  block.Dwork(10).Dimensions      = 1; 
  block.Dwork(10).DatatypeID      = 0;      % double
  block.Dwork(10).Complexity      = 'Real'; % real
  block.Dwork(10).UsedAsDiscState = false;
  
  % step received  
  block.Dwork(11).Name            = 'step_received';
  block.Dwork(11).Dimensions      = 10000; 
  block.Dwork(11).DatatypeID      = 3;      % uint8
  block.Dwork(11).Complexity      = 'Real'; % real
  block.Dwork(11).UsedAsDiscState = false;
  
    % step received  
  block.Dwork(12).Name            = 'step_computed';
  block.Dwork(12).Dimensions      = 10000; 
  block.Dwork(12).DatatypeID      = 3;      % uint8
  block.Dwork(12).Complexity      = 'Real'; % real
  block.Dwork(12).UsedAsDiscState = false;
  
    % dynamic_computed
  block.Dwork(13).Name            = 'dynamic_computed';
  block.Dwork(13).Dimensions      = 10000; 
  block.Dwork(13).DatatypeID      = 3;      % uint8
  block.Dwork(13).Complexity      = 'Real'; % real
  block.Dwork(13).UsedAsDiscState = false;
  
    % step sended  
  block.Dwork(14).Name            = 'step_sended';
  block.Dwork(14).Dimensions      = 10000; 
  block.Dwork(14).DatatypeID      = 3;      % uint8
  block.Dwork(14).Complexity      = 'Real'; % real
  block.Dwork(14).UsedAsDiscState = false;
  
    % step sended  
  block.Dwork(15).Name            = 'initial_state_array';
  block.Dwork(15).Dimensions      = 200; 
  block.Dwork(15).DatatypeID      = 0;      % double
  block.Dwork(15).Complexity      = 'Real'; % real
  block.Dwork(15).UsedAsDiscState = false;
  
  
  
   
  %close(conn);
  
  if cisia.loadfromfile==0
      if cisia.savetofile==1
        save_variables='save(filename,''data_entity'',''data_entity_port'',''data_input_port'',''data_status'')';
        eval(save_variables)
      end
  end
  
  
  
  %end  errore

end % NORMAL ENTITY
  
    
   

  % Register all tunable parameters as runtime parameters.
  %block.AutoRegRuntimePrms;

%endfunction

function InitializeConditions(block)

global cisia

%disp(strcat('Init. cond. continuous var:',block.DialogPrm(1).Data))

%offset=block.Dwork(1).data;

name_entity=block.DialogPrm(1).Data;


if strcmp(name_entity,'CISIA_MASTER')
    if strcmp(get_param(cisia.gcs,'FastRestart'),'on')
        disp('Initialize time hits on Fast Testart for MASTER and all')
        cisia.last_input_update=1;
        cisia.first_run=1;
        cisia.last_major_timehit=0;
        cisia.major_time=0;
        cisia.force_major_timehit=0;
        cisia.force_major_update=0;
        cisia.last_minor_timehit=0;
        cisia.time_past_sec=0;
    else
        disp('Initialize Conditions for MASTER')
    end
end


if block.NumContStates>0
for i=1:block.NumContStates
    block.ContStates.Data(i)=block.Dwork(8).data(i);
end

end




%endfunction

function Start(block)

global cisia;

if cisia.phase==2
    disp('PHASE: Start and Initialization')
    cisia.phase=3;
    cisia.num_blocks=cisia.max_blocks;
    if strcmp(get_param(cisia.gcs,'FastRestart'),'on')
        disp('Phase 2 - Start Block - Fast restart on')
        cisia.tic=tic;
    end
    cisia.update=0;
    
end

%
%disp(strcat('Start:',block.DialogPrm(1).Data))
%

%Initialization of state variables if required

name_entity=block.DialogPrm(1).Data;

%% ---
if strcmp(name_entity,'CISIA_MASTER')
    
    
  block.Dwork(1).Data            = 0; % minor hits number
  block.Dwork(2).Data            = 0; % major hits number
  block.Dwork(3).Data            = 0; 
  block.Dwork(4).Data            = 0;
  block.Dwork(5).Data            = 0;

  mask_values=get_param(gcb,'MaskValues');
  %mask_values{4}='No input resources';
  set_param(gcb,'MaskValues',mask_values);
  
  % Creazione del nuovo id_run
    cisia.date_now=now;
    cisia.timestamp=string(datetime(cisia.date_now,'ConvertFrom','datenum','Format', 'yyyy-MM-dd HH:mm:ss'));
    cisia.milliseconds=string(datetime(cisia.date_now,'ConvertFrom','datenum','Format', 'SSS'));
    query=strcat('INSERT INTO run (id_run, currDate, milliseconds,model) VALUES (NULL,''',cisia.timestamp, ''',', cisia.milliseconds,',''',cisia.gcs,''')');
    execute(cisia.conn, query)
    query=strcat('SELECT id_run FROM run WHERE currDate=''',cisia.timestamp,''' AND milliseconds=', cisia.milliseconds);
    data=fetch(cisia.conn,query);
    cisia.id_run=data.id_run(1);
    disp(strcat('Id run:',string(cisia.id_run)))
    
    
   % clean actual_entities table
    query=strcat('TRUNCATE actual_entities');
    execute(cisia.conn, query)
    

  
  
%% ---
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'LINK')),'1')  % LINK ENTITY

  if block.DialogPrm(7).Data
      block.Dwork(1).Data=block.InputPort(2).data;  
      data_links=block.InputPort(2).data;
  else
      query=strcat('SELECT * FROM dynamic_links WHERE link_name=''',block.DialogPrm(1).Data,''' AND id_project=',num2str(cisia.id_project));
      data_links=fetch(cisia.conn, query);
      block.Dwork(1).Data=data_links.link_val(1);  
  end
  
  
  block.Dwork(2).Data=0;  

%% ---  
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'ROUTE')),'1')  % ROUTE ENTITY

  %PortHandles=get_param(gcb,'PortHandles');
  %name_res=get_param(PortHandles.Inport(1),'Name');
  
  query=strcat('SELECT * FROM route_link AS a JOIN resources AS c WHERE  a.id_project=c.id_project AND a.id_res=c.id_res AND a.routing_name=''', block.DialogPrm(1).Data,  ''' AND a.id_project=',string(cisia.id_project));
  data_route=fetch(cisia.conn,query);
  
  if height(data_route)>0
    block.Dwork(3).Data=data_route.dim_res(1);  
  end
    
    
  if block.DialogPrm(7).Data
      block.Dwork(1).Data=block.InputPort(2).data;
  else
      % bisogna leggere la tabella di instradamento
      
      query=strcat('SELECT * FROM route_link AS a JOIN routing_table AS b WHERE  a.id_project=b.id_project AND a.id_routing=b.id_routing AND a.routing_name=''',block.DialogPrm(1).Data,''' AND a.id_project=',num2str(cisia.id_project));
      data_routing=fetch(cisia.conn, query);
      
      if height(data_routing)>0
         for i=1:height(data_routing)
             block.Dwork(1).Data((data_routing.out_port(i)-1)* block.Dwork(3).Data+data_routing.res_index(i))=1;
             
         end
      end
      
      
  end
  
  
  block.Dwork(2).Data=0;  

%---------------------------------------------------------------------------------
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'SAVE')),'1')  % SAVE ENTITY

 
    query=strcat('SELECT * FROM save2db AS a JOIN resources AS b WHERE a.id_res=b.id_res AND save_name=''',block.DialogPrm(1).Data,''' AND a.id_project=',num2str(cisia.id_project));
    data_links=fetch(cisia.conn, query);
    
    PortHandles=get_param(gcb,'PortHandles');
    name_input=get_param(PortHandles.Inport,'Name');
    a=uint8(name_input);
    n=length(a); 
    a=[a 32*ones(1,20-n)];
    
    block.Dwork(1).Data = a;
    block.Dwork(2).Data=0; 
    block.Dwork(3).Data=data_links.dim_res(1);
    block.Dwork(4).Data=zeros(1,data_links.dim_res(1)); 
  
%---------------------------------------------------------------------------------
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'RFDB')),'1')  % RFDB ENTITY

  block.Dwork(1).Data=0;    
  block.Dwork(2).Data=0;  
    
 
    
else % NORMAL ENTITY
    
  
  % read all parameters from mask
  mask_values=get_param(gcb,'MaskValues'); 

    
  % Ricavo id_entity e id_type
  
  if cisia.loadfrommask==0
      query=strcat('SELECT * FROM entity WHERE name_entity=''',name_entity,''' AND id_project=''',num2str(cisia.id_project),'''');
      data_entity=fetch(cisia.conn, query);
      id_entity=data_entity.id_entity(1);
      id_type=data_entity.id_type(1);
  else
      id_entity=str2num(mask_values{11});
      id_type=str2num(mask_values{13});
  end

 
  
  

%disp('Inizializing Dworks and State Variables')
  

  % qui si dovrebbe eliminare almeno il JOIN
  %
  
  offset=cisia.offset;
  
  num_state_var=block.Dwork(7).Dimensions;
  
  if cisia.loadfrommask==0
    query=strcat('SELECT * FROM status AS a JOIN variables AS b ON a.id_var=b.id_var where a.id_entity=', num2str(id_entity), ' AND a.id_project=',num2str(cisia.id_project), ' ORDER BY a.id_var');
    data_status=fetch(cisia.conn, query);
  else
    query=strcat('SELECT val_status FROM status WHERE id_entity=', num2str(id_entity), ' AND id_project=',num2str(cisia.id_project), ' ORDER BY id_var');
    data_val_status=fetch(cisia.conn, query);
  
    % estrai le variabili dalla maschera
    testo=mask_values{4};
    ind1=strfind(testo,'NUM_VARIABLES');
    ind2=strfind(testo,'*** OUTPUT');
    vars=testo(ind1:ind2-3);
    
    [num_vars,num,msg,last]=sscanf(vars,'NUM_VARIABLES %g');
    lines=strsplit(vars(last+1:end),'\n');
    
    data_status = table('Size', [num_vars 4],'VariableNames', {'name_var', 'val_type', 'val_status', 'var_dim'},'VariableTypes', {'string', 'string', 'string', 'double' });
    
    for i=1:num_vars
       line=strsplit(lines{i},{'(',')'});
       data_status.name_var(i)=line{1};
       data_status.val_type(i)=line{2};
       data_status.var_dim(i)=str2num(line{3});
       %
       data_status.val_status(i)=data_val_status.val_status(i);
       % 
    end
    
  end
  
  
    
  
  
  
  
  % offset
  block.Dwork(1).Data            = offset; 
  % id_entity
  block.Dwork(2).Data            = id_entity;
  % conn
  %block.Dwork(3).Data            = conn;
  % id_project
  block.Dwork(4).Data            = cisia.id_project;
  % num_state_var
  block.Dwork(5).Data            = num_state_var;
  
 
  
  name_var=cell(num_state_var,1);
  id_var=zeros(num_state_var,1);
  initial_state=zeros(num_state_var,1);
  initial_state_array=[];
  cont_initial_state=zeros(num_state_var,1);
  var_type=zeros(num_state_var,1);
  
  j=0;
  
  for i=1:num_state_var % per tutte le variabili di stato
    
    k=i+offset;
    %name_var{i}=strrep(data_status.name_var{i},' ','_');
    %id_var(i)=data_status.id_var(i);
         
    
    if strcmp(data_status.val_type(i),'CONTINUOUS')
        %disp('CONTINUOUS')
        var_type(i)=0;
        initial_state(i)=str2num(data_status.val_status{i});
        if isempty(initial_state(i))
            initial_state(i)=0;
        end
        j=j+1;
        cont_initial_state(j)=initial_state(i);
        block.Dwork(k).Data = initial_state(i);
        
    elseif strcmp(data_status.val_type(i),'NUMERIC') % Discrete states
        %disp('NUMERIC')
        var_type(i)=1;
        
        val=str2num(data_status.val_status{i});
        if isempty(val)
            val=0;
        end
        
        initial_state(i)=val;
        
        if isempty(initial_state(i))
            initial_state(i)=0;
        end
        block.Dwork(k).Data = initial_state(i);
        
    elseif strcmp(data_status.val_type(i),'STRING')
        %disp('STRING')
        var_type(i)=2;
        a=uint8(data_status.val_status{i} );
        n=length(a); 
        a=[a 32*ones(1,100-n)];
        block.Dwork(k).Data = a;
        
    elseif strcmp(data_status.val_type(i),'NUMERIC_ARRAY')
        %disp('NUMERIC_ARRAY')
        var_type(i)=3;
        var_dim=data_status.var_dim(i);
        
        if strcmp(data_status.val_status{i},'') % nessuna inizializzazione
            val_init = zeros(1,var_dim);
        else
            val_init=sscanf(data_status.val_status{i}, '%g,', [var_dim, inf])';
            block.Dwork(k).Data = val_init;
        end            
        block.Dwork(k).Data = val_init;
        initial_state_array=[initial_state_array val_init];
           
               
        
    end
    
  end
  
  % var_type  0: continuous; 1: discrete; 2: string
  block.Dwork(6).Data            = var_type;
  % initial_state  
  block.Dwork(7).Data            = initial_state; % INITIAL STATE VARIABILI NUMERIC
  % cont_initial_state  
  block.Dwork(8).Data            = cont_initial_state;
  % major time hit
  block.Dwork(9).Data            = zeros(block.Dwork(9).Dimensions,1); % old inputs
  block.Dwork(10).Data           = 0;
  
  n=size(initial_state_array,2);
  initial_state_array=[initial_state_array zeros(1,200-n)];
  block.Dwork(15).Data           = initial_state_array;
  
  
  if cisia.loadfrommask==0
      query2=strcat('SELECT * FROM entity_type WHERE id_type=',string(id_type), ' AND id_project=',num2str(cisia.id_project));
      data_entity_type=fetch(cisia.conn, query2);
  
      step_received=data_entity_type.step_received{1};
      step_computed=data_entity_type.step_computed{1};  
      dynamic_computed=data_entity_type.dynamic_computed{1};
      step_sended=data_entity_type.step_sended{1};
      
      mask_values{7}=step_received;
      mask_values{8}=step_computed;
      mask_values{9}=dynamic_computed;
      mask_values{10}=step_sended;
      
      mask_values{14}=data_entity_type.name_type{1};
      mask_values{15}=data_entity_type.color{1};

  else
      step_received=mask_values{7};
      step_computed=mask_values{8};
      dynamic_computed=mask_values{9};
      step_sended=mask_values{10};
  end
  
  % recupera i nomi delle risorse in ingresso per scriverli nella maschera
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  if cisia.loadfrommask==0
    query=strcat('SELECT * FROM entity_port AS a JOIN resources AS b ON a.id_res=b.id_res where a.id_entity=', num2str(id_entity), ' AND type_port=''INPUT''', ' AND a.id_project=',num2str(cisia.id_project),' ORDER BY a.id_res');
    data_input_port=fetch(cisia.conn, query);
  else
    num_inputs=block.NumInputPorts;
    %num_outputs=block.NumOutputPorts;
    PortHandles=get_param(gcb,'PortHandles');
    data_input_port = table('Size', [num_inputs 1],'VariableNames', {'name_res'},'VariableTypes', {'string'});
    for i=1:num_inputs
        data_input_port.name_res(i)=get_param(PortHandles.Inport(i),'Name');
    end
    
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  
  if cisia.loadfrommask==0 % save inputs, variables and outputs to mask
        
        %inp_port_dim=data.dim_res;
        num_inputs=height(data_input_port);
  
    
          % Imposta i nomi dei segnali in ingresso
          all_inputs=['*** INPUT RESOURCES ***' newline 'NUM_INPUTS ' num2str(num_inputs)];
          if num_inputs>0
              for i=1:num_inputs 
                all_inputs=[all_inputs newline data_input_port.name_res{i} ' (' num2str(data_input_port.dim_res(i)) ')'];
              end
          end  



          % Variable state added to all_inputs
          if num_state_var>0
            all_inputs=[all_inputs newline newline '*** STATE VARIABLES ***' newline 'NUM_VARIABLES ' num2str(num_state_var) newline];
            for i=1:num_state_var

                % var_type  0: continuous; 1: discrete; 2: string; 3: array

                if block.Dwork(6).Data(i)==2   % STRING
                    type='STRING';
                    value=strtrim(char(block.Dwork(i+offset).Data'));
                elseif block.Dwork(6).Data(i)==0 % CONTINUOUS
                    type='CONTINUOUS';
                    value=char(num2str(block.Dwork(i+offset).Data));
                elseif block.Dwork(6).Data(i)==3 % ARRAY
                    type='NUMERIC_ARRAY';
                    value=char(num2str(block.Dwork(i+offset).Data'));
                else % NUMERIC
                    type='NUMERIC';
                    value=char(num2str(block.Dwork(i+offset).Data'));
                end
                all_inputs=[all_inputs  block.Dwork(i+offset).name '(' type ')(' num2str(block.Dwork(i+offset).Dimensions) ')(' value ')' newline];

            end    
          end 

         % recupera i nomi delle risorse in uscita
          query=strcat('SELECT * FROM entity_port AS a JOIN resources AS b ON a.id_res=b.id_res where a.id_entity=', num2str(id_entity), ' AND type_port=''OUTPUT''', ' AND a.id_project=',num2str(cisia.id_project),' ORDER BY a.id_res');
          data_output_port=fetch(cisia.conn, query);
          %inp_port_dim=data.dim_res;
          num_outputs=height(data_output_port);


          % Imposta i nomi dei segnali in uscita
          all_inputs=[all_inputs newline '*** OUTPUT RESOURCES ***' newline 'NUM_OUTPUTS ' num2str(num_outputs)];
          if num_outputs>0
              for i=1:num_outputs
                all_inputs=[all_inputs newline data_output_port.name_res{i} ' (' num2str(data_output_port.dim_res(i)) ')'];
              end
          end  

  
  
          mask_values{4}=all_inputs;   
          
          
  end % if cisia.loadfrommask==0
  
  
  %% step_received
  
  
  % Variable initial state substitution  %%var_type
  if num_state_var>0
    j=0;
    k=0;
    for i=1:num_state_var
        
        if block.Dwork(6).Data(i)==0  % var_type=continuous
            step_received=strrep(step_received,strcat(block.Dwork(i+offset).name,'_init'),strcat('block.Dwork(8).Data(',num2str(i),')'));   
        elseif block.Dwork(6).Data(i)==1  % var_type=numeric
            step_received=strrep(step_received,strcat(block.Dwork(i+offset).name,'_init'),strcat('block.Dwork(7).Data(',num2str(i),')'));   
        elseif block.Dwork(6).Data(i)==3  % var_type=array
            k=j+block.Dwork(i+offset).Dimensions;
            j=j+1;
            step_received=strrep(step_received,strcat(block.Dwork(i+offset).name,'_init'),strcat('block.Dwork(15).Data(',num2str(j),':',num2str(k),')'));
            j=k;
            
        elseif block.Dwork(6).Data(i)==2  % var_type=string
            if contains(step_received,strcat(block.Dwork(i+offset).name,'_init'))
                disp(strcat('Cannot use initial state of STRING variable in entity:',block.DialogPrm(1).Data))
                errorStruct.message = 'Cannot use initial state of STRING variable!';
                errorStruct.identifier = 'CISIA:wrong_variable';  
                error(errorStruct) 
                return
            end
        end
        
        
    end    
  end 
  
   
   
  % Variable state substitution  %%var_type
  if num_state_var>0
    for i=1:num_state_var
        step_received=strrep(step_received,block.Dwork(i+offset).name,strcat('block.Dwork(',num2str(i),'+offset).data'));   
    end    
  end 
  
  
  % Input substitution
  if block.NumInputPorts>0
    
    
      
    c=cell(block.NumInputPorts,3);
    for i=1:block.NumInputPorts
        c{i,1}=length(data_input_port.name_res{i});
        c{i,2}=data_input_port.name_res{i};
        c{i,3}=i;
    end      
    c=sortrows(c,'descend');  
      
    
    for i=1:block.NumInputPorts
        a=c{i,2};
        step_received=strrep(step_received,a,strcat('block.InputPort(',num2str(c{i,3}),').data'));
        % In case of unconnected input here can be substituted the default
        % value
    end    
  end
 

  
  
  step_received=uint8(step_received);
  n=length(step_received); 
  step_received=[step_received 64*ones(1,10000-n)];
  block.Dwork(11).Data = step_received;
  
  %sr=strrep(char(block.Dwork(11).Data'),'@','')
  
  
  %% step_computed (update dello stato discreto)
  
  
  % Variable state substitution %%var_type
  if num_state_var>0
    for i=1:num_state_var
        step_computed=strrep(step_computed,strcat(block.Dwork(i+offset).name,'_new'),strcat('new_state{',num2str(i),'}'));   
    end    
  end 
  
  
  % Variable state substitution %%var_type
  if num_state_var>0
    for i=1:num_state_var
        step_computed=strrep(step_computed,block.Dwork(i+offset).name,strcat('block.Dwork(',num2str(i),'+offset).data'));   
    end    
  end 
  
  % Input substitution
  if block.NumInputPorts>0
    c=cell(block.NumInputPorts,3);
    for i=1:block.NumInputPorts
        c{i,1}=length(data_input_port.name_res{i});
        c{i,2}=data_input_port.name_res{i};
        c{i,3}=i;
    end      
    c=sortrows(c,'descend');  
      
    for i=1:block.NumInputPorts
        a=c{i,2};
        step_computed=strrep(step_computed,a,strcat('block.InputPort(',num2str(c{i,3}),').data'));   
    end     
  end
  
  % final preparation
  step_computed=uint8(step_computed);
  n=length(step_computed); 
  step_computed=[step_computed 64*ones(1,10000-n)];
  block.Dwork(12).Data = step_computed;
  
  
  
  %% dynamic_computed (valutazione dell'uscita)
  
  
  %disp(['dynamic computed substitution' block.DialogPrm(1).Data])
  
  
  % derivatives state substitution
  
  %disp('dot substitution')
  if num_state_var>0
    j=0;
    for i=1:num_state_var
        if block.Dwork(6).Data(i)==0  % var_type=continuous
            j=j+1;
            %disp(strcat(block.Dwork(i+offset).name,'_dot'))
            dynamic_computed=strrep(dynamic_computed,strcat(block.Dwork(i+offset).name,'_dot'),strcat('block.Derivatives.Data(',num2str(j),')'));   
        end
    end    
  end 
  
  
  
  % Variable state substitution
  if num_state_var>0
    j=0;
    for i=1:num_state_var
        if block.Dwork(6).Data(i)==0  % var_type=continuous
            j=j+1;
            dynamic_computed=strrep(dynamic_computed,block.Dwork(i+offset).name,strcat('block.ContStates.Data(',num2str(j),')'));  
        end
    end    
  end 
  
  
  
  
  % Input substitution
  if block.NumInputPorts>0
      
    c=cell(block.NumInputPorts,3);
    for i=1:block.NumInputPorts
        c{i,1}=length(data_input_port.name_res{i});
        c{i,2}=data_input_port.name_res{i};
        c{i,3}=i;
    end      
    c=sortrows(c,'descend');  
      
    for i=1:block.NumInputPorts
        a=c{i,2};
        dynamic_computed=strrep(dynamic_computed,a,strcat('block.InputPort(',num2str(c{i,3}),').data'));   
    end    
  end
  
  

  % final preparation
  dynamic_computed=uint8(dynamic_computed);
  n=length(dynamic_computed); 
  dynamic_computed=[dynamic_computed 64*ones(1,10000-n)];
  block.Dwork(13).Data = dynamic_computed;
  
  %disp('final dynamic')
  %char(block.Dwork(13).Data')
  
  
  
  %% step_sended
  
  % recupera i nomi delle risorse in uscita
  
  %% QUERY INUTILE I NOMI SONO GIA' NELLE PROPRIETA' DELLE PORTE IN USCITA
  
  
  if cisia.loadfrommask==0
    query=strcat('SELECT * FROM entity_port AS a JOIN resources AS b ON a.id_res=b.id_res where a.id_entity=', num2str(id_entity), ' AND type_port=''OUTPUT''', ' AND a.id_project=',num2str(cisia.id_project), ' ORDER BY a.id_res');
    data_entity_port=fetch(cisia.conn, query);
  else
    num_outputs=block.NumOutputPorts;
    data_entity_port = table('Size', [num_outputs 1],'VariableNames', {'name_res'},'VariableTypes', {'string'});
    PortHandles=get_param(gcb,'PortHandles');
    for i=1:num_outputs
        data_entity_port.name_res(i)=get_param(PortHandles.Outport(i),'Name');
    end
    
  end
  
  
  % discrete state substitution  %%var_type
  if num_state_var>0
    for i=1:num_state_var
        if (block.Dwork(6).Data(i)==1) || (block.Dwork(6).Data(i)==3)  % var_type=discrete
            step_sended=strrep(step_sended,block.Dwork(i+offset).name,strcat('block.Dwork(',num2str(i),'+offset).data'));  
        end
    end    
  end 
  
 
  
  % continuous state substitution
  if num_state_var>0
    j=0;
    for i=1:num_state_var
        if block.Dwork(6).Data(i)==0  % var_type=continuous
            j=j+1;
            step_sended=strrep(step_sended,block.Dwork(i+offset).name,strcat('block.ContStates.Data(',num2str(j),')'));  
        end
    end    
  end 
  
  
  % Output substitution
  num_outputs=block.NumOutputPorts;
  if block.DialogPrm(5).Data
      num_outputs=block.NumOutputPorts-1;
  end
  
  
  if num_outputs>0
    
    c=cell(num_outputs,3);
    for i=1:num_outputs
        c{i,1}=length(data_entity_port.name_res{i});
        c{i,2}=data_entity_port.name_res{i};
        c{i,3}=i;
    end      
    c=sortrows(c,'descend');

    for i=1:num_outputs
        a=c{i,2};
        step_sended=strrep(step_sended,a,strcat('block.OutputPort(',num2str(c{i,3}),').data'));   
    end    
  end
    

  
  % final preparation
  step_sended=uint8(step_sended);
  n=length(step_sended);  
  step_sended=[step_sended 32*ones(1,10000-n)];
  block.Dwork(14).Data = step_sended;
  %char(block.Dwork(14).Data)
  
    
  mask_values{6}='off';
  
  
  
  if cisia.loadfrommask==0
  % Salvataggio degli ultimi parametri della Mask
  
      mask_values{11}=string(data_entity.id_entity(1));
      mask_values{12}=string(data_entity.id_project(1));
      mask_values{13}=string(data_entity.id_type(1));

      %disp('scrivo mask values 2')
      
      if strcmp(get_param(cisia.gcs,'FastRestart'),'off')
        set_param(gcb,'MaskValues',mask_values);
        %disp('Save on mask')
      end
      
  end
  
  

end % CISIA MASTER

%disp(['END START:' name_entity])
   
%endfunction

function WriteRTW(block)
  
   block.WriteRTWParam('matrix', 'M',    [1 2; 3 4]);
   block.WriteRTWParam('string', 'Mode', 'Auto');
   
%endfunction

%% -----------------
%
%
function Outputs(block)



global cisia;

name_entity=block.DialogPrm(1).Data;
%user.name_entity=name_entity;





if strcmp(name_entity,'CISIA_MASTER')

    block.OutputPort(1).Data=block.Dwork(1).data;
    block.OutputPort(2).Data=block.Dwork(2).data;
    
    
    if block.DialogPrm(8).Data && isfield(cisia,'delta')
        time_now=now;
        minutes=str2double(string(datetime(time_now,'ConvertFrom','datenum','Format', 'mm')));
        seconds=str2double(string(datetime(time_now,'ConvertFrom','datenum','Format', 'ss')));
        milliseconds=str2double(string(datetime(time_now,'ConvertFrom','datenum','Format', 'SSS')));
        cisia.time_past=minutes*60+seconds+milliseconds/1000;
    
        block.OutputPort(3).Data=cisia.delta;
        block.OutputPort(4).Data=cisia.time_past_sec;   %+block.DialogPrm(9).Data;
        
    else
        block.OutputPort(3).Data=0;
        block.OutputPort(4).Data=0;
    end
    
    
    
%-------------------------------------------------------------------------------------    
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'LINK')),'1')  % LINK ENTITY
    
    if block.DialogPrm(7).Data
        for i=1:block.NumOutputPorts
           if block.InputPort(2).data==i
               block.OutputPort(i).Data=block.InputPort(1).Data;
           else
               block.OutputPort(i).Data=block.DialogPrm(5).Data;
           end
        end
    else
        for i=1:block.NumOutputPorts
           if block.Dwork(1).data==i
               block.OutputPort(i).Data=block.InputPort(1).Data;
           else
               block.OutputPort(i).Data=block.DialogPrm(5).Data*ones(1,block.OutputPort(i).Dimensions);
           end
        end
    end
    
%-------------------------------------------------------------------------------------    
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'ROUTE')),'1')  % ROUTE ENTITY

  
    
for i=0:block.NumOutputPorts-1
    res_out=zeros(1,block.Dwork(3).Data);  %  inizializza le risorse in output per la singola porta
    for j=1:block.Dwork(3).Data % per tutte le risorse
        if block.DialogPrm(7).Data
            if block.InputPort(2).Data(i*block.NumOutputPorts+j)==1
                res_out(1,j)=block.InputPort(1).Data(j);
            end
        else
            if block.Dwork(1).Data(i*block.Dwork(3).Data+j)==1
                res_out(1,j)=block.InputPort(1).Data(j);
            end
        end
    end
    block.OutputPort(i+1).Data=res_out;
end

    
%-------------------------------------------------------------------------------------
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'SAVE')),'1')  % SAVE ENTITY
    
% salvataggio in Dworks
    if ~(isreal(block.DialogPrm(3).Data))
        block.Dwork(4).Data=block.InputPort(1).data;
    elseif block.CurrentTime<=block.DialogPrm(3).Data
        block.Dwork(4).Data=block.InputPort(1).data;
    end

    
%-------------------------------------------------------------------------------------   
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'RFDB')),'1')  % RFDB ENTITY
    

query=['SELECT * FROM actual_values WHERE var_name=''' block.DialogPrm(4).Data ''''];
data_variable=fetch(cisia.conn, query);

block.OutputPort(1).Data=str2double(data_variable.value{1});

    
%-------------------------------------------------------------------------------------       

else % normal ENTITY
   
    
    

% STEP RECEIVED during first OUTPUT

if (block.CurrentTime==0)
    step_received=strrep(char(block.Dwork(11).data'),'@','');
    offset=cisia.offset;

    try
       Tout=evalc(step_received);
       disp(Tout)
       if ~isempty(Tout)
          disp(strcat('Output produced in step_received of entity:',name_entity)) 
       end
    catch exception
       disp(strcat('*** ERROR in step received during first OUTPUT of entity:',name_entity,' ***'))
       disp(step_received)
       eval(step_received);
    end
end
    



% STEP SENDED: output 

    step_sended=strrep(char(block.Dwork(14).data'),'@','');
    offset=cisia.offset;
    try
       Tout=evalc(step_sended);
       disp(Tout)
       if ~isempty(Tout)
          disp(strcat('Output produced in step_sended of entity:',name_entity)) 
       end
    catch exception
       disp(strcat('Error in step_sended for entity:',name_entity)) 
       disp(step_sended)
       eval(step_sended);
    end
   
    
    
    
    % mette in output lo stato se necessario
    if block.DialogPrm(5).Data % Bring state variables to output
        output=zeros(block.NumOutputPorts-1,1);
        for i=1:block.Dwork(5).data   % FORSE DOVREBBE ESSERE MENO UNO  *** ERROR ***
            j=0;
            if block.Dwork(6).Data(i)==0  % CONTINUOUS
                j=j+1;
                output(i)=block.ContStates.Data(j);
            elseif block.Dwork(6).Data(i)==1 % NUMERIC
                output(i)=block.Dwork(i+offset).data; 
            elseif block.Dwork(6).Data(i)==3 % NUMERIC ARRAY
                output(i)=block.Dwork(i+offset).data(1); % PURTROPPO SOLO IL PRIMO ELEMENTO %%var_type
            else % STRING
                output(i)=0;
            end
        end
       block.OutputPort(block.NumOutputPorts).data=output;
    end
    
    

    
%end

end % CISIA MASTER
  



%endfunction

function Update(block)



global cisia;

if cisia.update==0
    cisia.time_start=now;
    cisia.update=1;
end



name_entity=block.DialogPrm(1).Data;

%now1 = tic();
%disp(strcat('Update for:',name_entity))

%% Update next sampling time

if strcmp(name_entity,'CISIA_MASTER') % CISIA MASTER
   
% block.CurrentTime

    if cisia.force_major_update==1 % if major update has been performed
        cisia.force_major_update=0;
    end
    
    %cisia
    %block.CurrentTime
    
    if cisia.last_input_update==0 && cisia.first_run==0 % second time with no input update
        
        %disp('MASTER MAJOR')
        
        cisia.major_time=cisia.last_major_timehit;
        
        %cisia.last_major_timehit=cisia.last_major_timehit+cisia.major_sampling_time; % next major hit
        
        if cisia.time_index<length(cisia.major_sampling_time)
            cisia.time_index=cisia.time_index+1;
            cisia.last_major_timehit=cisia.major_sampling_time(cisia.time_index); % next major hit
           
        else
            cisia.last_major_timehit=block.CurrentTime+1; % next major hit di default
        end
        
        
        
        %cisia.last_major_timehit=block.CurrentTime+cisia.major_sampling_time; % next major hit
        
        
        %current_time=block.CurrentTime
        block.NextTimeHit=cisia.last_major_timehit; % next time hit is major hit
        
        cisia.force_major_timehit=1; % force major hit for every block
        cisia.last_input_update=1;
        %cisia.first_run=1;
        
        block.Dwork(2).Data=block.Dwork(2).Data+1; % increment major hits number
        %cisia_struct
        
        
        
        
    else % perform an other minor hit
        
        %display('MASTER MINOR')

        
        if (cisia.force_major_timehit==1) || (block.CurrentTime==0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if block.DialogPrm(8).Data
                
                %ct=block.CurrentTime
                %lmth=cisia.last_major_timehit
                
                cisia.actual_time=now;
                cisia.time_past=cisia.actual_time-cisia.time_start;
                minutes=str2double(string(datetime(cisia.time_past,'ConvertFrom','datenum','Format', 'mm')));
                seconds=str2double(string(datetime(cisia.time_past,'ConvertFrom','datenum','Format', 'ss')));
                milliseconds=str2double(string(datetime(cisia.time_past,'ConvertFrom','datenum','Format', 'SSS')));
                cisia.time_past_sec=minutes*60+seconds+milliseconds/1000;
                %cisia.delta=cisia.last_major_timehit+cisia.major_sampling_time-cisia.time_past_sec;
                
                if isfield(cisia,'delta')
                    cisia.delta=cisia.delta+cisia.last_major_timehit-cisia.time_past_sec;
                else
                    cisia.delta=cisia.last_major_timehit+cisia.major_sampling_time-cisia.time_past_sec;
                end
                                
                
                
                %cisia.delta=block.CurrentTime-cisia.time_past_sec; 

                % se il major_hit supera il tempo vero, inserisci una pausa
                if cisia.delta>0
                   set_param(gcb,'BackgroundColor','cyan')
                   pause(cisia.delta)
                else
                   set_param(gcb,'BackgroundColor','red')
                   disp('red')
                end
            
            end
 
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
        end
        
         
        if cisia.force_major_timehit==1
            cisia.force_major_timehit=0; % terminate forcing major hit
            cisia.force_major_update=1; % force update for major hit;
            
            
            
            
        end
        
        cisia.first_run=0; % end of first run
        cisia.last_input_update=0; % try no update condition
               
        block.Dwork(1).Data=block.Dwork(1).Data+1; % increment minor hits number
        block.NextTimeHit=block.CurrentTime+cisia.minor_sampling_time; % next time is minor hit
        cisia.last_minor_timehit=block.CurrentTime;        
    end
    
    
    
    
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'LINK')),'1') || strcmp(num2str(strfind(block.DialogPrm(1).Data,'ROUTE')),'1') || strcmp(num2str(strfind(block.DialogPrm(1).Data,'RFDB')),'1')% LINK or ROUTE or RFDB
    
    if cisia.force_major_timehit==1 & block.Dwork(2).data==0  % a major hit can be issued
        %disp([name_entity ' force major to ' num2str(cisia.last_major_timehit)])
        block.NextTimeHit=cisia.last_major_timehit; % next time hit has already been computed 
        block.Dwork(2).data=1; % major hit issued
    else
        
        %disp([name_entity ' force minor'])
        block.NextTimeHit=block.CurrentTime+cisia.minor_sampling_time; % next time is minor hit
        block.Dwork(2).data=0; % mimor hit issued
    end
    
    
elseif strcmp(num2str(strfind(block.DialogPrm(1).Data,'SAVE')),'1')% SAVE
    
    if cisia.force_major_timehit==1 & block.Dwork(2).data==0  % a major hit can be issued
        %disp([name_entity ' force major to ' num2str(cisia.last_major_timehit)])
        block.NextTimeHit=cisia.last_major_timehit; % next time hit has already been computed 
        block.Dwork(2).data=1; % major hit issued
        
        % Save the state
        if (block.CurrentTime>=cisia.major_sampling_time(1)) && (cisia.save_major_hits==1)
            SaveBlock(block,0,1)
        end
        
        
    else
        
        %disp([name_entity ' force minor'])
        block.NextTimeHit=block.CurrentTime+cisia.minor_sampling_time; % next time is minor hit
        block.Dwork(2).data=0; % mimor hit issued
    end
    
    
else 
    
    % NORMAL ENTITY
    %current_time=block.CurrentTime
    
    %cisia_struct
    
    if cisia.force_major_timehit==1 & block.Dwork(10).data==0  % a major hit can be issued
        %disp([name_entity ' force major to ' num2str(cisia.last_major_timehit)])
        block.NextTimeHit=cisia.last_major_timehit; % next time hit has already been computed 
        block.Dwork(10).data=1; % major hit issued
                    
        % Save the state
        if block.CurrentTime>=cisia.major_sampling_time(1) && (cisia.save_major_hits==1)
            SaveBlock(block,0,1)
        end
        
    else
        
        %disp([name_entity ' force minor'])
        block.NextTimeHit=block.CurrentTime+cisia.minor_sampling_time; % next time is minor hit
        block.Dwork(10).data=0; % mimor hit issued
    end
    
    
end % CISIA _MASTER o LINK o SAVE o ROUTE o RFDB

%% Perform the update for cisia blocks


if (~strcmp(name_entity,'CISIA_MASTER')) && isempty(strfind(block.DialogPrm(1).Data,'LINK'))  && isempty(strfind(block.DialogPrm(1).Data,'SAVE')) && isempty(strfind(block.DialogPrm(1).Data,'ROUTE')) && isempty(strfind(block.DialogPrm(1).Data,'RFDB'))

    %if input are changed then cisia.last_input_update=1;
    %cisia.last_input_update=0;
    
    % NORMAL ENTITY  
    
    if cisia.force_major_update==1 % if we have forced a major update
        cisia.last_input_update=1; % force update during major hit update
    
    else % minor hit time
        
%         disp(strcat(name_entity, ':input check', num2str(block.CurrentTime)))
        
        if block.NumInputPorts>0
            
            input_port=[];
            
            for i=1:block.NumInputPorts
                input_port=[input_port; block.InputPort(i).data];
            end
            
%             if strcmp(name_entity,'R_F_2')
%                disp(strcat(num2str(input_port),':' ,num2str(block.Dwork(9).Data))) 
%             end
            
            %sum(abs(input_port-block.Dwork(9).Data))
            
            if sum(abs(input_port-block.Dwork(9).Data)) % input has changed 
               %disp(strcat('Input changed for:',name_entity))
               %ct=block.CurrentTime
               block.Dwork(9).Data=input_port; % store last input
               cisia.last_input_update=1;
            else
               %disp(['NO UPDATE ' name_entity])
            end
            
            
        end
    end

    
    
    

%% STEP RECEIVED: no dynamics

%disp('step received')
step_received=strrep(char(block.Dwork(11).data'),'@','');
offset=cisia.offset;



try
   eval(step_received);
catch exception
   disp(strcat('*** ERROR in step received during update of entity:',name_entity,' ***'))
   disp(step_received)
   eval(step_received);
end


%% STEP COMPUTED: discrete dynamics


if cisia.force_major_update==1 % major update time
    
    
    %new_state=zeros(1,block.Dwork(5).Data);
    
    new_state=cell(1,block.Dwork(5).Data);
    
    for i=1:block.Dwork(5).Data  % num_state_var
        if (block.Dwork(6).Data(i)==1) || (block.Dwork(6).Data(i)==3)  % var_type=discrete or array
            %new_state(i)=block.Dwork(i+offset).data;
            new_state{i}=block.Dwork(i+offset).data;
        end
    end
    
    
    %disp('update major')
    step_computed=strrep(char(block.Dwork(12).data'),'@','');
    
    
    
    
    try
        eval(step_computed);
    catch exception
        disp(strcat('****** Error in step_computed for entity:',name_entity,' ******'))
        disp(step_computed)
        eval(step_computed);
    end
    
    for i=1:block.Dwork(5).Data  % num_state_var
        if block.Dwork(6).Data(i)==1  % var_type is discrete
            block.Dwork(i+offset).data=new_state{i};
        end
    end
    

end


end % NOT CISIA MASTER

%wholeTime = toc(now1);
%disp(strcat('End update for:',name_entity,'(',string(wholeTime),')'))


%endfunction

function Derivatives(block) 
global cisia;

name_entity=block.DialogPrm(1).Data;


%disp(strcat('Derivatives for:',name_entity))

if (~strcmp(name_entity,'CISIA_MASTER')) && isempty(strfind(block.DialogPrm(1).Data,'LINK')) && isempty(strfind(block.DialogPrm(1).Data,'SAVE'))  && isempty(strfind(block.DialogPrm(1).Data,'ROUTE')) && isempty(strfind(block.DialogPrm(1).Data,'RFDB'))
    
    %disp('derivatives')

%% DYNAMIC COMPUTED
    offset=cisia.offset; 
    dynamic_computed=strrep(char(block.Dwork(13).data'),'@','');
    
    try
        eval(dynamic_computed);
    catch exception
        disp(dynamic_computed)
        eval(dynamic_computed);
    end
    
   

else
    %disp('derivative master')
end

%endfunction

function Projection(block)

%states = block.ContStates.Data;
%block.ContStates.Data = states+eps; 

%endfunction

function SimStatusChange(block, s)
  
  block.Dwork(2).Data = block.Dwork(2).Data+1;    

  if s == 0
    disp('Pause in simulation.');
  elseif s == 1
    disp('Resume simulation.');
  end
  
%endfunction
    
function Terminate(block)

global cisia;


if cisia.phase==3
    disp('PHASE: Terminate')
    cisia.phase=2;
end

if (cisia.save_major_hits==1)
    SaveBlock(block,1,0)
else
    SaveBlock(block,1,1)
end

if cisia.num_blocks==cisia.max_blocks
    disp('FIRST BLOCK TERMINATED')
end

cisia.num_blocks=cisia.num_blocks-1;
if cisia.num_blocks==0
    %close(cisia.conn)
    %disp('Connection closed')
    %save('cisia')
    
    
    query=strcat('UPDATE run SET end_of_run=1 WHERE id_run=',string(cisia.id_run));
    execute(cisia.conn, query);
    
    disp('LAST BLOCK TERMINATED')
    disp(strcat('Elapsed time:',num2str(toc(cisia.tic))))
end
    



%endfunction
 
function outSimState = GetSimState(block)

outSimState = block.Dwork(1).Data;

%endfunction

function SetSimState(block, inSimState)

block.Dwork(1).Data = inSimState;

%endfunction


function SaveBlock(block, info, state)

global cisia;

name_entity=block.DialogPrm(1).Data;


if isempty(strfind(block.DialogPrm(1).Data,'LINK'))  % NOT A LINK

    if isempty(strfind(block.DialogPrm(1).Data,'SAVE'))  % NOT A SAVE

        if isempty(strfind(block.DialogPrm(1).Data,'ROUTE'))  % NOT A ROUTE

            if isempty(strfind(block.DialogPrm(1).Data,'RFDB'))  % NOT A RFDB

                % STANDARD ENTITY
                if block.Dwork(5).Data>0

                    offset=cisia.offset;

                    if info==1
                    % insert entity in actual_entities
                        query=strcat('INSERT INTO actual_entities (name_entity, block_handler) VALUES (''',name_entity,''',''',string(gcb),''')');
                        execute(cisia.conn,query);

                        for i=0:block.Dwork(5).Data
                            op_level=1;
                            if strcmp(upper(block.Dwork(i+offset).name),'OPERATIVE_LEVEL')
                                  op_level=block.Dwork(i+offset).data;
                                  index=floor(20*op_level)+1;
                                  if index<0
                                     disp(block.DialogPrm(1).Data)
                                  end
                                  color=num2str(cisia.colormap(index,:));
                                  if cisia.colors==1
                                    set_param(gcb,'BackgroundColor',['[' color ']'])
                                  end
                                  %query=strcat('INSERT INTO run_output (id_run, sim_time, name_entity, name_var, val_type, val_status) VALUES (''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''' , ''OL_COLOR'' , ''NUMERIC ARRAY'' ,''', color,''')');
                                  %execute(cisia.conn,query)

                            end
                        end
                    end

                   if state==1
                       query='INSERT INTO run_output (id_run, sim_time, name_entity, name_var, val_type, val_status) VALUES ';

                       for i=1: block.Dwork(5).Data
                           j=0;
                           if block.Dwork(6).Data(i)==0 %CONTINUOUS
                                j=j+1;
                                %query=strcat('INSERT INTO run_output (id_run, sim_time, name_entity, name_var, val_type, val_status) VALUES (''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''',''', block.Dwork(i+cisia.offset).name,''',', '''CONTINUOUS''',',''', num2str(block.ContStates.data(j)),''')');
                                add_query=strcat('(''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''',''', block.Dwork(i+cisia.offset).name,''',', '''CONTINUOUS''',',''', num2str(block.ContStates.data(j)),''')');
                                %execute(cisia.conn,query)
                           elseif block.Dwork(6).Data(i)==1 % NUMERIC
                                %query=strcat('INSERT INTO run_output (id_run, sim_time, name_entity, name_var, val_type, val_status) VALUES (''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''',''', block.Dwork(i+cisia.offset).name,''',', '''NUMERIC''',',''', num2str(block.Dwork(i+cisia.offset).Data),''')');
                                add_query=strcat('(''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''',''', block.Dwork(i+cisia.offset).name,''',', '''NUMERIC''',',''', num2str(block.Dwork(i+cisia.offset).Data),''')');
                                %execute(cisia.conn,query)
                           elseif block.Dwork(6).Data(i)==3 % NUMERIC_ARRAY
                                %query=strcat('INSERT INTO run_output (id_run, sim_time, name_entity, name_var, val_type, val_status) VALUES (''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''',''', block.Dwork(i+cisia.offset).name,''',', '''NUMERIC_ARRAY''',',''', num2str(block.Dwork(i+cisia.offset).Data'),''')');
                                add_query=strcat('(''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''',''', block.Dwork(i+cisia.offset).name,''',', '''NUMERIC_ARRAY''',',''', num2str(block.Dwork(i+cisia.offset).Data'),''')');
                                %execute(cisia.conn,query)
                           elseif block.Dwork(6).Data(i)==2 % STRING
                                %query=strcat('INSERT INTO run_output (id_run, sim_time, name_entity, name_var, val_type, val_status) VALUES (''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''',''', block.Dwork(i+cisia.offset).name,''',', '''STRING''',',''', strtrim(string(char(block.Dwork(i+cisia.offset).Data)')),''')');
                                add_query=strcat('(''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''',''', block.Dwork(i+cisia.offset).name,''',', '''STRING''',',''', strtrim(string(char(block.Dwork(i+cisia.offset).Data)')),''')');
                                %execute(cisia.conn,query)
                           else
                               disp('Unnown datatype')
                               add_query='';
                           end

                           if i==block.Dwork(5).Data
                               query=strcat(query,add_query);

                               if ~cisia.skipsaving
                                execute(cisia.conn,query)
                               end

                           else
                               query=strcat(query,add_query, ',');

                           end

                       end
                   end

                end % if block.Dwork(5).Data>0

            end % if not RFDB
        end % if not ROUTE
    end % if not SAVE
end % if not LINK

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmp(num2str(strfind(block.DialogPrm(1).Data,'SAVE')),'1')  % SAVE ENTITY

    if state==1
        data=num2str(block.Dwork(4).Data');
        query=strcat('INSERT INTO run_output (id_run, sim_time, name_entity, name_var, val_type, val_status) VALUES (''', string(cisia.id_run),''',''' , num2str(block.CurrentTime),''',''', block.DialogPrm(1).Data,''',''', strtrim(string(char(block.Dwork(1).Data)')),''',', '''RESOURCE''',',''', data,''')');
        if ~cisia.skipsaving
            execute(cisia.conn,query)
        end
    
    end

%     color=num2str(cisia.colormap(floor(20*block.Dwork(4).Data)+1,:));
%     if cisia.colors==1
%         set_param(gcb,'BackgroundColor',['[' color ']'])
%     end
    
    %set_param(gcb,'Parameter5',['[' block.Dwork(4).Data ']'])
    set_param(gcb,'Parameter5',['[' num2str(block.Dwork(4).Data') ']'])
    %disp(block.DialogPrm(1).Data)
    %disp(block.Dwork(4).Data')

    if info==1
        % insert save in actual_entities
        query=strcat('INSERT INTO actual_entities (name_entity, block_handler) VALUES (''',name_entity,''',''',string(gcb),''')');
        execute(cisia.conn,query);
    end
end

%endfunction

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% AUXILIARY FUNCTIONS

function [v]=timed_value(valori,tempi,t)

    indice=find(tempi<=t);
    v=valori(indice(end));







