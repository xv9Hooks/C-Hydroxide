local TextService = game:GetService("TextService")

local ConstantScanner = {}
local ClosureSpy = import("modules/ClosureSpy")
local Methods = import("modules/ConstantScanner")

if not hasMethods(Methods.RequiredMethods) then
    return ConstantScanner
end

local Constant = import("objects/Constant")

local List, ListButton = import("ui/controls/List")
local MessageBox, MessageType = import("ui/controls/MessageBox")
local ContextMenu, ContextMenuButton = import("ui/controls/ContextMenu")
local TabSelector = import("ui/controls/TabSelector")
local Prompt = import("ui/controls/Prompt")

local Prompts = import("rbxassetid://11389137937").Base.Prompts
local Page = import("rbxassetid://11389137937").Base.Body.Pages.ConstantScanner
local Assets = import("rbxassetid://5042114982").ConstantScanner

local Query = Page.Query
local Search = Query.Search
local SearchBox = Query.Query

local constantList = List.new(Page.Results.Clip.Content)
local constantLogs = {}
local selectedLog
local selectedConstant
local selectedConstantLog

local spyClosureContext = ContextMenuButton.new("rbxassetid://4666593447", "Spy Closure")
local viewConstantsContext = ContextMenuButton.new("rbxassetid://5179169654", "View All Constants")
local getScriptContext = ContextMenuButton.new("rbxassetid://4891705738", "Get Script Path")
local changeConstantContext = ContextMenuButton.new("rbxassetid://5458573463", "Modify Constant(NOT DONE)")

local constants = { tempConstantColor = Color3.fromRGB(40, 20, 20), tempBorderColor = Color3.fromRGB(20, 0, 0) }

constantList:BindContextMenu(ContextMenu.new({ spyClosureContext, viewConstantsContext, getScriptContext, changeConstantContext }))

local modifyConstant = Prompt.new(Prompts.ModifyUpvalue)
local modifyConstantInput = Prompts.ModifyUpvalue.Inner.Content.Value.Input
local modifyConstantSubmit = Prompts.ModifyUpvalue.Inner.Buttons.SetCancel.Set

modifyConstantSubmit.MouseButton1Click:Connect(function()
    local value = modifyConstantInput.Text
    local newValue = tonumber(value) or value
    if selectedConstant and selectedConstant.Set then
        selectedConstant:Set(newValue)
        local valueType = type(newValue)
        if selectedConstantLog and selectedConstantLog.Value then
            selectedConstantLog.Value.Text = tostring(newValue)
            selectedConstantLog.Value.TextColor3 = oh.Constants.Syntax[valueType] or Color3.fromRGB(255, 255, 255)
            selectedConstantLog.Icon.Image = oh.Constants.Types[valueType] or ""
        end
        modifyConstant:Hide()
    end
end)

