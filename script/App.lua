--[[
Title: 
Author: 
Date: 
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

-- local ServerState = commonlib.gettable("Raft.ServerState");
-- local ServerRole = NPL.load("(gl)script/Raft/ServerRole.lua");
local ServerStateManager = commonlib.gettable("Raft.ServerStateManager");
local RaftParameters = commonlib.gettable("Raft.RaftParameters");
local RaftContext = commonlib.gettable("Raft.RaftContext");
local RpcListener = commonlib.gettable("Raft.RpcListener");
NPL.load("(gl)script/ide/socket/url.lua");
local url = commonlib.gettable("commonlib.socket.url")
NPL.load("(gl)script/Raft/RaftConsensus.lua");
local RaftConsensus = commonlib.gettable("Raft.RaftConsensus");
NPL.load("(gl)script/Raft/RpcClient.lua");
local RpcClient = commonlib.gettable("Raft.RpcClient");
local MessagePrinter = commonlib.gettable("Raft.MessagePrinter");
local util = commonlib.gettable("System.Compiler.lib.util")
local LoggerFactory = NPL.load("(gl)script/Raft/LoggerFactory.lua");

local logger = LoggerFactory.getLogger("App")

-- local configDir = "script/config/"
-- local mpDir = "script/mpDir/"


local baseDir = ParaEngine.GetAppCommandLineByParam("baseDir", "1");
local mpPort = ParaEngine.GetAppCommandLineByParam("mpPort", "8090");

logger.info("app arg:"..baseDir..mpPort)

stateManager = ServerStateManager:new(baseDir);
config = stateManager:loadClusterConfiguration();

local localEndpoint = config:getServer(stateManager.serverId).endpoint
local parsed_url = url.parse(localEndpoint)
logger.info("local server info"..util.table_tostring(parsed_url))

raftParameters = RaftParameters:new()
raftParameters.electionTimeoutUpperBound = 5000;
raftParameters.electionTimeoutLowerBound = 3000;
raftParameters.heartbeatInterval = 1500;
raftParameters.rpcFailureBackoff = 500;
raftParameters.maximumAppendingSize = 200;
raftParameters.logSyncBatchSize = 5;
raftParameters.logSyncStoppingGap = 5;
raftParameters.snapshotEnabled = 5000;
raftParameters.syncSnapshotBlockSize = 0;

-- logger.debug(raftParameters)
-- message printer
mp = MessagePrinter:new(baseDir, parsed_url.host, mpPort)

context = RaftContext:new(stateManager,
                          mp,
                          raftParameters,
                          RpcListener:new(parsed_url.host, parsed_url.port, config.servers),
                          LoggerFactory);
RaftConsensus.run(context);





-- local serverState = ServerState:new()

-- NPL.load("(gl)script/ide/timer.lua");

-- local mytimer = commonlib.Timer:new({callbackFunc = function(timer)
-- 	logger({"ontimer", timer.id, timer.delta, timer.lastTick})
--   mytimer:Change()
-- end})

-- -- start the timer after 0 milliseconds, and signal every 1000 millisecond
-- logger.error("here")
-- mytimer:Change(0, 1000)
-- -- ParaEngine.Sleep(2);
-- -- 
-- -- mytimer:Change()
-- -- ParaEngine.Sleep(1);
-- logger.error("here2")
-- mytimer:Change(0, 1000)
-- logger.error("here")


-- logger.info(serverState)

-- -- must be colon, to provide the hidden self
-- serverState:increaseTerm()
-- logger.info(serverState)

-- logger.info(ServerRole.Follower)

-- test = {
--   a = "k",
--   b ="l"
-- }

-- util.table_print(test)

-- NPL.load("(gl)script/Raft/rpc.lua");
-- local rpc = commonlib.gettable("System.Concurrent.Async.rpc");
-- rpc:new():init("Test.testRPC", function(self, msg) 
-- 	LOG.std(nil, "info", "category", msg);
-- 	msg.output=true; 
-- 	-- ParaEngine.Sleep(1);
-- 	return msg; 
-- end)

-- NPL.StartNetServer("127.0.0.1", "60001");
-- NPL.AddNPLRuntimeAddress({host = "127.0.0.1", port = "60002", nid = "server2"})
-- Test.testRPC:MakePublic();
-- print(Test.testRPC)

-- -- now we can invoke it anywhere in any thread or remote address.
-- while(Test.testRPC("server1:","server2:", {"input"}, function(err, msg) 
--    LOG.std(nil, "info", "category", msg);
-- 	assert(msg.output == true and msg[1] == "input")
-- end) ~= 0) do end;

-- -- time out in 500ms
-- Test.testRPC("(worker1)", {"input"}, function(err, msg) 
-- 	assert(err == "timeout" and msg==nil)
-- 	echo(err);
-- end, 500);

-- NPL.activate("rpc/Test.testRPC.lua",{
-- 		type="run", 
-- 		msg = {"imputtest"}, 
-- 		name = "Test.testRPC",
-- 		-- callbackId = self.next_run_id, 
-- 		callbackThread="(osAsync)",
-- 	})


-- NPL.load("(gl)script/test/network/TestSimpleServer.lua");
-- test_start_simple_server();

--[[
local function activate()
   if(msg) then
      logger.info(msg.data or "");
      --- C/C++ API call is counted as one instruction, so if you call ParaEngine.Sleep(10), 
      --it will block all concurrent jobs on that NPL thread for 10 seconds
      ParaEngine.Sleep(0.5);
   end
   NPL.activate("(gl)script/helloworld.lua", {data="hello world!"})
end

NPL.this(activate);
]]--