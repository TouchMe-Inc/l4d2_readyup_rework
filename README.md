# About readyup_rework
The plugin allows you to control the moment the round starts.

## Commands
* `!ready` or `!r` - Mark your status as Ready.
* `!unready` or `!nr` - Mark your status as Not Ready.
* `!show` - Show Ready Bar.
* `!hide` - Hide Ready Bar.
* `!return` - Return to spawn point.

## ConVars
| ConVar               | Value         | Description                                                                                     |
| -------------------- | ------------- | ----------------------------------------------------------------------------------------------- |
| sm_readyup_mode      | 2             | Plugin operating mode (Values: 0 = Disabled, 1 = Auto start, 2 = Player ready, 3 = Team ready)  |
| sm_readyup_delay     | 3             | Number of seconds to count down before the round goes live                                      |
| sm_readyup_autostart_delay | 20.0    | Number of seconds before forced automatic start (only `sm_readyup_mode 1`)                      |
| sm_readyup_afk_duration | 15.0       | Number of seconds since the player's last activity to count his afk                             |

Coming soon...

## Developers
In the repository you can find the file [addons/sourcemod/scripting/include/readyup_rework.inc](https://github.com/TouchMe-Inc/l4d2_readyup_rework/blob/main/addons/sourcemod/scripting/include/readyup_rework.inc) , which contains the plugin API. 
At the moment I have not prepared a description :c

Coming soon...

## Require
* Colors
* [Left4DHooks](https://github.com/SilvDev/Left4DHooks)
* [NativeVotesRework](https://github.com/TouchMe-Inc/l4d2_nativevotes_rework)
