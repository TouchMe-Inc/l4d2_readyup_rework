#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <nativevotes_rework>
#include <colors>

#undef REQUIRE_PLUGIN
#include <caster_system>
#define REQUIRE_PLUGIN


public Plugin myinfo = {
    name        = "ReadyupRework",
    author      = "CanadaRox, TouchMe",
    description = "The plugin allows you to control the moment the round starts",
    version     = "build_0009",
    url         = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
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
 * Sound for precache.
 */
#define DEFAULT_NOTIFY_SOUND    "buttons/button14.wav"
#define DEFAULT_COUNTDOWN_SOUND "weapons/hegrenade/beep.wav"
#define DEFAULT_LIVE_SOUND      "ui/survival_medal.wav"

/**
 * Teams.
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
 * Native error messages.
 */
#define ERROR_INVALID_INDEX    "Invalid client index %d"
#define ERROR_INVALID_CLIENT   "Client %d is not in game"
#define ERROR_INDEX_OUT_BOUND  "Array index out bound"

/**
 * Silent cvar.
 */
#define CVAR_DISABLE           "0"
#define CVAR_ENABLE            "1"

#define MAXSIZE_SHORT_NAME     18


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

enum Switcher
{
    Enable,
    Disable
}

enum PanelPos
{
    PanelPos_Header = 0,
    PanelPos_Footer
}

GlobalForward
    g_fwdOnChangeReadyState = null,
    g_fwdOnChangeClientReady = null,
    g_fwdOnPrepareReadyUpItem = null,
    g_fwdOnRemoveReadyUpItem = null
;

ConVar
    g_cvGod = null,
    g_cvPlayerStop = null,
    g_cvInfinitePrimaryAmmo = null,
    g_cvVersusForceStartTime = null,
    g_cvScavengeRoundInitialTime = null,
    g_cvScavengeRoundSetupTime = null,
    g_cvTeamSize = null,

    g_cvReadyupMode = null,
    g_cvStrict = null,
    g_cvDelay = null,
    g_cvAutoStartDelay = null,
    g_cvAfkDuration = null,

    g_cvSoundEnable = null,
    g_cvSoundNotify = null,
    g_cvSoundCountdown = null,
    g_cvSoundLive = null,

    g_cvSpamCooldownInitial = null,
    g_cvSpamCooldownIncrement = null,
    g_cvMaxAttemptsBeforeIncrement = null
;

char
    g_sNotifySound[PLATFORM_MAX_PATH],
    g_sCountdownSound[PLATFORM_MAX_PATH],
    g_sLiveSound[PLATFORM_MAX_PATH]
;

bool g_bStrict = false;

int
    g_iStartDelay = 0,
    g_iCountdownTimer = 0,
    g_iAutoStartDelay = 0,
    g_iAutoStartTimer = 0
;

int g_iPlayerLoading = 0;

float g_fAfkDuration = 0.0;

float g_fLastClientActivityTime[MAXPLAYERS + 1] = {0.0, ...};

bool
    g_bClientReady[MAXPLAYERS + 1] = {false, ...},
    g_bClientReadyUpVisible[MAXPLAYERS + 1] = {false, ...}
;

float g_fSpamCooldownInitial = 0.0;
float g_fSpamCooldownIncrement = 0.0;
int g_iMaxAttempts = 0;

float g_fClientCommandSpamCooldown[MAXPLAYERS + 1];
int g_iClientCommandSpamAttempts[MAXPLAYERS + 1];

bool g_bForceStarted = false;

bool g_bCasterAvailable = false; /**< Caster System */

ReadyupState g_eReadyupState = ReadyupState_None;

ReadyupMode g_eReadyupMode = ReadyupMode_AlwaysReady;

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
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    /*
     * Natives.
     */
    CreateNative("GetReadyState", Native_GetReadyState);
    CreateNative("GetReadyMode", Native_GetReadyMode);
    CreateNative("IsClientReady", Native_IsClientReady);
    CreateNative("SetClientReady", Native_SetClientReady);
    CreateNative("IsClientReadyUpVisible", Native_IsClientReadyUpVisible);
    CreateNative("SetClientReadyUpVisible", Native_SetClientReadyUpVisible);
    CreateNative("PushReadyUpItem", Native_PushReadyUpItem);
    CreateNative("UpdateReadyUpItem", Native_UpdateReadyUpItem);
    CreateNative("RemoveReadyUpItem", Native_RemoveReadyUpItem);

    /*
     * Forwards.
     */
    g_fwdOnChangeReadyState   = CreateGlobalForward("OnChangeReadyState", ET_Ignore, Param_Cell, Param_Cell);
    g_fwdOnChangeClientReady  = CreateGlobalForward("OnChangeClientReady", ET_Ignore, Param_Cell, Param_Cell);
    g_fwdOnPrepareReadyUpItem = CreateGlobalForward("OnPrepareReadyUpItem", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
    g_fwdOnRemoveReadyUpItem  = CreateGlobalForward("OnRemoveReadyUpItem", ET_Ignore, Param_Cell, Param_Cell);

    /*
     * Library.
     */
    RegPluginLibrary("readyup_rework");

    return APLRes_Success;
}

any Native_GetReadyState(Handle hPlugin, int iParams) {
    return g_eReadyupState;
}

any Native_GetReadyMode(Handle hPlugin, int iParams) {
    return g_eReadyupMode;
}

any Native_IsClientReady(Handle hPlugin, int iParams)
{
    int iClient = GetNativeCell(1);

    if (!IsValidClient(iClient)) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INVALID_INDEX, iClient);
    }

    if (!IsClientInGame(iClient)) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INVALID_CLIENT, iClient);
    }

    return IsClientReady(iClient);
}

