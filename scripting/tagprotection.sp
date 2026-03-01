/**
 * tagprotection.sp
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
Handle      g_CVarAdminFlag;

// Tag data.
Handle      g_TagData;                              // Key/Value pairs of tag data
char        g_TagListFile[PLATFORM_MAX_PATH];       // The path of the tag list file.
AdminFlag   g_ImmunityFlag;                         // The specified admin flag for immunity

// Player data.
bool        g_AdminFlagsChecked[MAXPLAYERS + 1];    // Tracks if OnClientPostAdminCheck() has completed.
bool        g_KickImmunity[MAXPLAYERS + 1];         // Tracks if a player is immune.

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
    g_CVarTagFileLoc = CreateConVar("sm_tp_tag_cfg" , "configs/taglist.cfg" , "File to load and save tags.", FCVAR_PLUGIN);
	g_CVarAdminFlag = CreateConVar("sm_tp_admin_flag" , "Admin_Generic" , "SourceMod admin tag to grant immunity (https://sm.alliedmods.net/new-api/admin/AdminFlag)", FCVAR_PLUGIN);

	// Set the configuration file location.
    char fileLoc[PLATFORM_MAX_PATH];
    GetConVarString(g_CVarTagFileLoc, fileLoc, PLATFORM_MAX_PATH);
    BuildPath(Path_SM, g_TagListFile, PLATFORM_MAX_PATH, fileLoc);

    // Halt the plugin if the file doesn't exist.
    if (FileExists(g_TagListFile) == false) {

        LogMessage("[CRITICAL] OnPluginStart(): configuration file does not exist.");
        SetFailState("[CRITICAL] OnPluginStart(): configuration file does not exist.");

    }

    // Convert admin flag CVar to type string.
	char immunityFlagString[MAXIMUM_FLAG_LENGTH];
    GetConVarString(g_CVarAdminFlag, immunityFlagString, MAXIMUM_FLAG_LENGTH);
    int immunityFlag = ReadFlagString(immunityFlagString);

    // Admin flag is out of range.
    if (immunityFlag < 0 || immunityFlag > AdminFlags_TOTAL) {

        LogMessage("[CRITICAL] OnPluginStart(): specificed admin flag is invalid. Check the configuration file.");
        SetFailState("[CRITICAL] OnPluginStart(): specificed admin flag is invalid. Check the configuration file.");

    }

    else if ((immunityFlag > -1) && (immunityFlag <= AdminFlags_TOTAL)) {

        BitToFlag(immunityFlag, g_ImmunityFlag);

    }

    else {

        LogMessage("[CRITICAL] OnPluginStart(): specificed admin flag is invalid. Check the configuration file.");
        SetFailState("[CRITICAL] OnPluginStart(): specificed admin flag is invalid. Check the configuration file.");

    }

    // Register server commands
    RegAdminCmd("sm_tpaddtag", Command_AddTag, ADMFLAG_BAN, "[SM] Add tags to the list. Usage: sm_addtag <tag> (time for ban, -1 for kick)");
    RegAdminCmd("sm_tpremovetag", Command_RemoveTag, ADMFLAG_BAN, "[SM] Removes the specified tag from the list. Usage: sm_removetag <tag>");

    // Execute the configuration
    AutoExecConfig(true);
    LogMessage("[INFO] Plugin loaded.");

}

public void OnMapStart() {

    /**
     * Import the config file into a KV object.
     *
     * This occurs on map load to support adding and removing tags to the
     * configuration file while the server is running.
    */

    g_TagData = CreateKeyValues("Tag Protection");
    FileToKeyValues(g_TagData, g_TagListFile);

}

public void OnClientSettingsChanged(int client) {

    /**
     * Check for player name changes on client setting change.
     *
     * This function ensures that OnClientPostAdminCheck() has completed. If so, then a
     * check of the player's name is initiated. This is not guaranteed to work if a player
     * changes name in game as there is an unfixable race condition due to name change cooldown.
    */

    if (g_AdminFlagsChecked[client] == true) {

        tagCheck(client);

    }

}

