local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

-- Clipboard suporte seguro
local hasClipboard, copyFunc = pcall(function()
    return setclipboard or toclipboard or (Clipboard and Clipboard.set)
end)
local function CopyToClipboard(text)
    if setclipboard then setclipboard(text)
    elseif toclipboard then toclipboard(text)
    elseif Clipboard and Clipboard.set then Clipboard:set(text)
    else return false end
    return true
end

local OrionLib = {
    Elements = {},
    ThemeObjects = {},
    Connections = {},
    Flags = {},
    Themes = {
        Default = {
            Main = Color3.fromRGB(20, 20, 25),
            Second = Color3.fromRGB(30, 30, 35),
            Stroke = Color3.fromRGB(55, 55, 65),
            Divider = Color3.fromRGB(45, 45, 55),
            Text = Color3.fromRGB(245, 245, 255),
            TextDark = Color3.fromRGB(160, 160, 180),
            Accent = Color3.fromRGB(88, 101, 242) -- Discord-like accent
        }
    },
    SelectedTheme = "Default",
    Folder = nil,
    SaveCfg = false,
    Transparency = 0.92,
    CustomColors = { Text = nil, Stroke = nil, Accent = nil },
    RemotesLog = {},
    RemoteSpyActive = false
}

-- GUI Protection
local function ProtectGui(gui)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
        if gethui and not gui.Parent then gui.Parent = gethui() end
    end)
end

-- Main GUI
local Orion = Instance.new("ScreenGui")
Orion.Name = "Orion"
Orion.ResetOnSpawn = false
ProtectGui(Orion)

local function GetGuiParent()
    local success, result = pcall(function()
        if gethui then return gethui() end
        return game:GetService("CoreGui")
    end)
    return success and result or game.CoreGui
end
Orion.Parent = GetGuiParent()

-- Clean old instances
for _, v in ipairs(GetGuiParent():GetChildren()) do
    if v.Name == Orion.Name and v ~= Orion then v:Destroy() end
end

-- Make clickable (cross-platform)
local function MakeClickable(el)
    pcall(function()
        el.Active = true
        el.Selectable = true
        el.AutoButtonColor = false
        el.Modal = true
        if el:IsA("ImageButton") or el:IsA("TextButton") then
            el.AutoButtonColor = false
        end
    end)
end

-- Safe connection
local function AddConnection(signal, func)
    if not Orion.Parent then return end
    local conn = signal:Connect(func)
    table.insert(OrionLib.Connections, conn)
    return conn
end

-- Feather Icons
local Icons = {}
pcall(function()
    Icons = HttpService:JSONDecode(game:HttpGetAsync("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")).icons
end)
local function GetIcon(name) return Icons[name] end

-- Element creators
local function Create(name, props, children)
    local obj = Instance.new(name)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, child in pairs(children or {}) do child.Parent = obj end
    return obj
end

local function CreateElement(name, func)
    OrionLib.Elements[name] = func
end
local function MakeElement(name, ...) return OrionLib.Elements[name](...) end

CreateElement("Corner", function(scale, offset)
    return Create("UICorner", { CornerRadius = UDim.new(scale or 0, offset or 8) })
end)
CreateElement("Stroke", function(color, thickness)
    return Create("UIStroke", { Color = color or Color3.fromRGB(255,255,255), Thickness = thickness or 1 })
end)
CreateElement("List", function(scale, offset)
    return Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(scale or 0, offset or 8) })
end)
CreateElement("Padding", function(b,l,r,t)
    return Create("UIPadding", {
        PaddingBottom = UDim.new(0, b or 8),
        PaddingLeft = UDim.new(0, l or 8),
        PaddingRight = UDim.new(0, r or 8),
        PaddingTop = UDim.new(0, t or 8)
    })
end)
CreateElement("TFrame", function()
    return Create("Frame", { BackgroundTransparency = 1 })
end)
CreateElement("Frame", function(color)
    return Create("Frame", { BackgroundColor3 = color or Color3.fromRGB(255,255,255), BorderSizePixel = 0 })
end)
CreateElement("RoundFrame", function(color, scale, offset)
    return Create("Frame", { BackgroundColor3 = color or Color3.fromRGB(255,255,255), BorderSizePixel = 0 }, {
        Create("UICorner", { CornerRadius = UDim.new(scale or 0, offset or 8) })
    })
end)
CreateElement("Button", function()
    local btn = Create("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0 })
    MakeClickable(btn)
    return btn
end)
CreateElement("ScrollFrame", function(color, width)
    return Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        ScrollBarImageColor3 = color,
        BorderSizePixel = 0,
        ScrollBarThickness = width or 4,
        CanvasSize = UDim2.new(0,0,0,0)
    })
end)
CreateElement("Image", function(id)
    local img = Create("ImageLabel", { Image = id, BackgroundTransparency = 1 })
    if GetIcon(id) then img.Image = GetIcon(id) end
    return img
end)
CreateElement("ImageButton", function(id)
    local btn = Create("ImageButton", { Image = id, BackgroundTransparency = 1 })
    MakeClickable(btn)
    if GetIcon(id) then btn.Image = GetIcon(id) end
    return btn
end)
CreateElement("Label", function(text, size, transp)
    return Create("TextLabel", {
        Text = text or "", TextColor3 = Color3.fromRGB(240,240,240),
        TextTransparency = transp or 0, TextSize = size or 14,
        Font = Enum.Font.Gotham, RichText = true,
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left
    })
end)

