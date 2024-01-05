#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>
#include <nativevotes_rework>


#undef REQUIRE_PLUGIN
#include <caster_system>
#define REQUIRE_PLUGIN


public Plugin myinfo =
{
	name = "ReadyUpRework",
	author = "CanadaRox, TouchMe",
	description = "The plugin allows you to control the moment the round starts",
	version = "build0001",
	url = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
};


/**
 * Libs.
 */
#define LIB_CASTER              "caster_system"

/**
 *
 */
#define TRANSLATION             "readyup_rework.phrases"

/**
 *
 */
#define DEFAULT_NOTIFY_SOUND    "buttons/button14.wav"
#define DEFAULT_COUNTDOWN_SOUND "weapons/hegrenade/beep.wav"
#define DEFAULT_LIVE_SOUND      "ui/survival_medal.wav"

/**
 *
 */
#define TEAM_NONE               0
#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

/**
 *
 */
#define WATER_LEVEL_EYES        3

/**
 *
 */
#define DrawPanelSpace(%0)      (DrawPanelText(%0, " "))


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

char PANEL_BLOCK_NAME[][] = {
	"PANEL_SURVIVOR_TEAM", "PANEL_INFECTED_TEAM", "PANEL_CASTER_TEAM"
};

GlobalForward
	g_fwdOnChangeReadyState = null,
	g_fwdOnChangeClientReady = null,
	g_fwdOnPreparePanelItem = null,
	g_fwdOnRemovePanelItem = null
;

ConVar
	g_cvGod = null,
	g_cvSbStop = null,
	g_cvSurvivorLimit = null,
	g_cvMaxPlayerZombies = null,
	g_cvInfinitePrimaryAmmo = null,
	g_cvForceStartTime = null,

	g_cvMode = null,
	g_cvDelay = null,
	g_cvAutoStartDelay = null,
	g_cvAfkDuration = null,

	g_cvSoundEnable = null,
	g_cvSoundNotify = null,
	g_cvSoundCountdown = null,
	g_cvSoundLive = null
;

char
	g_sNotifySound[PLATFORM_MAX_PATH],
	g_sCountdownSound[PLATFORM_MAX_PATH],
	g_sLiveSound[PLATFORM_MAX_PATH]
;

float
	g_fLastClientActivityTime[MAXPLAYERS + 1] = {0.0, ...}
;

int
	g_iDelay = 0,
	g_iTimer = 0,
	g_iAutoStartDelay = 0,
	g_iAutoStartTimer = 0
;

float g_fAfkDuration = 0.0;

bool
	g_bClientReady[MAXPLAYERS + 1],
	g_bClientPanelVisible[MAXPLAYERS + 1]
;

bool g_bCasterAvailable = false; /**< Caster System */

State g_eState = State_None;

Mode g_eMode = Mode_AlwaysReady;

Handle
	g_hPanelHeader = null,
	g_hPanelFooter = null
;


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded() {
	g_bCasterAvailable = LibraryExists(LIB_CASTER);
}

/**
  * Global event. Called when a library is removed.
  *
  * @param sName     Library name
  */
public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, LIB_CASTER)) {
		g_bCasterAvailable = false;
	}
}

/**
  * Global event. Called when a library is added.
  *
  * @param sName     Library name
  */
public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, LIB_CASTER)) {
		g_bCasterAvailable = true;
	}
}

