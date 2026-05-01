-- HackerConsoleUI (ModuleScript)
-- Coloque em: ReplicatedStorage > HackerConsoleUI
-- ================================================

local HackerConsole = {}
HackerConsole.__index = HackerConsole

local DEFAULT_CONFIG = {
	ConsoleName    = "root@roblox:~#",
	TriggerWord    = ".console",
	WelcomeMessage = "Sistema iniciado. Digite !help para ver os comandos.",
	MaxLines       = 80,
	TextSpeed      = 0.012,
	AccentColor    = Color3.fromRGB(0, 255, 128),
	ErrorColor     = Color3.fromRGB(255, 80, 80),
	WarnColor      = Color3.fromRGB(255, 200, 0),
	SystemColor    = Color3.fromRGB(120, 200, 255),
}

local DEFAULT_ASCII = [[
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@.@@.@@.@@.@@.@@.@@.@@.@@.@@.@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@.@@.@@.@@.@@.@@.@@.@@.@@.@@.@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@]]

-- =============================================
--  CONSTRUTOR
-- =============================================
function HackerConsole.new(config)
	local self = setmetatable({}, HackerConsole)

	self.Config = {}
	for k, v in pairs(DEFAULT_CONFIG) do self.Config[k] = v end
	if config then
		for k, v in pairs(config) do self.Config[k] = v end
	end

	self._asciiArt    = DEFAULT_ASCII
	self._showBanner  = true   -- banner "HACKER" ligado por padrao
	self._sideImageId = nil    -- asset id da imagem lateral (nil = sem imagem)
	self.Commands     = {}
	self.LineCount    = 0
	self.IsOpen       = false
	self.IsTyping     = false
	self._lines       = {}

	self:_buildGui()
	self:_registerDefaultCommands()

	return self
end

