#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

public Plugin myinfo =
{
	name = "Instagib test",
	author = "Neidermeyer",
	description = "Quake3-style instagib mode with magjumps and coloured trails",
	version = "1.0",
	//url = ""
};

new Handle:iGib;
new Handle:iTrace;
new Handle:MagJump;
new Handle:MagJumpMult;
new Handle:clTraceR;
new Handle:clTraceG;
new Handle:clTraceB;

new g_modelLaser;

new activeoffset;
new clipoffset;

public OnMapStart()
{
	g_modelLaser = PrecacheModel("sprites/laser.vmt");
	if (GetConVarInt(iGib) == 1){
		CreateTimer(0.1, startInstagib);  
	}  
}  

public void OnPluginStart()
{
	iGib = CreateConVar("instagib", "0", "Instagib mode on/off");
	iTrace = CreateConVar("instagib_tracers", "1", "Instagib tracers on/off");
	MagJump = CreateConVar("instagib_magjump", "1", "Instagib magnum jumps on/off");
	MagJumpMult = CreateConVar("instagib_magjump_mult", "2.9999999", "Instagib magnum jump force multiplier");
	RegAdminCmd("instagib", instagibCmd, ADMFLAG_CHANGEMAP, "Instagib mode on/off");
	RegConsoleCmd("tracers", tracersColor);
	RegConsoleCmd("ent_remove_all", dontRunOnClient);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start", Event_GameStart);
	HookConVarChange(iGib, instagibToggle);
	
	//Cookies
	clTraceR = RegClientCookie("Instagib tracer R", "Red component for tracer", CookieAccess_Public); 
	clTraceG = RegClientCookie("Instagib tracer G", "Green component for tracer", CookieAccess_Public);
	clTraceB = RegClientCookie("Instagib tracer B", "Blue component for tracer", CookieAccess_Public);
	SetCookieMenuItem(customisationMenu, 0, "Instagib tracers customisation"); 
	
	activeoffset = FindSendPropInfo("CAI_BaseNPC", "m_hActiveWeapon");
	clipoffset = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
}

public Action tracersColor(int player, int args)
{
	if (GetConVarInt(iGib) == 1){
		char arg[128];
		if (args != 3)
		{
			ReplyToCommand(player, "Example: !tracers 0 255 255");	
		}	
		else
		{
			new intarg;
			decl String:color[3][4];
			for (int i=1; i<=args; i++)
			{
				GetCmdArg(i, arg, sizeof(arg));
				intarg = StringToInt(arg);
				if (intarg >= 0 || intarg <= 255){
					strcopy(color[i-1], 4, arg);		
				}
				else
				{
					color[i] = "0"
				}
			}
			if (StringToInt(color[0]) + StringToInt(color[1]) + StringToInt(color[2]) < 255){
				PrintToChat(player, "R+G+B has to be > 255");
			} 
			else
			{
				SetClientCookie(player, clTraceR, color[0]);
				SetClientCookie(player, clTraceG, color[1]);
				SetClientCookie(player, clTraceB, color[2]);
			}
		}
	}
	return Plugin_Handled;
	
}

public customisationMenu(client, CookieMenuAction:action, any:info, String:sBuffer[], iBufferSize){
	new Handle:colormenu = CreateMenu(colorMenuHandler);
	AddMenuItem(colormenu, "0", "Set Red to 255");
	AddMenuItem(colormenu, "1", "Set Green to 255");
	AddMenuItem(colormenu, "2", "Set Blue to 255");	
	AddMenuItem(colormenu, "3", "Set Red to 0");
	AddMenuItem(colormenu, "4", "Set Green to 0");
	AddMenuItem(colormenu, "5", "Set Blue to 0");	
	AddMenuItem(colormenu, "6", "Set Red to 128");
	AddMenuItem(colormenu, "7", "Set Green to 128");
	AddMenuItem(colormenu, "8", "Set Blue to 128");
	AddMenuItem(colormenu, "9", "+25 to Red");
	AddMenuItem(colormenu, "10", "+25 to Green");
	AddMenuItem(colormenu, "11", "+25 to Blue");
	AddMenuItem(colormenu, "12", "-25 to Red");
	AddMenuItem(colormenu, "13", "-25 to Green");
	AddMenuItem(colormenu, "14", "-25 to Blue");
	DisplayMenu(colormenu, client, MENU_TIME_FOREVER);
}