local function addConstant(constant, temporary)
    local constantLog = Assets.Constant:Clone()
    local index = constant.Index
    local value = constant.Value
    local valueType = type(value)
    local valueText = tostring(value)
    if temporary then
        constantLog.ImageColor3 = constants.tempConstantColor
        constantLog.Border.ImageColor3 = constants.tempBorderColor
    end
    if valueType == "function" then
        local closureName = getInfo(value).name or ''
        constantLog.Value.Text = (closureName == '' and "Unnamed function") or closureName
    else
        constantLog.Value.Text = tostring(value)
    end
    constantLog.Name = index
    constantLog.Index.Text = index
    constantLog.Value.TextColor3 = oh.Constants.Syntax[valueType] or Color3.fromRGB(255, 255, 255)
    constantLog.Icon.Image = oh.Constants.Types[valueType] or ""
    constantLog.MouseButton1Click:Connect(function()
        if selectedConstantLog then
            TweenService:Create(selectedConstantLog, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
        end
        selectedConstant = constant
        selectedConstantLog = constantLog
        TweenService:Create(constantLog, TweenInfo.new(0.15), { BackgroundTransparency = 0.8 }):Play()
    end)
    return constantLog
end

local Log = {}

function Log.new(closure)
    local log = {}
    local button = Assets.ClosureLog:Clone()
    local listButton = ListButton.new(button, constantList)
    local constants = closure.Constants or {}
    local logHeight = 30
    for _i, constant in pairs(constants) do
        local constantLog = addConstant(constant)
        constantLog.Parent = button.Constants
        logHeight = logHeight + constantLog.AbsoluteSize.Y + 5
    end
    if closure.Name == "Unnamed function" then
        button:FindFirstChild("Name").TextColor3 = Color3.fromRGB(127, 127, 127)
    end
    button:FindFirstChild("Name").Text = closure.Name
    button.Size = UDim2.new(1, 0, 0, logHeight)
    listButton:SetRightCallback(function()
        selectedLog = log
    end)
    constantLogs[closure.Data] = log
    log.Closure = closure
    log.Constants = constants
    log.Button = listButton
    return log
end

local function addConstants()
    local query = SearchBox.Text
    if query:gsub(' ', '') ~= '' then
        if not tonumber(query) and query:len() <= 1 then
            return
        end
        constantList:Clear()
        constantLogs = {}
        for _i, closure in pairs(Methods.Scan(query) or {}) do
            Log.new(closure)
        end
        constantList:Recalculate()
    else
        MessageBox.Show("Invalid query", "Your query is too short", MessageType.OK)
    end
    SearchBox.Text = ''
end

local SpyHook = ClosureSpy.Hook
spyClosureContext:SetCallback(function()
    local selectedClosure = selectedLog and selectedLog.Closure
    if selectedClosure and TabSelector.SelectTab("ClosureSpy") then
        local result = SpyHook.new(selectedClosure)
        if result == false then
            MessageBox.Show("Already hooked", "You are already spying " .. selectedClosure.Name)
        elseif result == nil then
            MessageBox.Show("Cannot hook", ('Cannot hook "%s" because there are no upvalues'):format(selectedClosure.Name))
        end
    end
end)

viewConstantsContext:SetCallback(function()
    if not selectedLog then return end
    local instance = selectedLog.Button.Instance
    if selectedLog.TemporaryConstants then
        local newHeight = 0
        for _, constantLog in pairs(selectedLog.TemporaryConstants) do
            newHeight = newHeight - (constantLog.AbsoluteSize.Y + 5)
            constantLog:Destroy()
        end
        selectedLog.TemporaryConstants = nil
        selectedLog.Closure.TemporaryConstants = {}
        instance.Constants.Size = instance.Constants.Size + UDim2.new(0, 0, 0, newHeight)
        instance.Size = instance.Size + UDim2.new(0, 0, 0, newHeight)
        constantList:Recalculate()
        return
    end
    local closure = selectedLog.Closure
    local temporaryConstants = {}
    local newHeight = 0
    for i, v in pairs(getConstants(closure.Data) or {}) do
        if not closure.Constants[i] then
            local constant = Constant.new(closure, i, v)
            local constantLog = addConstant(constant, true)
            constantLog.Parent = instance.Constants
            newHeight = newHeight + constantLog.AbsoluteSize.Y + 5
            temporaryConstants[i] = constantLog
            closure.TemporaryConstants[i] = constant
        end
    end
    selectedLog.TemporaryConstants = temporaryConstants
    instance.Constants.Size = instance.Constants.Size + UDim2.new(0, 0, 0, newHeight)
    instance.Size = instance.Size + UDim2.new(0, 0, 0, newHeight)
    constantList:Recalculate()
end)

getScriptContext:SetCallback(function()
    local closure = selectedLog and selectedLog.Closure
    if closure then
        local script = getfenv(closure.Data).script
        if typeof(script) == "Instance" then
            setClipboard(getInstancePath(script))
        end
    end
end)

changeConstantContext:SetCallback(function()
    if selectedConstant then
        modifyConstantInput.Text = tostring(selectedConstant.Value)
        modifyConstant:Show()
    else
        MessageBox.Show("No constant selected", "Please select a constant to modify", MessageType.OK)
    end
end)

Search.MouseButton1Click:Connect(addConstants)
SearchBox.FocusLost:Connect(function(returned)
    if returned then
        addConstants()
    end
end)

return ConstantScanner
