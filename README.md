# SourceMod: Tag Protection

A fork of [InstantDeath's plugin](https://forums.alliedmods.net/showthread.php?t=80020).

A small simple plugin that allows only certain people to wear a specific tag. or use it to keep clans that you don't want on your server out.

- Allows only people with the Admflag_custom1 flag (and people with root access) to wear a protected clan tag.
- In-game Admin control, add and remove tags from in game, with the option to kick or ban offenders.
- A kick time limit, to give offenders a chance to remove the offensive tag.

## Commands

* `sm_addtag`:
  * **Description:** Add tags to the list.
  * **Parameters:**
    * **Tag:** (*Mandatory*) the tag string.
    * **Time:** (*Mandatory*) the time in seconds until a kick. `-1` is an instant kick.
* `sm_removetag`:
  * **Description:** Removes the specified tag from the list.
  * **Parameters:**
    * **Tag:** (*Mandatory*) the tag string.

## Configuration

### AutoExec

```
// File to load and save tags.
// -
// Default: "configs/taglist.cfg"
sm_tagcfg "configs/taglist.cfg"

// Tag Protection Version
// -
// Default: "1.4.0"
sm_tagprotection_version "1.4.0"

// Time in seconds to warn player that he has an invalid tag
// -
// Default: "60.0"
sm_tagwarntime "60.0"
```
### SourceMod

```
"Tag Protection"
{
	"My Tag"
	{
		"time"		"-1"
	}
  "My Tag"
	{
		"time"		"-1"
	}
}
```
## Installation

Follow the standard SourceMod process for installation by adding:

- The compiled plugin `tagprotection.smx` to `tf/addons/sourcemod/plugins/`.
- The configuration file 'tags.cfg` to `/tf/addons/sourcemod/config/`.
- Reload all plugins or restart the server.
