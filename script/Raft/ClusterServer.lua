--[[
Title: 
Author: liuluheng
Date: 2017.03.25
Desc: 

Cluster server configuration 
a class to hold the configuration information for a server in a cluster
------------------------------------------------------------
NPL.load("(gl)script/Raft/ClusterServer.lua");
local ClusterServer = commonlib.gettable("Raft.ClusterServer");
------------------------------------------------------------
]]--


local ClusterServer = commonlib.gettable("Raft.ClusterServer");

function ClusterServer:new() 
    local o = {
        id = 0,
        endpoint = "",
    };
    setmetatable(o, self);
    return o;
end

function ClusterServer:__index(name)
    return rawget(self, name) or ClusterServer[name];
end

function ClusterServer:__tostring()
    return util.table_tostring(self)
end


function ClusterServer:toBytes()
    return ;
end
