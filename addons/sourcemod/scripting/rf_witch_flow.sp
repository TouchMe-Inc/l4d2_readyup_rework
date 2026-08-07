#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <boss_flow>
#include <readyup_rework>
#include <colors>


public Plugin myinfo =
{
    name        = "[Readyup] ReadyupFooter.WitchFlow",
    author      = "TouchMe",
    description = "Adds witch percentages to the bottom of ReadyUp",
    version     = "build0002",
    url         = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
}


#define LIB_READY               "readyup_rework"

#define TRANSLATIONS            "rf_witch_flow.phrases"


int g_iThisIndex = -1;


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded()
{
    if (LibraryExists(LIB_READY)) {
        g_iThisIndex = PushReadyUpItem(PanelPos_Footer, "OnPrepareReadyUpItem");
    }
}

public void OnPluginStart() {
    LoadTranslations(TRANSLATIONS);
}

public Action OnPrepareReadyUpItem(PanelPos ePos, int iClient, int iIndex)
{
    if (ePos != PanelPos_Footer || g_iThisIndex != iIndex) {
        return Plugin_Continue;
    }

    if (!IsBossSpawnAllowed(Boss_Witch)) {
        return Plugin_Continue;
    }

    char szWitchPercent[32];

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

    UpdateReadyUpItem(ePos, iIndex, "%T", "WITCH_FLOW", iClient, szWitchPercent);

    return Plugin_Stop;
}
