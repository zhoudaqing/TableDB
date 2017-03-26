--[[
Title: 
Author: liuluheng
Date: 2017.03.25
Desc: 
]]--

NPL.load("(gl)script/ide/commonlib.lua");
NPL.load("(gl)script/ide/System/Compiler/lib/util.lua");
NPL.load("(gl)script/Raft/ServerState.lua");
NPL.load("(gl)script/Raft/ServerStateManager.lua");
NPL.load("(gl)script/Raft/RaftParameters.lua");
NPL.load("(gl)script/Raft/RaftContext.lua");
NPL.load("(gl)script/Raft/RpcListener.lua");
NPL.load("(gl)script/Raft/MessagePrinter.lua");
NPL.load("(gl)script/Raft/RaftClient.lua");
NPL.load("(gl)script/ide/socket/url.lua");
NPL.load("(gl)script/Raft/RaftConsensus.lua");
NPL.load("(gl)script/Raft/RpcClient.lua");

local RaftClient = commonlib.gettable("Raft.RaftClient");
local ServerStateManager = commonlib.gettable("Raft.ServerStateManager");
local RaftParameters = commonlib.gettable("Raft.RaftParameters");
local RaftContext = commonlib.gettable("Raft.RaftContext");
local RpcListener = commonlib.gettable("Raft.RpcListener");
local url = commonlib.gettable("commonlib.socket.url")
local RaftConsensus = commonlib.gettable("Raft.RaftConsensus");
local RpcClient = commonlib.gettable("Raft.RpcClient");
local MessagePrinter = commonlib.gettable("Raft.MessagePrinter");
local util = commonlib.gettable("System.Compiler.lib.util")
local LoggerFactory = NPL.load("(gl)script/Raft/LoggerFactory.lua");

local logger = LoggerFactory.getLogger("App")


local baseDir = ParaEngine.GetAppCommandLineByParam("baseDir", "./");
local mpPort = ParaEngine.GetAppCommandLineByParam("mpPort", "8090");
local raftMode = ParaEngine.GetAppCommandLineByParam("raftMode", "server");

logger.info("app arg:"..baseDir..mpPort..raftMode)

local stateManager = ServerStateManager:new(baseDir);
local config = stateManager:loadClusterConfiguration();

logger.info("config:%s", util.table_tostring(config))

local localEndpoint = config:getServer(stateManager.serverId).endpoint
local parsed_url = url.parse(localEndpoint)
logger.info("local state info"..util.table_tostring(parsed_url))
local rpcListener = RpcListener:new(parsed_url.host, parsed_url.port, config.servers)

-- message printer
mp = MessagePrinter:new(baseDir, parsed_url.host, mpPort)

local function executeInServerMode(...)
    local raftParameters = RaftParameters:new()
    raftParameters.electionTimeoutUpperBound = 5000;
    raftParameters.electionTimeoutLowerBound = 3000;
    raftParameters.heartbeatInterval = 1500;
    raftParameters.rpcFailureBackoff = 500;
    raftParameters.maximumAppendingSize = 200;
    raftParameters.logSyncBatchSize = 5;
    raftParameters.logSyncStoppingGap = 5;
    raftParameters.snapshotEnabled = 5000;
    raftParameters.syncSnapshotBlockSize = 0;

    local context = RaftContext:new(stateManager,
                                    mp,
                                    raftParameters,
                                    rpcListener,
                                    LoggerFactory);
    RaftConsensus.run(context);
end


local function executeAsClient(localAddress, RequestRPC, configuration, loggerFactory)
    local raftClient = RaftClient:new(localAddress, RequestRPC, configuration, loggerFactory)

    local values = {
      "test:1111",
      "test:1112",
      "test:1113",
      "test:1114",
      "test:1115",
    }

    raftClient:appendEntries(values, function (err, response)
      local result = (err == nil and response.accepted and "accepted") or "denied"
      logger.info("the request has been %s", result)
    end)

end

if raftMode:lower() == "server" then
  executeInServerMode()
elseif raftMode:lower() == "client" then
  local localAddress = {
    host = "localhost",
    port = "9004",
    id = "server4:",
  }
  NPL.StartNetServer(localAddress.host, localAddress.port);
  mp:start()
  executeAsClient(localAddress, MPRequestRPC, config, LoggerFactory)
end



local function activate()
  --  if(msg) then
      --- C/C++ API call is counted as one instruction, so if you call ParaEngine.Sleep(10), 
      --it will block all concurrent jobs on that NPL thread for 10 seconds
      -- ParaEngine.Sleep(0.5);
  --  end
end

NPL.this(activate);