public colorMenuHandler(Handle:colormenu, MenuAction:action, player, item){
	if (action == MenuAction_Select) {
		new act, clr;  //These variables define colour component and action on it
		decl String:preference[3];
		GetMenuItem(colormenu, item, preference, sizeof(preference));
		act = RoundToFloor(StringToFloat(preference) / 3.0);
		clr = StringToInt(preference) - act * 3 
		decl String:color[3][4];
		GetClientCookie(player, clTraceR, color[0], 4);
		GetClientCookie(player, clTraceG, color[1], 4);
		GetClientCookie(player, clTraceB, color[2], 4);
		switch (act)
		{
			case 0:
			{
				color[clr] = "255";
			}
			case 1:
			{
				color[clr] = "0";
			}
			case 2:
			{
				color[clr] = "128";	
			}
			case 3:
			{	
				IntToString(StringToInt(color[clr]) > 230 ? 255 : StringToInt(color[clr]) + 25, color[clr], sizeof(color[]));	
			}	
			case 4:
			{	
				IntToString(StringToInt(color[clr]) < 25 ? 0 : StringToInt(color[clr]) - 25, color[clr], sizeof(color[]));	
			}				
		}
		if (StringToInt(color[0]) + StringToInt(color[1]) + StringToInt(color[2]) < 255){
			PrintToChat(player, "R+G+B has to be > 255");
		} 
		else
		{
			SetClientCookie(player, clTraceR, color[0]);
			SetClientCookie(player, clTraceG, color[1]);
			SetClientCookie(player, clTraceB, color[2]);
		}
	}
	else if (action == MenuAction_End) {
		CloseHandle(colormenu);
	}	
}

public Action:dontRunOnClient(client, args)
{
	if (GetConVarInt(iGib) == 1 && client > 0){
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action instagibCmd(int client, int args)
{
	if (GetConVarInt(iGib) == 0){
		SetConVarInt(iGib, 1)
	}
	else
	{
		SetConVarInt(iGib, 0)	
	}
	return Plugin_Handled;
}

public OnClientPutInServer(client){
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_FireBulletsPost, FireBulletsPost);
    if (GetConVarInt(iGib) == 1){
		CreateTimer(60.0, tellAboutTracers, GetClientSerial(client));	
	}
}

public Action tellAboutTracers(Handle timer, any serial){
	int client = GetClientFromSerial(serial); 
	if (client == 0) 
	{
		return Plugin_Stop;
	}
	PrintToChat(GetClientFromSerial(serial), "Use !settings or !tracers to set your 357 tracers colour");
	return Plugin_Stop; 
}

public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{   
	if (GetConVarInt(iGib) == 1){
		if(damage > 74)
		{
			damage = 255.0;
			return Plugin_Changed;
		}  
		else
		{
			damage = 0.0;
			return Plugin_Changed;	
		}
	}
	return Plugin_Continue;
}

public void FireBulletsPost(player, shots,  String:weaponname[])
{
	if (GetConVarInt(iGib) == 1){
		new gun	= GetEntDataEnt2(player, activeoffset);		//Infinite ammo
		SetEntData(gun, clipoffset, 6, 4, true);
		
		//Tracer and energy splashes
		decl color[4] = {255, 0, 0, 86};
		
		decl Float:eyePos[3];
		decl Float:eyeAngl[3];
		decl Float:endPos[3];
		decl Float:splashNorm[3];
		GetClientEyePosition(player, eyePos); 
		GetClientEyeAngles(player, eyeAngl);
		
		TR_TraceRayFilter(eyePos, eyeAngl, MASK_SHOT, RayType_Infinite,  TraceEntityFilterPlayer, player);
		eyePos[2] -= 7.0;			
		if(TR_DidHit(INVALID_HANDLE))
		{
			TR_GetEndPosition(endPos, INVALID_HANDLE);
		}
		TR_GetPlaneNormal(INVALID_HANDLE, splashNorm);
		if (GetConVarInt(iTrace) == 1){	
			//Client settings for tracers
			if (AreClientCookiesCached(player)){	
				decl String:clcolor[3][4];				
				GetClientCookie(player, clTraceR, clcolor[0], 4);
				GetClientCookie(player, clTraceG, clcolor[1], 4);
				GetClientCookie(player, clTraceB, clcolor[2], 4);
				//If cookies don't have stored colour yet
				if (StrEqual(clcolor[0], "") || StrEqual(clcolor[1], "") || StrEqual(clcolor[2], "")) {
					SetClientCookie(player, clTraceR, "0");
					SetClientCookie(player, clTraceG, "255");
					SetClientCookie(player, clTraceB, "0");
					clcolor[0] = "0";	
					clcolor[1] = "255";
					clcolor[2] = "0";
				}
				color[0] = StringToInt(clcolor[0]);
				color[1] = StringToInt(clcolor[1]);
				color[2] = StringToInt(clcolor[2]);	
				
				if (color[0] + color[1] + color[2] < 255){
					color[1] = 255; 
					SetClientCookie(player, clTraceG, "255");
					PrintToChat(player, "R+G+B has to be > 255");
				} 	
			}	
			TE_SetupBeamPoints(eyePos, endPos, g_modelLaser, 0, 0, 5, 1.0, 15.0, 15.0, 1, 0.0, color, 64); 
			TE_SendToAll(0.0); 	
		}	
		TE_SetupEnergySplash(endPos, splashNorm, true);
		TE_SendToAll(0.0); 	
		
		//MagJumps
		if (GetConVarInt(MagJump) == 1){
			new Float:maxRadius = 200.0;
			decl Float:shotDir[3];
			decl Float:PlrSpeed[3];
			MakeVectorFromPoints(endPos, eyePos, shotDir);
			new Float:dist = GetVectorLength(shotDir, false);
			if (dist < maxRadius){
				new Float:scale = (maxRadius - dist)*GetConVarInt(MagJumpMult);
				NormalizeVector(shotDir,shotDir);
				ScaleVector(shotDir, scale);
				//Increasing horizontal components
				shotDir[0] *= 1.25;
				shotDir[1] *= 1.25;
				GetEntPropVector(player, Prop_Data, "m_vecVelocity", PlrSpeed);
				AddVectors(shotDir, PlrSpeed, PlrSpeed);
				TeleportEntity(player, NULL_VECTOR, NULL_VECTOR, PlrSpeed);
			} 
		}		
	}
}

public bool:TraceEntityFilterPlayer(entity, contentsMask, any:data)  
{ 
	return entity > MaxClients; 
}

public Action give357(Handle timer, any serial)
{
	GivePlayerItem(GetClientFromSerial(serial), "weapon_357");
	FakeClientCommand(GetClientFromSerial(serial), "use weapon_357");
	return Plugin_Stop;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(iGib) == 1){
		int player = GetClientOfUserId(GetEventInt(event, "userid"));
		CreateTimer(0.2, give357, GetClientSerial(player));
		ServerCommand("ent_remove_all weapon_smg1");  
		ServerCommand("ent_remove_all weapon_pistol");
		ServerCommand("ent_remove_all weapon_crowbar"); 
		ServerCommand("ent_remove_all weapon_stunstick"); 
		ServerCommand("ent_remove_all weapon_frag");
	}
}

