local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local UpvalueScanner = {}
local ClosureSpy = import("modules/ClosureSpy")
local Methods = import("modules/UpvalueScanner")

if not hasMethods(Methods.RequiredMethods) then
    return UpvalueScanner
end

local Upvalue = import("objects/Upvalue")

local Prompt = import("ui/controls/Prompt")
local CheckBox = import("ui/controls/CheckBox")
local Dropdown = import("ui/controls/Dropdown")
local List, ListButton = import("ui/controls/List")
local TabSelector = import("ui/controls/TabSelector")
local MessageBox, MessageType = import("ui/controls/MessageBox")
local ContextMenu, ContextMenuButton = import("ui/controls/ContextMenu")

local Base = import("rbxassetid://11389137937").Base
local Assets = import("rbxassetid://5042114982").UpvalueScanner

local Prompts = Base.Prompts
local Page = Base.Body.Pages.UpvalueScanner

local Query = Page.Query
local Search = Query.Search
local SearchBox = Query.Query
local Filters = Page.Filters
local ResultsClip = Page.Results.Clip
local ResultStatus = ResultsClip.ResultStatus

local modifyUpvalue = Prompt.new(Prompts.ModifyUpvalue)
local modifyElement = Prompt.new(Prompts.ModifyElement)
local deepSearch = CheckBox.new(Filters.SearchInTables)
local upvalueList = List.new(ResultsClip.Content)

local deepSearchFlag = false
local currentUpvalues = {}

local selectedLog
local selectedUpvalue
local selectedUpvalueLog
local selectedElement

local spyClosureContext = ContextMenuButton.new("rbxassetid://4666593447", "Spy Closure")
local viewUpvaluesContext = ContextMenuButton.new("rbxassetid://5179169654", "View All Upvalues")
local changeUpvalueContext = ContextMenuButton.new("rbxassetid://5458573463", "Change Upvalue")
local changeTableContext = ContextMenuButton.new("rbxassetid://5458573463", "Change Upvalue")
local viewElementsContext = ContextMenuButton.new("rbxassetid://5179169654", "View All Elements")
local changeElementContext = ContextMenuButton.new("rbxassetid://5458573463", "Change Element")
local upvalueScriptContext = ContextMenuButton.new("rbxassetid://4800244808", "Generate Script")
local tableScriptContext = ContextMenuButton.new("rbxassetid://4800244808", "Generate Script")
local elementScriptContext = ContextMenuButton.new("rbxassetid://4800244808", "Generate Script")
local getScriptContext = ContextMenuButton.new("rbxassetid://4891705738", "Get Script Path")

local closureContextMenu = ContextMenu.new({ spyClosureContext, viewUpvaluesContext, getScriptContext })
local tableContextMenu = ContextMenu.new({ changeTableContext, viewElementsContext, tableScriptContext })
local upvalueContextMenu = ContextMenu.new({ changeUpvalueContext, upvalueScriptContext })
local elementContextMenu = ContextMenu.new({ changeElementContext, elementScriptContext })

local modifyUpvalueInner = modifyUpvalue.Instance.Inner
local modifyUpvalueContent = modifyUpvalueInner.Content
local modifyUpvalueButtons = modifyUpvalueInner.Buttons.SetCancel
local modifyUpvalueType = modifyUpvalueContent.Type
local modifyUpvalueValue = modifyUpvalueContent.Value.Input

local modifyElementInner = modifyElement.Instance.Inner
local modifyElementContent = modifyElementInner.Content
local modifyElementButtons = modifyElementInner.Buttons.SetCancel
local modifyElementType = modifyElementContent.Type
local modifyElementValue = modifyElementContent.Value.Input

local upvalueTypeDropdown = Dropdown.new(modifyUpvalueType)
local elementTypeDropdown = Dropdown.new(modifyElementType)

local constants = {
    tempElementColor = Color3.fromRGB(30, 10, 10),
    tempUpvalueColor = Color3.fromRGB(40, 20, 20),
    tempBorderColor = Color3.fromRGB(20, 0, 0)
}

local function recalcFrame(container, baseHeight)
    task.wait()
    local layout = container:FindFirstChildOfClass("UIListLayout")
    if layout then
        return layout.AbsoluteContentSize.Y + (baseHeight or 0)
    end
    return baseHeight or 0
end

local function addElement(upvalueLog, upvalue, index, value, temporary)
    local elementLog = Assets.Element:Clone()
    local elementIndexType = type(index)
    local elementValueType = type(value)
    local indexText = toString(index)

    if temporary then
        elementLog.ImageColor3 = constants.tempElementColor
        elementLog.Border.ImageColor3 = constants.tempBorderColor
    end

    elementLog.Name = indexText
    elementLog.Index.Label.Text = indexText
    elementLog.Value.Label.Text = toString(value)
    elementLog.Index.Label.TextColor3 = oh.Constants.Syntax[elementIndexType]
    elementLog.Index.Icon.Image = oh.Constants.Types[elementIndexType]
    elementLog.Value.Label.TextColor3 = oh.Constants.Syntax[elementValueType]
    elementLog.Value.Icon.Image = oh.Constants.Types[elementValueType]

    elementLog.MouseButton2Click:Connect(function()
        selectedUpvalue = upvalue
        selectedUpvalueLog = upvalueLog
        selectedElement = index
        elementTypeDropdown:SetSelected(typeof(value))
        elementContextMenu:Show()
    end)

    return elementLog