any Native_SetClientReady(Handle hPlugin, int iParams)
{
    int iClient = GetNativeCell(1);

    if (!IsValidClient(iClient)) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INVALID_INDEX, iClient);
    }

    if (!IsClientInGame(iClient)) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INVALID_CLIENT, iClient);
    }

    bool bReady = GetNativeCell(2);

    return SetClientReady(iClient, bReady);
}

any Native_IsClientReadyUpVisible(Handle hPlugin, int iParams)
{
    int iClient = GetNativeCell(1);

    if (!IsValidClient(iClient)) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INVALID_INDEX, iClient);
    }

    if (!IsClientInGame(iClient)) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INVALID_CLIENT, iClient);
    }

    return IsClientReadyUpVisible(iClient);
}

any Native_SetClientReadyUpVisible(Handle hPlugin, int iParams)
{
    int iClient = GetNativeCell(1);

    if (!IsValidClient(iClient)) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INVALID_INDEX, iClient);
    }

    if (!IsClientInGame(iClient)) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INVALID_CLIENT, iClient);
    }

    bool bVisible = GetNativeCell(2);

    SetClientReadyUpVisible(iClient, bVisible);

    return 0;
}

any Native_PushReadyUpItem(Handle hPlugin, int iParams)
{
    PanelPos ePos = GetNativeCell(1);

    Handle hItems = (ePos == PanelPos_Header) ? g_hPanelHeader : g_hPanelFooter;

    char szBuffer[64]; FormatNativeString(0, 2, 3, sizeof(szBuffer), _, szBuffer);

    return PushArrayString(hItems, szBuffer);
}

any Native_UpdateReadyUpItem(Handle hPlugin, int iParams)
{
    PanelPos ePos = GetNativeCell(1);

    Handle hItems = (ePos == PanelPos_Header) ? g_hPanelHeader : g_hPanelFooter;

    int iTargetIndex = GetNativeCell(2);

    int iItemCount = GetArraySize(hItems);

    if (iTargetIndex >= iItemCount) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INDEX_OUT_BOUND);
    }

    char szBuffer[64]; FormatNativeString(0, 3, 4, sizeof(szBuffer), _, szBuffer);

    SetArrayString(hItems, iTargetIndex, szBuffer);

    return 0;
}

any Native_RemoveReadyUpItem(Handle hPlugin, int iParams)
{
    PanelPos ePos = GetNativeCell(1);

    Handle hItems = (ePos == PanelPos_Header) ? g_hPanelHeader : g_hPanelFooter;

    int iTargetIndex = GetNativeCell(2);

    int iItemCount = GetArraySize(hItems);

    if (iTargetIndex >= iItemCount) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INDEX_OUT_BOUND);
    }

    for (int iIndex = iTargetIndex + 1; iIndex < iItemCount; iIndex ++)
    {
        ExecuteForward_OnRemoveReadyUpItem(ePos, iIndex, iIndex - 1);
    }

    RemoveFromArray(hItems, iTargetIndex);

    return 0;
}

/**
 * Called when the map is loaded.
 */
