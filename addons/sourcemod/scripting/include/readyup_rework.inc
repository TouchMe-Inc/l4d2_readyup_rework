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
 * Returns the current state of the ready-up system.
 *
 * @return ReadyupState enum value representing the current state.
 */
native ReadyupState GetReadyState();

/**
 * Returns the current mode of the ready-up system.
 *
 * @return ReadyupMode enum value representing the active mode.
 */
native ReadyupMode GetReadyMode();

/**
 * Returns whether the player is marked as ready to play.
 * In ReadyupMode_PlayerReady mode, returns true if the player's command is ready.
 */
native bool IsClientReady(int iClient);

/**
 * Sets the ready status of a specific client.
 *
 * @param iClient Client index.
 * @param bReady True to mark as ready; false to unready.
 * @return True if the status was successfully updated.
 */
native bool SetClientReady(int iClient, bool bReady);

/**
 * Checks whether the ready-up panel is visible for a client.
 *
 * @param iClient Client index.
 * @return True if the panel is visible; false otherwise.
 */
native bool IsClientReadyUpVisible(int iClient);

/**
 * Sets the visibility of the ready-up panel for a client.
 *
 * @param iClient Client index.
 * @param bVisible True to show the panel; false to hide it.
 */
native void SetClientReadyUpVisible(int iClient, bool bVisible);

/**
 * Adds a new item to the ready-up panel.
 *
 * @param ePos Panel position (header or footer).
 * @param szFormat Translation format string (e.g., "%T").
 * @param ... Arguments for the format string.
 * @return Index of the newly added item.
 */
native int PushReadyUpItem(PanelPos ePos, const char[] szFormat, any...);

/**
 * Updates an existing item in the ready-up panel.
 *
 * @param ePos Panel position.
 * @param iIndex Index of the item to update.
 * @param szFormat Translation format string.
 * @param ... Arguments for the format string.
 * @return New index of the updated item.
 */
native int UpdateReadyUpItem(PanelPos ePos, int iIndex, const char[] szFormat, any...);

/**
 * Removes an item from the ready-up panel.
 *
 * @param ePos Panel position.
 * @param iIndex Index of the item to remove.
 * @return New index of the item that replaced the removed one, or -1 if none.
 */
native int RemoveReadyUpItem(PanelPos ePos, int iIndex);

/**
 * Called when the ready-up state changes.
 *
 * @param eOldState Previous state.
 * @param eNewState New state.
 */
forward void OnChangeReadyState(ReadyupState eOldState, ReadyupState eNewState);

/**
 * Called when a client's ready status changes.
 *
 * @param iClient Client index.
 * @param bReady New ready status.
 */
forward void OnChangeClientReady(int iClient, bool bReady);

/**
 * Called before rendering a ready-up item.
 * Allows modification or cancellation of the item.
 *
 * @param ePos Panel position.
 * @param iClient Client index.
 * @param iIndex Item index.
 * @return Plugin_Continue to allow, Plugin_Stop to skip rendering.
 */
forward Action OnPrepareReadyUpItem(PanelPos ePos, int iClient, int iIndex);

/**
 * Called when a ready-up item is removed.
 *
 * @param ePos Panel position.
 * @param iOldIndex Index of the removed item.
 * @param iNewIndex Index of the item that replaced it.
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