end

local function addUpvalue(upvalue, temporary)
    local upvalueLog
    local index = upvalue.Index
    local value = upvalue.Value
    local valueType = type(value)

    if valueType == "table" then
        upvalueLog = Assets.Table:Clone()

        if temporary then
            upvalueLog.ImageColor3 = constants.tempUpvalueColor
            upvalueLog.Border.ImageColor3 = constants.tempBorderColor
        end

        if not temporary then
            for i, v in pairs(upvalue.Scanned) do
                local elementLog = addElement(upvalueLog, upvalue, i, v)
                elementLog.Parent = upvalueLog.Elements
            end
        end

        local h = recalcFrame(upvalueLog.Elements, 25)
        upvalueLog.Size = UDim2.new(1, 0, 0, h)
    else
        upvalueLog = Assets.Upvalue:Clone()

        if temporary then
            upvalueLog.ImageColor3 = constants.tempUpvalueColor
            upvalueLog.Border.ImageColor3 = constants.tempBorderColor
        end

        if valueType == "function" then
            local closureName = getInfo(value).name or ''
            upvalueLog.Value.Text = (closureName == '' and "Unnamed function") or closureName
        else
            upvalueLog.Value.Text = toString(value)
        end
    end

    upvalueLog.Name = index
    upvalueLog.Index.Text = index
    upvalueLog.Value.TextColor3 = oh.Constants.Syntax[valueType]
    upvalueLog.Icon.Image = oh.Constants.Types[valueType]

    upvalueLog.MouseButton2Click:Connect(function()
        selectedUpvalue = upvalue
        selectedUpvalueLog = upvalueLog
        upvalueTypeDropdown:SetSelected(typeof(upvalue.Value))

        if upvalue.Scanned then
            tableContextMenu:Show()
        else
            upvalueContextMenu:Show()
        end
    end)

    return upvalueLog
end

local Log = {}

function Log.new(closure)
    local log = {}
    local instance = Assets.ClosureLog:Clone()
    local listButton = ListButton.new(instance, upvalueList)

    log.Instance = instance
    log.Closure = closure
    log.Upvalues = {}
    log.Update = Log.update

    for i, upvalue in pairs(closure.Upvalues) do
        local upvalueLog = addUpvalue(upvalue)
        upvalueLog.Parent = instance.Upvalues
        log.Upvalues[i] = upvalueLog
    end

    local h = recalcFrame(instance.Upvalues, 30)
    instance.Size = UDim2.new(1, 0, 0, h)
    instance:FindFirstChild("Name").Text = closure.Name

    listButton:SetRightCallback(function()
        selectedLog = log
    end)

    currentUpvalues[closure.Data] = log
    upvalueList:Recalculate()

    return log
end

function Log.update(log)
    for _, upvalue in pairs(log.Closure.Upvalues) do
        local closureLog = log.Instance
        local upvalueLog = closureLog.Upvalues[tostring(upvalue.Index)]
        if upvalueLog then
            local newValue = getUpvalue(upvalue.Closure.Data, upvalue.Index)
            local valueType = type(newValue)
            upvalueLog.Value.Text = toString(newValue)
            upvalueLog.Value.TextColor3 = oh.Constants.Syntax[valueType]
            upvalueLog.Icon.Image = oh.Constants.Types[valueType]
            upvalue:Update(newValue)
        end
    end
end

local function addUpvalues()
    local query = SearchBox.Text

    if query:gsub(' ', '') ~= '' then
        if not tonumber(query) and query:len() <= 1 then
            return
        end

        upvalueList:Clear()
        currentUpvalues = {}

        local unnamedFunctions = {}

        for _, closure in pairs(Methods.Scan(query, deepSearchFlag)) do
            if closure.Name == '' then
                unnamedFunctions[closure.Data] = closure
            else
                Log.new(closure)
            end
        end

        for _, closure in pairs(unnamedFunctions) do
            Log.new(closure)
        end

        ResultStatus.Visible = true
        upvalueList:Recalculate()
    else
        MessageBox.Show("Invalid query", "Your query is too short", MessageType.OK)
    end

    SearchBox.Text = ""
end

Search.MouseButton1Click:Connect(addUpvalues)

SearchBox.FocusLost:Connect(function(returned)
    if returned then
        addUpvalues()
    end
end)

viewElementsContext:SetCallback(function()
    local scanned = selectedUpvalue.Scanned
    local temporaryElements = selectedUpvalue.TemporaryElements or {}

    for i, v in pairs(selectedUpvalue.Value) do
        if not scanned[i] and not temporaryElements[i] then
            local elementLog = addElement(selectedUpvalueLog, selectedUpvalue, i, v, true)
            elementLog.Parent = selectedUpvalueLog.Elements
            temporaryElements[i] = elementLog
        end
    end

    selectedUpvalue.TemporaryElements = temporaryElements

    local h = recalcFrame(selectedUpvalueLog.Elements, 25)
    selectedUpvalueLog.Size = UDim2.new(1, 0, 0, h)

    upvalueList:Recalculate()
end)

oh.Events.UpdateUpvalues = RunService.Heartbeat:Connect(function()
    for _, closureLog in pairs(currentUpvalues) do
        closureLog:Update()
    end
end)

return UpvalueScanner
