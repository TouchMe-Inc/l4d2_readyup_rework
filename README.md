# About readyup_rework
The plugin allows you to control the moment the round starts.

## Commands
* `!ready` or `!r` - Mark your status as Ready.
* `!unready` or `!nr` - Mark your status as Not Ready.
* `!readyup` - Show/Hide Ready Panel.
* `!return` - Return to spawn point.
* `!fs` or `!forcestart`.

## ConVars
| ConVar               | Value         | Description                                                                                     |
| -------------------- | ------------- | ----------------------------------------------------------------------------------------------- |
| sm_readyup_sound_enable | 1          | Enable sounds played to clients                                                                 |
| sm_readyup_sound_notify | "buttons/button14.wav" | Path to the sound that is played when the client status changes                     |
| sm_readyup_sound_countdown | "weapons/hegrenade/beep.wav" | The sound that plays when a round goes on countdown                        |
| sm_readyup_sound_live | "ui/survival_medal.wav" | The sound that plays when a round goes live                                          |
| sm_readyup_mode      | 2             | Plugin operating mode (Values: 0 = Disabled, 1 = Auto start, 2 = Player ready, 3 = Team ready)  |
| sm_readyup_delay     | 3             | Number of seconds to count down before the round goes live                                      |
| sm_readyup_autostart_delay | 20.0    | Number of seconds before forced automatic start (only `sm_readyup_mode 1`)                      |
| sm_readyup_afk_duration | 15.0       | Number of seconds since the player's last activity to count his afk                             |
| sm_readyup_spam_cd_init | 2.0        | Initial cooldown time in seconds                                                                |
| sm_readyup_spam_cd_inc  | 1.0        | Cooldown increment time in seconds                                                              |
| sm_readyup_spam_attempts_before_inc | 1 | Maximum number of attempts before increasing cooldown                                                               |

## Developers
In the repository you can find the file [addons/sourcemod/scripting/include/readyup_rework.inc](https://github.com/TouchMe-Inc/l4d2_readyup_rework/blob/main/addons/sourcemod/scripting/include/readyup_rework.inc) , which contains the plugin API. 
At the moment I have not prepared a description :c

Coming soon...

## Require
* Colors
* [Left4DHooks](https://github.com/SilvDev/Left4DHooks)
* [NativeVotesRework](https://github.com/TouchMe-Inc/l4d2_nativevotes_rework)