-- =============================================
--  CONSTRUCAO DA GUI
-- =============================================
function HackerConsole:_buildGui()
	local Players     = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	local playerGui   = localPlayer:WaitForChild("PlayerGui")

	-- ScreenGui raiz
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "HackerConsoleGui"
	screenGui.ResetOnSpawn   = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.Parent         = playerGui
	self._screenGui = screenGui

	-- Janela principal
	local window = Instance.new("Frame")
	window.Name                   = "ConsoleWindow"
	window.Size                   = UDim2.new(0.72, 0, 0.68, 0)
	window.Position               = UDim2.new(0.14, 0, 0.16, 0)
	window.BackgroundColor3       = Color3.fromRGB(8, 8, 8)
	window.BackgroundTransparency = 0.05
	window.BorderSizePixel        = 0
	window.Visible                = false
	window.ZIndex                 = 10
	window.Parent                 = screenGui
	self._window = window

	local stroke = Instance.new("UIStroke")
	stroke.Color        = self.Config.AccentColor
	stroke.Thickness    = 1.5
	stroke.Transparency = 0
	stroke.Parent       = window
	self._windowStroke  = stroke

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent       = window

	-- Barra de titulo
	local titleBar = Instance.new("Frame")
	titleBar.Name             = "TitleBar"
	titleBar.Size             = UDim2.new(1, 0, 0, 28)
	titleBar.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	titleBar.BorderSizePixel  = 0
	titleBar.ZIndex           = 11
	titleBar.Parent           = window

	local titleBarCorner = Instance.new("UICorner")
	titleBarCorner.CornerRadius = UDim.new(0, 4)
	titleBarCorner.Parent       = titleBar

	local dotDefs = {
		{ Color3.fromRGB(255, 92,  92),  8  },
		{ Color3.fromRGB(255, 189, 68),  26 },
		{ Color3.fromRGB(80,  250, 123), 44 },
	}
	for _, d in ipairs(dotDefs) do
		local dot = Instance.new("Frame")
		dot.Size             = UDim2.new(0, 12, 0, 12)
		dot.Position         = UDim2.new(0, d[2], 0.5, -6)
		dot.BackgroundColor3 = d[1]
		dot.BorderSizePixel  = 0
		dot.ZIndex           = 12
		dot.Parent           = titleBar
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = dot
	end

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name                   = "TitleLabel"
	titleLabel.Size                   = UDim2.new(1, -80, 1, 0)
	titleLabel.Position               = UDim2.new(0, 66, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3             = self.Config.AccentColor
	titleLabel.Font                   = Enum.Font.Code
	titleLabel.TextSize               = 13
	titleLabel.Text                   = self.Config.ConsoleName
	titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
	titleLabel.ZIndex                 = 12
	titleLabel.Parent                 = titleBar
	self._titleLabel = titleLabel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size                   = UDim2.new(0, 28, 0, 20)
	closeBtn.Position               = UDim2.new(1, -32, 0.5, -10)
	closeBtn.BackgroundTransparency = 1
	closeBtn.TextColor3             = Color3.fromRGB(255, 92, 92)
	closeBtn.Font                   = Enum.Font.Code
	closeBtn.TextSize               = 14
	closeBtn.Text                   = "[X]"
	closeBtn.ZIndex                 = 13
	closeBtn.Parent                 = titleBar
	closeBtn.MouseButton1Click:Connect(function() self:close() end)

	-- Body: container que divide texto (esquerda) e imagem (direita)
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name                   = "BodyFrame"
	bodyFrame.Size                   = UDim2.new(1, -10, 1, -72)
	bodyFrame.Position               = UDim2.new(0, 5, 0, 32)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.BorderSizePixel        = 0
	bodyFrame.ZIndex                 = 11
	bodyFrame.Parent                 = window
	self._bodyFrame = bodyFrame

	-- Coluna de texto (scroll) - ocupa tudo por padrao, encolhe quando imagem aparece
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name                   = "OutputScroll"
	scrollFrame.Size                   = UDim2.new(1, 0, 1, 0)
	scrollFrame.Position               = UDim2.new(0, 0, 0, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel        = 0
	scrollFrame.ScrollBarThickness     = 4
	scrollFrame.ScrollBarImageColor3   = self.Config.AccentColor
	scrollFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	scrollFrame.ZIndex                 = 11
	scrollFrame.Parent                 = bodyFrame
	self._outputScroll = scrollFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding   = UDim.new(0, 1)
	listLayout.Parent    = scrollFrame
	self._listLayout = listLayout

	-- Coluna da imagem (oculta ate setSideImage ser chamado)
	local sidePanel = Instance.new("Frame")
	sidePanel.Name                   = "SidePanel"
	sidePanel.Size                   = UDim2.new(0.38, 0, 1, 0)
	sidePanel.Position               = UDim2.new(0.62, 0, 0, 0)
	sidePanel.BackgroundTransparency = 1
	sidePanel.BorderSizePixel        = 0
	sidePanel.Visible                = false
	sidePanel.ZIndex                 = 11
	sidePanel.Parent                 = bodyFrame
	self._sidePanel = sidePanel

	-- linha divisoria entre texto e imagem
	local divider = Instance.new("Frame")
	divider.Name                   = "Divider"
	divider.Size                   = UDim2.new(0, 1, 0.9, 0)
	divider.Position               = UDim2.new(0, 0, 0.05, 0)
	divider.BackgroundColor3       = self.Config.AccentColor
	divider.BackgroundTransparency = 0.65
	divider.BorderSizePixel        = 0
	divider.ZIndex                 = 12
	divider.Parent                 = sidePanel
	self._sideDivider = divider

	-- ImageLabel que mostra o asset
	local sideImg = Instance.new("ImageLabel")
	sideImg.Name                   = "SideImage"
	sideImg.Size                   = UDim2.new(1, -14, 1, -14)
	sideImg.Position               = UDim2.new(0, 10, 0, 7)
	sideImg.BackgroundTransparency = 1
	sideImg.BorderSizePixel        = 0
	sideImg.ScaleType              = Enum.ScaleType.Fit
	sideImg.Image                  = ""
	sideImg.ZIndex                 = 12
	sideImg.Parent                 = sidePanel
	self._sideImage = sideImg

	-- Barra de input
	local inputBar = Instance.new("Frame")
	inputBar.Name             = "InputBar"
	inputBar.Size             = UDim2.new(1, -10, 0, 32)
	inputBar.Position         = UDim2.new(0, 5, 1, -38)
	inputBar.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
	inputBar.BorderSizePixel  = 0
	inputBar.ZIndex           = 11
	inputBar.Parent           = window

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color        = self.Config.AccentColor
	inputStroke.Thickness    = 1
	inputStroke.Transparency = 0.45
	inputStroke.Parent       = inputBar
	self._inputStroke = inputStroke

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 3)
	inputCorner.Parent       = inputBar

	local prompt = Instance.new("TextLabel")
	prompt.Size                   = UDim2.new(0, 22, 1, 0)
	prompt.Position               = UDim2.new(0, 6, 0, 0)
	prompt.BackgroundTransparency = 1
	prompt.TextColor3             = self.Config.AccentColor
	prompt.Font                   = Enum.Font.Code
	prompt.TextSize               = 14
	prompt.Text                   = ">"
	prompt.ZIndex                 = 12
	prompt.Parent                 = inputBar
	self._promptLabel = prompt

	local inputBox = Instance.new("TextBox")
	inputBox.Name                   = "InputBox"
	inputBox.Size                   = UDim2.new(1, -32, 1, 0)
	inputBox.Position               = UDim2.new(0, 28, 0, 0)
	inputBox.BackgroundTransparency = 1
	inputBox.TextColor3             = Color3.fromRGB(220, 255, 220)
	inputBox.PlaceholderText        = "digite um comando  (!help para ajuda)..."
	inputBox.PlaceholderColor3      = Color3.fromRGB(55, 85, 55)
	inputBox.Font                   = Enum.Font.Code
	inputBox.TextSize               = 13
	inputBox.TextXAlignment         = Enum.TextXAlignment.Left
	inputBox.ClearTextOnFocus       = false
	inputBox.ZIndex                 = 12
	inputBox.Parent                 = inputBar
	self._inputBox = inputBox

	inputBox.FocusLost:Connect(function(enter)
		if enter then
			local text = inputBox.Text
			inputBox.Text = ""
			if text ~= "" then self:_processInput(text) end
		end
	end)

	-- barra de status (rodape)
	local statusBar = Instance.new("Frame")
	statusBar.Size                   = UDim2.new(1, 0, 0, 5)
	statusBar.Position               = UDim2.new(0, 0, 1, -5)
	statusBar.BackgroundColor3       = self.Config.AccentColor
	statusBar.BackgroundTransparency = 0.55
	statusBar.BorderSizePixel        = 0
	statusBar.ZIndex                 = 11
	statusBar.Parent                 = window
	self._statusBar = statusBar

	self:_makeDraggable(window, titleBar)
end

-- =============================================
--  ARRASTAR
-- =============================================
function HackerConsole:_makeDraggable(frame, handle)
	local UIS = game:GetService("UserInputService")
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			dragStart = inp.Position
			startPos  = frame.Position
		end
	end)
	handle.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
			local d = inp.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