public void OnMapStart()
{
    GetConVarString(g_cvSoundNotify, g_sNotifySound, sizeof(g_sNotifySound));
    if (!IsSoundExists(g_sNotifySound)) {
        strcopy(g_sNotifySound, sizeof(g_sNotifySound), DEFAULT_NOTIFY_SOUND);
    }
    PrecacheSound(g_sNotifySound);

    GetConVarString(g_cvSoundCountdown, g_sCountdownSound, sizeof(g_sCountdownSound));
    if (!IsSoundExists(g_sCountdownSound)) {
        strcopy(g_sCountdownSound, sizeof(g_sCountdownSound), DEFAULT_COUNTDOWN_SOUND);
    }
    PrecacheSound(g_sCountdownSound);

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

    /*
     * Find and Create ConVars.
     */
    g_cvGod = FindConVar("god");
    g_cvPlayerStop = FindConVar("nb_player_stop");
    g_cvInfinitePrimaryAmmo = FindConVar("sv_infinite_primary_ammo");
    g_cvVersusForceStartTime = FindConVar("versus_force_start_time");
    g_cvScavengeRoundInitialTime = FindConVar("scavenge_round_initial_time");
    g_cvScavengeRoundSetupTime = FindConVar("scavenge_round_setup_time");
    g_cvTeamSize = FindConVar("survivor_limit");

    g_cvSoundEnable    = CreateConVar("sm_readyup_sound_enable", "1", "Enable sounds played to clients", _, true, 0.0, true, 1.0);
    g_cvSoundNotify    = CreateConVar("sm_readyup_sound_notify", DEFAULT_NOTIFY_SOUND, "Path to the sound that is played when the client status changes");
    g_cvSoundCountdown = CreateConVar("sm_readyup_sound_countdown", DEFAULT_COUNTDOWN_SOUND, "The sound that plays when a round goes on countdown");
    g_cvSoundLive      = CreateConVar("sm_readyup_sound_live", DEFAULT_LIVE_SOUND, "The sound that plays when a round goes live");

    g_cvReadyupMode    = CreateConVar("sm_readyup_mode", "2", "Plugin operating mode (Values: 0 = Disabled, 1 = Auto start, 2 = Player ready, 3 = Team ready)", _, true, 0.0, true, 3.0);
    g_cvStrict         = CreateConVar("sm_readyup_strict", "0", "Team with strict mode (Values: 0 = Disabled, 1 = Enabled)", _, true, 0.0, true, 1.0);
    g_cvDelay          = CreateConVar("sm_readyup_delay", "3", "Number of seconds to count down before the round goes live", _, true, 0.0);
    g_cvAutoStartDelay = CreateConVar("sm_readyup_autostart_delay", "20.0", "Number of seconds before forced automatic start (only sm_readyup_mode 1)", _, true, 0.0);
    g_cvAfkDuration    = CreateConVar("sm_readyup_afk_duration", "15.0", "Number of seconds since the player's last activity to count his afk", _, true, 1.0);

    g_cvSpamCooldownInitial = CreateConVar("sm_readyup_spam_cd_init", "2.0", "Initial cooldown time in seconds", _, true, 0.0);
    g_cvSpamCooldownIncrement = CreateConVar("sm_readyup_spam_cd_inc", "1.0", "Cooldown increment time in seconds", _, true,  0.0);
    g_cvMaxAttemptsBeforeIncrement = CreateConVar("sm_readyup_spam_attempts_before_inc", "2", "Maximum number of attempts before increasing cooldown", _, true, 10.0);

    /*
     * Register ConVar change callbacks.
     */
    HookConVarChange(g_cvReadyupMode, OnModeChanged);
    HookConVarChange(g_cvStrict, OnStrictChanged);
    HookConVarChange(g_cvDelay, OnDelayChanged);
    HookConVarChange(g_cvAutoStartDelay, OnAutoStartDelayChanged);
    HookConVarChange(g_cvAfkDuration, OnAfkDurationChanged);

    HookConVarChange(g_cvSpamCooldownInitial, OnInitialSpamCooldownChanged);
    HookConVarChange(g_cvSpamCooldownIncrement, OnSpamCooldownIncrementChanged);
    HookConVarChange(g_cvMaxAttemptsBeforeIncrement, OnMaxAttemptsBeforeIncementChanged);

    /*
     * Player Commands.
     */
    RegConsoleCmd("sm_readyup", Cmd_TogglePanel, "Show/hide the readyup panel");
    RegConsoleCmd("sm_return",  Cmd_ReturnToSaferoom, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
    RegConsoleCmd("sm_ready",   Cmd_Ready, "Mark yourself as ready for the round to go live");
    RegConsoleCmd("sm_r",       Cmd_Ready, "Mark yourself as ready for the round to go live");
    RegConsoleCmd("sm_unready", Cmd_Unready, "Mark yourself as not ready if you have set yourself as ready");
    RegConsoleCmd("sm_nr",      Cmd_Unready, "Mark yourself as not ready if you have set yourself as ready");
    RegAdminCmd("sm_forcestart",Cmd_ForceStart, ADMFLAG_BAN, "Forces the round to start regardless of player ready status");
    RegAdminCmd("sm_fs",        Cmd_ForceStart, ADMFLAG_BAN, "Forces the round to start regardless of player ready status");
    AddCommandListener(Vote_Callback, "Vote"); // Hook vote <KEY_F1> or <KEY_F2>.

    /*
     * Events.
     */
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("survival_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("gameinstructor_draw",   Event_GameInstructorDraw, EventHookMode_PostNoCopy);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);

    /*
     * Initialize variables with ConVar values.
     */
    g_eReadyupMode    = view_as<ReadyupMode>(GetConVarInt(g_cvReadyupMode));
    g_bStrict         = GetConVarBool(g_cvStrict);
    g_iStartDelay     = GetConVarInt(g_cvDelay);
    g_iAutoStartDelay = GetConVarInt(g_cvAutoStartDelay);
    g_fAfkDuration    = GetConVarFloat(g_cvAfkDuration);

    g_fSpamCooldownInitial = GetConVarFloat(g_cvSpamCooldownInitial);
    g_fSpamCooldownIncrement = GetConVarFloat(g_cvSpamCooldownIncrement);
    g_iMaxAttempts = GetConVarInt(g_cvMaxAttemptsBeforeIncrement);

    /*
     * Init hud arrays.
     */
    g_hPanelHeader = CreateArray(ByteCountToCells(64));
    g_hPanelFooter = CreateArray(ByteCountToCells(64));
}

/**
 *
 */
public void OnPluginEnd()
{
    SetConVarStringSilence(g_cvGod, CVAR_DISABLE);
    SetConVarStringSilence(g_cvInfinitePrimaryAmmo, CVAR_DISABLE);
    SetConVarStringSilence(g_cvPlayerStop, CVAR_DISABLE);

    if (g_eReadyupState == ReadyupState_None) {
        return;
    }

    SetVersusForceStartTime(Enable);
    ReturnSurvivorToSaferoom();
}

/**
 *
 */
void OnModeChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue)
{
    ReadyupMode eOldReadyupMode = g_eReadyupMode;
    ReadyupMode eNewReadyupMode = view_as<ReadyupMode>(GetConVarInt(g_cvReadyupMode));

    if (eOldReadyupMode == eNewReadyupMode) {
        return;
    }

    if (g_eReadyupState == ReadyupState_None)
    {
        g_eReadyupMode = eNewReadyupMode;
        return;
    }

    g_eReadyupState = ReadyupState_None;
    g_eReadyupMode = eNewReadyupMode;

    CreateTimer(1.0, Timer_OnModeChanged, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_OnModeChanged(Handle hTimer)
{
    InitReadyup();
    return Plugin_Stop;
}

/**
 *
 */
void OnStrictChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bStrict = GetConVarBool(cv);
}

/**
 *
 */
void OnDelayChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_iStartDelay = GetConVarInt(cv);
}

/**
 *
 */
void OnAutoStartDelayChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_iAutoStartDelay = GetConVarInt(cv);
}

/**
 *
 */
void OnAfkDurationChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_fAfkDuration = GetConVarFloat(cv);
}

/**
 *
 */
void OnInitialSpamCooldownChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_fSpamCooldownInitial = GetConVarFloat(cv);
}

/**
 *
 */
void OnSpamCooldownIncrementChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_fSpamCooldownIncrement = GetConVarFloat(cv);
}

/**
 *
 */
void OnMaxAttemptsBeforeIncementChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_iMaxAttempts = GetConVarInt(cv);
}

/**
 *
 */
