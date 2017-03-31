--[[
Title: 
Author: liuluheng
Date: 2017.03.25
Desc: 


------------------------------------------------------------
NPL.load("(gl)script/app/MessagePrinter.lua");
local MessagePrinter = commonlib.gettable("app.MessagePrinter");
------------------------------------------------------------
]]--
NPL.load("(gl)script/ide/System/Compiler/lib/util.lua");
local util = commonlib.gettable("System.Compiler.lib.util")

NPL.load("(gl)script/Raft/Rpc.lua");
local Rpc = commonlib.gettable("Raft.Rpc");
local MessagePrinter = commonlib.gettable("app.MessagePrinter");

function MessagePrinter:new(baseDir, ip, listeningPort) 
    local o = {
        -- ip = ip,
        -- port = listeningPort,
        logger = commonlib.logging.GetLogger(""),
        snapshotStore = baseDir.."snapshot/",
        commitIndex = 0,
        messageSender = nil,
        snapshotInprogress = false,

        messages = {},
        pendingMessages = {},
    };
    setmetatable(o, self);

    if not ParaIO.CreateDirectory(o.snapshot) then
        o.logger.error("%s create error", baseDir)
    end
    return o;
end

function MessagePrinter:__index(name)
    return rawget(self, name) or MessagePrinter[name];
end

function MessagePrinter:__tostring()
    return util.table_tostring(self)
end


--[[
 * Starts the state machine, called by RaftConsensus, RaftConsensus will pass an instance of
 * RaftMessageSender for the state machine to send logs to cluster, so that all state machines
 * in the same cluster could be in synced
 * @param raftMessageSender
 ]]--
function MessagePrinter:start(raftMessageSender)
    self.messageSender = raftMessageSender;
    local o = self;

    -- use Rpc for incoming Request message
    Rpc:new():init("MPRequestRPC", function(self, msg) 
        -- LOG.std(nil, "info", "MPRequestRPC", msg);
        msg = o:processMessage(msg)
        return msg; 
    end)

    -- port is need to be string here??
    -- NPL.StartNetServer(self.ip, tostring(self.port));
    MPRequestRPC:MakePublic();

end
    
--[[
 * Commit the log data at the {@code logIndex}
 * @param logIndex the log index in the logStore
 * @param data 
 ]]--
function MessagePrinter:commit(logIndex, data)
    local message = data;
    print(format("commit: %d\t%s", logIndex, message));
    self.commitIndex = logIndex;
    self:addMessage(message);
end

--[[
 * Rollback a preCommit item at index {@code logIndex}
 * @param logIndex log index to be rolled back
 * @param data
 ]]--
function MessagePrinter:rollback(logIndex, data)
    local message = data;
    local index = string.find(message, ':');
    if(index ~= nil) then
        key = string.sub(message, 1, index - 1);
        self.pendingMessages[key] = nil;
    end

    print(format("Rollback index %d\t%s", logIndex, message or ""));
end

--[[
 * PreCommit a log entry at log index {@code logIndex}
 * @param logIndex the log index to commit
 * @param data
 ]]--
function MessagePrinter:preCommit(logIndex, data)
    local message = data;
    print(string.format("PreCommit:%s at %d", message, tonumber(logIndex)));

    local index = string.find(message, ':');
    if(index ~= nil) then
        key = string.sub(message, 1, index - 1);
        self.pendingMessages[key] = message;
    end
end

--[[
 * Save data for the snapshot
 * @param snapshot the snapshot information
 * @param offset offset of the data in the whole snapshot
 * @param data part of snapshot data
 ]]--