end

-- =============================================
--  IMPRIMIR NO OUTPUT
-- =============================================
function HackerConsole:print(text, color, noPrefix)
	color = color or self.Config.AccentColor
	if self.LineCount >= self.Config.MaxLines then self:clear() end

	local line = Instance.new("TextLabel")
	line.Size                   = UDim2.new(1, -8, 0, 18)
	line.AutomaticSize          = Enum.AutomaticSize.Y
	line.BackgroundTransparency = 1
	line.TextColor3             = color
	line.Font                   = Enum.Font.Code
	line.TextSize               = 12
	line.TextXAlignment         = Enum.TextXAlignment.Left
	line.TextWrapped            = true
	line.RichText               = false
	line.LayoutOrder            = self.LineCount
	line.ZIndex                 = 12
	line.Text                   = text
	line.Parent                 = self._outputScroll

	self.LineCount += 1
	table.insert(self._lines, line)

	task.defer(function()
		self._outputScroll.CanvasPosition =
			Vector2.new(0, self._outputScroll.AbsoluteCanvasSize.Y)
	end)

	return line
end

function HackerConsole:printSystem(text)
	self:print("  " .. text, self.Config.SystemColor, true)
end

function HackerConsole:printError(text)
	self:print("  [ERRO] " .. text, self.Config.ErrorColor, true)
end

function HackerConsole:printWarn(text)
	self:print("  [AVISO] " .. text, self.Config.WarnColor, true)
end

function HackerConsole:printUser(text)
	self:print(self.Config.ConsoleName .. " " .. text, Color3.fromRGB(160, 160, 160), true)
end

