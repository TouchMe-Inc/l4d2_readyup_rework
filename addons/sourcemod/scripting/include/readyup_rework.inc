#if defined  _readyup_rework_included_
 #endinput
#endif
#define _readyup_rework_included_

enum ReadyupMode
{
    ReadyupMode_AlwaysReady = 0,
    ReadyupMode_AutoStart,
    ReadyupMode_PlayerReady,
    ReadyupMode_TeamReady
}

enum ReadyupState
{
	ReadyupState_None = 0,
	ReadyupState_UnReady,
	ReadyupState_Countdown,
	ReadyupState_Ready
}

enum PanelPos
{
	PanelPos_Header = 0,
	PanelPos_Footer
}

/**
 * Returns the current state.
 */
native ReadyupState GetReadyState();

/**
 * Returns the current mode.
 */
native ReadyupMode GetReadyMode();

/**
 * Returns whether the player is marked as ready to play.
 * In ReadyupMode_PlayerReady mode, returns true if the player's command is ready.
 */
native bool IsClientReady(int iClient);

/**
 *
 */
native bool SetClientReady(int iClient, bool bReady);

/**
 *
 */
native bool IsClientReadyUpVisible(int iClient);

/**
 *
 */
native void SetClientReadyUpVisible(int iClient, bool bVisible);

/**
 *
 */
native int PushReadyUpItem(PanelPos ePos, const char[] sFormat, any...);

/**
 *
 */
native int UpdateReadyUpItem(PanelPos ePos, int iIndex, const char[] sFormat, any...);

/**
 *
 */
native int RemoveReadyUpItem(PanelPos ePos, int iIndex);

/**
 *
 */
forward void OnChangeReadyState(ReadyupState eOldState, ReadyupState eNewState);

/**
 *
 */
forward void OnChangeClientReady(int iClient, bool bReady);

/**
 *
 */
forward Action OnPrepareReadyUpItem(PanelPos ePos, int iClient, int iIndex);

/**
 *
 */
forward void OnRemoveReadyUpItem(PanelPos ePos, int iOldIndex, int iNewIndex);


public SharedPlugin __pl_readyup_rework =
{
	name = "readyup_rework",
	file = "readyup_rework.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_readyup_rework_SetNTVOptional()
{
	MarkNativeAsOptional("GetReadyState");
	MarkNativeAsOptional("GetReadyMode");
	MarkNativeAsOptional("IsClientReady");
	MarkNativeAsOptional("SetClientReady");
	MarkNativeAsOptional("IsClientReadyUpVisible");
	MarkNativeAsOptional("SetClientReadyUpVisible");
	MarkNativeAsOptional("PushReadyUpItem");
	MarkNativeAsOptional("UpdateReadyUpItem");
	MarkNativeAsOptional("RemoveReadyUpItem");
}
#endif