-- Dragging (mouse + touch)
local function AddDragging(dragPoint, mainFrame)
    local dragData = { dragging = false, startPos = nil, startMouse = nil }
    dragPoint.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragData.dragging = true
            dragData.startMouse = input.Position
            dragData.startPos = mainFrame.Position
        end
    end)
    dragPoint.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragData.dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragData.dragging then
            local delta = input.Position - dragData.startMouse
            mainFrame.Position = UDim2.new(dragData.startPos.X.Scale, dragData.startPos.X.Offset + delta.X,
                                           dragData.startPos.Y.Scale, dragData.startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Theme management
local function SetTheme()
    for typeName, objects in pairs(OrionLib.ThemeObjects) do
        local color = OrionLib.Themes[OrionLib.SelectedTheme][typeName]
        if typeName == "Text" and OrionLib.CustomColors.Text then color = OrionLib.CustomColors.Text
        elseif typeName == "Stroke" and OrionLib.CustomColors.Stroke then color = OrionLib.CustomColors.Stroke
        elseif typeName == "Accent" and OrionLib.CustomColors.Accent then color = OrionLib.CustomColors.Accent end
        
        for _, obj in pairs(objects) do
            local prop = nil
            if obj:IsA("Frame") or obj:IsA("TextButton") then prop = "BackgroundColor3"
            elseif obj:IsA("ScrollingFrame") then prop = "ScrollBarImageColor3"
            elseif obj:IsA("UIStroke") then prop = "Color"
            elseif obj:IsA("TextLabel") or obj:IsA("TextBox") then prop = "TextColor3"
            elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then prop = "ImageColor3" end
            if prop then
                if prop == "BackgroundColor3" and typeName == "Main" then
                    obj.BackgroundTransparency = 1 - OrionLib.Transparency
                end
                obj[prop] = color
            end
        end
    end
end

local function AddThemeObject(obj, typeName)
    if not OrionLib.ThemeObjects[typeName] then OrionLib.ThemeObjects[typeName] = {} end
    table.insert(OrionLib.ThemeObjects[typeName], obj)
    local prop = nil
    if obj:IsA("Frame") or obj:IsA("TextButton") then prop = "BackgroundColor3"
    elseif obj:IsA("ScrollingFrame") then prop = "ScrollBarImageColor3"
    elseif obj:IsA("UIStroke") then prop = "Color"
    elseif obj:IsA("TextLabel") or obj:IsA("TextBox") then prop = "TextColor3"
    elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then prop = "ImageColor3" end
    if prop and prop == "BackgroundColor3" and typeName == "Main" then
        obj.BackgroundTransparency = 1 - OrionLib.Transparency
    end
    if prop then
        obj[prop] = OrionLib.Themes[OrionLib.SelectedTheme][typeName]
    end
    return obj
end

-- Executor
local function ExecuteScript(code)
    local success, err = pcall(function()
        local func = loadstring(code)
        if func then func() else error("Falha ao compilar") end
    end)
    return success, err
end

-- Remote Spy (improved)
local remoteSpyHooks = {}
local function StartRemoteSpy()
    if OrionLib.RemoteSpyActive then return end
    OrionLib.RemoteSpyActive = true
    
    local function LogRemote(remote, action, ...)
        local args = {...}
        local str = {}
        for i, arg in ipairs(args) do
            if typeof(arg) == "Instance" then str[i] = arg.ClassName..":"..arg.Name
            elseif typeof(arg) == "function" then str[i] = "function"
            elseif typeof(arg) == "table" then str[i] = "{...}"
            else str[i] = tostring(arg) end
        end
        local entry = {
            Remote = remote.Name,
            Action = action,
            Args = table.concat(str, ", "),
            Time = os.date("%H:%M:%S")
        }
        table.insert(OrionLib.RemotesLog, 1, entry)
        if #OrionLib.RemotesLog > 100 then table.remove(OrionLib.RemotesLog) end
        OrionLib:MakeNotification({ Name = remote.Name, Content = action.." | "..table.concat(str, ", "), Time = 2 })
    end
    
    local function HookRemote(remote)
        if remote:IsA("RemoteEvent") then
            local oldFire = remote.FireServer
            remote.FireServer = function(self, ...)
                LogRemote(remote, "FireServer", ...)
                return oldFire(self, ...)
            end
            table.insert(remoteSpyHooks, {remote, oldFire})
        elseif remote:IsA("RemoteFunction") then
            local oldInvoke = remote.InvokeServer
            remote.InvokeServer = function(self, ...)
                LogRemote(remote, "InvokeServer", ...)
                return oldInvoke(self, ...)
            end
            table.insert(remoteSpyHooks, {remote, oldInvoke})
        end
    end
    
    local function Scan(container)
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                HookRemote(child)
            end
            Scan(child)
        end
    end
    Scan(game)
    
    local descendantAdded = game.DescendantAdded:Connect(function(desc)
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            HookRemote(desc)
        end
    end)
    table.insert(remoteSpyHooks, descendantAdded)
end

local function StopRemoteSpy()
    OrionLib.RemoteSpyActive = false
    for _, hook in ipairs(remoteSpyHooks) do
        if type(hook) == "RBXScriptConnection" then
            hook:Disconnect()
        elseif type(hook) == "table" then
            local remote, oldFunc = hook[1], hook[2]
            if remote:IsA("RemoteEvent") then remote.FireServer = oldFunc
            elseif remote:IsA("RemoteFunction") then remote.InvokeServer = oldFunc end
        end
    end
    remoteSpyHooks = {}
end

-- Notification system
local notifContainer = MakeElement("TFrame")
notifContainer.Position = UDim2.new(1, -20, 1, -20)
notifContainer.Size = UDim2.new(0, 340, 1, -20)
notifContainer.AnchorPoint = Vector2.new(1, 1)
notifContainer.Parent = Orion
local notifLayout = Create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8) })
notifLayout.Parent = notifContainer

