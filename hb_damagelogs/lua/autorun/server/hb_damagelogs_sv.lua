util.AddNetworkString("hb_damagelogs_printsend")

local hb_damagelogs_enable = CreateConVar("hb_damagelogs_enable", "1", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies whether Damage Logs are enabled or not [Realm: Serverside | Type: Boolean | Min Value: 0 | Max Value: 1 | Default Value: 1]")
local hb_damagelogs_printmode = CreateConVar("hb_damagelogs_printmode", "1", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies whether to print damage logs to console or not [Realm: Serverside | Type: Boolean | Min Value: 0 | Max Value: 1 | Default Value: 0]")
local hb_damagelogs_printmode_cl = CreateConVar("hb_damagelogs_printmode_cl", "0", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies whether to print damage logs to client console or not - 0: Disabled | 1: Everyone | 2: Admin+ only | 3: SuperAdmin only+ [Realm: Serverside | Type: Integer | Min Value: 0 | Max Value: 3 | Default Value: 2]")
local hb_damagelogs_cooldowntime = CreateConVar("hb_damagelogs_cooldowntime", "0.25", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies the minimum amount of time required after a damage log before another can be triggered [Realm: Serverside | Type: Float | Min Value: 0 | Max Value: Inf | Default Value: 0.25]")
local hb_damagelogs_damagethreshold = CreateConVar("hb_damagelogs_damagethreshold", "1", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies the minimum amount of damage inflicted required to trigger a log [Realm: Serverside | Type: Integer | Min Value: 1 | Max Value: Inf | Default Value: 1]")

local LastLogTime = CurTime()
local LastTarget = ""
local LastAttacker = ""
local InflictorName = ""

local function HBDamageLogsPre(tgt, dmg)
	if not hb_damagelogs_enable:GetBool() then return end
	if not tgt:IsPlayer() then return end
	if dmg:GetDamage() < hb_damagelogs_damagethreshold:GetInt() then return end
	local Attacker = dmg:GetAttacker()
	local Inflictor = dmg:GetInflictor()
	
	if Inflictor == NULL then
		InflictorName = "an unknown weapon"
	elseif Inflictor:IsPlayer() or Inflictor:IsNPC() then
		local InflictorActiveWeapon = Inflictor:GetActiveWeapon()
		
		if IsValid(InflictorActiveWeapon) then
			InflictorName = InflictorActiveWeapon:GetClass()
		else
			InflictorName = "an unknown weapon"
		end
	elseif Attacker:IsPlayer() or Attacker:IsNPC() then
		InflictorName = Inflictor:GetClass()
	else
		local InflictorModel = string.GetFileFromFilename(Inflictor:GetModel() or "")
		
		if InflictorModel == "" then
			InflictorName = "an unknown weapon"
		elseif (CPPI) then
			local InflictorOwner = ents.GetByIndex(Inflictor:EntIndex()):CPPIGetOwner()
			
			if IsValid(InflictorOwner) then
				InflictorName = InflictorModel.." - Owned by "..InflictorOwner:Nick().." ("..InflictorOwner:SteamID()..")"
			else
				InflictorName = InflictorModel
			end
		else
			InflictorName = InflictorModel
		end
	end
end

local function HBDamageLogsPost(tgt, att, hlr, dmg)
	if not hb_damagelogs_enable:GetBool() then return end
	if dmg < hb_damagelogs_damagethreshold:GetInt() then return end
	local LogTime = CurTime()
	local DamageDealt = tostring(math.Round(dmg))
	local TargetName = ""
	local AttackerName = ""
	local All = 1
	local AdminOnly = 2
	local SuperAdminOnly = 3
	
	if tgt:SteamID64() == LastTarget and tostring(att) == LastAttacker then
		if LogTime ~= LastLogTime then
			if LogTime < LastLogTime + hb_damagelogs_cooldowntime:GetFloat() then
				LastLogTime = LastLogTime + 0.01
				return
			end
		end
	else
		LastTarget = tgt:SteamID64()
		LastAttacker = tostring(att)
	end
	if LogTime ~= LastLogTime then
		if LogTime < LastLogTime + hb_damagelogs_cooldowntime:GetFloat() then
			return
		else
			LastLogTime = CurTime()
		end
	end
	
	TargetName = tgt:Nick().." ("..tgt:SteamID()..")"
	if att:IsPlayer() then
		AttackerName = att:Nick().." ("..att:SteamID()..")"
	elseif (CPPI) then
		local AttackerOwner = ents.GetByIndex(att:EntIndex()):CPPIGetOwner()
		
		if IsValid(AttackerOwner) then
			AttackerName = att:GetClass().." ("..att:EntIndex()..") - Owned by "..AttackerOwner:Nick().." ("..AttackerOwner:SteamID()..")"
		else
			AttackerName = att:GetClass().." ("..att:EntIndex()..")"
		end
	else
		AttackerName = att:GetClass().." ("..att:EntIndex()..")"
	end
	
	--ServerLog(TargetName.." received damage from "..AttackerName.." via "..InflictorName.." inflicting "..DamageDealt.." damage!\n")
	if hb_damagelogs_printmode:GetBool() then
		MsgC(Color(102, 255, 102), TargetName, Color(255, 255, 255), " received damage from ", Color(255, 102, 102), AttackerName, Color(255, 255, 255), " via ", Color(255, 255, 102), InflictorName, Color(255, 255, 255), " inflicting ", Color(255, 255, 102), DamageDealt.." damage!\n")
	end
	
	local function ClientPrintSend(tgt)
		net.Start("hb_damagelogs_printsend")
			net.WriteString(TargetName)
			net.WriteString(AttackerName)
			net.WriteString(InflictorName)
			net.WriteFloat(dmg)
		if tgt == All then
			net.Broadcast()
		else
			for k, v in pairs(player.GetAll()) do
				if tgt == AdminOnly then
					if v:IsSuperAdmin() or v:IsAdmin() then
						net.Send(v)
					end
				elseif tgt == SuperAdminOnly then
					if v:IsSuperAdmin() then
						net.Send(v)
					end
				end
			end
		end
	end
	
	if hb_damagelogs_printmode_cl:GetInt() == All then
		ClientPrintSend(All)
	elseif hb_damagelogs_printmode_cl:GetInt() == AdminOnly then
		ClientPrintSend(AdminOnly)
	elseif hb_damagelogs_printmode_cl:GetInt() == SuperAdminOnly then
		ClientPrintSend(SuperAdminOnly)
	end
end

hook.Add("EntityTakeDamage", "HBDamageLogsPre", HBDamageLogsPre)
hook.Add("PlayerHurt", "HBDamageLogsPost", HBDamageLogsPost)