/**
 * Called before OnPluginStart.
 *
 * @param myself            Handle to the plugin.
 * @param late              Whether or not the plugin was loaded "late" (after map load).
 * @param error             Error message buffer in case load failed.
 * @param err_max           Maximum number of characters for error message buffer.
 * @return                  APLRes_Success | APLRes_SilentFailure.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	// Natives.
	CreateNative("GetReadyState", Native_GetReadyState);
	CreateNative("GetReadyMode", Native_GetReadyMode);
	CreateNative("IsClientReady", Native_IsClientReady);
	CreateNative("SetClientReady", Native_SetClientReady);
	CreateNative("IsClientPanelVisible", Native_IsClientPanelVisible);
	CreateNative("SetClientPanelVisible", Native_SetClientPanelVisible);
	CreateNative("PushPanelItem", Native_PushPanelItem);
	CreateNative("UpdatePanelItem", Native_UpdatePanelItem);
	CreateNative("RemovePanelItem", Native_RemovePanelItem);

	// Forwards.
	g_fwdOnChangeReadyState = CreateGlobalForward("OnChangeReadyState", ET_Ignore, Param_Cell, Param_Cell);
	g_fwdOnChangeClientReady = CreateGlobalForward("OnChangeClientReady", ET_Ignore, Param_Cell, Param_Cell);
	g_fwdOnPreparePanelItem = CreateGlobalForward("OnPreparePanelItem", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnRemovePanelItem = CreateGlobalForward("OnRemovePanelItem", ET_Ignore, Param_Cell, Param_Cell);

	// Library.
	RegPluginLibrary("readyup_rework");

	return APLRes_Success;
}

any Native_GetReadyState(Handle hPlugin, int iParams) {
	return g_eState;
}

any Native_GetReadyMode(Handle hPlugin, int iParams) {
	return g_eMode;
}

any Native_IsClientReady(Handle hPlugin, int iParams)
{
	int iClient = GetNativeCell(1);

	if (!IsValidClient(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
	}

	if (!IsClientInGame(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	}

	return IsClientReady(iClient);
}

any Native_SetClientReady(Handle hPlugin, int iParams)
{
	int iClient = GetNativeCell(1);

	if (!IsValidClient(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
	}

	if (!IsClientInGame(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	}

	bool bReady = GetNativeCell(2);

	return SetClientReady(iClient, bReady);
}

any Native_IsClientPanelVisible(Handle hPlugin, int iParams)
{
	int iClient = GetNativeCell(1);

	if (!IsValidClient(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
	}

	if (!IsClientInGame(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	}

	return IsClientPanelVisible(iClient);
}

any Native_SetClientPanelVisible(Handle hPlugin, int iParams)
{
	int iClient = GetNativeCell(1);

	if (!IsValidClient(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
	}

	if (!IsClientInGame(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	}

	bool bVisible = GetNativeCell(2);

	SetClientPanelVisible(iClient, bVisible);

	return 0;
}

any Native_PushPanelItem(Handle hPlugin, int iParams)
{
	PanelPos ePos = GetNativeCell(1);

	Handle hItems = (ePos == PanelPos_Header) ? g_hPanelHeader : g_hPanelFooter;

	char sBuffer[64]; FormatNativeString(0, 2, 3, sizeof(sBuffer), _, sBuffer);

	return PushArrayString(hItems, sBuffer);
}

any Native_UpdatePanelItem(Handle hPlugin, int iParams)
{
	PanelPos ePos = GetNativeCell(1);

	Handle hItems = (ePos == PanelPos_Header) ? g_hPanelHeader : g_hPanelFooter;

	int iTargetIndex = GetNativeCell(2);

	int iItemCount = GetArraySize(hItems);

	if (iTargetIndex >= iItemCount) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Array index out bound");
	}

	char sBuffer[64]; FormatNativeString(0, 3, 4, sizeof(sBuffer), _, sBuffer);

	SetArrayString(hItems, iTargetIndex, sBuffer);

	return 0;
}

any Native_RemovePanelItem(Handle hPlugin, int iParams)
{
	PanelPos ePos = GetNativeCell(1);

	Handle hItems = (ePos == PanelPos_Header) ? g_hPanelHeader : g_hPanelFooter;

	int iTargetIndex = GetNativeCell(2);

	int iItemCount = GetArraySize(hItems);

	if (iTargetIndex >= iItemCount) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Array index out bound");
	}

	for (int iIndex = iTargetIndex + 1; iIndex < iItemCount; iIndex ++)
	{
		ExecuteForward_OnRemovePanelItem(ePos, iIndex, iIndex - 1);
	}

	RemoveFromArray(hItems, iTargetIndex);

	return 0;
}

/**
 * Called when the map is loaded.
 */
public void OnMapStart()
{
	// Precache
	GetConVarString(g_cvSoundNotify, g_sNotifySound, sizeof(g_sNotifySound));
	if (!IsSoundExists(g_sNotifySound)) {
		strcopy(g_sNotifySound, sizeof(g_sNotifySound), DEFAULT_NOTIFY_SOUND);
	}
	PrecacheSound(g_sNotifySound);

	// Precache
	GetConVarString(g_cvSoundCountdown, g_sCountdownSound, sizeof(g_sCountdownSound));
	if (!IsSoundExists(g_sCountdownSound)) {
		strcopy(g_sCountdownSound, sizeof(g_sCountdownSound), DEFAULT_COUNTDOWN_SOUND);
	}
	PrecacheSound(g_sCountdownSound);

	// Precache
	GetConVarString(g_cvSoundLive, g_sLiveSound, sizeof(g_sLiveSound));
	if (!IsSoundExists(g_sLiveSound)) {
		strcopy(g_sLiveSound, sizeof(g_sLiveSound), DEFAULT_LIVE_SOUND);
	}
	PrecacheSound(g_sLiveSound);
}

/**
 *
 */
