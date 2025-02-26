#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <boss_flow>
#include <readyup_rework>
#include <colors>


public Plugin myinfo =
{
    name        = "ReadyupFooterBossFlow",
    author      = "TouchMe",
    description = "Adds boss percentages to the bottom of ReadyUp",
    version     = "build0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
}


#define LIB_READY               "readyup_rework"


#define TRANSLATIONS            "rf_boss_flow.phrases"

int g_iThisIndex = -1;

bool g_bReadyUpAvailable = false;

/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded()
{
    g_bReadyUpAvailable = LibraryExists(LIB_READY);

    if (g_bReadyUpAvailable) {
        g_iThisIndex = PushReadyUpItem(PanelPos_Footer, "OnPrepareReadyUpItem");
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

public Action OnPrepareReadyUpItem(PanelPos ePos, int iClient, int iIndex)
{
    if (!g_bReadyUpAvailable || ePos != PanelPos_Footer || g_iThisIndex != iIndex) {
        return Plugin_Continue;
    }

    char sTankPercent[32], sWitchPercent[32];

    if (IsBossSpawnAllowed(Boss_Tank))
    {
        int iTankPercent = GetBossFlow(Boss_Tank);

        if (IsMapWithStaticBossSpawn(Boss_Tank)) {
            FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "STATIC", iClient);
        }

        else if (iTankPercent == 0) {
            FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "DISABLE", iClient);
        }

        else {
            FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "PERCENT", iClient, iTankPercent);
        }
    }

    if (IsBossSpawnAllowed(Boss_Witch))
    {
        int iWitchPercent = GetBossFlow(Boss_Witch);

        if (IsMapWithStaticBossSpawn(Boss_Witch)) {
            FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "STATIC", iClient);
        }

        else if (iWitchPercent == 0) {
            FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "DISABLE", iClient);
        }

        else {
            FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "PERCENT", iClient, iWitchPercent);
        }
    }

    if (sTankPercent[0] != '\0' && sWitchPercent[0] != '\0') {
        UpdateReadyUpItem(ePos, iIndex, "%T %T", "TANK_FLOW", iClient, sTankPercent, "WITCH_FLOW", iClient, sWitchPercent);
    } else if (sTankPercent[0] != '\0' ) {
        UpdateReadyUpItem(ePos, iIndex, "%T", "TANK_FLOW", iClient, sTankPercent);
    } else if (sWitchPercent[0] != '\0') {
        UpdateReadyUpItem(ePos, iIndex, "%T", "WITCH_FLOW", iClient, sWitchPercent);
    }

    return Plugin_Stop;
}
