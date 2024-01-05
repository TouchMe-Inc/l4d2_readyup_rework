#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <readyup_rework>
#include <colors>



public Plugin myinfo =
{
	name = "ReadyUpHeaderServerName",
	author = "TouchMe",
	description = "...",
	version = "build0000",
	url = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
};


ConVar
	g_cvServerNameCvar,
	g_cvServerNamer
;

int iThisIndex = -1;

/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded() {
	iThisIndex = PushPanelItem(PanelPos_Header, "OnPreparePanelItem");
}

public void OnPluginStart()
{
	// LoadTranslations(TRANSLATION);

	// basic
	g_cvServerNameCvar	= CreateConVar("sm_rh_servername_cvar", "", "default: hostname");

	g_cvServerNamer = FindServerNameConVar();

	HookConVarChange(g_cvServerNameCvar, OnServerCvarChanged);
}

/**
 *
 */
public Action OnPreparePanelItem(PanelPos ePos, int iClient, int iIndex)
{
	if (ePos != PanelPos_Header || iThisIndex != iIndex) {
		return Plugin_Handled;
	}

	char buffer[64]; GetConVarString(g_cvServerNamer, buffer, sizeof(buffer));
	UpdatePanelItem(ePos, iIndex, "%s", buffer);

	return Plugin_Continue;
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
