#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <boss_flow>
#include <readyup_rework>
#include <colors>


public Plugin myinfo =
{
	name = "ReadyUpFooterBossFlow",
	author = "TouchMe",
	description = "N/a",
	version = "build0000",
	url = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
}


#define LIB_READY               "readyup_rework"


#define TRANSLATIONS            "rf_boss_flow.phrases"

int iThisIndex = -1;

bool g_bReadyUpAvailable = false;

/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded()
{
	g_bReadyUpAvailable = LibraryExists(LIB_READY);

	if (g_bReadyUpAvailable) {
		iThisIndex = PushPanelItem(PanelPos_Footer, "OnPreparePanelItem");
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

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Load translations.
	LoadTranslations(TRANSLATIONS);
}

public Action OnPreparePanelItem(PanelPos ePos, int iClient, int iIndex)
{
	if (!g_bReadyUpAvailable || ePos != PanelPos_Footer || iThisIndex != iIndex) {
		return Plugin_Handled;
	}

	char sInfo[64];

	if (IsTankSpawnAllow())
	{
		char sTankPercent[32];

		int iTankPercent = GetTankFlowPercent();

		if (IsStaticTankMap()) {
			FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "STATIC", iClient);
		}

		else if (iTankPercent == 0) {
			FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "DISABLE", iClient);
		}

		else {
			FormatEx(sTankPercent, sizeof(sTankPercent), "%d", iTankPercent);
		}

		FormatEx(sInfo, sizeof(sInfo), "%T ", "TANK_FLOW", iClient, sTankPercent);
	}

	if (IsWitchSpawnAllow())
	{
		char sWitchPercent[32];

		int iWitchPercent = GetWitchFlowPercent();

		if (IsStaticWitchMap()) {
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "STATIC", iClient);
		}

		else if (iWitchPercent == 0) {
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "DISABLE", iClient);
		}

		else {
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%d", iWitchPercent);
		}

		FormatEx(sInfo, sizeof(sInfo), "%s%T", sInfo, "WITCH_FLOW", iClient, sWitchPercent);
	}

	UpdatePanelItem(ePos, iIndex, sInfo);

	return Plugin_Continue;
}
