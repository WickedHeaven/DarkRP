local plyMeta = FindMetaTable("Player")
local finishWarrantRequest
local arrestedPlayers = {}

/*---------------------------------------------------------------------------
Interface functions
---------------------------------------------------------------------------*/
function plyMeta:warrant(warranter, reason)
	if self.warranted then return end
	hook.Call("PlayerWarranted", GAMEMODE, warranter, self, reason)

	self.warranted = true
	timer.Simple(GAMEMODE.Config.searchtime, function()
		if not IsValid(self) then return end
		self:unWarrant(warranter)
	end)

	local warranterNick = IsValid(warranter) and warranter:Nick() or DarkRP.getPhrase("disconnected_player")
	local centerMessage = DarkRP.getPhrase("warrant_approved", self:Nick(), reason, warranterNick)
	local printMessage = DarkRP.getPhrase("warrant_ordered", warranterNick, self:Nick(), reason)

	for a, b in pairs(player.GetAll()) do
		b:PrintMessage(HUD_PRINTCENTER, centerMessage)
		b:PrintMessage(HUD_PRINTCONSOLE, printMessage)
	end

	GAMEMODE:Notify(warranter, 0, 4, DarkRP.getPhrase("warrant_approved2"))
end

function plyMeta:unWarrant(unwarranter)
	if not self.warranted then return end

	hook.Call("PlayerUnWarranted", GAMEMODE, unwarranter, self)

	self.warranted = false
	GAMEMODE:Notify(unwarranter, 2, 4, DarkRP.getPhrase("warrant_expired", self:Nick()))
end

function plyMeta:requestWarrant(suspect, actor, reason)
	local question = DarkRP.getPhrase("warrant_request", actor:Nick(), suspect:Nick(), reason)
	GAMEMODE.ques:Create(question, suspect:EntIndex() .. "warrant", self, 40, finishWarrantRequest, actor, suspect, reason)
end

function plyMeta:wanted(actor, reason)
	hook.Call("PlayerWanted", DarkRP.hooks, actor, self, reason)

	self:setDarkRPVar("wanted", true)
	self:setDarkRPVar("wantedReason", reason)

	local actorNick = IsValid(actor) and actor:Nick() or DarkRP.getPhrase("disconnected_player")
	local centerMessage = DarkRP.getPhrase("wanted_by_police", self:Nick(), reason, actorNick)
	local printMessage = DarkRP.getPhrase("wanted_by_police_print", actorNick, self:Nick(), reason)

	for _, ply in pairs(player.GetAll()) do
		ply:PrintMessage(HUD_PRINTCENTER, centerMessage)
		ply:PrintMessage(HUD_PRINTCONSOLE, printMessage)
	end

	timer.Create(self:UniqueID() .. " wantedtimer", GAMEMODE.Config.wantedtime, 1, function()
		if not IsValid(self) then return end
		self:unWanted()
	end)
end

function plyMeta:unWanted(actor)
	hook.Call("PlayerUnWanted", GAMEMODE, actor, self)
	self:setDarkRPVar("wanted", false)

	local expiredMessage = IsValid(actor) and DarkRP.getPhrase("wanted_revoked", self:Nick(), actor:Nick() or "") or
		DarkRP.getPhrase("wanted_expired", self:Nick())

	for _, ply in pairs(player.GetAll()) do
		ply:PrintMessage(HUD_PRINTCENTER, expiredMessage)
		ply:PrintMessage(HUD_PRINTCONSOLE, expiredMessage)
	end
	timer.Destroy(self:UniqueID() .. " wantedtimer")
end

function plyMeta:arrest(time, arrester)
	time = GAMEMODE.Config.jailtimer or 120

	hook.Call("playerArrested", DarkRP.hooks, self, time, arrester)
	self:setDarkRPVar("Arrested", true)
	arrestedPlayers[self:SteamID()] = true

	-- Always get sent to jail when Arrest() is called, even when already under arrest
	if GAMEMODE.Config.teletojail and DarkRP.jailPosCount() ~= 0 then
		local jailpos = DarkRP.retrieveJailPos()
		if jailpos then
			jailpos = GAMEMODE:FindEmptyPos(jailpos, {ply}, 300, 30, Vector(16, 16, 64))
			self:SetPos(jailpos)
		end
	end
end

