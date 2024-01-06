#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <boss_flow>
#include <readyup_rework>
#include <left4dhooks>
#include <colors>


public Plugin myinfo = {
    name        = "[ReadyupFooter] TankFlow",
    author      = "TouchMe",
    description = "Adds tank percentages to the bottom of ReadyUp",
    version     = "build0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
}


#define LIB_READY               "readyup_rework"

#define TRANSLATIONS            "rf_tank_flow.phrases"


int g_iThisIndex = -1;

bool g_bReadyUpAvailable = false;

ConVar g_cvVsBossBuffer = null;


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

public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);

    g_cvVsBossBuffer = FindConVar("versus_boss_buffer");
}

public Action OnPrepareReadyUpItem(PanelPos ePos, int iClient, int iIndex)
{
    if (!g_bReadyUpAvailable || ePos != PanelPos_Footer || g_iThisIndex != iIndex) {
        return Plugin_Continue;
    }

    char szTankPercent[32];

    if (IsBossSpawnAllowed(Boss_Tank))
    {
        int iTankFlow = GetBossFlow(Boss_Tank);

        if (IsMapWithStaticBossSpawn(Boss_Tank)) {
            FormatEx(szTankPercent, sizeof szTankPercent, "%T", "STATIC", iClient);
        }

        else if (iTankFlow == 0) {
            FormatEx(szTankPercent, sizeof szTankPercent, "%T", "DISABLE", iClient);
        }

        else
        {
            float fBossBuffer = GetConVarFloat(g_cvVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();

            int iTankFlowTrigger = iTankFlow - RoundToNearest(fBossBuffer * 100.0);

            if (iTankFlowTrigger < 0) {
                iTankFlowTrigger = 1;
            }

            FormatEx(szTankPercent, sizeof szTankPercent, "%T", "PERCENT", iClient, iTankFlow, iTankFlowTrigger);
        }
    }

    if (szTankPercent[0] != '\0' ) {
        UpdateReadyUpItem(ePos, iIndex, "%T", "TANK_FLOW", iClient, szTankPercent);
    }

    return Plugin_Stop;
}