public void Event_GameStart(Event event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(iGib) == 1){
		CreateTimer(0.1, startInstagib);
	}	
}

public instagibToggle(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if (StringToInt(newVal) == 1)
	{
		PrintToChatAll("Instagib mode is on");
		ServerCommand("mp_restartgame 3");	
		if (GetCommandFlags("ent_remove_all") > 4){
			SetCommandFlags("ent_remove_all", GetCommandFlags("ent_remove_all")^FCVAR_CHEAT);
		}
	}
	if (StringToInt(newVal) == 0)
	{
		PrintToChatAll("Instagib mode is off");
		ServerCommand("mp_restartgame 3");
		SetCommandFlags("ent_remove_all", GetCommandFlags("ent_remove_all")|FCVAR_CHEAT);	 	
	}
}

public Action startInstagib(Handle timer)
{
	ServerCommand("ent_remove_all weapon_smg1");  
	ServerCommand("ent_remove_all weapon_pistol");
	ServerCommand("ent_remove_all weapon_crowbar"); 
	ServerCommand("ent_remove_all weapon_stunstick"); 
	ServerCommand("ent_remove_all weapon_frag");
	ServerCommand("ent_remove_all weapon_ar2"); 
	ServerCommand("ent_remove_all weapon_shotgun");
	ServerCommand("ent_remove_all weapon_rpg");
	ServerCommand("ent_remove_all weapon_crossbow"); 
	ServerCommand("ent_remove_all weapon_357");   
	ServerCommand("ent_remove_all weapon_slam"); 
	
	ServerCommand("ent_remove_all item_ammo_357");      
	ServerCommand("ent_remove_all item_ammo_357_large");
	ServerCommand("ent_remove_all item_ammo_ar2"); 
	ServerCommand("ent_remove_all item_ammo_ar2_large");  
	ServerCommand("ent_remove_all item_ammo_ar2_altfire");  
	ServerCommand("ent_remove_all item_ammo_crate");  
	ServerCommand("ent_remove_all item_ammo_crossbow");  
	ServerCommand("ent_remove_all item_ammo_pistol");  
	ServerCommand("ent_remove_all item_ammo_pistol_large"); 
	ServerCommand("ent_remove_all item_ammo_smg1");
	ServerCommand("ent_remove_all item_ammo_smg1_large");
	ServerCommand("ent_remove_all item_ammo_smg1_grenade"); 
	ServerCommand("ent_remove_all item_box_buckshot");
	ServerCommand("ent_remove_all item_ammo_rpg_round"); 
	
	ServerCommand("ent_remove_all item_healthkit");
	ServerCommand("ent_remove_all item_healthvial");
	ServerCommand("ent_remove_all item_healthcharger");
	ServerCommand("ent_remove_all item_suitcharger");
	ServerCommand("ent_remove_all item_battery");
	
	return Plugin_Stop; 
}
