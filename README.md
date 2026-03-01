# SourceMod: Tag Protection

A fork of [InstantDeath's plugin](https://forums.alliedmods.net/showthread.php?t=80020).

A SourceMod plugin that restricts gaming group tags to only authorized players. The plugin will search for any specified tags in a connecting player's Steam display name and either kick or ban the player, depending on the desired settings.

Admins with the ban permission have the capability to add and remove tags while in game, which will be saved to file at the end of every map.

## Commands

* `sm_tpaddtag`:
  * **Description:** Add tags to the list.
  * **Parameters:**
    * **Tag:** (*Mandatory*) the tag string.
    * **Time:** (*Mandatory*) the time in minutes until an action is taken. `-1` for kick, `0` for a permanent ban, or the number of minutes to ban.
* `sm_tpremovetag`:
  * **Description:** Removes the specified tag from the list.
  * **Parameters:**
    * **Tag:** (*Mandatory*) the tag string.

## Configuration

### AutoExec

The main configuration file is located in `tf/cfg/sourcemod/plugin.tagprotection.cfg`.

```
// File to load and save tags.
// -
// Default: "configs/taglist.cfg"
sm_tp_tag_cfg "configs/taglist.cfg"

// Tag protection version
// -
// Default: "1.4.0"
sm_tagprotection_version "1.4.0"

// SourceMod admin tag to grant immunity (https://sm.alliedmods.net/new-api/admin/AdminFlag)
// -
// Default: "Admin_Generic"
sm_tp_admin_flag "Admin_Generic"
```
### SourceMod

The plugin has an additional configuration file which houses the key/value pairs for the tags. Each tag must have a time assigned for handling infractions:

* Kick: -1
* Permanent ban: 0
* Timed ban: any amount of time in minutes.

```
"Tag Protection"
{
	"Tag 1"
	{
		"time"		"-1"
	}
    "Tag 2"
	{
		"time"		"0"
	}
	"Tag 3"
	{
		"time"		"60"
	}
}
```
## Installation

Follow the standard SourceMod process for installation by adding:

- The compiled plugin `tagprotection.smx` to `tf/addons/sourcemod/plugins/`.
- The configuration file `tags.cfg` to `/tf/addons/sourcemod/config/`.
- Reload all plugins or restart the server.

## Testing

The following testing scenarios are recommended when making code changes:

* Standard player:
	* Kick on join with a restricted tag.
	* Permanent ban on join with a restricted tag.
	* Timed ban on join with a restricted tag.
	* Add a tag after choosing a team.
* Admin
	* Join with the specified admin flag.
 	* Join with the root admin flag.
	* Add a tag via command.
 	* Remove a tag via command.
	* Inspect the tag configuration file after map change for addition and removal. 