public void OnPluginStart()
{
	LoadTranslations(TRANSLATION);

	g_cvMode = CreateConVar("sm_readyup_mode", "2", "Enable this plugin. (Values: 0 = Disabled, 1 = Auto start, 2 = Player ready, 3 = Team ready)", _, true, 0.0, true, 3.0);
	g_cvDelay = CreateConVar("sm_readyup_delay", "3", "Number of seconds to count down before the round goes live", _, true, 0.0);
	g_cvAutoStartDelay = CreateConVar("sm_readyup_autostart_delay", "20.0", "Number of seconds to wait for connecting players before auto-start is forced", _, true, 0.0);
	g_cvAfkDuration = CreateConVar("sm_readyup_afk_duration", "15.0", "Number of seconds to count down before the round goes live", _, true, 1.0);
	g_cvSoundEnable = CreateConVar("sm_readyup_sound_enable", "1", "Enable sounds played to clients", _, true, 0.0, true, 1.0);
	g_cvSoundNotify = CreateConVar("sm_readyup_sound_notify", DEFAULT_NOTIFY_SOUND, "The sound that plays when a round goes on countdown");
	g_cvSoundCountdown = CreateConVar("sm_readyup_sound_countdown", DEFAULT_COUNTDOWN_SOUND, "The sound that plays when a round goes on countdown");
	g_cvSoundLive = CreateConVar("sm_readyup_sound_live", DEFAULT_LIVE_SOUND, "The sound that plays when a round goes live");

	// game convars
	(g_cvGod = FindConVar("god"));
	(g_cvSbStop = FindConVar("sb_stop"));
	(g_cvSurvivorLimit = FindConVar("survivor_limit"));
	(g_cvMaxPlayerZombies = FindConVar("z_max_player_zombies"));
	(g_cvInfinitePrimaryAmmo = FindConVar("sv_infinite_primary_ammo"));
	(g_cvForceStartTime = FindConVar("versus_force_start_time"));

	HookConVarChange(g_cvMode, OnModeChanged);
	HookConVarChange(g_cvDelay, OnDelayChanged);
	HookConVarChange(g_cvAutoStartDelay, OnAutoStartDelayChanged);
	HookConVarChange(g_cvAfkDuration, OnAfkDurationChanged);

	// Player Commands.
	RegConsoleCmd("sm_hide", Cmd_HidePanel, "Hides the ready-up panel so other menus can be seen");
	RegConsoleCmd("sm_show", Cmd_ShowPanel, "Shows a hidden ready-up panel");
	RegConsoleCmd("sm_return", Cmd_ReturnToSaferoom, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
	RegConsoleCmd("sm_ready", Cmd_Ready, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_r", Cmd_Ready, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_unready", Cmd_Unready, "Mark yourself as not ready if you have set yourself as ready");
	RegConsoleCmd("sm_nr", Cmd_Unready, "Mark yourself as not ready if you have set yourself as ready");

	// Hook vote <KEY_F1> or <KEY_F2>.
	AddCommandListener(Vote_Callback, "Vote");

	// Events.
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);

	// Init
	g_eMode = view_as<Mode>(GetConVarInt(g_cvMode));
	g_iDelay = GetConVarInt(g_cvDelay);
	g_iAutoStartDelay = GetConVarInt(g_cvAutoStartDelay);
	g_fAfkDuration = GetConVarFloat(g_cvAfkDuration);

	g_hPanelHeader = CreateArray(ByteCountToCells(64));
	g_hPanelFooter = CreateArray(ByteCountToCells(64));
}

/**
 *
 */
void OnModeChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue) {
	g_eMode = view_as<Mode>(GetConVarInt(convar));
}

/**
 *
 */
void OnDelayChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue) {
	g_iDelay = GetConVarInt(convar);
}

/**
 *
 */
void OnAutoStartDelayChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue) {
	g_iAutoStartDelay = GetConVarInt(convar);
}

/**
 *
 */
void OnAfkDurationChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue) {
	g_fAfkDuration = GetConVarFloat(convar);
}

/**
 *
 */
public Action L4D_OnFirstSurvivorLeftSafeArea(int iClient)
{
	if (g_eMode == Mode_AlwaysReady)
	{
		SetConVarStringSilence(g_cvGod, "0");
		SetConVarStringSilence(g_cvInfinitePrimaryAmmo, "0");
		SetConVarStringSilence(g_cvSbStop, "0");

		SetReadyState(State_None);

		return Plugin_Continue;
	}

	if (!IsReadyStateInProgress())
	{
		SetReadyState(State_None);

		return Plugin_Continue;
	}

	ReturnClientToSaferoom(iClient);

	return Plugin_Handled;
}

/**
 *
 */