function OrionLib:MakeNotification(cfg)
    task.spawn(function()
        cfg.Name = cfg.Name or "Notificação"
        cfg.Content = cfg.Content or ""
        cfg.Time = cfg.Time or 4
        
        local holder = MakeElement("TFrame")
        holder.Size = UDim2.new(1, 0, 0, 0)
        holder.AutomaticSize = Enum.AutomaticSize.Y
        holder.Parent = notifContainer
        
        local frame = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(25,25,25), 0, 8), "Second")
        frame.Parent = holder
        frame.Size = UDim2.new(1, 0, 0, 0)
        frame.Position = UDim2.new(1, 0, 0, 0)
        frame.AutomaticSize = Enum.AutomaticSize.Y
        
        local stroke = MakeElement("Stroke", OrionLib.Themes.Default.Stroke, 1.2)
        stroke.Parent = frame
        local padding = MakeElement("Padding", 12, 12, 12, 12)
        padding.Parent = frame
        
        local icon = MakeElement("Image", cfg.Image or "rbxassetid://4384403532")
        icon.Size = UDim2.new(0, 22, 0, 22)
        icon.ImageColor3 = OrionLib.Themes.Default.Accent
        icon.Parent = frame
        
        local title = MakeElement("Label", cfg.Name, 15)
        title.Size = UDim2.new(1, -34, 0, 22)
        title.Position = UDim2.new(0, 34, 0, 0)
        title.Font = Enum.Font.GothamBold
        title.Parent = frame
        
        local content = MakeElement("Label", cfg.Content, 13)
        content.Size = UDim2.new(1, -34, 0, 0)
        content.Position = UDim2.new(0, 34, 0, 26)
        content.AutomaticSize = Enum.AutomaticSize.Y
        content.TextColor3 = OrionLib.Themes.Default.TextDark
        content.TextWrapped = true
        content.Parent = frame
        
        TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Position = UDim2.new(0,0,0,0) }):Play()
        task.wait(cfg.Time)
        TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Position = UDim2.new(1,20,0,0) }):Play()
        task.wait(0.5)
        holder:Destroy()
    end)
end

