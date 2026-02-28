/**
 * SourceMod Plugin: Tag Protection
 * License: GNU General Public License v3.0
 */
#pragma semicolon 1
#pragma newdecls  required

#include <sourcemod>
#include <sdktools>

////////////////////////////////////////////////////////////////////////////////
//
// VARIABLES
//
////////////////////////////////////////////////////////////////////////////////

#define     PLUGIN_NAME         "Tag Protection"
#define     PLUGIN_AUTHOR       "InstantDeath, X8ETr1x"
#define     PLUGIN_VERSION      "2.0.0"
#define     PLUGIN_URL          "https://github.com/Radioactive-Gaming/sm-tag-protection"
#define     PLUGIN_DESC         "Prevents unwanted tag usage in names."
#define     STEAMID64_LENGTH    17
#define     MAXIMUM_FLAG_LENGTH 19
#define     RED                 0
#define     GREEN               255
#define     BLUE                0
#define     ALPHA               255

// CVar handles, defined in OnPluginStart().
Handle      g_CVarTagFileLoc;
Handle      g_CVarTagWarnTime;
Handle      g_CVarAdminFlag;

// Tag data.
Handle      g_TagData;                              // Key/Value pairs of tag data
char        g_TagListFile[PLATFORM_MAX_PATH];       // The path of the tag list file.
AdminFlag   g_ImmunityFlag;                         // The specified admin flag for immunity
int         g_TagWarnTime;                          // The maximum amount of time for a player to remove a tag.

// Player data.
bool        g_StillHasTag[MAXPLAYERS + 1];          // Tracks if the player still has the tag in their display name.
Handle      g_KickTimer[MAXPLAYERS + 1];            // Tracks the timer to kick a player.
bool        g_KickTimerActive[MAXPLAYERS + 1];      // Tracks the if the timer to kick a player is active.
bool        g_AdminFlagsChecked[MAXPLAYERS + 1];    // Tracks if OnClientPostAdminCheck() has completed.
bool        g_KickImmunity[MAXPLAYERS + 1];         // Tracks if a player is immune.
int         g_ServerTimeStamp[MAXPLAYERS + 1];      // Tracks the server time stamp at the time of calling a kick timer for a player.

////////////////////////////////////////////////////////////////////////////////
//
// ENUMS
//
////////////////////////////////////////////////////////////////////////////////

public Plugin myinfo = {

    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL

};

////////////////////////////////////////////////////////////////////////////////
//
// MAIN
//
////////////////////////////////////////////////////////////////////////////////