void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	DisableForceStartTime();

	// ConVars.
	SetConVarStringSilence(g_cvGod, "1");
	SetConVarStringSilence(g_cvInfinitePrimaryAmmo, "1");
	SetConVarStringSilence(g_cvSbStop, "1");

	// Reset client ready status.
	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		g_bClientReady[iClient] = false;
		g_bClientPanelVisible[iClient] = true;
	}

	// Vars.
	SetReadyState(State_UnReady);

	// Show panel.
	CreateTimer(1.0, Timer_UpdatePanel, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

	if (g_eMode == Mode_AutoStart)
	{
		SetReadyState(State_Countdown);

		g_iAutoStartTimer = g_iAutoStartDelay;
		CreateTimer(1.0, Timer_AutoStart, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
}

/**
 *
 */
Action Timer_UpdatePanel(Handle timer)
{
	if (!IsReadyStateInProgress()) {
		return Plugin_Stop;
	}

	if (NativeVotes_IsVoteInProgress()) {
		return Plugin_Continue;
	}

	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (!IsClientInGame(iClient)
		|| IsFakeClient(iClient)
		|| !IsClientPanelVisible(iClient)) {
			continue;
		}

		switch (GetClientMenu(iClient)) {
			case MenuSource_External, MenuSource_Normal: continue;
		}

		Panel hPanel = BuildPanel(iClient);

		SendPanelToClient(hPanel, iClient, DummyHandler, 1);

		CloseHandle(hPanel);
	}

	return Plugin_Continue;
}

/**
 *
 */
Action Timer_AutoStart(Handle timer)
{
	if (!IsReadyStateCountdown()) {
		return Plugin_Stop;
	}

	if (IsEmptyServer())
	{
		g_iAutoStartTimer = g_iAutoStartDelay;

		return Plugin_Continue;
	}

	if (IsAnyPlayerLoading())
	{
		PrintHintTextToAll("%t", "AUTOSTART_WAIT_LOADING_PLAYERS");
		return Plugin_Continue;
	}

	if (g_iAutoStartTimer <= 0)
	{
		PrintHintTextToAll("%t", "AUTOSTART_COUNTDOWN_END");

		PlayLiveSound();
		EnableForceStartTime();
		ReturnSurvivorToSaferoom();

		SetConVarStringSilence(g_cvGod, "0");
		SetConVarStringSilence(g_cvInfinitePrimaryAmmo, "0");
		SetConVarStringSilence(g_cvSbStop, "0");

		SetReadyState(State_Ready);

		return Plugin_Stop;
	}

	PrintHintTextToAll("%t", "AUTOSTART_COUNTDOWN", g_iAutoStartTimer --);

	return Plugin_Continue;
}

/**
 *
 */
Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsModeNeedClientAction()) {
		return Plugin_Continue;
	}

	if (!IsReadyStateInProgress()) {
		return Plugin_Continue;
	}

	int iClient = GetClientOfUserId(event.GetInt("userid"));

	if (!iClient || IsFakeClient(iClient))
		return Plugin_Continue;

	int iTeam = event.GetInt("team");
	int iOldTeam = event.GetInt("oldteam");

	/*
	 * Player disconnect
	 */
	if (iTeam == TEAM_NONE && iOldTeam != TEAM_SPECTATOR)
	{
		if (g_eMode == Mode_PlayerReady) {
			SetTeamReady(iTeam, false);
		} else {
			SetClientReady(iClient, false);
		}

		if (IsReadyStateCountdown())
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
			{
				if (!IsClientInGame(iPlayer)
				|| IsFakeClient(iPlayer)
				|| !IsValidTeam(GetClientTeam(iPlayer))) {
					continue;
				}

				CPrintToChat(iPlayer, "%T%T", "TAG", iPlayer, "STOP_COUNTDOWN_PLAYER_DISCONNECT", iPlayer, iClient);
			}

			SetReadyState(State_UnReady);
		}
	}

	else
	{
		DataPack hPack = CreateDataPack();
		hPack.WriteCell(iClient);
		hPack.WriteCell(iOldTeam);

		CreateTimer(0.1, Timer_PlayerTeam, hPack, TIMER_DATA_HNDL_CLOSE | TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

/**
 *
 */
Action Timer_PlayerTeam(Handle hTimer, DataPack hPack)
{
	if (!IsReadyStateCountdown()) {
		return Plugin_Stop;
	}

	hPack.Reset();

	int iClient = hPack.ReadCell();
	int iOldTeam = hPack.ReadCell();
	int iTeam = GetClientTeam(iClient);

	if (iOldTeam != TEAM_NONE || iTeam != TEAM_SPECTATOR)
	{
		if (g_eMode == Mode_PlayerReady) {
			SetTeamReady(iTeam, false);
		} else {
			SetClientReady(iClient, false);
		}

		if (IsReadyStateCountdown())
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
			{
				if (!IsClientInGame(iPlayer)
				|| IsFakeClient(iPlayer)
				|| !IsValidTeam(GetClientTeam(iPlayer))) {
					continue;
				}

				CPrintToChat(iPlayer, "%T%T", "TAG", iPlayer, "STOP_COUNTDOWN_PLAYER_CHANGE_TEAM", iPlayer, iClient);
			}

			SetReadyState(State_UnReady);
		}
	}

	return Plugin_Stop;
}

/**
 *
 */
Action Timer_Countdown(Handle timer)
{
	if (!IsReadyStateCountdown()) {
		return Plugin_Stop;
	}

	if (g_iTimer <= 0)
	{
		PrintHintTextToAll("%t", "START_COUNTDOWN_END");

		PlayLiveSound();
		EnableForceStartTime();
		ReturnSurvivorToSaferoom();

		SetConVarStringSilence(g_cvGod, "0");
		SetConVarStringSilence(g_cvInfinitePrimaryAmmo, "0");
		SetConVarStringSilence(g_cvSbStop, "0");

		SetReadyState(State_Ready);

		return Plugin_Stop;
	}

	PrintHintTextToAll("%t", "START_COUNTDOWN", g_iTimer --);
	PlayCountdownSound();

	return Plugin_Continue;
}


/**
 *
 */
Action Cmd_ShowPanel(int iClient, int iArgs)
{
	if (!IsReadyStateInProgress()) {
		return Plugin_Continue;
	}

	if (IsClientPanelVisible(iClient)) {
		return Plugin_Handled;
	}

	SetClientPanelVisible(iClient, true);
	CPrintToChat(iClient, "%T%T", "TAG", iClient, "PANEL_SHOW", iClient);

	return Plugin_Handled;
}

/**
 *
 */
Action Cmd_HidePanel(int iClient, int iArgs)
{
	if (!IsReadyStateInProgress()) {
		return Plugin_Continue;
	}

	if (!IsClientPanelVisible(iClient)) {
		return Plugin_Handled;
	}

	SetClientPanelVisible(iClient, false);
	CPrintToChat(iClient, "%T%T", "TAG", iClient, "PANEL_HIDDEN", iClient);

	return Plugin_Handled;
}

/**
 *
 */
Action Cmd_ReturnToSaferoom(int iClient, int iArgs)
{
	if (!IsReadyStateInProgress()) {
		return Plugin_Continue;
	}

	if (!IsClientSurvivor(iClient)) {
		return Plugin_Handled;
	}

	ReturnClientToSaferoom(iClient);
	return Plugin_Handled;
}

/**
 *
 */
Action Cmd_Ready(int iClient, int iArgs)
{
	if (!IsModeNeedClientAction()) {
		return Plugin_Continue;
	}

	if (!IsReadyStateInProgress()) {
		return Plugin_Continue;
	}

	int iTeam = GetClientTeam(iClient);

	if (!IsValidTeam(iTeam)) {
		return Plugin_Continue;
	}

	if (IsClientReady(iClient)) {
		return Plugin_Handled;
	}

	PlayNotifySound(iClient);

	if (g_eMode == Mode_PlayerReady) {
		SetTeamReady(iTeam, true);
	} else {
		SetClientReady(iClient, true);
	}

	if (IsGameReady())
	{
		SetReadyState(State_Countdown);

		g_iTimer = g_iDelay;
		CreateTimer(1.0, Timer_Countdown, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}

	return Plugin_Handled;
}

/**
 *
 */
Action Cmd_Unready(int iClient, int iArgs)
{
	if (!IsModeNeedClientAction()) {
		return Plugin_Continue;
	}

	if (!IsReadyStateInProgress()) {
		return Plugin_Continue;
	}

	int iTeam = GetClientTeam(iClient);

	if (!IsValidTeam(iTeam)) {
		return Plugin_Continue;
	}

	if (!IsClientReady(iClient)) {
		return Plugin_Handled;
	}

	PlayNotifySound(iClient);

	if (g_eMode == Mode_PlayerReady) {
		SetTeamReady(iTeam, false);
	} else {
		SetClientReady(iClient, false);
	}

	if (IsReadyStateCountdown())
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
		{
			if (!IsClientInGame(iPlayer)
			|| IsFakeClient(iPlayer)
			|| !IsValidTeam(GetClientTeam(iPlayer))) {
				continue;
			}

			CPrintToChat(iPlayer, "%T%T", "TAG", iPlayer, "STOP_COUNTDOWN_PLAYER_UNREADY", iPlayer, iClient);
		}

		SetReadyState(State_UnReady);
	}

	return Plugin_Handled;
}

/**
 *
 */
Action Vote_Callback(int iClient, const char[] sCmd, int iArgs)
{
	if (!IsModeNeedClientAction()) {
		return Plugin_Continue;
	}

	if (!IsReadyStateInProgress()) {
		return Plugin_Continue;
	}

	if (NativeVotes_IsVoteInProgress()) {
		return Plugin_Continue;
	}

	char sArg[8]; GetCmdArg(1, sArg, sizeof(sArg));

	if (strcmp(sArg, "Yes", false) == 0) {
		Cmd_Ready(iClient, 0);
	}

	else if (strcmp(sArg, "No", false) == 0) {
		Cmd_Unready(iClient, 0);
	}

	return Plugin_Continue;
}

/**
 *
 */
public void OnPlayerRunCmdPost(int iClient, int iButtons, int impulse,
	const float vel[3], const float angles[3], int weapon, int subtype,
	int cmdnum, int tickcount, int seed, const int iMouse[2])
{
	if (!IsReadyStateInProgress()) {
		return;
	}

	if (!IsClientInGame(iClient)) {
		return;
	}

	if (!IsFakeClient(iClient))
	{
		static int iLastMouse[MAXPLAYERS + 1][2];

		// iMouse Movement Check
		if (iMouse[0] != iLastMouse[iClient][0] || iMouse[1] != iLastMouse[iClient][1])
		{
			iLastMouse[iClient][0] = iMouse[0];
			iLastMouse[iClient][1] = iMouse[1];
			UpdateClientActivity(iClient);
		}

		else if (iButtons || impulse) {
			UpdateClientActivity(iClient);
		}
	}

	if (GetEntProp(iClient, Prop_Send, "m_nWaterLevel") == WATER_LEVEL_EYES) {
		ReturnClientToSaferoom(iClient);
	}
}

/**
 *
 */
Panel BuildPanel(int iClient)
{
	Panel hPanel = CreatePanel();

	/*
	 * Header.
	 */
	int iHeaderSize = GetArraySize(g_hPanelHeader);

	if (iHeaderSize > 0)
	{
		char sHeader[64];

		for (int iIndex = 0; iIndex < iHeaderSize; iIndex ++)
		{
			if (ExecuteForward_OnPreparePanelItem(PanelPos_Header, iClient, iIndex) != Plugin_Continue) {
				continue;
			}

			GetArrayString(g_hPanelHeader, iIndex, sHeader, sizeof(sHeader));
			DrawPanelText(hPanel, sHeader);
		}

		DrawPanelSpace(hPanel);
	}

	int iPlayers[4][MAXPLAYERS + 1];
	int iTotalPlayers[4] = {0, ...};

	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
	{
		if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)) {
			continue;
		}

		int iPlayerTeam = GetClientTeam(iPlayer);

		iPlayers[iPlayerTeam][iTotalPlayers[iPlayerTeam] ++] = iPlayer;
	}

	char sPanelPlayerReady[16]; FormatEx(sPanelPlayerReady, sizeof(sPanelPlayerReady), "%T", "PANEL_PLAYER_READY", iClient);
	char sPanelPlayerUnready[16]; FormatEx(sPanelPlayerUnready, sizeof(sPanelPlayerUnready), "%T", "PANEL_PLAYER_UNREADY", iClient);

	int iBlock = 0;
	char sBlockName[64];

	char sPlayerName[MAX_NAME_LENGTH];
	char sPlayerAfk[16];

	int iFullTeam[4];
	iFullTeam[TEAM_SURVIVOR] = GetConVarInt(g_cvSurvivorLimit);
	iFullTeam[TEAM_INFECTED] = GetConVarInt(g_cvMaxPlayerZombies);

	for (int iTeam = TEAM_SURVIVOR; iTeam <= TEAM_INFECTED; iTeam ++)
	{
		FormatEx(sBlockName, sizeof(sBlockName), "%T", PANEL_BLOCK_NAME[iBlock], iClient);

		DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_TEAM", iClient, iBlock + 1, sBlockName, iTotalPlayers[iTeam], iFullTeam[iTeam]);

		for (int iPlayer = 0; iPlayer < iTotalPlayers[iTeam]; iPlayer ++)
		{
			GetClientFixedName(iPlayers[iTeam][iPlayer], sPlayerName, sizeof(sPlayerName));

			if (IsClientAfk(iPlayers[iTeam][iPlayer])) {
				FormatEx(sPlayerAfk, sizeof(sPlayerAfk), "%T", "PANEL_BLOCK_AFK", iClient);
			} else {
				sPlayerAfk[0] = '\0';
			}

			DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
				(IsClientReady(iPlayers[iTeam][iPlayer]) || g_eMode == Mode_AlwaysReady) ? sPanelPlayerReady : sPanelPlayerUnready,
				sPlayerAfk,
				sPlayerName
			);
		}

		if (!iBlock) {
			DrawPanelSpace(hPanel);
		}

		iBlock ++;
	}

	if (g_bCasterAvailable)
	{
		int iCaster[MAXPLAYERS + 1];
		int iTotalCasters = 0;

		for (int iPlayer = 0; iPlayer < iTotalPlayers[TEAM_SPECTATOR]; iPlayer ++)
		{
			if (!IsClientCaster(iPlayers[TEAM_SPECTATOR][iPlayer])) {
				continue;
			}

			iCaster[iTotalCasters ++] = iPlayers[TEAM_SPECTATOR][iPlayer];
		}

		if (iTotalCasters > 0)
		{
			DrawPanelSpace(hPanel);
			FormatEx(sBlockName, sizeof(sBlockName), "%T", PANEL_BLOCK_NAME[iBlock], iClient);

			DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_TEAM_SHORT", iClient, iBlock + 1, sBlockName);

			for (int iPlayer = 0; iPlayer < iTotalCasters; iPlayer ++)
			{
				GetClientFixedName(iCaster[iPlayer], sPlayerName, sizeof(sPlayerName));

				if (IsClientAfk(iCaster[iPlayer])) {
					FormatEx(sPlayerAfk, sizeof(sPlayerAfk), "%T", "PANEL_BLOCK_AFK", iClient);
				} else {
					sPlayerAfk[0] = '\0';
				}

				DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
					sPanelPlayerReady,
					sPlayerAfk,
					sPlayerName
				);
			}
		}
	}

	/*
	 * Footer.
	 */
	int iFooterSize = GetArraySize(g_hPanelFooter);

	if (iFooterSize > 0)
	{
		DrawPanelSpace(hPanel);

		char sFooter[64];

		for (int iIndex = 0; iIndex < iFooterSize; iIndex ++)
		{
			if (ExecuteForward_OnPreparePanelItem(PanelPos_Footer, iClient, iIndex) != Plugin_Continue) {
				continue;
			}

			GetArrayString(g_hPanelFooter, iIndex, sFooter, sizeof(sFooter));
			DrawPanelText(hPanel, sFooter);
		}
	}

	return hPanel;
}

