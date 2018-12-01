#include <sourcemod>

public Plugin:myinfo = 
{
	name = "Adverts",
	author = "2389736818",
	description = "Display Advertising",
	version = "1.1",
	url = "http://sourcemod.net/"
};

new Handle:KV,
	Handle:adverts_delay,
	Handle:adverts_timer,
	Handle:mp_friendlyfire;

public OnPluginStart()
{
	adverts_delay = CreateConVar("adverts_delay", "60");
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	RegServerCmd("adverts_reload", adverts_reload);
	LoadAdverts();
}

public Action:ShowAdvert_Timer(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ShowAdvert();
			adverts_timer = CreateTimer(GetConVarFloat(adverts_delay), ShowAdvert_Timer);
			return;
		}
	}
	adverts_timer = INVALID_HANDLE;
}

ShowAdvert()
{
	decl String:text[250];
	KvGetString(KV, "text", text, 250);
	if (StrContains(text, "{FRAGPLAYER}") != -1)
	{
		new FRAGPLAYER = FindFRAGPLAYER();
		if (FRAGPLAYER > 0)
		{
			decl String:x_str[65];
			Format(x_str, 65, "%N (Frags: %d)", FRAGPLAYER, GetClientFrags(FRAGPLAYER));
			ReplaceString(text, 250, "{FRAGPLAYER}", x_str);
		}
		else
		{
			SetNextKey();
			return;
		}
	}
	if (StrContains(text, "{CASHPLAYER}") != -1)
	{
		new CASHPLAYER = FindCASHPLAYER();
		if (CASHPLAYER > 0)
		{
			decl String:x_str[65];
			Format(x_str, 65, "%N ($%d)", CASHPLAYER, GetEntProp(CASHPLAYER, Prop_Send, "m_iAccount"));
			ReplaceString(text, 250, "{CASHPLAYER}", x_str);
		}
		else
		{
			SetNextKey();
			return;
		}
	}
	if (StrContains(text, "{HURTPLAYER}") != -1)
	{
		new HURTPLAYER = FindHURTPLAYER();
		if (HURTPLAYER > 0)
		{
			decl String:x_str[65];
			Format(x_str, 65, "%N (%d hp)", HURTPLAYER, GetClientHealth(HURTPLAYER));
			ReplaceString(text, 250, "{HURTPLAYER}", x_str);
		}
		else
		{
			SetNextKey();
			return;
		}
	}
	if (StrContains(text, "{FF}") != -1)
	{
		if (GetConVarInt(mp_friendlyfire) == 1) ReplaceString(text, 250, "{FF}", "ДА");
		else ReplaceString(text, 250, "{FF}", "НЕТ");
	}
	if (StrContains(text, "{CURRENTMAP}") != -1)
	{
		decl String:map[75];
		GetCurrentMap(map, 75);
		ReplaceString(text, 250, "{CURRENTMAP}", map);
	}
	if (StrContains(text, "{PLAYERS}") != -1)
	{
		decl String:str_players[5];
		IntToString(GetClientCount(), str_players, 5);
		ReplaceString(text, 250, "{PLAYERS}", str_players);
	}
	if (StrContains(text, "{TIMELEFT}") != -1)
	{
		new timeleft;
		if (GetMapTimeLeft(timeleft) && timeleft > 0)
		{
			decl String:x_str[20];
			Format(x_str, 20, "%d:%02d", timeleft / 60, timeleft % 60);
			ReplaceString(text, 250, "{TIMELEFT}", x_str);
		}
		else ReplaceString(text, 250, "{TIMELEFT}", "0");
	}
	new type = KvGetNum(KV, "type");
	if (type == 2) PrintHintTextToAll(text);
	else if (type == 3) PrintCenterTextAll(text);
	else
	{
		ReplaceString(text, 250, "{DEFAULT}", "\x01");
		ReplaceString(text, 250, "{GREEN}", "\x04");
		ReplaceString(text, 250, "{LIGHTGREEN}", "\x03");
		ReplaceString(text, 250, "{DARKGREEN}", "\x05");
		PrintToChatAll(text);
	}
	SetNextKey(false);
}

SetNextKey(bool:show_advert = true)
{
	if (!KvGotoNextKey(KV))
	{
		KvRewind(KV);
		KvGotoFirstSubKey(KV);
	}
	if (show_advert) ShowAdvert();
}

FindFRAGPLAYER()
{
	new x = 0, best_client = 0, best_value;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (best_value = GetClientFrags(i)) > x)
		{
			x = best_value;
			best_client = i;
		}
	}
	return best_client;
}

FindCASHPLAYER()
{
	new x = 800, best_client = 0, best_value;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (best_value = GetEntProp(i, Prop_Send, "m_iAccount")) > x)
		{
			x = best_value;
			best_client = i;
		}
	}
	return best_client;
}

FindHURTPLAYER()
{
	new x = 100, best_client = 0, best_value;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && (best_value = GetClientHealth(i)) < x)
		{
			x = best_value;
			best_client = i;
		}
	}
	return best_client;
}

public OnClientPutInServer(client)
{
	if (adverts_timer == INVALID_HANDLE) adverts_timer = CreateTimer(GetConVarFloat(adverts_delay), ShowAdvert_Timer);
}

public Action:adverts_reload(args)
{
	if (args == 0)
	{
		if (LoadAdverts()) PrintToServer("[Advert] Plug-in successfully restarted!");
		else PrintToServer("[Advert] Error");
	}
	return Plugin_Handled;
}

bool:LoadAdverts()
{
	if (adverts_timer != INVALID_HANDLE)
	{
		KillTimer(adverts_timer);
		adverts_timer = INVALID_HANDLE;
	}
	if (KV != INVALID_HANDLE) CloseHandle(KV);
	KV = CreateKeyValues("adverts");
	if (!FileToKeyValues(KV, "cfg/adverts.txt") || !KvGotoFirstSubKey(KV))
	{
		CloseHandle(KV);
		SetFailState("Problem in cfg/adverts.txt");
		return false;
	}
	adverts_timer = CreateTimer(3.0, ShowAdvert_Timer);
	return true;
}