function plyMeta:unArrest(unarrester)
	if not self:isArrested() then return end

	self:setDarkRPVar("Arrested", false)
	arrestedPlayers[self:SteamID()] = nil
	hook.Call("playerUnArrested", DarkRP.hooks, self)
end

/*---------------------------------------------------------------------------
Chat commands
---------------------------------------------------------------------------*/
local function CombineRequest(ply, args)
	if args == "" then
		GAMEMODE:Notify(ply, 1, 4, DarkRP.getPhrase("invalid_x", "argument", ""))
		return ""
	end
	local t = ply:Team()

	local DoSay = function(text)
		if text == "" then
			GAMEMODE:Notify(ply, 1, 4, DarkRP.getPhrase("invalid_x", "argument", ""))
			return
		end
		for k, v in pairs(player.GetAll()) do
			if v:IsCP() or v == ply then
				GAMEMODE:TalkToPerson(v, team.GetColor(ply:Team()), DarkRP.getPhrase("request") ..ply:Nick(), Color(255,0,0,255), text, ply)
			end
		end
	end
	return args, DoSay
end
DarkRP.defineChatCommand("cr", CombineRequest, 1.5)

local function warrantCommand(ply, args)
	local expl = string.Explode(" ", args or "")
	local target = GAMEMODE:FindPlayer(expl[1])
	local reason = table.concat(expl, " ", 2)

	local canRequest, message = hook.Call("canRequestWarrant", DarkRP.hooks, target, ply, reason)
	if not canRequest then
		GAMEMODE:Notify(ply, 1, 4, message)
		return ""
	end

	if not RPExtraTeams[ply:Team()] or not RPExtraTeams[ply:Team()].mayor then -- No need to search through all the teams if the player is a mayor
		local mayors = {}

		for k,v in pairs(RPExtraTeams) do
			if v.mayor then
				table.Add(mayors, team.GetPlayers(k))
			end
		end

		if #mayors > 0 then -- Request a warrant if there's a mayor
			local mayor = table.Random(mayors)
			mayor:requestWarrant(target, ply, reason)
			GAMEMODE:Notify(ply, 0, 4, DarkRP.getPhrase("warrant_request2", mayor:Nick()))
			return ""
		end
	end

	target:warrant(ply, reason)

	return ""
end
DarkRP.defineChatCommand("warrant", warrantCommand)

local function wantedCommand(ply, args)
	local expl = string.Explode(" ", args or "")
	local target = GAMEMODE:FindPlayer(expl[1])
	local reason = table.concat(expl, " ", 2)

	local canWanted, message = hook.Call("canWanted", DarkRP.hooks, target, ply, reason)
	if not canWanted then
		GAMEMODE:Notify(ply, 1, 4, message)
		return ""
	end

	target:wanted(ply, reason)

	return ""
end
DarkRP.defineChatCommand("wanted", wantedCommand)

local function unwantedCommand(ply, args)
	local target = GAMEMODE:FindPlayer(args)

	local canUnwant, message = hook.Call("canUnwant", DarkRP.hooks, target, ply)
	if not canUnwant then
		GAMEMODE:Notify(ply, 1, 4, message)
		return ""
	end

	target:unWanted(ply)

	return ""
end
DarkRP.defineChatCommand("unwanted", unwantedCommand)

/*---------------------------------------------------------------------------
Admin commands
---------------------------------------------------------------------------*/
local function ccArrest(ply, cmd, args)
	if not args[1] then return end
	if ply:EntIndex() ~= 0 and not ply:HasPriv("rp_commands") then
		ply:PrintMessage(2, DarkRP.getPhrase("need_admin", "rp_arrest"))
		return
	end

	if DarkRP.jailPosCount() == 0 then
		if ply:EntIndex() == 0 then
			print(DarkRP.getPhrase("no_jail_pos"))
		else
			ply:PrintMessage(2, DarkRP.getPhrase("no_jail_pos"))
		end
		return
	end

	local target = DarkRP.findPlayer(args[1])
	if target then
		local length = tonumber(args[2])
		if length then
			target:arrest(length, ply)
		else
			target:arrest(nil, ply)
		end

		if ply:EntIndex() == 0 then
			DarkRP.log("Console force-arrested "..target:SteamName(), Color(0, 255, 255))
		else
			DarkRP.log(ply:Nick().." ("..ply:SteamID()..") force-arrested "..target:SteamName(), Color(0, 255, 255))
		end
	else
		if ply:EntIndex() == 0 then
			print(DarkRP.getPhrase("could_not_find", tostring(args[1])))
		else
			ply:PrintMessage(2, DarkRP.getPhrase("could_not_find", tostring(args[1])))
		end
	end