/**
 *
 */
int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { return 0; }

/**
 *
 */
bool DrawPanelFormatText(Handle hPanel, const char[] sText, any ...)
{
	char sFormatText[128];
	VFormat(sFormatText, sizeof(sFormatText), sText, 3);
	return DrawPanelText(hPanel, sFormatText);
}

/**
 *
 */
bool IsValidTeam(int iTeam) {
	return (iTeam == TEAM_SURVIVOR || iTeam == TEAM_INFECTED);
}

/**
 *
 */
bool IsTeamReady(int iTeam)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
			continue;
		}

		if (GetClientTeam(iClient) == iTeam && !IsClientReady(iClient)) {
			return false;
		}
	}

	return true;
}

/**
 *
 */
bool SetTeamReady(int iTeam, bool bReady)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) != iTeam) {
			continue;
		}

		SetClientReady(iClient, bReady);
	}

	return true;
}

/**
 *
 */
bool IsGameReady() {
	return IsTeamReady(TEAM_INFECTED) && IsTeamReady(TEAM_SURVIVOR);
}

/**
 *
 */
bool IsClientPanelVisible(int iClient) {
	return g_bClientPanelVisible[iClient];
}

/**
 *
 */
void SetClientPanelVisible(int iClient, bool bVisible) {
	g_bClientPanelVisible[iClient] = bVisible;
}

