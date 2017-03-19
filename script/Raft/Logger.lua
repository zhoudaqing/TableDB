--[[
Title: 
Author: 
Date: 
Desc: 


------------------------------------------------------------
NPL.load("(gl)script/Raft/Logger.lua");
local Logger = commonlib.gettable("Raft.Logger");
------------------------------------------------------------
]]--

local Logger = commonlib.gettable("Raft.Logger");

function Logger:new(modname)
    local module_name = modname or ""
    local logger = commonlib.logging.GetLogger(module_name);
    local function appender(level, ...)
        logger.std(nil, level, module_name, ...)
    end

    logger.setAppender(appender)
    local o = logger;
    setmetatable(o, self);
    return o;
end

function Logger:__index(name)
    return rawget(self, name) or Logger[name];
end

function Logger:__tostring()
    return util.table_tostring(self)
end
