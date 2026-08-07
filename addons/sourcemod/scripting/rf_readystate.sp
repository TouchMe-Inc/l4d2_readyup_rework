#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <readyup_rework>
#include <colors>


public Plugin myinfo = {
    name        = "[Readyup] ReadyupFooter.ReadyState",
    author      = "TouchMe",
    description = "",
    version     = "build0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
}


#define LIB_READY               "readyup_rework"

#define TRANSLATIONS            "rf_readystate.phrases"


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

    if (GetReadyMode() != ReadyupMode_PlayerReady && GetReadyMode() != ReadyupMode_TeamReady) {
        return Plugin_Continue;
    }

    if (GetReadyState() != ReadyupState_UnReady && GetReadyState() != ReadyupState_Countdown) {
        return Plugin_Continue;
    }

    UpdateReadyUpItem(ePos, iIndex, "%T", IsClientReady(iClient) ? "MARK_UNREADY" : "MARK_READY", iClient);

    return Plugin_Stop;
}