/**
 *
 */
void UpdateClientActivity(int iClient) {
	g_fLastClientActivityTime[iClient] = GetEngineTime();
}

/**
 *
 */
float GetClientAfkTime(int iClient) {
	return GetEngineTime() - g_fLastClientActivityTime[iClient];
}

/**
 *
 */
bool IsClientAfk(int iClient) {
	return GetClientAfkTime(iClient) > g_fAfkDuration;
}

/**
 *
 */
void DisableForceStartTime() {
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.9);
}

/**
 *
 */
void EnableForceStartTime() {
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, GetConVarFloat(g_cvForceStartTime));
}

/**
 *
 */
bool IsModeNeedClientAction() {
	return (g_eMode == Mode_PlayerReady || g_eMode == Mode_TeamReady);
}

/**
 *
 */
void SetReadyState(State eState)
{
	State eOldState = g_eState;

	if (eOldState != eState) {
		ExecuteForward_OnChangeReadyState(eOldState, eState);
	}

	g_eState = eState;
}

/**
 *
 */
void ExecuteForward_OnChangeReadyState(State eOldState, State eNewState)
{
	if (GetForwardFunctionCount(g_fwdOnChangeReadyState))
	{
		Call_StartForward(g_fwdOnChangeReadyState);
		Call_PushCell(eOldState);
		Call_PushCell(eNewState);
		Call_Finish();
	}
}