public Action L4D_OnFirstSurvivorLeftSafeArea(int iClient)
{
    if (IsReadyStateInProgress())
    {
        ReturnClientToSaferoom(iClient);
        CreateTimer(0.1, Timer_DisableGameplayTimers, .flags = TIMER_FLAG_NO_MAPCHANGE);

        return Plugin_Handled;
    }

    SetConVarStringSilence(g_cvGod, CVAR_DISABLE);
    SetConVarStringSilence(g_cvInfinitePrimaryAmmo, CVAR_DISABLE);
    SetConVarStringSilence(g_cvPlayerStop, CVAR_DISABLE);

    SetReadyState(ReadyupState_None);

    return Plugin_Continue;
}

/**
 *
 */
void Event_RoundStart(Event event, const char[] szName, bool bDontBroadcast) {
    InitReadyup();
}

void InitReadyup()
{
    CreateTimer(1.0, Timer_DisableGameplayTimers, .flags = TIMER_FLAG_NO_MAPCHANGE);

    // ConVars.
    SetConVarStringSilence(g_cvGod, CVAR_ENABLE);
    SetConVarStringSilence(g_cvInfinitePrimaryAmmo, CVAR_ENABLE);
    SetConVarStringSilence(g_cvPlayerStop, CVAR_ENABLE);

    // Reset client ready status.
    for (int iClient = 1; iClient <= MaxClients; iClient ++)
    {
        g_bClientReady[iClient] = false;
        g_bClientReadyUpVisible[iClient] = true;
    }

    // Show panel.
    CreateTimer(1.0, Timer_UpdatePanel, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

    if (!InSecondHalfOfRound())
    {
        g_iPlayerLoading = GetLoadingPlayers();
        CreateTimer(1.0, Timer_HasPlayerLoading, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    }

    switch (g_eReadyupMode)
    {
        case ReadyupMode_AutoStart: {
            SetReadyState(ReadyupState_Countdown);

            g_iAutoStartTimer = g_iAutoStartDelay;
            CreateTimer(1.0, Timer_AutoStart, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
        }

        case ReadyupMode_AlwaysReady: SetReadyState(ReadyupState_Ready);

        default: SetReadyState(ReadyupState_UnReady);
    }

    g_bForceStarted = false;
}

/**
 *
 */
Action Timer_HasPlayerLoading(Handle hTimer)
{
    g_iPlayerLoading = GetLoadingPlayers();

    if (g_iPlayerLoading > 0) {
        return Plugin_Continue;
    }

    return Plugin_Stop;
}

/**
 *
 */
Action Timer_UpdatePanel(Handle hTimer)
{
    if (IsReadyState(ReadyupState_None)) {
        return Plugin_Stop;
    }

    if (NativeVotes_IsVoteInProgress()) {
        return Plugin_Continue;
    }

    for (int iClient = 1; iClient <= MaxClients; iClient ++)
    {
        if (!IsClientInGame(iClient)
        || (IsFakeClient(iClient) && !IsClientSourceTV(iClient))
        || !IsClientReadyUpVisible(iClient)) {
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
Action Timer_AutoStart(Handle hTimer)
{
    if (!IsReadyState(ReadyupState_Countdown)) {
        return Plugin_Stop;
    }

    if (IsEmptyServer())
    {
        g_iAutoStartTimer = g_iAutoStartDelay;

        return Plugin_Continue;
    }

    if (NeedWaitLoadingPlayers(g_iPlayerLoading)) {
        return Plugin_Continue;
    }

    if (g_iAutoStartTimer-- <= 0)
    {
        ReturnSurvivorToSaferoom();

        PlayLiveSound();

        SetReadyState(ReadyupState_Ready);

        return Plugin_Stop;
    }

    return Plugin_Continue;
}

/**
 *
 */
void Event_GameInstructorDraw(Event event, const char[] szName, bool bDontBroadcast) {
    CreateTimer(0.1, Timer_DisableGameplayTimers, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

/**
 *
 */
 Action Timer_DisableGameplayTimers(Handle hTimer)
 {
    if (L4D2_IsScavengeMode())
    {
        SetScavengeRoundSetupTimer(Disable);
        ResetAccumulatedTime();
    }
    else
    {
        SetVersusForceStartTime(Disable);
    }

    return Plugin_Stop;
 }

/**
 *
 */
Action Event_PlayerTeam(Event event, const char[] szName, bool bDontBroadcast)
{
    if (!IsModeNeedClientAction()) {
        return Plugin_Continue;
    }

    if (!IsReadyStateInProgress()) {
        return Plugin_Continue;
    }

    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!iClient || IsFakeClient(iClient)) {
        return Plugin_Continue;
    }

    if (g_bForceStarted) {
        return Plugin_Continue;
    }

    int iOldTeam = GetEventInt(event, "oldteam");

    char szPlayerName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, szPlayerName, sizeof(szPlayerName), MAXSIZE_SHORT_NAME);

    DataPack hPack = CreateDataPack();
    CreateDataTimer(0.1, Timer_PlayerTeam, hPack, TIMER_FLAG_NO_MAPCHANGE);
    WritePackCell(hPack, GetClientUserId(iClient));
    WritePackCell(hPack, iOldTeam);
    WritePackString(hPack, szPlayerName);

    return Plugin_Continue;
}

/**
 *
 */
Action Timer_PlayerTeam(Handle hTimer, DataPack hPack)
{
    if (!IsReadyStateInProgress()) {
        return Plugin_Stop;
    }

    ResetPack(hPack);

    int iClient = GetClientOfUserId(ReadPackCell(hPack));
    int iOldTeam = ReadPackCell(hPack);
    int iNewTeam = iClient > 0 && IsClientConnected(iClient) ? GetClientTeam(iClient) : TEAM_NONE;

    char szPlayerName[MAX_NAME_LENGTH];
    ReadPackString(hPack, szPlayerName, sizeof(szPlayerName));

    if (IsValidTeam(iOldTeam) || IsValidTeam(iNewTeam))
    {
        if (IsReadyupMode(ReadyupMode_PlayerReady))
        {
            SetTeamReady(iOldTeam, false);

            if (iNewTeam != TEAM_NONE) {
                SetTeamReady(iNewTeam, false);
            }
        }
        else
        {
            SetClientReady(iClient, false);
        }

        if (IsReadyState(ReadyupState_Countdown))
        {
            SetReadyState(ReadyupState_UnReady);

            for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
            {
                if (!IsClientInGame(iPlayer)
                || IsFakeClient(iPlayer)
                || !IsValidTeam(GetClientTeam(iPlayer))) {
                    continue;
                }

                CPrintToChat(iPlayer, "%T%T", "TAG", iPlayer, iNewTeam == TEAM_NONE ? "STOP_COUNTDOWN_PLAYER_DISCONNECT" : "STOP_COUNTDOWN_PLAYER_CHANGE_TEAM", iPlayer, szPlayerName);
            }
        }
    }

    return Plugin_Stop;
}

/**
 *
 */
Action Timer_Countdown(Handle hTimer)
{
    if (!IsReadyState(ReadyupState_Countdown)) {
        return Plugin_Stop;
    }

    if (g_iCountdownTimer-- <= 0)
    {
        ReturnSurvivorToSaferoom();

        PlayLiveSound();

        SetReadyState(ReadyupState_Ready);

        return Plugin_Stop;
    }

    PlayCountdownSound();

    return Plugin_Continue;
}

/**
 *
 */
Action Cmd_TogglePanel(int iClient, int iArgs)
{
    if (IsClientReadyUpVisible(iClient))
    {
        SetClientReadyUpVisible(iClient, false);
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "PANEL_DISABLED", iClient);
    }

    else
    {
        SetClientReadyUpVisible(iClient, true);
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "PANEL_ENABLED", iClient);
    }

    return Plugin_Handled;
}

/**
 *
 */
Action Cmd_ReturnToSaferoom(int iClient, int iArgs)
{
    if (IsReadyState(ReadyupState_None)) {
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
    if (!iClient || !IsClientInGame(iClient)) {
        return Plugin_Continue;
    }

    if (!IsModeNeedClientAction() || !IsReadyStateInProgress()) {
        return Plugin_Continue;
    }

    if (NeedWaitLoadingPlayers(g_iPlayerLoading)) {
        return Plugin_Continue;
    }

    int iTeam = GetClientTeam(iClient);

    if (!IsValidTeam(iTeam)) {
        return Plugin_Handled;
    }

    if (IsClientReady(iClient) || g_bForceStarted) {
        return Plugin_Handled;
    }

    switch (IsClientSpamCommand(iClient))
    {
        case 0:
        {
            CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND", iClient, GetClientCommandSpamCooldown(iClient));
            return Plugin_Handled;
        }

        case 1:
        {
            CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND_WITH_INC", iClient, GetClientCommandSpamCooldown(iClient), g_fSpamCooldownIncrement);
            return Plugin_Handled;
        }
    }

    PlayNotifySound(iClient);

    if (IsReadyupMode(ReadyupMode_PlayerReady))
    {
        if (!SetTeamReady(iTeam, true)) {
            SetTeamReady(iTeam, false);
        }
    } else {
        SetClientReady(iClient, true);
    }

    if (IsGameReady())
    {
        SetReadyState(ReadyupState_Countdown);

        g_iCountdownTimer = g_iStartDelay;
        CreateTimer(1.0, Timer_Countdown, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    }

    return Plugin_Handled;
}

/**
 *
 */
Action Cmd_Unready(int iClient, int iArgs)
{
    if (!iClient || !IsClientInGame(iClient)) {
        return Plugin_Continue;
    }

    if (!IsModeNeedClientAction() || !IsReadyStateInProgress()) {
        return Plugin_Continue;
    }

    if (NeedWaitLoadingPlayers(g_iPlayerLoading)) {
        return Plugin_Continue;
    }

    int iTeam = GetClientTeam(iClient);

    if (!IsValidTeam(iTeam)) {
        return Plugin_Handled;
    }

    if (!IsClientReady(iClient) || g_bForceStarted) {
        return Plugin_Handled;
    }

    switch (IsClientSpamCommand(iClient))
    {
        case 0:
        {
            CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND", iClient, GetClientCommandSpamCooldown(iClient));
            return Plugin_Handled;
        }

        case 1:
        {
            CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND_WITH_INC", iClient, GetClientCommandSpamCooldown(iClient), g_fSpamCooldownIncrement);
            return Plugin_Handled;
        }
    }

    PlayNotifySound(iClient);

    if (IsReadyupMode(ReadyupMode_PlayerReady)) {
        SetTeamReady(iTeam, false);
    } else {
        SetClientReady(iClient, false);
    }

    if (IsReadyState(ReadyupState_Countdown))
    {
        SetReadyState(ReadyupState_UnReady);

        char szPlayerName[MAX_NAME_LENGTH];
        GetClientNameFixed(iClient, szPlayerName, sizeof(szPlayerName), MAXSIZE_SHORT_NAME);

        for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
        {
            if (!IsClientInGame(iPlayer)
            || IsFakeClient(iPlayer)
            || !IsValidTeam(GetClientTeam(iPlayer))) {
                continue;
            }

            CPrintToChat(iPlayer, "%T%T", "TAG", iPlayer, "STOP_COUNTDOWN_PLAYER_UNREADY", iPlayer, szPlayerName);
        }
    }

    return Plugin_Handled;
}

/**
 *
 */
Action Cmd_ForceStart(int iClient, int args)
{
    if (!IsModeNeedClientAction() || !IsReadyState(ReadyupState_UnReady)) {
        return Plugin_Continue;
    }

    SetReadyState(ReadyupState_Countdown);

    g_iCountdownTimer = g_iStartDelay;
    CreateTimer(1.0, Timer_Countdown, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

    char szPlayerName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, szPlayerName, sizeof(szPlayerName), MAXSIZE_SHORT_NAME);

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer)
        || IsFakeClient(iPlayer)
        || !IsValidTeam(GetClientTeam(iPlayer))) {
            continue;
        }

        CPrintToChat(iPlayer, "%T%T", "TAG", iPlayer, "FORCE_START_BY_ADMIN", iPlayer, szPlayerName);
    }

    g_bForceStarted = true;

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

    char szArg[8]; GetCmdArg(1, szArg, sizeof(szArg));

    if (strcmp(szArg, "Yes", false) == 0) {
        Cmd_Ready(iClient, 0);
    }

    else if (strcmp(szArg, "No", false) == 0) {
        Cmd_Unready(iClient, 0);
    }

    return Plugin_Continue;
}

/**
 *
 */
public void OnPlayerRunCmdPost(int iClient, int iButtons, int iImpulse,
    const float vel[3], const float angles[3], int weapon, int subtype,
    int cmdnum, int tickcount, int seed, const int iMouse[2])
{
    if (IsReadyState(ReadyupState_None)) {
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

        else if (iButtons || iImpulse) {
            UpdateClientActivity(iClient);
        }
    }

    if (IsClientInWater(iClient)) {
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
        char szHeader[64];

        for (int iIndex = 0; iIndex < iHeaderSize; iIndex ++)
        {
            if (ExecuteForward_OnPrepareReadyUpItem(PanelPos_Header, iClient, iIndex) == Plugin_Continue) {
                continue;
            }

            GetArrayString(g_hPanelHeader, iIndex, szHeader, sizeof(szHeader));
            DrawPanelText(hPanel, szHeader);
        }

        DrawPanelSpace(hPanel);
    }

    /*
     * Body.
     */
    if (!IsReadyState(ReadyupState_Ready))
    {
        switch (g_eReadyupMode)
        {
            case ReadyupMode_AutoStart: DrawPanelBodyForAutoStart(hPanel, iClient);
            case ReadyupMode_PlayerReady: DrawPanelBodyForPlayerReady(hPanel, iClient);
            case ReadyupMode_TeamReady: DrawPanelBodyForTeamReady(hPanel, iClient);
        }
    }

    else DrawPanelFormatText(hPanel, "%T", "PANEL_ALREADY_READY", iClient);

    /*
     * Footer.
     */
    int iFooterSize = GetArraySize(g_hPanelFooter);

    if (iFooterSize > 0)
    {
        DrawPanelSpace(hPanel);

        char szFooter[64];

        for (int iIndex = 0; iIndex < iFooterSize; iIndex ++)
        {
            if (ExecuteForward_OnPrepareReadyUpItem(PanelPos_Footer, iClient, iIndex) == Plugin_Continue) {
                continue;
            }

            GetArrayString(g_hPanelFooter, iIndex, szFooter, sizeof(szFooter));
            DrawPanelText(hPanel, szFooter);
        }
    }

    return hPanel;
}

/**
 *
 */
int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { return 0; }

void DrawPanelBodyForAutoStart(Handle hPanel, int iClient)
{
    if (NeedWaitLoadingPlayers(g_iPlayerLoading)) {
        DrawPanelFormatText(hPanel, "%T", "PANEL_CONNECTING_DELAY", iClient, g_iPlayerLoading);
    } else {
        DrawPanelFormatText(hPanel, "%T", "PANEL_AUTOSTART_TIMER", iClient, g_iAutoStartTimer);
    }
}

void DrawPanelBodyForPlayerReady(Handle hPanel, int iClient)
{
    if (NeedWaitLoadingPlayers(g_iPlayerLoading))
    {
        DrawPanelFormatText(hPanel, "%T", "PANEL_CONNECTING_DELAY", iClient, g_iPlayerLoading);
        return;
    }

    if (IsReadyState(ReadyupState_Countdown))
    {
        DrawPanelFormatText(hPanel, "%T", "PANEL_COUNTDOWN", iClient, g_iCountdownTimer);
        return;
    }

    bool bSurvivorAfk = false;
    bool bInfectedAfk = false;

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer)|| IsFakeClient(iPlayer) || !IsClientAfk(iPlayer)) {
            continue;
        }

        int iPlayerTeam = GetClientTeam(iPlayer);

        if (iPlayerTeam == TEAM_SURVIVOR) {
            bSurvivorAfk = true;
        } else if (iPlayerTeam == TEAM_INFECTED) {
            bInfectedAfk = true;
        }
    }

    char szPanelMarkReady[8]; FormatEx(szPanelMarkReady, sizeof(szPanelMarkReady), "%T", "PANEL_MARK_READY", iClient);
    char szPanelMarkUnready[8]; FormatEx(szPanelMarkUnready, sizeof(szPanelMarkUnready), "%T", "PANEL_MARK_UNREADY", iClient);
    char szPanelMarkAfk[16]; FormatEx(szPanelMarkAfk, sizeof(szPanelMarkAfk), "%T", "PANEL_MARK_AFK", iClient);
    char sSurvivorTeam[64]; FormatEx(sSurvivorTeam, sizeof(sSurvivorTeam), "%T", "PANEL_SURVIVOR_TEAM", iClient);
    char szInfectedTeam[64]; FormatEx(szInfectedTeam, sizeof(szInfectedTeam), "%T", "PANEL_INFECTED_TEAM", iClient);

    DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
        IsTeamReady(TEAM_SURVIVOR) ? szPanelMarkReady : szPanelMarkUnready,
        bSurvivorAfk ? szPanelMarkAfk : "",
        sSurvivorTeam
    );

    DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
        IsTeamReady(TEAM_INFECTED) ? szPanelMarkReady : szPanelMarkUnready,
        bInfectedAfk ? szPanelMarkAfk : "",
        szInfectedTeam
    );
}