function HackerConsole:typewrite(text, color)
	color = color or self.Config.AccentColor
	local line = self:print("", color, true)
	task.spawn(function()
		self.IsTyping = true
		for i = 1, #text do
			line.Text = string.sub(text, 1, i)
			task.wait(self.Config.TextSpeed)
		end
		self.IsTyping = false
	end)
end

function HackerConsole:clear()
	for _, lbl in ipairs(self._lines) do lbl:Destroy() end
	self._lines    = {}
	self.LineCount = 0
end

-- =============================================
--  ABRIR / FECHAR
-- =============================================
function HackerConsole:open()
	if self.IsOpen then return end
	self.IsOpen = true
	self._window.Visible = true

	local TweenService = game:GetService("TweenService")
	self._window.Size     = UDim2.new(0.01, 0, 0.01, 0)
	self._window.Position = UDim2.new(0.495, 0, 0.495, 0)

	TweenService:Create(self._window,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0.72,0,0.68,0), Position = UDim2.new(0.14,0,0.16,0) }
	):Play()

	task.delay(0.25, function() self._inputBox:CaptureFocus() end)
	if self.LineCount == 0 then self:_printBoot() end
end

function HackerConsole:close()
	if not self.IsOpen then return end
	self.IsOpen = false

	local TweenService = game:GetService("TweenService")
	local tw = TweenService:Create(self._window,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Size = UDim2.new(0.01,0,0.01,0), Position = UDim2.new(0.495,0,0.495,0) }
	)
	tw:Play()
	tw.Completed:Connect(function() self._window.Visible = false end)
end

function HackerConsole:toggle()
	if self.IsOpen then self:close() else self:open() end
end

-- =============================================
--  BOOT SCREEN
-- =============================================
function HackerConsole:_printBoot()
	-- ASCII art personalizada
	if self._asciiArt and self._asciiArt ~= "" then
		for line in self._asciiArt:gmatch("[^\n]+") do
			self:print(line, self.Config.AccentColor, true)
		end
		self:print("", Color3.fromRGB(0,0,0), true)
	end

	-- Banner "HACKER" (pode ser desligado com setHeaderBanner(false))
	if self._showBanner then
		local header = {
			"  ██╗  ██╗ █████╗  ██████╗██╗  ██╗███████╗██████╗ ",
			"  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗",
			"  ███████║███████║██║     █████╔╝ █████╗  ██████╔╝",
			"  ██╔══██║██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗",
			"  ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║",
			"  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝",
		}
		for _, l in ipairs(header) do
			self:print(l, self.Config.AccentColor, true)
		end
		self:print("", Color3.fromRGB(0,0,0), true)
	end

	self:printSystem("Sistema: HackerConsole v1.2  |  Roblox")
	self:printSystem("Usuario: " .. game:GetService("Players").LocalPlayer.Name)
	self:printSystem(os.date("Data : %Y-%m-%d  Hora: %H:%M:%S"))
	self:print("", Color3.fromRGB(0,0,0), true)
	self:typewrite("  " .. self.Config.WelcomeMessage, self.Config.AccentColor)
	self:print("", Color3.fromRGB(0,0,0), true)
end

-- =============================================
--  PROCESSAR INPUT
-- =============================================
function HackerConsole:_processInput(rawText)
	local text = rawText:match("^%s*(.-)%s*$")
	self:printUser(text)

	local parts = {}
	for w in text:gmatch("%S+") do table.insert(parts, w) end
	if #parts == 0 then return end

	local cmdKey = parts[1]:lower()
	local args   = {}
	for i = 2, #parts do table.insert(args, parts[i]) end

	if self.Commands[cmdKey] then
		local ok, err = pcall(self.Commands[cmdKey].callback, args)
		if not ok then
			self:printError("Erro ao executar: " .. tostring(err))
		end
	else
		self:printError("Comando desconhecido: '" .. cmdKey .. "'  ->  !help para ver a lista.")
	end

	self:print("", Color3.fromRGB(0,0,0), true)
end

-- =============================================
--  API PUBLICA - PERSONALIZACAO
-- =============================================

-- Muda o nome exibido na barra de titulo.
-- Ex: console:setConsoleName("admin@server:~#")
function HackerConsole:setConsoleName(name)
	self.Config.ConsoleName = name
	self._titleLabel.Text   = name