public void OnClientPostAdminCheck(int client) {

    /**
     * Check for SourceMod admin status.
     *
     * The function looks for either the specificed admin flag or the
     * root (z) flag.
    */

	// Check for client's admin status.
	AdminId adminID = GetUserAdmin(client);

	if (adminID != INVALID_ADMIN_ID) {

        // Checks for the specified admin flag.
		bool hasAdminFlag = GetAdminFlag(adminID, g_ImmunityFlag, Access_Effective);
		bool hasRootFlag = GetAdminFlag(adminID, Admin_Root, Access_Effective);

		if(hasAdminFlag == true || hasRootFlag == true) {

            g_KickImmunity[client] = true;

		}

		else if (hasAdminFlag == false && hasRootFlag == false) {

            g_KickImmunity[client] = false;

		}

    }

    else if (adminID == INVALID_ADMIN_ID) {

        g_KickImmunity[client] = false;

    }

	// Set that the admin checks have completed.
	g_AdminFlagsChecked[client] = true;

}

public void OnClientDisonnect(int client) {

	// Clear the admin checks for the client.
	g_AdminFlagsChecked[client] = false;
    g_KickImmunity[client] = false;

}

public void OnMapEnd() {

	// Overwrite the tag file with new values.
	KvRewind(g_TagData);
	KeyValuesToFile(g_TagData, g_TagListFile);
	CloseHandle(g_TagData);

}

////////////////////////////////////////////////////////////////////////////////
//
// COMMANDS
//
////////////////////////////////////////////////////////////////////////////////

Action Command_AddTag(int client, int args) {

    /**
     * Adds a new restricted tag to the configuration file.
     *
     * Params:
     *  int client: the client index of the player running the command.
     *  int args:
     *      tag: string of the tag.
     *      time:
     *          > 0: timed ban.
     *            0: permanent ban.
     *           -1: kick.
    */

    // Cancel if there aren't enough arguments.
    if (args < 2) {

        ReplyToCommand(client, "\x04[Tag Protection] \x01Too few arguments. Usage: sm_tpaddtag <tag> <time> (>0 timed ban, 0 permaban, -1 kick)");

	}

    // Correct number of arguments.
	else if (args == 2) {

        char tag[MAX_NAME_LENGTH];
		char kbtime[32];
		int time;

		// Set the command arguments.
        GetCmdArg(1, tag, MAX_NAME_LENGTH);
		GetCmdArg(2, kbtime, 32);

        // Cancel if the tag already exists.
        if (tagExistCheck(tag) == true) {

            ReplyToCommand(client, "\x04[Tag Protection] \x01The tag '%s' already exists.", tag);

		}

		// Create the new tag.
		else if (tagExistCheck(tag) == false) {

            time = StringToInt(kbtime);

			// Start at the beginning of the KV object.
            KvRewind(g_TagData);
			// Create the new tag.
            KvJumpToKey(g_TagData, tag, true);
			// Set the ban time.
            KvSetNum(g_TagData, "time", time);

			// Confirm the tag was created.
            if (tagExistCheck(tag) == true) {

                ReplyToCommand(client, "\x04[Tag Protection] \x01'%s' tag was successfully added. This will not take effect until the map changes.", tag);

			}

			else if (tagExistCheck(tag) == false) {

                ReplyToCommand(client, "\x04[Tag Protection] \x01'%s' tag failed to be added. Ask an admin to check the server logs for errors.", tag);

            }

		}

    }

	else if (args > 2) {

        ReplyToCommand(client, "\x04[Tag Protection] \x01Too many arguments. Usage: sm_tpaddtag <tag> <time> (>0 timed ban, 0 permaban, -1 kick)");

	}

	return Plugin_Handled;

}