void DrawPanelBodyForTeamReady(Handle hPanel, int iClient)
{
    if (NeedWaitLoadingPlayers(g_iPlayerLoading))
    {
        DrawPanelFormatText(hPanel, "%T", "PANEL_CONNECTING_DELAY", iClient, g_iPlayerLoading);
        return;
    }

    if (IsReadyState(ReadyupState_Countdown))
    {
        DrawPanelFormatText(hPanel, "%T", "PANEL_COUNTDOWN", iClient, g_iCountdownTimer);
        return;
    }

    char PANEL_BLOCK_NAME[][] = {
        "PANEL_SURVIVOR_TEAM", "PANEL_INFECTED_TEAM", "PANEL_CASTER_TEAM"
    };

    char szPanelMarkReady[8]; FormatEx(szPanelMarkReady, sizeof(szPanelMarkReady), "%T", "PANEL_MARK_READY", iClient);
    char szPanelMarkUnready[8]; FormatEx(szPanelMarkUnready, sizeof(szPanelMarkUnready), "%T", "PANEL_MARK_UNREADY", iClient);
    char szPanelMarkAfk[16]; FormatEx(szPanelMarkAfk, sizeof(szPanelMarkAfk), "%T", "PANEL_MARK_AFK", iClient);

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

    int iBlock = 0;
    char szBlockName[64];

    char szPlayerName[MAX_NAME_LENGTH];

    for (int iTeam = TEAM_SURVIVOR; iTeam <= TEAM_INFECTED; iTeam ++)
    {
        FormatEx(szBlockName, sizeof(szBlockName), "%T", PANEL_BLOCK_NAME[iBlock], iClient);

        DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_TEAM", iClient, iBlock + 1, szBlockName);

        for (int iPlayer = 0; iPlayer < iTotalPlayers[iTeam]; iPlayer ++)
        {
            GetClientNameFixed(iPlayers[iTeam][iPlayer], szPlayerName, sizeof szPlayerName, MAXSIZE_SHORT_NAME);

            DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
                IsClientReady(iPlayers[iTeam][iPlayer]) ? szPanelMarkReady : szPanelMarkUnready,
                IsClientAfk(iPlayers[iTeam][iPlayer]) ? szPanelMarkAfk : "",
                szPlayerName
            );
        }

        if (g_bStrict)
        {
            int iTeamSize = g_cvTeamSize.IntValue;
            int iDots = GetTime() % 4;
            Format(szPlayerName, sizeof szPlayerName, "%s",
                iDots == 0 ? "▪" :
                iDots == 1 ? "▫▪" :
                iDots == 2 ? "▫▫▪" :
                ""
            );

            for (int iPlayer = iTotalPlayers[iTeam]; iPlayer < iTeamSize; iPlayer ++)
            {
                DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
                    szPanelMarkUnready,
                    "",
                    szPlayerName
                );
            }
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
            FormatEx(szBlockName, sizeof szBlockName, "%T", PANEL_BLOCK_NAME[iBlock], iClient);

            DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_TEAM", iClient, iBlock + 1, szBlockName);

            for (int iPlayer = 0; iPlayer < iTotalCasters; iPlayer ++)
            {
                GetClientNameFixed(iCaster[iPlayer], szPlayerName, sizeof(szPlayerName), MAXSIZE_SHORT_NAME);

                DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
                    szPanelMarkReady,
                    IsClientAfk(iCaster[iPlayer]) ? szPanelMarkAfk : "",
                    szPlayerName
                );
            }
        }
    }
}