end

-- Substitui a ASCII art mostrada no boot.
-- Passe "" ou nil para desativar.
-- Ex: console:setAscii("  /\\_/\\\n ( o.o )")
function HackerConsole:setAscii(asciiString)
	self._asciiArt = asciiString or ""
end

-- Liga ou desliga o banner "HACKER" em ASCII grande no boot.
-- Ex: console:setHeaderBanner(false)  -> desliga
--     console:setHeaderBanner(true)   -> liga
function HackerConsole:setHeaderBanner(enabled)
	self._showBanner = enabled == true
end

-- Coloca uma imagem no painel direito do console.
-- Passe um Asset ID do Roblox (numero ou string "rbxassetid://...").
-- Passe nil ou "" para remover a imagem e volcar ao layout full.
-- Ex: console:setSideImage(123456789)
--     console:setSideImage("rbxassetid://123456789")
--     console:setSideImage(nil)  -> remove imagem
function HackerConsole:setSideImage(assetId)
	if assetId == nil or assetId == "" then
		-- remove imagem: scroll volta a ocupar 100% da largura
		self._sidePanel.Visible             = false
		self._outputScroll.Size             = UDim2.new(1, 0, 1, 0)
		self._sideImageId                   = nil
		self._sideImage.Image               = ""
	else
		-- monta a url corretamente
		local url
		if type(assetId) == "number" then
			url = "rbxassetid://" .. tostring(assetId)
		elseif tostring(assetId):find("rbxassetid://") then
			url = tostring(assetId)
		else
			url = "rbxassetid://" .. tostring(assetId)
		end

		self._sideImageId   = url
		self._sideImage.Image = url

		-- scroll ocupa 62% e painel de imagem os 38% restantes
		self._outputScroll.Size = UDim2.new(0.62, -4, 1, 0)
		self._sidePanel.Visible = true
	end
end

-- Muda a cor principal de toda a interface.
-- Ex: console:setAccentColor(Color3.fromRGB(0, 180, 255))
function HackerConsole:setAccentColor(color)
	self.Config.AccentColor = color
	self._windowStroke.Color                = color
	self._outputScroll.ScrollBarImageColor3 = color
	self._inputStroke.Color                 = color
	self._promptLabel.TextColor3            = color
	self._titleLabel.TextColor3             = color
	self._statusBar.BackgroundColor3        = color
	self._sideDivider.BackgroundColor3      = color
end

-- Muda a cor de erros.
function HackerConsole:setErrorColor(color)
	self.Config.ErrorColor = color
end

-- Muda a cor de avisos.
function HackerConsole:setWarnColor(color)
	self.Config.WarnColor = color
end

-- Muda a cor das mensagens de sistema.
function HackerConsole:setSystemColor(color)
	self.Config.SystemColor = color
end

-- =============================================
--  API PUBLICA - COMANDOS
-- =============================================

-- Adiciona um comando. O trigger e case-insensitive.
-- Ex: console:addCommand("!oi", "Diz oi", function(args) ... end)
function HackerConsole:addCommand(trigger, desc, callback)
	self.Commands[trigger:lower()] = { trigger = trigger, desc = desc, callback = callback }
end

-- Remove um comando registrado.
function HackerConsole:removeCommand(trigger)
	self.Commands[trigger:lower()] = nil
end

