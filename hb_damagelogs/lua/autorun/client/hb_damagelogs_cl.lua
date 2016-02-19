net.Receive("hb_damagelogs_printsend", function(len, ply)
	local TargetName = net.ReadString()
	local AttackerName = net.ReadString()
	local InflictorName = net.ReadString()
	local DamageDealt = net.ReadFloat()
	
	MsgC(Color(102, 255, 102), TargetName, Color(255, 255, 255), " received damage from ", Color(255, 102, 102), AttackerName, Color(255, 255, 255), " via ", Color(255, 255, 102), InflictorName, Color(255, 255, 255), " inflicting ", Color(255, 255, 102), DamageDealt.." damage!\n")
end)