-- Main Window
function OrionLib:MakeWindow(cfg)
    cfg = cfg or {}
    cfg.Name = cfg.Name or "Orion"
    cfg.SaveConfig = cfg.SaveConfig or false
    cfg.CloseCallback = cfg.CloseCallback or function() end
    
    local minimized = false
    local hidden = false
    local firstTab = true
    
    -- UI Elements construction (same as original but optimized)
    local TopBar = MakeElement("TFrame")
    TopBar.Size = UDim2.new(1,0,0,50)
    TopBar.Name = "TopBar"
    
    local WindowName = AddThemeObject(MakeElement("Label", cfg.Name, 18), "Text")
    WindowName.Size = UDim2.new(1, -100, 2, 0)
    WindowName.Position = UDim2.new(0, 20, 0, -24)
    WindowName.Font = Enum.Font.GothamBlack
    WindowName.Parent = TopBar
    
    local TopLine = AddThemeObject(MakeElement("Frame"), "Stroke")
    TopLine.Size = UDim2.new(1,0,0,1)
    TopLine.Position = UDim2.new(0,0,1,-1)
    TopLine.Parent = TopBar
    
    local BtnFrame = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), "Second")
    BtnFrame.Size = UDim2.new(0, 80, 0, 32)
    BtnFrame.Position = UDim2.new(1, -90, 0, 9)
    BtnFrame.Parent = TopBar
    local BtnStroke = MakeElement("Stroke")
    BtnStroke.Parent = BtnFrame
    local Div = AddThemeObject(MakeElement("Frame"), "Stroke")
    Div.Size = UDim2.new(0,1,1,0)
    Div.Position = UDim2.new(0.5,0,0,0)
    Div.Parent = BtnFrame
    
    local CloseBtn = MakeElement("Button")
    CloseBtn.Size = UDim2.new(0.5,0,1,0)
    CloseBtn.Position = UDim2.new(0.5,0,0,0)
    CloseBtn.Parent = BtnFrame
    local CloseIcon = AddThemeObject(MakeElement("Image", "rbxassetid://7072725342"), "Text")
    CloseIcon.Position = UDim2.new(0,10,0,7)
    CloseIcon.Size = UDim2.new(0,18,0,18)
    CloseIcon.Parent = CloseBtn
    
    local MinBtn = MakeElement("Button")
    MinBtn.Size = UDim2.new(0.5,0,1,0)
    MinBtn.Parent = BtnFrame
    local MinIcon = AddThemeObject(MakeElement("Image", "rbxassetid://7072719338"), "Text")
    MinIcon.Position = UDim2.new(0,10,0,7)
    MinIcon.Size = UDim2.new(0,18,0,18)
    MinIcon.Name = "Ico"
    MinIcon.Parent = MinBtn
    
    local DragPoint = MakeElement("TFrame")
    DragPoint.Size = UDim2.new(1,0,0,50)
    
    local TabHolder = AddThemeObject(MakeElement("ScrollFrame", Color3.fromRGB(255,255,255), 4), "Divider")
    TabHolder.Size = UDim2.new(1,0,1,-50)
    local TabList = MakeElement("List")
    TabList.Parent = TabHolder
    local TabPad = MakeElement("Padding", 8,0,0,8)
    TabPad.Parent = TabHolder
    AddConnection(TabList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        TabHolder.CanvasSize = UDim2.new(0,0,0, TabList.AbsoluteContentSize.Y + 16)
    end)
    
    local WindowStuff = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 12), "Second")
    WindowStuff.Size = UDim2.new(0, 200, 1, -50)
    WindowStuff.Position = UDim2.new(0,0,0,50)
    local StuffCorner = MakeElement("Corner", 0, 12)
    StuffCorner.Parent = WindowStuff
    TabHolder.Parent = WindowStuff
    
    local MainWindow = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 12), "Main")
    MainWindow.Parent = Orion
    MainWindow.Position = UDim2.new(0.5, -360, 0.5, -280)
    MainWindow.Size = UDim2.new(0, 720, 0, 560)
    MainWindow.ClipsDescendants = true
    MainWindow.Name = "MainWindow"
    
    TopBar.Parent = MainWindow
    DragPoint.Parent = MainWindow
    WindowStuff.Parent = MainWindow
    AddDragging(DragPoint, MainWindow)
    
    AddConnection(CloseBtn.MouseButton1Click, function()
        hidden = true
        MainWindow.Visible = false
        cfg.CloseCallback()
        OrionLib:MakeNotification({ Name = "Interface", Content = "Digite 'open' no chat para reabrir", Time = 5 })
    end)
    AddConnection(MinBtn.MouseButton1Click, function()
        if minimized then
            TweenService:Create(MainWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Size = UDim2.new(0,720,0,560) }):Play()
            MinIcon.Image = "rbxassetid://7072719338"
            task.wait(0.1)
            WindowStuff.Visible = true
        else
            MinIcon.Image = "rbxassetid://7072720870"
            TweenService:Create(MainWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Size = UDim2.new(0, WindowName.TextBounds.X + 160, 0, 50) }):Play()
            task.wait(0.1)
            WindowStuff.Visible = false
        end
        minimized = not minimized
    end)
    AddConnection(LocalPlayer.Chatted, function(msg)
        if msg:lower() == "open" then
            MainWindow.Visible = true
            hidden = false
        end
    end)
    
    -- Tab creator
    local function MakeTab(tabCfg)
        tabCfg.Name = tabCfg.Name or "Tab"
        tabCfg.Icon = tabCfg.Icon or ""
        
        local TabBtn = MakeElement("Button")
        TabBtn.Size = UDim2.new(1,0,0,38)
        TabBtn.Parent = TabHolder
        
        local TabIcon = AddThemeObject(MakeElement("Image", tabCfg.Icon), "Text")
        TabIcon.AnchorPoint = Vector2.new(0,0.5)
        TabIcon.Size = UDim2.new(0,22,0,22)
        TabIcon.Position = UDim2.new(0,12,0.5,0)
        TabIcon.ImageTransparency = 0.5
        TabIcon.Name = "Ico"
        TabIcon.Parent = TabBtn
        
        local TabTitle = AddThemeObject(MakeElement("Label", tabCfg.Name, 14), "Text")
        TabTitle.Size = UDim2.new(1, -44, 1, 0)
        TabTitle.Position = UDim2.new(0,44,0,0)
        TabTitle.Font = Enum.Font.GothamSemibold
        TabTitle.TextTransparency = 0.5
        TabTitle.Name = "Title"
        TabTitle.Parent = TabBtn
        
        local Container = AddThemeObject(MakeElement("ScrollFrame", Color3.fromRGB(255,255,255), 5), "Divider")
        Container.Size = UDim2.new(1, -210, 1, -50)
        Container.Position = UDim2.new(0, 210, 0, 50)
        Container.Parent = MainWindow
        Container.Visible = false
        Container.Name = "ItemContainer"
        local ContainerList = MakeElement("List", 0, 10)
        ContainerList.Parent = Container
        local ContainerPad = MakeElement("Padding", 16, 16, 16, 16)
        ContainerPad.Parent = Container
        AddConnection(ContainerList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            Container.CanvasSize = UDim2.new(0,0,0, ContainerList.AbsoluteContentSize.Y + 32)
        end)
        
        if firstTab then
            firstTab = false
            TabIcon.ImageTransparency = 0
            TabTitle.TextTransparency = 0
            TabTitle.Font = Enum.Font.GothamBlack
            Container.Visible = true
        end
        
        AddConnection(TabBtn.MouseButton1Click, function()
            for _, tab in ipairs(TabHolder:GetChildren()) do
                if tab:IsA("TextButton") then
                    local ic = tab:FindFirstChild("Ico")
                    local tt = tab:FindFirstChild("Title")
                    if ic and tt then
                        tt.Font = Enum.Font.GothamSemibold
                        TweenService:Create(ic, TweenInfo.new(0.2), { ImageTransparency = 0.5 }):Play()
                        TweenService:Create(tt, TweenInfo.new(0.2), { TextTransparency = 0.5 }):Play()
                    end
                end
            end
            for _, cont in ipairs(MainWindow:GetChildren()) do
                if cont.Name == "ItemContainer" then cont.Visible = false end
            end
            TweenService:Create(TabIcon, TweenInfo.new(0.2), { ImageTransparency = 0 }):Play()
            TweenService:Create(TabTitle, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
            TabTitle.Font = Enum.Font.GothamBlack
            Container.Visible = true
        end)
        
        -- Element builders
        local function GetElements(parent)
            local els = {}
            
            function els:AddLabel(text)
                local f = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), "Second")
                f.Size = UDim2.new(1,0,0,38)
                f.BackgroundTransparency = 0.7
                f.Parent = parent
                local lbl = AddThemeObject(MakeElement("Label", text, 14), "Text")
                lbl.Size = UDim2.new(1, -20, 1, 0)
                lbl.Position = UDim2.new(0,20,0,0)
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = f
                local str = MakeElement("Stroke")
                str.Parent = f
                return { Set = function(t) lbl.Text = t end }
            end
            
            function els:AddButton(cfg2)
                cfg2.Name = cfg2.Name or "Button"
                cfg2.Callback = cfg2.Callback or function() end
                local f = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), "Second")
                f.Size = UDim2.new(1,0,0,42)
                f.Parent = parent
                local txt = AddThemeObject(MakeElement("Label", cfg2.Name, 15), "Text")
                txt.Size = UDim2.new(1, -20, 1, 0)
                txt.Position = UDim2.new(0,20,0,0)
                txt.Font = Enum.Font.GothamBold
                txt.Parent = f
                local str = MakeElement("Stroke")
                str.Parent = f
                local btn = MakeElement("Button")
                btn.Size = UDim2.new(1,0,1,0)
                btn.Parent = f
                AddConnection(btn.MouseButton1Click, function()
                    cfg2.Callback()
                    OrionLib:MakeNotification({ Name = cfg2.Name, Content = "Executado!", Time = 1.5 })
                end)
                return { Set = function(t) txt.Text = t end }
            end
            
            function els:AddToggle(cfg2)
                cfg2.Name = cfg2.Name or "Toggle"
                cfg2.Default = cfg2.Default or false
                cfg2.Callback = cfg2.Callback or function() end
                local toggle = { Value = cfg2.Default }
                local f = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), "Second")
                f.Size = UDim2.new(1,0,0,42)
                f.Parent = parent
                local lbl = AddThemeObject(MakeElement("Label", cfg2.Name, 14), "Text")
                lbl.Size = UDim2.new(1, -60, 1, 0)
                lbl.Position = UDim2.new(0,20,0,0)
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = f
                local box = AddThemeObject(MakeElement("RoundFrame", OrionLib.Themes.Default.Accent, 0, 4), "Main")
                box.Size = UDim2.new(0, 26, 0, 26)
                box.Position = UDim2.new(1, -18, 0.5, 0)
                box.AnchorPoint = Vector2.new(0.5,0.5)
                box.Parent = f
                local boxStroke = MakeElement("Stroke", OrionLib.Themes.Default.Accent)
                boxStroke.Transparency = 0.4
                boxStroke.Parent = box
                local check = MakeElement("Image", "rbxassetid://3944680095")
                check.Size = UDim2.new(0,22,0,22)
                check.AnchorPoint = Vector2.new(0.5,0.5)
                check.Position = UDim2.new(0.5,0,0.5,0)
                check.ImageColor3 = Color3.fromRGB(255,255,255)
                check.Name = "Check"
                check.Parent = box
                local str = MakeElement("Stroke")
                str.Parent = f
                local click = MakeElement("Button")
                click.Size = UDim2.new(1,0,1,0)
                click.Parent = f
                
                function toggle:Set(v)
                    toggle.Value = v
                    TweenService:Create(box, TweenInfo.new(0.2), { BackgroundColor3 = v and OrionLib.Themes.Default.Accent or Color3.fromRGB(60,60,60) }):Play()
                    TweenService:Create(boxStroke, TweenInfo.new(0.2), { Color = v and OrionLib.Themes.Default.Accent or Color3.fromRGB(60,60,60) }):Play()
                    TweenService:Create(check, TweenInfo.new(0.2), { ImageTransparency = v and 0 or 1 }):Play()
                    cfg2.Callback(v)
                end
                toggle:Set(cfg2.Default)
                AddConnection(click.MouseButton1Click, function() toggle:Set(not toggle.Value) end)
                return toggle
            end
            
            function els:AddSlider(cfg2)
                cfg2.Name = cfg2.Name or "Slider"
                cfg2.Min = cfg2.Min or 0
                cfg2.Max = cfg2.Max or 100
                cfg2.Default = cfg2.Default or 50
                cfg2.Increment = cfg2.Increment or 1
                cfg2.Callback = cfg2.Callback or function() end
                local slider = { Value = cfg2.Default }
                local f = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), "Second")
                f.Size = UDim2.new(1,0,0,70)
                f.Parent = parent
                local lbl = AddThemeObject(MakeElement("Label", cfg2.Name, 14), "Text")
                lbl.Size = UDim2.new(1, -20, 0, 20)
                lbl.Position = UDim2.new(0,20,0,10)
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = f
                local valueDisplay = AddThemeObject(MakeElement("Label", tostring(cfg2.Default), 12), "TextDark")
                valueDisplay.Size = UDim2.new(0, 60, 0, 20)
                valueDisplay.Position = UDim2.new(1, -80, 0, 10)
                valueDisplay.TextXAlignment = Enum.TextXAlignment.Right
                valueDisplay.Parent = f
                local barBg = MakeElement("RoundFrame", Color3.fromRGB(45,45,55), 0, 4)
                barBg.Size = UDim2.new(1, -40, 0, 8)
                barBg.Position = UDim2.new(0,20,0,45)
                barBg.Parent = f
                local barFill = MakeElement("RoundFrame", OrionLib.Themes.Default.Accent, 0, 4)
                barFill.Size = UDim2.new((cfg2.Default-cfg2.Min)/(cfg2.Max-cfg2.Min), 0, 1, 0)
                barFill.Parent = barBg
                local str = MakeElement("Stroke")
                str.Parent = f
                local dragging = false
                barBg.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        local percent = math.clamp((i.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
                        local val = cfg2.Min + (cfg2.Max-cfg2.Min) * percent
                        val = math.floor(val / cfg2.Increment) * cfg2.Increment
                        slider:Set(val)
                    end
                end)
                UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        local percent = math.clamp((i.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
                        local val = cfg2.Min + (cfg2.Max-cfg2.Min) * percent
                        val = math.floor(val / cfg2.Increment) * cfg2.Increment
                        slider:Set(val)
                    end
                end)
                function slider:Set(val)
                    self.Value = math.clamp(val, cfg2.Min, cfg2.Max)
                    local percent = (self.Value - cfg2.Min) / (cfg2.Max - cfg2.Min)
                    TweenService:Create(barFill, TweenInfo.new(0.1), { Size = UDim2.new(percent, 0, 1, 0) }):Play()
                    valueDisplay.Text = tostring(self.Value)
                    cfg2.Callback(self.Value)
                end
                slider:Set(cfg2.Default)
                return slider
            end
            
            function els:AddTextbox(cfg2)
                cfg2.Name = cfg2.Name or "Input"
                cfg2.Default = cfg2.Default or ""
                cfg2.Callback = cfg2.Callback or function() end
                local f = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), "Second")
                f.Size = UDim2.new(1,0,0,42)
                f.Parent = parent
                local lbl = AddThemeObject(MakeElement("Label", cfg2.Name, 14), "Text")
                lbl.Size = UDim2.new(1, -110, 1, 0)
                lbl.Position = UDim2.new(0,20,0,0)
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = f
                local box = AddThemeObject(Create("TextBox", {
                    Size = UDim2.new(0, 90, 0, 28),
                    Position = UDim2.new(1, -20, 0.5, 0),
                    AnchorPoint = Vector2.new(1,0.5),
                    BackgroundColor3 = Color3.fromRGB(40,40,45),
                    TextColor3 = Color3.fromRGB(240,240,240),
                    PlaceholderColor3 = Color3.fromRGB(150,150,170),
                    PlaceholderText = "Digite...",
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    ClearTextOnFocus = false
                }), "Main")
                local boxCorner = Create("UICorner", { CornerRadius = UDim.new(0,6) })
                boxCorner.Parent = box
                box.Parent = f
                local str = MakeElement("Stroke")
                str.Parent = f
                box.Text = cfg2.Default
                AddConnection(box.FocusLost, function() cfg2.Callback(box.Text) end)
            end
            
            function els:AddDropdown(cfg2)
                cfg2.Name = cfg2.Name or "Dropdown"
                cfg2.Options = cfg2.Options or {}
                cfg2.Default = cfg2.Default or "..."
                cfg2.Callback = cfg2.Callback or function() end
                local dropdown = { Value = cfg2.Default, Open = false, Buttons = {} }
                local f = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), "Second")
                f.Size = UDim2.new(1,0,0,42)
                f.ClipsDescendants = true
                f.Parent = parent
                local top = MakeElement("TFrame")
                top.Size = UDim2.new(1,0,0,42)
                top.Parent = f
                local lbl = AddThemeObject(MakeElement("Label", cfg2.Name, 14), "Text")
                lbl.Size = UDim2.new(1, -100, 1, 0)
                lbl.Position = UDim2.new(0,20,0,0)
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = top
                local selected = AddThemeObject(MakeElement("Label", dropdown.Value, 13), "TextDark")
                selected.Size = UDim2.new(0, 80, 1, 0)
                selected.Position = UDim2.new(1, -90, 0, 0)
                selected.TextXAlignment = Enum.TextXAlignment.Right
                selected.Parent = top
                local arrow = AddThemeObject(MakeElement("Image", "rbxassetid://7072706796"), "TextDark")
                arrow.Size = UDim2.new(0,18,0,18)
                arrow.Position = UDim2.new(1, -20, 0.5, 0)
                arrow.AnchorPoint = Vector2.new(0.5,0.5)
                arrow.Parent = top
                local btn = MakeElement("Button")
                btn.Size = UDim2.new(1,0,1,0)
                btn.Parent = top
                local listContainer = MakeElement("ScrollFrame", Color3.fromRGB(40,40,45), 4)
                listContainer.Size = UDim2.new(1,0,0,0)
                listContainer.Position = UDim2.new(0,0,0,42)
                listContainer.BackgroundTransparency = 0
                listContainer.Parent = f
                local listLayout = MakeElement("List", 0, 4)
                listLayout.Parent = listContainer
                listContainer.CanvasSize = UDim2.new(0,0,0,0)
                
                local function rebuild()
                    for _, kid in ipairs(listContainer:GetChildren()) do if kid:IsA("TextButton") then kid:Destroy() end end
                    for _, opt in ipairs(cfg2.Options) do
                        local optBtn = AddThemeObject(MakeElement("Button"), "Second")
                        optBtn.Size = UDim2.new(1,0,0,32)
                        optBtn.BackgroundTransparency = 0.8
                        optBtn.Parent = listContainer
                        local optLbl = AddThemeObject(MakeElement("Label", opt, 13), "Text")
                        optLbl.Size = UDim2.new(1, -16, 1, 0)
                        optLbl.Position = UDim2.new(0,16,0,0)
                        optLbl.Parent = optBtn
                        AddConnection(optBtn.MouseButton1Click, function()
                            dropdown:Set(opt)
                            dropdown.Open = false
                            TweenService:Create(f, TweenInfo.new(0.2), { Size = UDim2.new(1,0,0,42) }):Play()
                            listContainer.Size = UDim2.new(1,0,0,0)
                            TweenService:Create(arrow, TweenInfo.new(0.2), { Rotation = 0 }):Play()
                        end)
                        dropdown.Buttons[opt] = optBtn
                    end
                    listContainer.CanvasSize = UDim2.new(0,0,0, #cfg2.Options * 36 + 8)
                end
                AddConnection(btn.MouseButton1Click, function()
                    dropdown.Open = not dropdown.Open
                    local newHeight = dropdown.Open and math.min(#cfg2.Options * 36 + 42, 200) or 42
                    TweenService:Create(f, TweenInfo.new(0.2), { Size = UDim2.new(1,0,0,newHeight) }):Play()
                    if dropdown.Open then
                        listContainer.Size = UDim2.new(1,0,0, newHeight-42)
                        TweenService:Create(arrow, TweenInfo.new(0.2), { Rotation = 180 }):Play()
                    else
                        listContainer.Size = UDim2.new(1,0,0,0)
                        TweenService:Create(arrow, TweenInfo.new(0.2), { Rotation = 0 }):Play()
                    end
                end)
                function dropdown:Set(val)
                    if not table.find(cfg2.Options, val) then return end
                    self.Value = val
                    selected.Text = val
                    cfg2.Callback(val)
                end
                rebuild()
                dropdown:Set(cfg2.Default)
                return dropdown
            end
            
            function els:AddColorpicker(cfg2)
                cfg2.Name = cfg2.Name or "Color"
                cfg2.Default = cfg2.Default or Color3.fromRGB(255,255,255)
                cfg2.Callback = cfg2.Callback or function() end
                local colorpick = { Value = cfg2.Default, Open = false }
                local f = AddThemeObject(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 8), "Second")
                f.Size = UDim2.new(1,0,0,42)
                f.ClipsDescendants = true
                f.Parent = parent
                local top = MakeElement("TFrame")
                top.Size = UDim2.new(1,0,0,42)
                top.Parent = f
                local lbl = AddThemeObject(MakeElement("Label", cfg2.Name, 14), "Text")
                lbl.Size = UDim2.new(1, -60, 1, 0)
                lbl.Position = UDim2.new(0,20,0,0)
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = top
                local colorBox = AddThemeObject(MakeElement("RoundFrame", cfg2.Default, 0, 4), "Main")
                colorBox.Size = UDim2.new(0, 28, 0, 28)
                colorBox.Position = UDim2.new(1, -22, 0.5, 0)
                colorBox.AnchorPoint = Vector2.new(0.5,0.5)
                colorBox.Parent = top
                local btn = MakeElement("Button")
                btn.Size = UDim2.new(1,0,1,0)
                btn.Parent = top
                local pickerFrame = MakeElement("TFrame")
                pickerFrame.Size = UDim2.new(1,0,0,150)
                pickerFrame.Position = UDim2.new(0,0,0,42)
                pickerFrame.BackgroundTransparency = 1
                pickerFrame.Parent = f
                local hueSlider = MakeElement("Frame")
                hueSlider.Size = UDim2.new(0, 20, 1, -20)
                hueSlider.Position = UDim2.new(1, -30, 0, 10)
                hueSlider.BackgroundColor3 = Color3.fromRGB(255,255,255)
                hueSlider.Parent = pickerFrame
                local hueGradient = Create("UIGradient", { Rotation = 270, Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
                    ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255,255,0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
                    ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0,0,255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0))
                } })
                hueGradient.Parent = hueSlider
                local hueCorner = Create("UICorner", { CornerRadius = UDim.new(0,10) })
                hueCorner.Parent = hueSlider
                local huePick = MakeElement("Image", "rbxassetid://4805639000")
                huePick.Size = UDim2.new(0,18,0,18)
                huePick.AnchorPoint = Vector2.new(0.5,0.5)
                huePick.Position = UDim2.new(0.5,0,0,0)
                huePick.Parent = hueSlider
                local satVal = MakeElement("ImageLabel", nil, { Image = "rbxassetid://4155801252" })
                satVal.Size = UDim2.new(1, -50, 1, -20)
                satVal.Position = UDim2.new(0,15,0,10)
                satVal.BackgroundColor3 = Color3.fromHSV(0,1,1)
                satVal.BackgroundTransparency = 0
                satVal.Parent = pickerFrame
                local satValCorner = Create("UICorner", { CornerRadius = UDim.new(0,10) })
                satValCorner.Parent = satVal
                local picker = MakeElement("Image", "rbxassetid://4805639000")
                picker.Size = UDim2.new(0,18,0,18)
                picker.AnchorPoint = Vector2.new(0.5,0.5)
                picker.Position = UDim2.new(1,0,0,0)
                picker.Parent = satVal
                local function updateColor()
                    local h, s, v = Color3.toHSV(colorBox.BackgroundColor3)
                    colorpick.Value = colorBox.BackgroundColor3
                    cfg2.Callback(colorpick.Value)
                end
                local function setFromHue(y)
                    local h = 1 - math.clamp((y - hueSlider.AbsolutePosition.Y) / hueSlider.AbsoluteSize.Y, 0, 1)
                    local _, s, v = Color3.toHSV(colorBox.BackgroundColor3)
                    colorBox.BackgroundColor3 = Color3.fromHSV(h, s, v)
                    satVal.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    updateColor()
                end
                local function setFromSatVal(x, y)
                    local s = math.clamp((x - satVal.AbsolutePosition.X) / satVal.AbsoluteSize.X, 0, 1)
                    local v = 1 - math.clamp((y - satVal.AbsolutePosition.Y) / satVal.AbsoluteSize.Y, 0, 1)
                    local h = Color3.toHSV(colorBox.BackgroundColor3)
                    colorBox.BackgroundColor3 = Color3.fromHSV(h, s, v)
                    updateColor()
                end
                hueSlider.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        setFromHue(i.Position.Y)
                        local conn
                        conn = UserInputService.InputChanged:Connect(function(input)
                            if input.UserInputType == i.UserInputType then
                                setFromHue(input.Position.Y)
                            else
                                conn:Disconnect()
                            end
                        end)
                    end
                end)
                satVal.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        setFromSatVal(i.Position.X, i.Position.Y)
                        local conn
                        conn = UserInputService.InputChanged:Connect(function(input)
                            if input.UserInputType == i.UserInputType then
                                setFromSatVal(input.Position.X, input.Position.Y)
                            else
                                conn:Disconnect()
                            end
                        end)
                    end
                end)
                AddConnection(btn.MouseButton1Click, function()
                    colorpick.Open = not colorpick.Open
                    local newH = colorpick.Open and 192 or 42
                    TweenService:Create(f, TweenInfo.new(0.2), { Size = UDim2.new(1,0,0,newH) }):Play()
                end)
                colorpick:Set = function(c3)
                    colorBox.BackgroundColor3 = c3
                    updateColor()
                end
                colorpick:Set(cfg2.Default)
                return colorpick
            end
            
            return els
        end
        
        local tabElements = GetElements(Container)
        
        function tabElements:AddSection(cfg2)
            cfg2.Name = cfg2.Name or "Section"
            local secFrame = MakeElement("TFrame")
            secFrame.Size = UDim2.new(1,0,0,32)
            secFrame.Parent = Container
            local secTitle = AddThemeObject(MakeElement("Label", cfg2.Name, 12), "TextDark")
            secTitle.Size = UDim2.new(1, -20, 0, 18)
            secTitle.Position = UDim2.new(0,0,0,4)
            secTitle.Font = Enum.Font.GothamSemibold
            secTitle.Parent = secFrame
            local secHolder = MakeElement("TFrame")
            secHolder.Size = UDim2.new(1,0,1, -30)
            secHolder.Position = UDim2.new(0,0,0,30)
            secHolder.Name = "Holder"
            secHolder.Parent = secFrame
            local holderList = MakeElement("List", 0, 8)
            holderList.Parent = secHolder
            AddConnection(holderList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                secFrame.Size = UDim2.new(1,0,0, holderList.AbsoluteContentSize.Y + 38)
                secHolder.Size = UDim2.new(1,0,0, holderList.AbsoluteContentSize.Y)
            end)
            return GetElements(secHolder)
        end
        
        function tabElements:AddExecutorTab()
            local sec = tabElements:AddSection({ Name = "Script Executor" })
            local scriptBox = Create("TextBox", {
                Size = UDim2.new(1, -30, 0, 120),
                BackgroundColor3 = Color3.fromRGB(35,35,40),
                TextColor3 = Color3.fromRGB(240,240,240),
                PlaceholderColor3 = Color3.fromRGB(150,150,170),
                PlaceholderText = "Cole seu script Lua aqui...",
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                ClearTextOnFocus = false
            })
            local corner = Create("UICorner", { CornerRadius = UDim.new(0,8) })
            corner.Parent = scriptBox
            scriptBox.Parent = Container
            scriptBox.Position = UDim2.new(0, 20, 0, 70)
            sec:AddButton({ Name = "▶ Executar", Callback = function()
                if scriptBox.Text and scriptBox.Text ~= "" then
                    local ok, err = ExecuteScript(scriptBox.Text)
                    OrionLib:MakeNotification({ Name = "Executor", Content = ok and "Executado!" or "Erro: "..tostring(err), Time = 3 })
                end
            end })
            sec:AddButton({ Name = "🗑 Limpar", Callback = function() scriptBox.Text = "" end })
            return scriptBox
        end
        
        function tabElements:AddRemoteSpyTab()
            local sec = tabElements:AddSection({ Name = "Remote Spy" })
            local spyToggle = sec:AddToggle({ Name = "Ativar Spy", Default = false, Callback = function(s)
                if s then StartRemoteSpy() else StopRemoteSpy() end
            end })
            sec:AddButton({ Name = "🗑 Limpar Logs", Callback = function() OrionLib.RemotesLog = {} end })
            local logFrame = MakeElement("RoundFrame", Color3.fromRGB(35,35,40), 0, 8)
            logFrame.Size = UDim2.new(1,0,0,200)
            logFrame.Parent = Container
            local logScroll = MakeElement("ScrollFrame", Color3.fromRGB(100,100,100), 4)
            logScroll.Size = UDim2.new(1,0,1,0)
            logScroll.Parent = logFrame
            local logList = MakeElement("List", 0, 4)
            logList.Parent = logScroll
            local logPad = MakeElement("Padding", 8,8,8,8)
            logPad.Parent = logScroll
            local function refreshLogs()
                for _, ch in ipairs(logList:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
                for _, log in ipairs(OrionLib.RemotesLog) do
                    local line = MakeElement("Label", string.format("[%s] %s %s", log.Time, log.Remote, log.Action), 11)
                    line.Size = UDim2.new(1,0,0,20)
                    line.TextColor3 = Color3.fromRGB(200,200,220)
                    line.TextWrapped = true
                    line.Parent = logList
                end
                logScroll.CanvasSize = UDim2.new(0,0,0, logList.AbsoluteContentSize.Y + 16)
            end
            task.spawn(function() while true do task.wait(1) refreshLogs() end end)
            return spyToggle
        end
        
        return tabElements
    end
    
    OrionLib:MakeNotification({ Name = "Orion", Content = "Carregada com sucesso!", Time = 2 })
    return { MakeTab = MakeTab }
end

function OrionLib:Destroy()
    for _, conn in ipairs(self.Connections) do pcall(function() conn:Disconnect() end) end
    Orion:Destroy()
end

return OrionLib