/**
 *
 */
bool IsReadyStateInProgress() {
	return g_eState != State_None && g_eState != State_Ready;
}

/**
 *
 */
bool IsReadyStateCountdown() {
	return g_eState == State_Countdown;
}

/**
 *
 */
bool SetClientReady(int iClient, bool bReady)
{
	bool bBeforeReady = g_bClientReady[iClient];

	if ((bBeforeReady && !bReady) || (!bBeforeReady && bReady)) {
		ExecuteForward_OnChangeClientReady(iClient, bReady);
	}

	g_bClientReady[iClient] = bReady;

	return bBeforeReady != bReady;
}

/**
 *
 */
bool IsClientReady(int iClient) {
	return g_bClientReady[iClient];
}

/**
 *
 */
void ExecuteForward_OnChangeClientReady(int iClient, bool bReady)
{
	if (GetForwardFunctionCount(g_fwdOnChangeClientReady))
	{
		Call_StartForward(g_fwdOnChangeClientReady);
		Call_PushCell(iClient);
		Call_PushCell(bReady);
		Call_Finish();
	}
}

/**
 *
 */
Action ExecuteForward_OnPreparePanelItem(PanelPos ePos, int iClient, int iIndex)
{
	Action aReturn = Plugin_Continue;

	if (GetForwardFunctionCount(g_fwdOnPreparePanelItem))
	{
		Call_StartForward(g_fwdOnPreparePanelItem);
		Call_PushCell(ePos);
		Call_PushCell(iClient);
		Call_PushCell(iIndex);
		Call_Finish(aReturn);
	}

	return aReturn;
}

