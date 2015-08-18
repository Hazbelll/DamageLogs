CreateConVar("hb_damagelogs_enable", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies whether Damage Logs are enabled or not [Realm: Serverside | Type: Boolean | Min Value: 0 | Max Value: 1 | Default Value: 1]")
CreateConVar("hb_damagelogs_printmode", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies whether to print damage logs to console or not [Realm: Serverside | Type: Boolean | Min Value: 0 | Max Value: 1 | Default Value: 0]")
CreateConVar("hb_damagelogs_printmode_cl", 2, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies whether to print damage logs to client console or not - 0: Disabled | 1: Everyone | 2: Admin+ only | 3: SuperAdmin only+ [Realm: Serverside | Type: Integer | Min Value: 0 | Max Value: 3 | Default Value: 2]")
CreateConVar("hb_damagelogs_cooldowntime", 0.25, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies the minimum amount of time required after a damage log before another can be triggered [Realm: Serverside | Type: Float | Min Value: 0 | Max Value: Inf | Default Value: 0.25]")
CreateConVar("hb_damagelogs_damagethreshold", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, "Specifies the minimum amount of damage inflicted required to trigger a log [Realm: Serverside | Type: Integer | Min Value: 1 | Max Value: Inf | Default Value: 1]")

util.AddNetworkString("hb_damagelogs_printsend")

local hb_damagelogs_enable = GetConVar("hb_damagelogs_enable")
local hb_damagelogs_printmode = GetConVar("hb_damagelogs_printmode")
local hb_damagelogs_printmode_cl = GetConVar("hb_damagelogs_printmode_cl")
local hb_damagelogs_cooldowntime = GetConVar("hb_damagelogs_cooldowntime")
local hb_damagelogs_damagethreshold = GetConVar("hb_damagelogs_damagethreshold")

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
	
	if Inflictor:IsPlayer() or Inflictor:IsNPC() then
		local InflictorActiveWeapon = Inflictor:GetActiveWeapon()
		if IsValid(InflictorActiveWeapon) then
			InflictorName = InflictorActiveWeapon:GetClass()
		else
			InflictorName = "a unknown weapon"
		end
	else
		if Attacker:IsPlayer() or Attacker:IsNPC() then
			InflictorName = Inflictor:GetClass()
		else
			local InflictorModel = string.GetFileFromFilename(Inflictor:GetModel() or "")
			
			if InflictorModel == "" then
				InflictorName = "a unknown weapon"
			else
				if (CPPI) then
					local InflictorOwner = ents.GetByIndex(Inflictor:EntIndex()):CPPIGetOwner()
					
					if IsValid(InflictorOwner) then
						InflictorName = InflictorModel.." owned by "..InflictorOwner:Nick().." ("..InflictorOwner:SteamID()..")"
					else
						InflictorName = InflictorModel
					end
				else
					InflictorName = InflictorModel
				end
			end
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
	else
		if (CPPI) then
			local AttackerOwner = ents.GetByIndex(att:EntIndex()):CPPIGetOwner()
			
			if IsValid(AttackerOwner) then
				AttackerName = att:GetClass().." ("..att:EntIndex()..") owned by "..AttackerOwner:Nick().." ("..AttackerOwner:SteamID()..")"
			else
				AttackerName = att:GetClass().." ("..att:EntIndex()..")"
			end
		else
			AttackerName = att:GetClass().." ("..att:EntIndex()..")"
		end
	end
	
	ServerLog(TargetName.." received damage from "..AttackerName.." via "..InflictorName.." inflicting "..DamageDealt.." damage!\n")
	if hb_damagelogs_printmode:GetBool() then
		MsgC(Color(255, 97, 247), "[Damage Log] ", Color(102, 255, 102), TargetName, Color(255, 255, 255), " received damage from ", Color(255, 102, 102), AttackerName, Color(255, 255, 255), " via ", Color(255, 255, 102), InflictorName, Color(255, 255, 255), " inflicting ", Color(102, 102, 255), DamageDealt.." damage!\n")
	end
	if hb_damagelogs_printmode_cl:GetInt() == 1 then
		net.Start("hb_damagelogs_printsend")
			net.WriteString(TargetName)
			net.WriteString(AttackerName)
			net.WriteString(InflictorName)
			net.WriteFloat(dmg)
		net.Broadcast()
	elseif hb_damagelogs_printmode_cl:GetInt() == 2 then
		for k, v in pairs(player.GetAll()) do
			if v:IsSuperAdmin() or v:IsAdmin() then
				net.Start("hb_damagelogs_printsend")
					net.WriteString(TargetName)
					net.WriteString(AttackerName)
					net.WriteString(InflictorName)
					net.WriteFloat(dmg)
				net.Send(v)
			end
		end
	elseif hb_damagelogs_printmode_cl:GetInt() == 3 then
		for k, v in pairs(player.GetAll()) do
			if v:IsSuperAdmin() then
				net.Start("hb_damagelogs_printsend")
					net.WriteString(TargetName)
					net.WriteString(AttackerName)
					net.WriteString(InflictorName)
					net.WriteFloat(dmg)
				net.Send(v)
			end
		end
	end
end

hook.Add("EntityTakeDamage", "HBDamageLogsPre", HBDamageLogsPre)
hook.Add("PlayerHurt", "HBDamageLogsPost", HBDamageLogsPost)