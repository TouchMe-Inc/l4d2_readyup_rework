#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <readyup_rework>
#include <colors>


public Plugin myinfo = {
    name        = "[ReadyupFooter] FirstHit",
    author      = "TouchMe",
    description = "N/a",
    version     = "build0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_readyup_rework"
}


/*
 * Infected Class.
 */
#define SI_CLASS_SMOKER         1
#define SI_CLASS_CHARGER        6

/*
 * Team.
 */
#define TEAM_INFECTED           3

/*
 * Libs.
 */
#define LIB_READY               "readyup_rework"

#define TRANSLATIONS            "rf_first_hit.phrases"


char g_szClassKey[][] =
{
    "",
    "SMOKER",
    "BOOMER",
    "HUNTER",
    "SPITTER",
    "JOCKEY",
    "CHARGER"
};

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

public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);
}

public Action OnPrepareReadyUpItem(PanelPos ePos, int iClient, int iIndex)
{
    if (ePos != PanelPos_Footer || g_iThisIndex != iIndex) {
        return Plugin_Continue;
    }

    Handle hSpawnOrder = CreateArray();

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer) || !IsClientInfected(iPlayer) || !IsPlayerAlive(iPlayer)) {
            continue;
        }

        int iZombieClass = GetClientClass(iPlayer);

        if (IsValidClass(iZombieClass)) {
            PushArrayCell(hSpawnOrder, iZombieClass);
        }
    }

    int iArraySize = GetArraySize(hSpawnOrder);

    if (!iArraySize) {
        return Plugin_Continue;
    }

    char szBuffer[64];

    for (int iItem = 0; iItem < iArraySize; iItem ++)
    {
        int iZombieClass = GetArrayCell(hSpawnOrder, iItem);
        Format(szBuffer, sizeof szBuffer, "%s%T%s", szBuffer, g_szClassKey[iZombieClass], iClient, iItem != (iArraySize - 1) ? ", " : "");
    }

    CloseHandle(hSpawnOrder);

    UpdateReadyUpItem(ePos, iIndex, "%T", "FIRST_HIT", iClient, szBuffer);

    return Plugin_Stop;
}

/**
 * Get the zombie player class.
 */
int GetClientClass(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}


/**
 * The class is included in the pool of infected.
 */
bool IsValidClass(int iClass) {
    return (iClass >= SI_CLASS_SMOKER && iClass <= SI_CLASS_CHARGER);
}

/**
 * Returns whether the player is infected.
 */
bool IsClientInfected(int iClient) {
    return (GetClientTeam(iClient) == TEAM_INFECTED);
}
