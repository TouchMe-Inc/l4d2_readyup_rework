#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <boss_flow>
#include <readyup_rework>
#include <colors>


public Plugin myinfo =
{
    name        = "[ReadyupFooter] WitchFlow",
    author      = "TouchMe",
    description = "Adds witch percentages to the bottom of ReadyUp",
    version     = "build0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
}


#define LIB_READY               "readyup_rework"

#define TRANSLATIONS            "rf_witch_flow.phrases"


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

public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);
}

public Action OnPrepareReadyUpItem(PanelPos ePos, int iClient, int iIndex)
{
    if (!g_bReadyUpAvailable || ePos != PanelPos_Footer || g_iThisIndex != iIndex) {
        return Plugin_Continue;
    }

    char szWitchPercent[32];


    if (IsBossSpawnAllowed(Boss_Witch))
    {
        int iWitchPercent = GetBossFlow(Boss_Witch);

        if (IsMapWithStaticBossSpawn(Boss_Witch)) {
            FormatEx(szWitchPercent, sizeof(szWitchPercent), "%T", "STATIC", iClient);
        }

        else if (iWitchPercent == 0) {
            FormatEx(szWitchPercent, sizeof(szWitchPercent), "%T", "DISABLE", iClient);
        }

        else {
            FormatEx(szWitchPercent, sizeof(szWitchPercent), "%T", "PERCENT", iClient, iWitchPercent);
        }
    }

    if (szWitchPercent[0] != '\0') {
        UpdateReadyUpItem(ePos, iIndex, "%T", "WITCH_FLOW", iClient, szWitchPercent);
    }

    return Plugin_Stop;
}
