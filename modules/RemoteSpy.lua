local RemoteSpy = {}
local Remote = import("objects/Remote")

local requiredMethods = {
    checkCaller = true,
    newCClosure = true,
    hookFunction = true,
    isReadOnly = true,
    setReadOnly = true,
    getInfo = true,
    getMetatable = true,
    setClipboard = true,
    getNamecallMethod = true,
    getCallingScript = true,
}

local remoteMethods = {
    FireServer = true,
    InvokeServer = true,
    Fire = true,
    Invoke = true
}

local remotesViewing = {
    RemoteEvent = true,
    UnreliableRemoteEvent = true,
    RemoteFunction = false,
    BindableEvent = false,
    BindableFunction = false
}

local methodHooks = {
    RemoteEvent = Instance.new("RemoteEvent").FireServer,
    UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent").FireServer,
    RemoteFunction = Instance.new("RemoteFunction").InvokeServer,
    BindableEvent = Instance.new("BindableEvent").Fire,
    BindableFunction = Instance.new("BindableFunction").Invoke
}

local currentRemotes = {}

local remoteDataEvent = Instance.new("BindableEvent")
local eventSet = false

local function connectEvent(callback)
    remoteDataEvent.Event:Connect(callback)
    eventSet = true
end

local function safeRemoteId(remote)
    local name
    local ok = pcall(function()
        name = tostring(remote.Name)
    end)

    if not ok or not name or name == "" then
        name = "<unnamed>"
    end

    local parent = rawget(remote, "Parent")
    if not parent then
        return "[NilParent]:" .. name
    end

    return remote.ClassName .. ":" .. name
end

local nmcTrampoline
nmcTrampoline = hookMetaMethod(game, "__namecall", function(self, ...)
    local args = {...}

    if typeof(self) ~= "Instance" then
        return nmcTrampoline(self, ...)
    end

    local method = getNamecallMethod():lower()
    if method == "fireserver" then
        method = "FireServer"
    elseif method == "invokeserver" then
        method = "InvokeServer"
    end

    if remotesViewing[self.ClassName] and self ~= remoteDataEvent and remoteMethods[method] then
        local remote = currentRemotes[self]

        if not remote then
            local ok, r = pcall(Remote.new, self)
            if not ok or not r then
                return nmcTrampoline(self, ...)
            end
            remote = r
            currentRemotes[self] = remote
        end

        local argsIgnored = remote.AreArgsIgnored(remote, args)
        local argsBlocked = remote.AreArgsBlocked(remote, args)

        if eventSet and not remote.Ignored and not argsIgnored then
            local info = getInfo(3)
            local script
            pcall(function()
                script = getCallingScript((PROTOSMASHER_LOADED ~= nil and 2) or nil)
            end)

            local call = {
                script = script,
                args = args,
                func = info and info.func or nil,
                id = safeRemoteId(self)
            }

            remote.IncrementCalls(remote, call)
            remoteDataEvent.Fire(remoteDataEvent, self, call)
        end

        if remote.Blocked or argsBlocked then
            return
        end
    end

    return nmcTrampoline(self, ...)
end)

local pcall = pcall

local function checkPermission(self)
    if self.ClassName then end
end

for className, hook in pairs(methodHooks) do
    local originalMethod
    originalMethod = hookFunction(hook, newCClosure(function(self, ...)
        local args = {...}
        local target = args[1]

        if typeof(target) ~= "Instance" then
            return originalMethod(self, ...)
        end

        local ok = pcall(checkPermission, target)
        if not ok then
            return originalMethod(self, ...)
        end

        if target.ClassName == className and remotesViewing[target.ClassName] and target ~= remoteDataEvent then
            local remote = currentRemotes[target]

            if not remote then
                local ok2, r = pcall(Remote.new, target)
                if not ok2 or not r then
                    return originalMethod(self, ...)
                end
                remote = r
                currentRemotes[target] = remote
            end

            local argsIgnored = remote:AreArgsIgnored(args)

            if eventSet and not remote.Ignored and not argsIgnored then
                local info = getInfo(3)
                local script
                pcall(function()
                    script = getCallingScript((PROTOSMASHER_LOADED ~= nil and 2) or nil)
                end)

                local call = {
                    script = script,
                    args = args,
                    func = info and info.func or nil,
                    id = safeRemoteId(target)
                }

                remote:IncrementCalls(call)
                remoteDataEvent:Fire(target, call)
            end

            if remote.Blocked or remote:AreArgsBlocked(args) then
                return
            end
        end

        return originalMethod(self, ...)
    end))

    oh.Hooks[originalMethod] = hook
end

RemoteSpy.RemotesViewing = remotesViewing
RemoteSpy.CurrentRemotes = currentRemotes
RemoteSpy.ConnectEvent = connectEvent
RemoteSpy.RequiredMethods = requiredMethods

return RemoteSpy
