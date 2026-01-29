/**
*Tag protection Plugin
*
* by InstantDeath
*customizable flag
*setable ban time
*add or remove tags from in game
*kick or ban option + in game
*
* 
* 
* sm_addtag
* sm_removetag
* sm_tagcfg
*/

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.4.0"

#define RED 0
#define GREEN 255
#define BLUE 0
#define ALPHA 255

#define ADMFLAG_TAGPROT ADMFLAG_CUSTOM1

Handle tagfile;
Handle tagwarntime;
Handle tagKicktimer[MAXPLAYERS+1];
Handle tagfileloc;
char taglistfile[PLATFORM_MAX_PATH];
char fileloc[255];
bool tagfile_exist = false;
bool kicktimerActive[MAXPLAYERS+1];
bool StillHasTag[MAXPLAYERS+1];
char WearingTag[255];
bool ClientisReady[MAXPLAYERS+1];
float gTimeLeft[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "Tag Protection",
	author = "InstantDeath",
	description = "Prevents unwanted tag usage in names.",
	version = PLUGIN_VERSION,
	url = "http://www.xpgaming.net"
};

public void OnPluginStart()
{
	CreateConVar("sm_tagprotection_version", PLUGIN_VERSION, "Tag Protection Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	tagfileloc = CreateConVar("sm_tagcfg" , "configs/taglist.cfg" , "File to load and save tags.", FCVAR_PLUGIN);
	tagwarntime = CreateConVar("sm_tagwarntime" , "60.0" , "Time in seconds to warn player that he has an invalid tag", FCVAR_PLUGIN);
	RegAdminCmd("sm_addtag", Command_AddTag, ADMFLAG_BAN, "[SM] Add tags to the list. Usage: sm_addtag <tag> (time for ban, -1 for kick)");
	RegAdminCmd("sm_removetag", Command_RemoveTag, ADMFLAG_BAN, "[SM] Removes the specified tag from the list. Usage: sm_removetag <tag>");
	
	AutoExecConfig(true);
}
public void OnMapStart()
{
	GetConVarString(tagfileloc, fileloc, sizeof(fileloc));
	BuildPath(Path_SM,taglistfile,sizeof(taglistfile), fileloc);
	tagfile = CreateKeyValues("taglist");
	FileToKeyValues(tagfile,taglistfile);
	if(!FileExists(taglistfile)) 
	{
		LogMessage("[SM] taglist.cfg not parsed...file doesnt exist!");
		SetFailState("[SM] taglist.cfg not parsed...file doesnt exist! Please install the plugin correctly...");
		tagfile_exist = false;
	}
	else
	{
		tagfile_exist = true;
	}
}

public Action Command_AddTag(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addtag <tag> (time for ban, -1 for kick)");
		return Plugin_Handled;
	}
	char tag[64];
	char kbtime[32];
	int time;
	
	GetCmdArg(1, tag, sizeof(tag));
	GetCmdArg(2, kbtime, sizeof(kbtime));
	
	if(tagExistCheck(tag) == 1)
	{
		PrintToConsole(client, "[SM] This tag already exists!");
		return Plugin_Handled;
	}
	time = StringToInt(kbtime);
		
	KvRewind(tagfile);
	KvJumpToKey(tagfile, tag, true);
	KvSetNum(tagfile, "time", time);
	if(tagExistCheck(tag) == 1)
	{
		PrintToConsole(client, "[SM] '%s' tag was successfully added. This will not take effect until the map changes.", tag);
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action Command_RemoveTag(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_removetag <tag>");
		return Plugin_Handled;
	}
	char Arguments[256];
	
	GetCmdArgString(Arguments, sizeof(Arguments));
		
	if(tagExistCheck(Arguments) == 1)
	{
	
		KvRewind(tagfile);
		KvJumpToKey(tagfile, Arguments, false);
		KvDeleteThis(tagfile);
		if(tagExistCheck(Arguments) == 0)
		{
			PrintToConsole(client, "[SM] The tag was successfully removed.");
			return Plugin_Handled;
		}
		else
			PrintToConsole(client, "[SM] The tag could not be found.");
	}
	return Plugin_Handled;
}

public void OnClientDisonnect(int client)
{
	ClientisReady[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	ClientisReady[client] = true;
}
public void OnMapEnd()
{
	KvRewind(tagfile);
	KeyValuesToFile(tagfile, taglistfile);
	CloseHandle(tagfile);
}

public void OnClientPutInServer(int client)
{
	StillHasTag[client] = true;
}

public void OnClientSettingsChanged(int client)
{
	if(!IsFakeClient(client) && ClientisReady[client])
	{
		if(client != 0 && IsClientInGame(client))
		{
			if(tagfile_exist)
				tagCheckChange(client);
		}
	}
}

public Action tagCheckChange(int client)
{	
	char clientName[64];
	char buffer[255];
	int time;
	int clientid = GetClientUserId(client);
	GetClientName(client,clientName,64);
	gTimeLeft[client] = GetConVarFloat(tagwarntime);
	int kicktime = FloatToInt(gTimeLeft[client]);
	
	KvRewind(tagfile);
	KvGotoFirstSubKey(tagfile);
	int flags = GetUserFlagBits(client);
	
	//timer is still active, but player has removed illegal tag
	if(kicktimerActive[client] && !StillHasTag[client])
	{
		PrintToChat(client,"[SM] Thank you for removing the %s tag", WearingTag);
		//KillTimer(tagKicktimer, false);
		kicktimerActive[client] = false;
	}
	
	do{
		KvGetSectionName(tagfile, buffer, sizeof(buffer));
		if (StrContains(clientName, buffer,false) != -1)
		{
			WearingTag = buffer;
			time = KvGetNum(tagfile, "time");
			if(time == -1)
			{
				//timer is active, we dont need to start the timer again
				if(!kicktimerActive[client] && IsClientInGame(client))
				{
					if(flags & ADMFLAG_TAGPROT || flags & ADMFLAG_ROOT)
					{
						return Plugin_Handled;
					}
					else 
					{				
						tagKicktimer[client] = CreateTimer(1.0, OnTagKick, client, TIMER_REPEAT);
						//TriggerTimer(tagKicktimer, true);
						kicktimerActive[client] = true;
						StillHasTag[client] = true;
						PrintToChat(client, "[SM] \x04You are not allowed to wear the '%s\x04' tag.", buffer);
						PrintToChat(client, "[SM] \x04You will be kicked in %d\x04 seconds if it is not removed", kicktime);
						return Plugin_Handled;
					}
				}
				
			}
			if(time > -1)
			{
				char bName[64];
				char bAuth[64];
				GetClientName(client, bName, sizeof(bName));
				GetClientAuthId(client, AuthId_Steam2, bAuth, sizeof(bAuth));
				ServerCommand("sm_ban #%d %d Illegal tag", clientid, time);
				LogMessage("[SM] Banned Player %s for illegal tag, SteamID: %s", bName, bAuth);
				return Plugin_Handled;
			}
				
		}
		else if (StrContains(clientName, buffer,false) == -1)
		{
			StillHasTag[client] = false;
		}
	} while (KvGotoNextKey(tagfile));
		
	return Plugin_Handled;
}

public Action OnTagKick(Handle timer, any index)
{
	int time = FloatToInt(GetConVarFloat(tagwarntime)/2);
	int time2 = FloatToInt(GetConVarFloat(tagwarntime)/4);
	//PrintToChatAll("time left to kick: %f", gTimeLeft[index]);
	if(GetConVarFloat(tagwarntime)/2 == gTimeLeft[index])
	{
		PrintToChat(index, "\x01\x04[SM] You will be kicked in %d seconds if it is not removed", time);
		
	}
	if(GetConVarFloat(tagwarntime)/4 == gTimeLeft[index])
	{
		PrintToChat(index, "\x01\x04[SM] You will be kicked in %d seconds if it is not removed", time2);
	}
	if(gTimeLeft[index] == 10)
	{
		PrintToChat(index, "\x01\x04[SM] You will be kicked in %d seconds if it is not removed", 10);
	}
	if(gTimeLeft[index] == 5)
	{
		PrintToChat(index, "\x01\x04[SM] You will be kicked in %d seconds if it is not removed", 5);
	}
	if (!index || !IsClientInGame(index))
	{
		kicktimerActive[index] = false;
		return Plugin_Stop;
	}
	
	gTimeLeft[index] = gTimeLeft[index] - 1;
	
	if(gTimeLeft[index]<=0)
	{
		kicktimerActive[index] = false;
		char kName[64];
		char kAuth[64];
		GetClientName(index, kName, sizeof(kName));
		GetClientAuthId(index, AuthId_Steam2, kAuth, sizeof(kAuth));
		KickClient(index, "%s", "Illegal Tag");
		LogMessage("[SM] Kicked Player %s for illegal tag, SteamID: %s", kName, kAuth);
		return Plugin_Stop;
	}
	else if(kicktimerActive[index] == false)
		return Plugin_Stop;
		
	return Plugin_Continue;
}

public int tagExistCheck(char[] Tag)
{
	KvRewind(tagfile);
	KvGotoFirstSubKey(tagfile);
	char buffer[255];
	do{
		KvGetSectionName(tagfile, buffer, sizeof(buffer));
		if (StrContains(Tag, buffer,false) != -1)
			return 1;
		
	} while (KvGotoNextKey(tagfile));
	return 0;
}

public int FloatToInt(float num)
{
	char temp[32];
	FloatToString(num, temp, sizeof(temp));
	return StringToInt(temp);
}

public void OnPluginEnd()
{
  CloseHandle(tagfile);
}