/**
 *
 */
bool DrawPanelFormatText(Handle hPanel, const char[] szText, any ...)
{
    char szFormatText[128];
    VFormat(szFormatText, sizeof(szFormatText), szText, 3);
    return DrawPanelText(hPanel, szFormatText);
}

/**
 *
 */
void DrawPanelSpace(Handle hPanel) {
    DrawPanelItem(hPanel, "", ITEMDRAW_SPACER);
}

/**
 *
 */
int IsClientSpamCommand(int iClient)
{
    float fCurrentTime = GetEngineTime();

    if (fCurrentTime < g_fClientCommandSpamCooldown[iClient])
    {
        g_iClientCommandSpamAttempts[iClient]++;

        if (g_iClientCommandSpamAttempts[iClient] > g_iMaxAttempts)
        {
            g_fClientCommandSpamCooldown[iClient] += g_fSpamCooldownIncrement; // Increase cooldown time
            g_iClientCommandSpamAttempts[iClient] = 0; // Reset spam attempts

            return 1;
        }

        return 0;
    }

    g_fClientCommandSpamCooldown[iClient] = fCurrentTime + g_fSpamCooldownInitial; // Set cooldown
    g_iClientCommandSpamAttempts[iClient] = 0; // Reset spam attempts

    return -1;
}