function MessagePrinter:saveSnapshotData(snapshot, offset, data)
    local filePath = self.snapshotStore..string.format("%d-%d.s", snapshot.lastLogIndex, snapshot.lastLogTerm);

    if(not ParaIO.DoesFileExist(filePath)) then
        local snapshotConf = self.snapshotStore..string.format("%d.cnf", snapshot.lastLogIndex);
        local sConf = ParaIO.open(snapshotConf, "rw");
        local bytes = snapshot.lastConfig:toBytes();
        sConf:WriteBytes(#bytes, {bytes:byte(1, -1)})
    end

    local snapshotFile = ParaIO.open(filePath, "rw");
    snapshotFile:seek(offset);
    snapshotFile:write(data);
    snapshotFile:close();
end

--[[
 * Apply a snapshot to current state machine
 * @param snapshot
 * @return true if successfully applied, otherwise false
 ]]--
function MessagePrinter:applySnapshot(snapshot)
    local filePath = self.snapshotStore..string.format("%d-%d.s", snapshot.lastLogIndex, snapshot.lastLogTerm);
    if(not ParaIO.DoesFileExist(filePath)) then
        return false;
    end

    local snapshotFile = ParaIO.open(filePath, "rw");

    self.messages = {}
    local line = snapshotFile:readline();
    while line do
        if #line > 0 then
            print(format("from snapshot: %s", line))
            self:addMessage(line)
        end

        line = snapshotFile:readline();
    end
    self.commitIndex = snapshot.lastLogIndex;
    snapshotFile:close()
end

--[[
 * Read snapshot data at the specified offset to buffer and return bytes read
 * @param snapshot the snapshot info
 * @param offset the offset of the snapshot data
 * @param buffer the buffer to be filled
 * @return bytes read
 ]]--
function MessagePrinter:readSnapshotData(snapshot, offset, buffer, expectedSize)
    local filePath = self.snapshotStore..string.format("%d-%d.s", snapshot.lastLogIndex, snapshot.lastLogTerm);
    if(not ParaIO.DoesFileExist(filePath)) then
        return -1;
    end

   local snapshotFile = ParaIO.open(filePath, "rw");

   snapshotFile:seek(offset);

   snapshotFile:ReadBytes(expectedSize, buffer);

   return expectedSize;

end

--[[
 * Read the last snapshot information
 * @return last snapshot information in the state machine or null if none
 ]]--
function MessagePrinter:getLastSnapshot()

end

--[[
 * Create a snapshot data based on the snapshot information asynchronously
 * set the future to true if snapshot is successfully created, otherwise, 
 * set it to false
 * @param snapshot the snapshot info
 * @return true if snapshot is created successfully, otherwise false
 ]]--
function MessagePrinter:createSnapshot(snapshot)
    if(snapshot.lastLogIndex > self.commitIndex) then
        return false;
    end

    if self.snapshotInprogress then
        return false;
    end

    self.snapshotInprogress = true;
    local copyOfMessages = self.messages


    -- make async ??
    local filePath = self.snapshotStore..string.format("%d-%d.s", snapshot.lastLogIndex, snapshot.lastLogTerm);

    if(not ParaIO.DoesFileExist(filePath)) then
        local snapshotConf = self.snapshotStore..string.format("%d.cnf", snapshot.lastLogIndex);
        local sConf = ParaIO.open(snapshotConf, "rw");
        local bytes = snapshot.lastConfig:toBytes();
        sConf:WriteBytes(#bytes, {bytes:byte(1, -1)})
    end

    local snapshotFile = ParaIO.open(filePath, "rw");

    for _,v in ipairs(self.messages) do
        snapshotFile:WriteBytes(#v, {v:byte(1, -1)})
        snapshotFile:WriteBytes(1, {string.byte("\n")})
    end

    snapshotFile:close();

    self.snapshotInprogress = false;


    return true;
end

--[[
 * Save the state of state machine to ensure the state machine is in a good state, then exit the system
 * this MUST exits the system to protect the safety of the algorithm
 * @param code 0 indicates the system is gracefully shutdown, -1 indicates there are some errors which cannot be recovered
 ]]--
function MessagePrinter:exit(code)
end


function MessagePrinter:processMessage(message)
    print("Got message " .. util.table_tostring(message));
    return self.messageSender:appendEntries(message);
end


function MessagePrinter:addMessage(message)
    index = string.find(message, ':');
    if(index == nil ) then
        return;
    end
    
    key = string.sub(message, 1, index-1);
    self.messages[key] = message;
    self.pendingMessages[key] = nil;

end