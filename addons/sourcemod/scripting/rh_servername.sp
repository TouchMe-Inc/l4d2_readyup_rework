#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <readyup_rework>
#include <colors>



public Plugin myinfo =
{
	name = "ReadyupHeaderServername",
	author = "TouchMe",
	description = "Adds the server name to the top of ReadyUp",
	version = "build0001",
	url = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
};


/*
 * Libs.
 */
#define LIB_READY               "readyup_rework"


ConVar
	g_cvServerNameCvar,
	g_cvServerNamer
;

int g_iThisIndex = -1;

bool g_bReadyUpAvailable = false;


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded()
{
	g_bReadyUpAvailable = LibraryExists(LIB_READY);

	if (g_bReadyUpAvailable) {
		g_iThisIndex = PushReadyUpItem(PanelPos_Header, "OnPrepareReadyUpItem");
	}
}

/**
  * Global event. Called when a library is removed.
  *
  * @param sName     Library name
  */
public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, LIB_READY)) {
		g_bReadyUpAvailable = false;
	}
}

/**
  * Global event. Called when a library is added.
  *
  * @param sName     Library name
  */
public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, LIB_READY)) {
		g_bReadyUpAvailable = true;
	}
}

public void OnPluginStart()
{
	g_cvServerNameCvar	= CreateConVar("sm_rh_servername_cvar", "", "blank = hostname");

	g_cvServerNamer = FindServerNameConVar();

	HookConVarChange(g_cvServerNameCvar, OnServerCvarChanged);
}

/**
 *
 */
public Action OnPrepareReadyUpItem(PanelPos ePos, int iClient, int iIndex)
{
	if (!g_bReadyUpAvailable || ePos != PanelPos_Header || g_iThisIndex != iIndex) {
		return Plugin_Continue;
	}

	char buffer[64]; GetConVarString(g_cvServerNamer, buffer, sizeof(buffer));
	UpdateReadyUpItem(ePos, iIndex, buffer);

	return Plugin_Stop;
}

/**
 *
 */
void OnServerCvarChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue) {
	g_cvServerNamer = FindServerNameConVar();
}

/**
 *
 */
ConVar FindServerNameConVar()
{
	char buffer[64]; GetConVarString(g_cvServerNameCvar, buffer, sizeof(buffer));
	ConVar cvServerName = FindConVar(buffer);

	if (FindConVar(buffer) == null) {
		return FindConVar("hostname");
	}

	return cvServerName;
}
