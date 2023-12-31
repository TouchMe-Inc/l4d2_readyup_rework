#if defined  _readyup_rework_included_
 #endinput
#endif
#define _readyup_rework_included_

enum Mode
{
	Mode_AlwaysReady = 0,
	Mode_AutoStart,
	Mode_PlayerReady,
	Mode_TeamReady
}

enum State
{
	State_None = 0,
	State_UnReady,
	State_Countdown,
	State_Ready
}

enum PanelPos
{
	PanelPos_Header = 0,
	PanelPos_Footer
}

/**
 *
 */
native State GetReadyState();

/**
 *
 */
native Mode GetReadyMode();

/**
 *
 */
native bool IsClientReady(int iClient);

/**
 *
 */
native bool SetClientReady(int iClient, bool bReady);

/**
 *
 */
native bool IsClientPanelVisible(int iClient);

/**
 *
 */
native void SetClientPanelVisible(int iClient, bool bVisible);

/**
 *
 */
native int PushPanelItem(PanelPos ePos, const char[] sFormat, any...);

/**
 *
 */
native int UpdatePanelItem(PanelPos ePos, int iIndex, const char[] sFormat, any...);

/**
 *
 */
native int RemovePanelItem(PanelPos ePos, int iIndex);

/**
 *
 */
forward void OnChangeReadyState(State eOldState, State eNewState);

/**
 *
 */
forward void OnChangeClientReady(int iClient, bool bReady);

/**
 *
 */
forward Action OnPreparePanelItem(PanelPos ePos, int iClient, int iIndex);

/**
 *
 */
forward void OnRemovePanelItem(PanelPos ePos, int iOldIndex, int iNewIndex);


public SharedPlugin __pl_readyup =
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
	MarkNativeAsOptional("IsClientPanelVisible");
	MarkNativeAsOptional("SetClientPanelVisible");
	MarkNativeAsOptional("PushPanelItem");
	MarkNativeAsOptional("UpdatePanelItem");
	MarkNativeAsOptional("RemovePanelItem");
}
#endif
