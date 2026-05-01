-- LocalScript de Exemplo
-- Coloque em: StarterPlayer > StarterPlayerScripts
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HackerConsole     = require(ReplicatedStorage:WaitForChild("HackerConsoleUI"))

-- ══════════════════════════════════════════════
--  CRIA O CONSOLE
-- ══════════════════════════════════════════════
local console = HackerConsole.new({
	ConsoleName    = "root@ghostconsole:~#",
	TriggerWord    = ".ghost",
	WelcomeMessage = "Sistema pronto. !help para ver os comandos.",
})

-- ativa escuta do chat (.console abre/fecha)
console:listenChat()

-- ══════════════════════════════════════════════
--  PERSONALIZAÇÃO INICIAL (opcional)
-- ══════════════════════════════════════════════

-- [ 1 ] Mudar a ASCII art do boot
-- Passe qualquer string multilinha.
-- Use console:setAscii("") para desativar.
console:setAscii([[
 ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
██║  ███╗███████║██║   ██║███████╗   ██║   
██║   ██║██╔══██║██║   ██║╚════██║   ██║   
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═]])

-- [ 2 ] Mudar a cor accent (toda a interface muda)
-- Verde padrão:   console:setAccentColor(Color3.fromRGB(0, 255, 128))
-- Azul cyber:     console:setAccentColor(Color3.fromRGB(0, 180, 255))
-- Rosa neon:      console:setAccentColor(Color3.fromRGB(255, 50, 180))
-- Laranja:        console:setAccentColor(Color3.fromRGB(255, 140, 0))
-- Roxo:           console:setAccentColor(Color3.fromRGB(180, 80, 255))
console:setAccentColor(Color3.fromRGB(255, 0, 4))  -- verde padrão

-- [ 3 ] Mudar o nome exibido na barra
-- console:setConsoleName("admin@server:~#")
console:setHeaderBanner(false)

console:setSideImage(130925893132189)
-- ══════════════════════════════════════════════
--  SEUS COMANDOS PERSONALIZADOS
-- ══════════════════════════════════════════════

console:addCommand("!greet", "Cumprimenta alguém. Ex: !greet Fulano", function(args)
	if #args == 0 then
		console:printWarn("Uso: !greet <nome>")
	else
		console:print("  Salve, " .. table.concat(args, " ") .. "!", Color3.fromRGB(255, 220, 100), true)
	end
end)

console:addCommand("!info", "Informações do servidor.", function()
	console:printSystem("Jogo     : " .. game.Name)
	console:printSystem("PlaceId  : " .. tostring(game.PlaceId))
	console:printSystem("JobId    : " .. tostring(game.JobId):sub(1, 18) .. "...")
	console:printSystem("Players  : " .. tostring(#game:GetService("Players"):GetPlayers()))
end)

console:addCommand("!players", "Lista jogadores online.", function()
	local players = game:GetService("Players"):GetPlayers()
	console:printSystem("Jogadores no servidor (" .. #players .. "):")
	for i, p in ipairs(players) do
		console:print(
			string.format("  [%02d] %-20s (ID: %d)", i, p.Name, p.UserId),
			Color3.fromRGB(180, 220, 255), true
		)
	end
end)

console:addCommand("!tp", "Teleporta. Ex: !tp 0 10 0", function(args)
	if #args < 3 then console:printWarn("Uso: !tp <x> <y> <z>") return end
	local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
	if not (x and y and z) then console:printError("Coordenadas inválidas.") return end
	local char = game:GetService("Players").LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
		console:printSystem(string.format("Teletransportado → (%.1f, %.1f, %.1f)", x, y, z))
	else
		console:printError("Personagem não encontrado.")
	end
end)

console:addCommand("!speed", "Muda WalkSpeed. Ex: !speed 30", function(args)
	local val = tonumber(args[1])
	if not val then console:printWarn("Uso: !speed <número>") return end
	local char = game:GetService("Players").LocalPlayer.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = val
		console:printSystem("WalkSpeed → " .. val)
	else
		console:printError("Humanoid não encontrado.")
	end
end)

console:addCommand("!jump", "Muda JumpPower. Ex: !jump 80", function(args)
	local val = tonumber(args[1])
	if not val then console:printWarn("Uso: !jump <número>") return end
	local char = game:GetService("Players").LocalPlayer.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = val
		console:printSystem("JumpPower → " .. val)
	else
		console:printError("Humanoid não encontrado.")
	end
end)

-- Comando que demonstra as 3 novas funções via terminal
console:addCommand("!theme", "Muda o tema. Ex: !theme verde | azul | rosa | laranja | roxo", function(args)
	local temas = {
		verde   = Color3.fromRGB(0, 255, 128),
		azul    = Color3.fromRGB(0, 180, 255),
		rosa    = Color3.fromRGB(255, 50, 180),
		laranja = Color3.fromRGB(255, 140, 0),
		roxo    = Color3.fromRGB(180, 80, 255),
		branco  = Color3.fromRGB(220, 220, 220),
		vermelho = Color3.fromRGB(255, 60, 60),
	}
	local nome = args[1] and args[1]:lower() or ""
	if temas[nome] then
		console:setAccentColor(temas[nome])
		console:printSystem("Tema aplicado: " .. nome)
	else
		console:printWarn("Temas: verde | azul | rosa | laranja | roxo | branco | vermelho")
	end
end)