end
concommand.Add("rp_arrest", ccArrest)

local function ccUnarrest(ply, cmd, args)
	if not args[1] then return end
	if ply:EntIndex() ~= 0 and not ply:HasPriv("rp_commands") then
		ply:PrintMessage(2, DarkRP.getPhrase("need_admin", "rp_unarrest"))
		return
	end

	local target = DarkRP.findPlayer(args[1])

	if target then
		target:unArrest(ply)
		if not target:Alive() then target:Spawn() end

		if ply:EntIndex() == 0 then
			DarkRP.log("Console force-unarrested "..target:SteamName(), Color(0, 255, 255))
		else
			DarkRP.log(ply:Nick().." ("..ply:SteamID()..") force-unarrested "..target:SteamName(), Color(0, 255, 255))
		end
	else
		if ply:EntIndex() == 0 then
			print(DarkRP.getPhrase("could_not_find", tostring(args[1])))
		else
			ply:PrintMessage(2, DarkRP.getPhrase("could_not_find", tostring(args[1])))
		end
		return
	end

end
concommand.Add("rp_unarrest", ccUnarrest)

/*---------------------------------------------------------------------------
Callback functions
---------------------------------------------------------------------------*/
function finishWarrantRequest(choice, mayor, initiator, suspect, reason)
	if not tobool(choice) then
		GAMEMODE:Notify(initiator, 1, 4, DarkRP.getPhrase("warrant_denied", mayor:Nick()))
		return
	end

	suspect:warrant(initiator, reason)
end

/*---------------------------------------------------------------------------
Hooks
---------------------------------------------------------------------------*/
function DarkRP.hooks:playerArrested(ply, time, arrester)
	if ply:isWanted() then ply:unWanted(arrester) end
	ply:unWarrant(arrester)
	ply:setSelfDarkRPVar("HasGunlicense", false)

	-- UpdatePlayerSpeed won't work here as the "Arrested" DarkRPVar is set AFTER this hook
	GAMEMODE:SetPlayerSpeed(ply, GAMEMODE.Config.arrestspeed, GAMEMODE.Config.arrestspeed)
	ply:StripWeapons()

	if ply:isArrested() then return end -- hasn't been arrested before

	ply:PrintMessage(HUD_PRINTCENTER, DarkRP.getPhrase("youre_arrested", time))
	for k, v in pairs(player.GetAll()) do
		if v == ply then continue end
		v:PrintMessage(HUD_PRINTCENTER, DarkRP.getPhrase("hes_arrested", ply:Name(), time))
	end

	local steamID = ply:SteamID()
	timer.Create(ply:UniqueID() .. "jailtimer", time, 1, function()
		if IsValid(ply) then ply:unArrest() end
		arrestedPlayers[steamID] = nil
	end)
	umsg.Start("GotArrested", ply)
		umsg.Float(time)
	umsg.End()
end

function DarkRP.hooks:playerUnArrested(ply, actor)
	if ply.Sleeping and GAMEMODE.KnockoutToggle then
		GAMEMODE:KnockoutToggle(ply, "force")
	end

	-- "Arrested" DarkRPVar is set to false BEFORE this hook however, so it is safe here.
	hook.Call("UpdatePlayerSpeed", GAMEMODE, ply)
	GAMEMODE:PlayerLoadout(ply)
	if GAMEMODE.Config.telefromjail and (not FAdmin or not ply:FAdmin_GetGlobal("fadmin_jailed")) then
		local _, pos = GAMEMODE:PlayerSelectSpawn(ply)
		ply:SetPos(pos)
	elseif FAdmin and ply:FAdmin_GetGlobal("fadmin_jailed") then
		ply:SetPos(ply.FAdminJailPos)
	end

	timer.Destroy(ply:SteamID() .. "jailtimer")
	GAMEMODE:NotifyAll(0, 4, DarkRP.getPhrase("hes_unarrested", ply:Name()))
end

hook.Add("PlayerInitialSpawn", "Arrested", function(ply)
	if not arrestedPlayers[ply:SteamID()] then return end
	local time = GAMEMODE.Config.jailtimer
	ply:arrest(time)
	GAMEMODE:Notify(ply, 0, 5, DarkRP.getPhrase("jail_punishment", time))
end)