float GetClientCommandSpamCooldown(int iClient) {
    return g_fClientCommandSpamCooldown[iClient] - GetEngineTime();
}

/**
 * Validates if is a valid team.
 *
 * @param iTeam     Team index.
 * @return          True if team is valid, false otherwise.
 */
bool IsValidTeam(int iTeam) {
    return (iTeam == TEAM_SURVIVOR || iTeam == TEAM_INFECTED);
}

/**
 *
 */
bool IsTeamReady(int iTeam)
{
    int iReadyCount = 0;

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient)
        || IsFakeClient(iClient)
        || GetClientTeam(iClient) != iTeam) {
            continue;
        }

        if (!IsClientReady(iClient)) {
            return false;
        }

        iReadyCount ++;
    }

    if (g_bStrict && iReadyCount < g_cvTeamSize.IntValue) {
        return false;
    }

    return true;
}

/**
 *
 */
bool SetTeamReady(int iTeam, bool bReady)
{
    int iChangeCount = 0;

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) != iTeam) {
            continue;
        }

        SetClientReady(iClient, bReady);
        iChangeCount ++;
    }

    if (g_bStrict && iChangeCount < g_cvTeamSize.IntValue) {
        return false;
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
bool IsClientReadyUpVisible(int iClient) {
    return g_bClientReadyUpVisible[iClient];
}

/**
 *
 */
void SetClientReadyUpVisible(int iClient, bool bVisible) {
    g_bClientReadyUpVisible[iClient] = bVisible;
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
void SetVersusForceStartTime(Switcher switcher) {
    L4D2_CTimerStart(L4D2CT_VersusStartTimer, switcher == Enable ? GetConVarFloat(g_cvVersusForceStartTime) : 99999.9);
}

/**
 *
 */
void SetScavengeRoundSetupTimer(Switcher switcher)
{
    CountdownTimer cTimer = L4D2Direct_GetScavengeRoundSetupTimer();

    if (cTimer == CTimer_Null) {
        return;
    }

    CTimer_Start(cTimer, switcher == Enable ? GetConVarFloat(g_cvScavengeRoundSetupTime) : 99999.9);

    for (int iClient = 1; iClient <= MaxClients; iClient ++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
            continue;
        }

        ShowVGUIPanel(iClient, "ready_countdown", _, switcher == Enable);
    }
}

/**
 *
 */
void ResetAccumulatedTime()
{
    L4D_NotifyNetworkStateChanged();
    GameRules_SetPropFloat("m_flAccumulatedTime", GetConVarFloat(g_cvScavengeRoundInitialTime));
}

/*
 *
 */
bool IsReadyupMode(ReadyupMode eMode) {
    return (g_eReadyupMode == eMode);
}

/**
 *
 */
bool IsModeNeedClientAction() {
    return (IsReadyupMode(ReadyupMode_PlayerReady) || IsReadyupMode(ReadyupMode_TeamReady));
}

/**
 *
 */
void SetReadyState(ReadyupState eReadyupState)
{
    if (!IsReadyState(eReadyupState)) {
        ExecuteForward_OnChangeReadyState(g_eReadyupState, eReadyupState);
    }

    g_eReadyupState = eReadyupState;
}

/**
 *
 */
void ExecuteForward_OnChangeReadyState(ReadyupState eOldState, ReadyupState eNewState)
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
bool IsReadyState(ReadyupState eReadtupState) {
    return (g_eReadyupState == eReadtupState);
}

/**
 *
 */
bool IsReadyStateInProgress() {
    return IsReadyState(ReadyupState_UnReady) || IsReadyState(ReadyupState_Countdown);
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
Action ExecuteForward_OnPrepareReadyUpItem(PanelPos ePos, int iClient, int iIndex)
{
    Action aReturn = Plugin_Continue;

    if (GetForwardFunctionCount(g_fwdOnPrepareReadyUpItem))
    {
        Call_StartForward(g_fwdOnPrepareReadyUpItem);
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
void ExecuteForward_OnRemoveReadyUpItem(PanelPos ePos, int iOldIndex, int iNewIndex)
{
    if (GetForwardFunctionCount(g_fwdOnRemoveReadyUpItem))
    {
        Call_StartForward(g_fwdOnRemoveReadyUpItem);
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
void GetClientNameFixed(int iClient, char[] sName, int length, int iMaxSize)
{
    GetClientName(iClient, sName, length);

    if (strlen(sName) > iMaxSize)
    {
        sName[iMaxSize - 3] = sName[iMaxSize - 2] = sName[iMaxSize - 1] = '.';
        sName[iMaxSize] = '\0';
    }
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
 * Determine if a player is connecting.
 *
 * @return          Player count.
 */
int GetLoadingPlayers()
{
    int iPlayers = 0;

    for (int iClient = 1; iClient <= MaxClients; iClient ++)
    {
        if (IsClientConnected(iClient) && (!IsClientInGame(iClient) || GetClientTeam(iClient) == TEAM_NONE)) {
            iPlayers ++;
        }
    }

    return iPlayers;
}

/**
 * Determines whether the game server should wait for additional loading players
 * before proceeding with gameplay.
 *
 * @param iLoadingPlayers   The number of players currently in the process of loading.
 * @return                  True if waiting is necessary (i.e., loading players exist
 *                          and the current in-game team size is below the configured threshold),
 *                          false otherwise.
 */
bool NeedWaitLoadingPlayers(int iLoadingPlayers)
{
    int iTeamSize = g_cvTeamSize.IntValue;

    int iPlayers = 0;
    for (int iClient = 1; iClient <= MaxClients; iClient ++)
    {
        if (IsClientInGame(iClient) && IsValidTeam(GetClientTeam(iClient))) {
            iPlayers ++;
        }
    }

    return (iLoadingPlayers > 0) && (iPlayers < iTeamSize);
}

/**
 * Checks that the server is empty.
 *
 * @return          True if server is empty, false otherwise.
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
 * Checks if the current round is the second half.
 *
 * @return true if it is the second half of the round, false otherwise.
 */
bool InSecondHalfOfRound() {
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

/**
 * Validates if is a valid client.
 *
 * @param iClient   Client index.
 * @return          True if client is valid, false otherwise.
 */
bool IsValidClient(int iClient) {
    return (iClient > 0 && iClient <= MaxClients);
}

/**
 * Returns whether the player is in water.
 *
 * @param iClient   Client index.
 * @return          True if client in water, false otherwise.
 */
bool IsClientInWater(int iClient) {
    return (GetEntProp(iClient, Prop_Send, "m_nWaterLevel") == WATER_LEVEL_EYES);
}

/**
 * Returns whether the player is survivor.
 *
 * @param iClient   Client index.
 * @return          True if client is survivor, false otherwise.
 */
bool IsClientSurvivor(int iClient) {
    return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}