Action Command_RemoveTag(int client, int args) {

    /**
     * Removes a restricted tag to the configuration file.
     *
     * Params:
     *  int client: the client index of the player running the command.
     *  int args:
     *      tag: string of the tag.
    */

    // Cancel if there aren't enough arguments.
	if (args < 1) {

		ReplyToCommand(client, "\x04[Tag Protection] \x01Too few arguments. Usage: sm_tpremovetag <tag>");

	}

	// Correct number of arguments.
	else if (args == 1) {

		char tag[MAX_NAME_LENGTH];
		GetCmdArgString(tag, MAX_NAME_LENGTH);

		// Cancel if the tag doesn't exist.
        if (tagExistCheck(tag) == false) {

			ReplyToCommand(client, "\x04[Tag Protection] \x01The tag '%s' could not be found.", tag);

		}

        // Remove the tag.
        else if (tagExistCheck(tag) == true) {

            // Start at the beginning of the KV object.
            KvRewind(g_TagData);
            // Locate the tag.
            KvJumpToKey(g_TagData, tag, false);
			// Delete the tag.
            KvDeleteThis(g_TagData);

			// Confirm the tag was removed.
            if (tagExistCheck(tag) == false) {

				ReplyToCommand(client, "\x04[Tag Protection] \x01The tag '%s' was successfully removed.", tag);

			}

			else if (tagExistCheck(tag) == false) {

				ReplyToCommand(client, "\x04[Tag Protection]\x01 The tag '%s' failed to be removed. Ask an admin to check the server logs for errors.", tag);

            }

        }

    }

	else if (args > 1) {

		ReplyToCommand(client, "\x04[Tag Protection] \x01Too many arguments. Usage: sm_tpremovetag <tag>");

	}

	return Plugin_Handled;

}

////////////////////////////////////////////////////////////////////////////////
//
// LOCAL FUNCTIONS
//
////////////////////////////////////////////////////////////////////////////////

void tagCheck(int client) {

    // Skip for bots.
    if (IsFakeClient(client) == false) {

        // Skip if the client is not yet in game.
        if (IsClientInGame(client) == true) {

            if (g_KickImmunity[client] == false) {

                int  tagMatch;
                int  userID;
                int  time;
                char tag[MAX_NAME_LENGTH];
                char clientName[MAX_NAME_LENGTH];
                char steamID[STEAMID64_LENGTH];

                // Retrieve player information.
                userID = GetClientUserId(client);
                GetClientAuthId(client, AuthId_SteamID64, steamID, STEAMID64_LENGTH);
                GetClientName(client, clientName, MAX_NAME_LENGTH);

                // Rewind to the start of the tag data.
                KvRewind(g_TagData);
                // Sets position to the first k/v pair under the first section.
                KvGotoFirstSubKey(g_TagData);

                // Loop through each tag to find a player name match.
                do {

                    //Check if the player's name contains the tag as a substring.
                    KvGetSectionName(g_TagData, tag, MAX_NAME_LENGTH);
                    tagMatch = StrContains(clientName, tag, false);

                    // Get the ban time from the section's key 'time'.
                    time = KvGetNum(g_TagData, "time", -1);

                    // A match will return the position of the substring, hence >= 0.
                    if (tagMatch >= 0) {

                        // Action: kick.
                        if (time  == -1) {

                            ServerCommand("sm_kick #%d You were kicked for wearing a restricted tag: '%s'", userID, tag);
                            LogMessage("Kicked player %s with ID %s for wearing the restricted tag '%s.'", clientName, steamID, tag);

                            break;

                        }

                        // Action: ban.
                        else if (time >= 0) {

                            ServerCommand("sm_ban #%d %d You were banned for wearing a restricted tag: '%s'", userID, time, tag);
                            LogMessage("Banned player %s with ID %s for wearing the restricted tag '%s.'", clientName, steamID, tag);

                            break;

                        }

                        else if (time < -1) {

                            LogMessage("[ERROR] tagCheck(): specified time %d for tag %s must be greater than -2.", time, tag);

                        }

                    }

                    else if (tagMatch < -1) {

                        LogMessage("[ERROR] tagCheckChange(): unexpected value in tagMatch: %d", tagMatch);

                        break;

                    }

                }

                while (KvGotoNextKey(g_TagData));

            }

        }

    }

}

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