-- =============================================
--  COMANDOS PADRAO
-- =============================================
function HackerConsole:_registerDefaultCommands()

	self:addCommand("!help", "Lista todos os comandos.", function()
		self:printSystem("======= COMANDOS =======")
		for _, cmd in pairs(self.Commands) do
			self:print(
				string.format("  %-18s - %s", cmd.trigger, cmd.desc),
				Color3.fromRGB(180, 255, 180), true
			)
		end
		self:printSystem("========================")
	end)

	self:addCommand("!clear", "Limpa o terminal.", function()
		self:clear()
		self:printSystem("Terminal limpo.")
	end)

	self:addCommand("!hello", "Mensagem de boas-vindas.", function()
		self:typewrite(
			"  Ola, " .. game:GetService("Players").LocalPlayer.Name .. "! Bem-vindo ao HackerConsole.",
			self.Config.AccentColor
		)
	end)

	self:addCommand("!whoami", "Informacoes do jogador.", function()
		local p = game:GetService("Players").LocalPlayer
		self:printSystem("Player      : " .. p.Name)
		self:printSystem("DisplayName : " .. p.DisplayName)
		self:printSystem("UserId      : " .. tostring(p.UserId))
		local ok, ping = pcall(function()
			return math.round(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
		end)
		self:printSystem("Ping        : " .. (ok and tostring(ping) .. " ms" or "N/A"))
	end)

	self:addCommand("!time", "Mostra a hora atual.", function()
		self:printSystem(os.date("Data/Hora: %Y-%m-%d  %H:%M:%S"))
	end)

	self:addCommand("!echo", "Repete texto. Ex: !echo oi", function(args)
		if #args == 0 then self:printWarn("Uso: !echo <texto>")
		else self:print("  " .. table.concat(args, " "), self.Config.AccentColor, true) end
	end)

	self:addCommand("!name", "Muda o nome do console. Ex: !name admin@srv", function(args)
		if #args == 0 then self:printWarn("Uso: !name <novo_nome>")
		else
			self:setConsoleName(table.concat(args, " "))
			self:printSystem("Nome alterado para: " .. self.Config.ConsoleName)
		end
	end)

	self:addCommand("!color", "Muda a cor accent (R G B). Ex: !color 255 0 128", function(args)
		local r, g, b = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
		if not (r and g and b) then
			self:printWarn("Uso: !color <R> <G> <B>  (valores 0-255)")
			return
		end
		self:setAccentColor(Color3.fromRGB(
			math.clamp(r,0,255), math.clamp(g,0,255), math.clamp(b,0,255)
		))
		self:printSystem(string.format("Cor alterada -> RGB(%d, %d, %d)", r, g, b))
	end)

	self:addCommand("!ascii", "Exibe a ASCII art atual.", function()
		if self._asciiArt == "" then
			self:printWarn("Nenhuma ASCII art definida.")
		else
			for line in self._asciiArt:gmatch("[^\n]+") do
				self:print(line, self.Config.AccentColor, true)
			end
		end
	end)

	self:addCommand("!banner", "Liga/desliga o banner HACKER. Ex: !banner on", function(args)
		local val = args[1] and args[1]:lower() or ""
		if val == "on" or val == "1" or val == "true" then
			self:setHeaderBanner(true)
			self:printSystem("Banner ativado.")
		elseif val == "off" or val == "0" or val == "false" then
			self:setHeaderBanner(false)
			self:printSystem("Banner desativado.")
		else
			self:printWarn("Uso: !banner on  |  !banner off")
		end
	end)

	self:addCommand("!image", "Define imagem lateral. Ex: !image 123456789", function(args)
		if #args == 0 or args[1]:lower() == "none" or args[1]:lower() == "off" then
			self:setSideImage(nil)
			self:printSystem("Imagem lateral removida.")
		else
			self:setSideImage(args[1])
			self:printSystem("Imagem definida: " .. tostring(args[1]))
		end
	end)

	self:addCommand("!close", "Fecha o console.", function()
		self:close()
	end)

	self:addCommand("!matrix", "Efeito Matrix.", function()
		local chars = "01#$%&@!abcdef"
		task.spawn(function()
			for _ = 1, 22 do
				local row = "  "
				for _ = 1, 40 do
					local i = math.random(1, #chars)
					row = row .. string.sub(chars, i, i)
				end
				self:print(row, Color3.fromRGB(0, math.random(140,255), 0), true)
				task.wait(0.06)
			end
			self:printSystem("[ Matrix sequence complete ]")
		end)
	end)
end

-- =============================================
--  OUVIR CHAT
-- =============================================
function HackerConsole:listenChat()
	local Players = game:GetService("Players")
	local player  = Players.LocalPlayer

	local ok = pcall(function()
		local TCS = game:GetService("TextChatService")
		TCS.MessageReceived:Connect(function(msg)
			if msg.TextSource and msg.TextSource.UserId == player.UserId then
				if msg.Text:lower() == self.Config.TriggerWord:lower() then
					self:toggle()
				end
			end
		end)
	end)

	if not ok then
		player.Chatted:Connect(function(msg)
			if msg:lower() == self.Config.TriggerWord:lower() then
				self:toggle()
			end
		end)
	end
end

return HackerConsole
