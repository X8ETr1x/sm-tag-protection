# SourceMod: Tag Protection

A fork of [InstantDeath's plugin](https://forums.alliedmods.net/showthread.php?t=80020).

This is a simple advertisements plugin. It supports center, chat, hint, menu and top messages.

sm_advertisements_enabled (0/1, def 1)
Enable/disable displaying advertisements.

sm_advertisements_file (def "advertisements.txt")
File to read the advertisements from. Useful if you're running multiple servers from one installation, and want to use different advertisements per server.

sm_advertisements_interval (def 30)
Number of seconds between advertisements.

sm_advertisements_random (0/1, def 0)
Enable/disable random advertisements. When enabled, advertisements are randomized on every map change and reload.

sm_advertisements_reload
Server command to reload the advertisements.


By default the plugin reads from addons/sourcemod/configs/advertisements.txt, which has this format:

Code:

"Advertisements"
{
    "1"
    {
        "chat"        "{green}contact@domain.com"
    }
    "2"
    {
        "top"         "www.domain.com"
        "flags"       "a"
    }
}

Make sure to save this file as UTF-8 (without BOM), otherwise special characters will not work!

Types

The following types are supported:

center: A center message, like sm_csay.
chat: A chat message, like sm_say. A list of supported colors can be found on https://github.com/PremyslTalich/ColorVariables.
hint: A hint message, like sm_hsay.
menu: A menu message, like sm_msay, but without the title or the Exit-option. Pressing 0 will still hide the message, but it will block 1-9 from switching weapons while it's showing.
top: A top-left message, like sm_tsay. It supports any of the colors listed on https://www.doctormckay.com/morecolors.php, or custom colors with {#abcdef}.

Multiple types per advertisement are allowed, so you can show a different message in multiple places at the same time.

Message

The message supports the following variables: {currentmap}, {nextmap}, {date}, {time}, {time24} and {timeleft}. Next to that you can print the value of any cvar by enclosing the name with {}, for example {mp_friendlyfire}. Use \n for newlines, which works with center, chat, hint and menu messages.

A couple of examples are given in the supplied advertisements.txt.

Flags

This field is optional. It accepts a list of flags of players who will not see the advertisement if they have any of those flags. If left empty, only admins will see the advertisement. If omitted everyone will see the advertisement.