public void OnPluginStart() {

    // Set CVars
    CreateConVar("sm_tagprotection_version", PLUGIN_VERSION, "Tag Protection Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    g_CVarTagFileLoc = CreateConVar("sm_tagcfg" , "configs/taglist.cfg" , "File to load and save tags.", FCVAR_PLUGIN);
    g_CVarTagWarnTime = CreateConVar("sm_tagwarntime" , "60.0" , "Time in seconds to warn player that he has an invalid tag", FCVAR_PLUGIN);
	g_CVarAdminFlag = CreateConVar("sm_adminflag" , "Admin_Generic" , "SourceMod admin tag to grant immunity (https://sm.alliedmods.net/new-api/admin/AdminFlag)", FCVAR_PLUGIN);

	// Convert admin flag CVar to type string.
	char immunityFlagString[MAXIMUM_FLAG_LENGTH];
    GetConVarString(g_CVarAdminFlag, immunityFlagString, MAXIMUM_FLAG_LENGTH);
    int immunityFlag = ReadFlagString(immunityFlagString);

    if (immunityFlag < 0 || immunityFlag > AdminFlags_TOTAL) {

        LogMessage("[CRITICAL] OnPluginStart(): specificed admin flag is invalid. Quitting.");
        SetFailState("[CRITICAL] OnPluginStart(): specificed admin flag is invalid. Quitting.");

    }

    else if ((immunityFlag > -1) && (immunityFlag <= AdminFlags_TOTAL)) {

        BitToFlag(immunityFlag, g_ImmunityFlag);

    }

    else {

        LogMessage("[CRITICAL] OnPluginStart(): unexepcted non-integer value in 'immunityFlag' . Quitting.");
        SetFailState("[CRITICAL] OnPluginStart(): unexepected non-integer value in 'immunityFlag' . Quitting.");

    }

    // Convert warn time to type int.
    float warnTimeCVar = GetConVarFloat(g_CVarTagWarnTime);
    g_TagWarnTime = FloatToInt(warnTimeCVar);

    // Register server commands
    RegAdminCmd("sm_addtag", Command_AddTag, ADMFLAG_BAN, "[SM] Add tags to the list. Usage: sm_addtag <tag> (time for ban, -1 for kick)");
    RegAdminCmd("sm_removetag", Command_RemoveTag, ADMFLAG_BAN, "[SM] Removes the specified tag from the list. Usage: sm_removetag <tag>");

    // Execute the configuration
    AutoExecConfig(true);
    LogMessage("[INFO] Plugin loaded.");

}

public void OnMapStart() {

    // Retrieve the config file path.
    char fileLoc[PLATFORM_MAX_PATH];
    GetConVarString(g_CVarTagFileLoc, fileLoc, PLATFORM_MAX_PATH);
    BuildPath(Path_SM, g_TagListFile, PLATFORM_MAX_PATH, fileLoc);

    // Set file state.
    if (FileExists(g_TagListFile) == true) {

        // Import the config file into a KV object.
        g_TagData = CreateKeyValues("taglist");
        FileToKeyValues(g_TagData, g_TagListFile);

    }

    else if (FileExists(g_TagListFile) == false) {

        LogMessage("[CRITICAL] OnMapStart(): tag configuration list not parsed. File does not exist.");
        SetFailState("[CRITICAL] tag configuration list not parsed. File doesnt exist.");

    }

}

public void OnClientPutInServer(int client) {

    // Zero the value.
	g_StillHasTag[client] = false;

}

public void OnClientSettingsChanged(int client) {

    if (g_AdminFlagsChecked[client] == true) {

        int clientID;

        LogMessage("[DEBUG] OnClientSettingsChanged(): g_AdminFlagsChecked is true, checking tag.");

        clientID = GetClientUserId(client);
        CreateTimer(5.0, tagCheckChange, clientID);

    }

    else if (g_AdminFlagsChecked[client] == false) {

        LogMessage("[DEBUG] OnClientSettingsChanged(): g_AdminFlagsChecked is false.");

    }

    else {

        LogMessage("[ERROR] OnClientSettingsChanged(): non-boolean value in 'g_AdminFlagsChecked'.");

    }

}

public void OnClientPostAdminCheck(int client) {

	// Check for client's admin status.
	AdminId adminID = GetUserAdmin(client);

	if (adminID != INVALID_ADMIN_ID) {

		LogMessage("[DEBUG] OnClientPostAdminCheck(): client has admin Id assigned.");

        // Checks for the specified admin flag.
		bool hasAdminFlag = GetAdminFlag(adminID, g_ImmunityFlag, Access_Effective);
		bool hasRootFlag = GetAdminFlag(adminID, Admin_Root, Access_Effective);

		if(hasAdminFlag == true || hasRootFlag == true) {

			LogMessage("[DEBUG] OnClientPostAdminCheck(): client has matching immunity flag.");

            g_KickImmunity[client] = true;

		}

		else if (hasAdminFlag == false && hasRootFlag == false) {

			LogMessage("[DEBUG] OnClientPostAdminCheck(): client does not have matching immunity flag.");

            g_KickImmunity[client] = false;

		}

    }

    else if (adminID == INVALID_ADMIN_ID) {

        LogMessage("[DEBUG] OnClientPostAdminCheck(): client has no admin Id assigned.");

        g_KickImmunity[client] = false;

    }

    else {

        LogMessage("[ERROR] OnClientPostAdminCheck(): unexpected admin flag in adminID.");

        g_KickImmunity[client] = false;

    }

    LogMessage("[DEBUG] OnClientPostAdminCheck(): setting flags checked to true.");

	// Set that the admin checks have completed.
	g_AdminFlagsChecked[client] = true;

}

public void OnClientDisonnect(int client) {

	// Clear the admin checks for the client.
	g_AdminFlagsChecked[client] = false;

}

public void OnMapEnd() {

	// Overwrite the tag file with new values.
	KvRewind(g_TagData);
	KeyValuesToFile(g_TagData, g_TagListFile);
	CloseHandle(g_TagData);

}

public void OnPluginEnd() {

	// Ensure the handle is closed on termination.
	CloseHandle(g_TagData);

}

////////////////////////////////////////////////////////////////////////////////
//
// ACTIONS
//
////////////////////////////////////////////////////////////////////////////////

Action Command_AddTag(int client, int args) {

	if (args < 2) {

		ReplyToCommand(client, "[Tag Protection] Too few arguments. Usage: sm_addtag <tag> (time for ban, -1 for kick)");

		return Plugin_Handled;

	}

	else if (args == 2) {

		char tag[MAX_NAME_LENGTH];
		char kbtime[32];
		int time;

		GetCmdArg(1, tag, MAX_NAME_LENGTH);
		GetCmdArg(2, kbtime, 32);

		if (tagExistCheck(tag) == true) {

			PrintToConsole(client, "[Tag Protection] This tag already exists!");

			return Plugin_Handled;

		}

		else if (tagExistCheck(tag) == false) {

			time = StringToInt(kbtime);

			KvRewind(g_TagData);
			KvJumpToKey(g_TagData, tag, true);
			KvSetNum(g_TagData, "time", time);

			if (tagExistCheck(tag) == true) {

				PrintToConsole(client, "[Tag Protection] '%s' tag was successfully added. This will not take effect until the map changes.", tag);

				return Plugin_Handled;

			}

			else {

				PrintToConsole(client, "[Tag Protection] '%s' tag failed to be added. Ask an admin to check the server logs for errors.", tag);

				if (tagExistCheck(tag) == false) {

					return Plugin_Handled;

				}

				else {

					LogMessage("[ERROR] Command_AddTag(): non-boolean value returned from tagExistCheck().");

					return Plugin_Handled;

				}

			}

		}

		else {

				LogMessage("[ERROR] Command_AddTag(): non-boolean value returned from tagExistCheck().");

                return Plugin_Handled;

		}

    }

	else if (args > 2) {

		ReplyToCommand(client, "[Tag Protection] Too many arguments. Usage: sm_addtag <tag> (time for ban, -1 for kick)");

		return Plugin_Handled;

	}

	else {

		LogMessage("[ERROR] Command_AddTag(): unexpected non-integer value in 'args'.");

        return Plugin_Handled;

	}

}

Action Command_RemoveTag(int client, int args) {

	if (args < 1) {

		ReplyToCommand(client, "[Tag Protection] Too few arguments. Usage: sm_removetag <tag>");
		return Plugin_Handled;

	}

	else if (args == 1) {

		char tag[256];
		GetCmdArgString(tag, 256);

		if (tagExistCheck(tag) == false) {

			PrintToConsole(client, "[Tag Protection] The tag could not be found.");

			return Plugin_Handled;

		}

		else if (tagExistCheck(tag) == true) {

			KvRewind(g_TagData);
			KvJumpToKey(g_TagData, tag, false);
			KvDeleteThis(g_TagData);

			if (tagExistCheck(tag) == false) {

				PrintToConsole(client, "[Tag Protection] The tag was successfully removed.");
				return Plugin_Handled;

			}

			else {

				PrintToConsole(client, "[Tag Protection] '%s' tag failed to be removed. Ask an admin to check the server logs for errors.", tag);

				if (tagExistCheck(tag) == true) {

					return Plugin_Handled;

				}

				else {

					LogMessage("[ERROR] Command_RemoveTag(): non-boolean value returned from tagExistCheck().");

					return Plugin_Handled;

				}

			}

		}

		else {

			LogMessage("[ERROR] Command_RemoveTag(): non-boolean value returned from tagExistCheck().");

			return Plugin_Handled;

		}

	}

	else if (args > 1) {

		ReplyToCommand(client, "[Tag Protection] Too many arguments. Usage: sm_removetag <tag>");

		return Plugin_Handled;

	}

	else {

		LogMessage("[ERROR] Command_RemoveTag(): unexpected non-integer value in 'args'.");

		return Plugin_Handled;

	}

}

Action tagCheckChange(Handle timer, int clientID)  {

    // Convert clientID to client index.
    int  client;
    client = GetClientOfUserId(clientID);

    // Skip for bots.
    if (IsFakeClient(client) == false) {

        // Skip if the client is not yet in game.
        if (IsClientInGame(client) == true) {

            LogMessage("[DEBUG] tagCheckChange(): client is in game.");

            if (g_KickImmunity[client] == true) {

                LogMessage("[DEBUG] tagCheckChange(): client is immune, skipping.");

                return Plugin_Handled;

            }

            else if (g_KickImmunity[client] == false) {

                LogMessage("[DEBUG] tagCheckChange(): client is not immune.");

                int  tagMatch;
                char tag[MAX_NAME_LENGTH];
                char clientName[MAX_NAME_LENGTH];
                char steamID[STEAMID64_LENGTH];


                // Retrieve player information.
                GetClientAuthId(client, AuthId_SteamID64, steamID, STEAMID64_LENGTH);

                // Create a timer to wait for SetClientInfo or player-initiated name changes to take effect.

                GetClientName(client, clientName, MAX_NAME_LENGTH);

                // Rewind to the start of the tag data.
                KvRewind(g_TagData);
                KvGotoFirstSubKey(g_TagData);

                // Loop through each tag to find a player name match.
                do {

                    //Check if the player's name contains the tag as a substring.
                    KvGetSectionName(g_TagData, tag, MAX_NAME_LENGTH);
                    LogMessage("[DEBUG] tagCheckChange(): check for client tag %s.", tag);
                    tagMatch = StrContains(clientName, tag, false);

                    // No match is -1.
                    if (tagMatch == -1) {

                        LogMessage("[DEBUG] tagCheckChange(): no match for tag %s.", tag);
                        // Stop the timer if the player removes the tag.
                        if (g_KickTimerActive[client] == true) {

                            LogMessage("[DEBUG] tagCheckChange(): timer active, tag %s removed.", tag);
                            PrintToChat(client, "[Tag Protection] Thank you for removing the %s tag.", tag);
                            KillTimer(g_KickTimer[client]);
                            g_KickTimerActive[client] = false;

                        }

                        else if (g_KickTimerActive[client] == false) {

                            LogMessage("[DEBUG] tagCheckChange(): timer inactive.", tag);

                        }

                        return Plugin_Handled;

                    }

                    // A match will return the position of the substring, hence >= 0.
                    else if (tagMatch >= 0) {

                        LogMessage("[DEBUG] tagCheckChange(): client has tag %s.", tag);

                        // Check for an active timer to avoid conflicting timers.
                        if (g_KickTimerActive[client] == true) {

                            LogMessage("[DEBUG] tagCheckChange(): client has tag %s, but timer is already active.", tag);
                            return Plugin_Continue;

                        }

                        // Run the kick.
                        else if (g_KickTimerActive[client] == false) {

                            LogMessage("[DEBUG] tagCheckChange(): client has tag %s with no active timer.", tag);

                            g_KickTimerActive[client] = true;

                            PrintToChat(client, "\x04[Tag Protection] \x01You are not allowed to wear the '%s' tag.", tag);

                            g_ServerTimeStamp[client] = GetTime();

                            // Create the timer and pass the player information. Use a data pack to avoid client index collisions.
                            DataPack clientPack;
                            g_KickTimer[client] = CreateDataTimer(1.0, OnTagKick, clientPack, TIMER_REPEAT);
                            clientPack.WriteCell(clientID);
                            clientPack.WriteString(steamID);
                            clientPack.WriteString(clientName);
                            clientPack.WriteString(tag);

                            return Plugin_Handled;

                        }

                    }

                    else if (tagMatch < -1) {

                        LogMessage("[ERROR] tagCheckChange(): unexpected value in tagMatch: %d", tagMatch);

                        return Plugin_Stop;

                    }

                }

                while (KvGotoNextKey(g_TagData));

                LogMessage("[DEBUG] tagCheckChange(): loop completed.");

                return Plugin_Handled;

            }

            else {

                LogMessage("[ERROR] tagCheckChange(): unexpected non-boolean value in 'g_KickImmunity'.");

                return Plugin_Handled;

            }

        }

        else if (IsClientInGame(client) == false) {

            return Plugin_Handled;

        }

        else {

            LogMessage("[ERROR] tagCheckChange(): unexpected non-boolean value returned by IsClientInGame().");

            return Plugin_Handled;

        }

    }

    else if (IsFakeClient(client) == true) {

        return Plugin_Handled;

    }

    else {

        LogMessage("[ERROR] tagCheckChange(): unexpected non-boolean value returned by IsFakeClient().");

        return Plugin_Handled;

    }

}


Action OnTagKick(Handle timer, DataPack dpack) {

    /**
     * Takes a client ID and initiates a timer that will run until either the client removes the tag or is kicked/disconnects.
     *
     * params:
     *  - dpack: a datapack with the client ID and client name. Client index must never be passed to a timer as a parameter.
    */

    // Retrieve client information.
	int clientID;
    char steamID[STEAMID64_LENGTH];
    char clientName[MAX_NAME_LENGTH];
    int client;
    char tag[MAX_NAME_LENGTH];

	ResetPack(dpack);
    clientID = dpack.ReadCell();
    dpack.ReadString(steamID, STEAMID64_LENGTH);
	dpack.ReadString(clientName, MAX_NAME_LENGTH);
    dpack.ReadString(tag, MAX_NAME_LENGTH);
    client = GetClientOfUserId(clientID);


    if (client == 0) {

        LogMessage("[DEBUG] OnTagKick(): client is server, skipping...");

        return Plugin_Stop;

    }

    else if (client > 0) {

        // Retrieve the configured warning threshold time.

        static int timeRemaining = 0;
        int warn1 = g_TagWarnTime / 2;
        int warn2 = g_TagWarnTime - (g_TagWarnTime / 4);
        int warn3 = g_TagWarnTime - 10;
        int warn4 = g_TagWarnTime - 5;

        if (timeRemaining == 0) {

            PrintToChat(client, "\x04[Tag Protection] \x01You will be kicked in %d seconds if the '%s' tag is not removed", g_TagWarnTime, tag);

        }

        else if (timeRemaining == warn1) {

            PrintToChat(client, "\x04[Tag Protection] \x01You will be kicked in %d seconds if the '%s' tag is not removed", (g_TagWarnTime / 2), tag);

        }

        else if (timeRemaining == warn2) {

            PrintToChat(client, "\x04[Tag Protection] \x01You will be kicked in %d seconds if the '%s' tag is not removed", (g_TagWarnTime / 4), tag);

        }

        else if (timeRemaining == warn3) {

            PrintToChat(client, "\x04[Tag Protection] \x01You will be kicked in %d seconds if the '%s' tag is not removed", 10, tag);

        }

        else if (timeRemaining == warn4) {

            PrintToChat(client, "\x04[Tag Protection] \x01You will be kicked in %d seconds if the '%s' tag is not removed", 5, tag);

        }

        else if (timeRemaining == g_TagWarnTime) {

            g_KickTimerActive[client] = false;
            CloseHandle(g_KickTimer[client]);
            g_KickTimer[client] = INVALID_HANDLE;
            CloseHandle(dpack);
            ServerCommand("sm_kick #%d Restricted tag: '%s'", clientID, timeRemaining, tag);
            LogMessage("[Tag Protection] Banned Player %s with ID %s for wearing the restricted tag '%s.'", clientName, clientID, tag);

            return Plugin_Handled;

        }

        timeRemaining++;

        return Plugin_Continue;

    }

    else if (client < 0) {

        LogMessage("[ERROR] OnTagKick(): unexpected value in 'client': %d", client);

        return Plugin_Stop;

    }

    else {

        LogMessage("[ERROR] OnTagKick(): non-integer value in 'client'.");

        return Plugin_Stop;

    }

}

////////////////////////////////////////////////////////////////////////////////
//
// LOCAL FUNCTIONS
//
////////////////////////////////////////////////////////////////////////////////

bool tagExistCheck(char[] Tag) {

	// Iterates through the tag data to find a match.
	KvRewind(g_TagData);
	KvGotoFirstSubKey(g_TagData);
	char buffer[255];

	do {

		KvGetSectionName(g_TagData, buffer, 255);
		// Run a case insensitive match against the entry.
		bool tagMatch = StrEqual(Tag, buffer, false);

		if (tagMatch == true) {

			return true;

		}

	}

	while (KvGotoNextKey(g_TagData));

	// Return no match.
	return false;

}

int FloatToInt(float num) {

	char temp[32];
	FloatToString(num, temp, sizeof(temp));
	return StringToInt(temp);

}