/**
 *
 */
void ExecuteForward_OnRemovePanelItem(PanelPos ePos, int iOldIndex, int iNewIndex)
{
	if (GetForwardFunctionCount(g_fwdOnRemovePanelItem))
	{
		Call_StartForward(g_fwdOnRemovePanelItem);
		Call_PushCell(ePos);
		Call_PushCell(iOldIndex);
		Call_PushCell(iNewIndex);
		Call_Finish();
	}
}

/**
 *
 */
void PlayLiveSound()
{
	if (IsSoundEnabled()) {
		EmitSoundToAll(g_sLiveSound, .volume = 0.5);
	}
}

/**
 *
 */
void PlayCountdownSound()
{
	if (IsSoundEnabled()) {
		EmitSoundToAll(g_sCountdownSound, .volume = 0.5);
	}
}

/**
 *
 */
void PlayNotifySound(int iClient)
{
	if (IsSoundEnabled()) {
		EmitSoundToClient(iClient, g_sNotifySound);
	}
}

/**
 *
 */
bool IsSoundEnabled() {
	return GetConVarBool(g_cvSoundEnable);
}

/**
 *
 */
bool IsSoundExists(const char[] sSoundPath)
{
	char szPath[PLATFORM_MAX_PATH];
	FormatEx(szPath, sizeof(szPath), "sound/%s", sSoundPath);

	return (FileExists(szPath, true));
}

/**
 *
 */
void GetClientFixedName(int iClient, char[] sName, int iLength)
{
	GetClientName(iClient, sName, iLength);
	ReplaceString(sName, iLength, "#", "_");
}

/**
 *
 */
void ReturnSurvivorToSaferoom()
{
	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (!IsClientInGame(iClient) || !IsClientSurvivor(iClient)) {
			continue;
		}

		ReturnClientToSaferoom(iClient);
	}
}

void SetConVarStringSilence(Handle hConVar, const char[] sValue)
{
	int iFlags = GetConVarFlags(hConVar);
	SetConVarFlags(hConVar, iFlags & ~FCVAR_NOTIFY);
	SetConVarString(hConVar, sValue, .notify = false);
	SetConVarFlags(hConVar, iFlags);
}

/**
 *
 */
void ReturnClientToSaferoom(int iClient)
{
	int iFlags = GetCommandFlags("warp_to_start_area");

	SetCommandFlags("warp_to_start_area", iFlags & ~FCVAR_CHEAT);

	if (GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge")) {
		L4D_ReviveSurvivor(iClient);
	}

	FakeClientCommand(iClient, "warp_to_start_area");

	SetCommandFlags("warp_to_start_area", iFlags);

	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, {0.0, 0.0, 0.0});
	SetEntPropFloat(iClient, Prop_Send, "m_flFallVelocity", 0.0);
}

/**
 *
 */
bool IsAnyPlayerLoading()
{
	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (IsClientConnected(iClient)
		&& (!IsClientInGame(iClient) || GetClientTeam(iClient) == TEAM_NONE)) {
			return true;
		}
	}

	return false;
}

/**
 *
 */
int IsEmptyServer()
{
	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
			continue;
		}

		return false;
	}

	return true;
}

/**
 *
 */
bool IsValidClient(int iClient) {
	return (iClient > 0 && iClient <= MaxClients);
}

/**
 * Survivor team player?
 */
bool IsClientSurvivor(int iClient) {
	return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}
