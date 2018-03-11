/*
*                                                           
*   L4D2 Disturbed                      
*   by Darkness                         
*                                                           
*   Description: Zombies aren't attracted to fire and weapon noises
*   ...Until now!
* 
*/

#pragma semicolon 1
#define PLUGIN_VERSION "1.1.0i"
#define DEBUG 1
#define CVAR_FLAGS 0

#define MAX_CLIENT_NAMES 64
#define MAX_TEXT_SIZE 4096
#define MTS MAX_TEXT_SIZE
#define PANEL_STRING_SIZE 64
#define AUTH_MAX_LENGTH MAX_NAME_LENGTH
#define WEAPON_SIZE 64
#define WEAPON_COUNT 48
#define DISTURB_PANEL_VISIBLE_TIMEOUT 10
#define FLOAT_PRECISION

#define MAX_COOKIE_LEN 5
#define MAX_ARG_LEN 64

#define MAX_DATA_UNIT 64
#define MDU MAX_DATA_UNIT
#define MAX_ARG_LEN 64
#define MAX_REGEX_STRING 256
#define MRS MAX_REGEX_STRING

#define ZOMBIE_CLASS_SMOKER 1
#define ZOMBIE_CLASS_BOOMER 2
#define ZOMBIE_CLASS_HUNTER 3
#define ZOMBIE_CLASS_SPITTER 4
#define ZOMBIE_CLASS_JOCKEY 5
#define ZOMBIE_CLASS_CHARGER 6
#define ZOMBIE_CLASS_WITCH 7
#define ZOMBIE_CLASS_TANK 8
#define SPECIALS_NO_TANK_OR_WITCH 6

#define DISTURB_SCALE_MIN 0
#define DISTURB_SCALE_LOW 200
#define DISTURB_SCALE_MED 400
#define DISTURB_SCALE_MID 600
#define DISTURB_SCALE_HIGH 800
#define DISTURB_SCALE_HIGHER 900
#define DISTURB_SCALE_MAX 1000
#define DISTURB_SCALE_MOD 1000

#define DISTURB_SCALE_LINEAR 0
#define DISTURB_SCALE_LOGARITHMIC 1
#define DISTURB_SCALE_EXPONENTIAL 2



#include <sourcemod>
#include <regex>
#include <sdktools>
#include <clientprefs>



public Plugin:myinfo = 
{
    name = "L4D2 Disturbed",
    author = "Darkness",
    description = "Spawns zombies based on weapons fire.",
    version = PLUGIN_VERSION,
    url = "http://www.sourcemod.net"
}

//Constants
const Float:DISTURB_SCALE_LOG_MOD = 1.666667;
const Float:DISTURB_SCALE_LOG_MAX = 30.000000;
const Float:DISTURB_SCALE_RATE_MIN = 0.100000;
const Float:DISTURB_SCALE_RATE_MAX = 6.000000;

//Handles
new Handle:disturbVersion = INVALID_HANDLE;
new Handle:disturbEnableSpawns = INVALID_HANDLE;
new Handle:disturbAdminFlags = INVALID_HANDLE;
new Handle:maxZombiesPerAction = INVALID_HANDLE;
new Handle:maxSpecials = INVALID_HANDLE;
new Handle:maxTanks = INVALID_HANDLE;
new Handle:maxWitches = INVALID_HANDLE;
new Handle:maxHunters = INVALID_HANDLE;
new Handle:maxSmokers = INVALID_HANDLE;
new Handle:maxSpitters = INVALID_HANDLE;
new Handle:maxBoomers = INVALID_HANDLE;
new Handle:maxChargers = INVALID_HANDLE;
new Handle:maxJockeys = INVALID_HANDLE;

new Handle:disturbCalcShotsTime = INVALID_HANDLE;
new Handle:disturbCalmRate = INVALID_HANDLE;
new Handle:disturbActionTime = INVALID_HANDLE;
new Handle:disturbActionDelay = INVALID_HANDLE;
new Handle:disturbPostActionDelay = INVALID_HANDLE;
new Handle:disturbPostFullDelay = INVALID_HANDLE;
new Handle:disturbAdvertise = INVALID_HANDLE;
new Handle:disturbDisplayBar = INVALID_HANDLE;
new Handle:disturbDisplayAdminChanges = INVALID_HANDLE;
new Handle:disturbCarAlarm = INVALID_HANDLE;
new Handle:disturbWeaponModifiers = INVALID_HANDLE;
new Handle:disturbBotExceptions = INVALID_HANDLE;
new Handle:disturbGameTypeEnabled = INVALID_HANDLE;
new Handle:disturbScaleMinCommands = INVALID_HANDLE;
new Handle:disturbScaleLowCommands = INVALID_HANDLE;
new Handle:disturbScaleMedCommands = INVALID_HANDLE;
new Handle:disturbScaleMidCommands = INVALID_HANDLE;
new Handle:disturbScaleHighCommands = INVALID_HANDLE;
new Handle:disturbScaleHigherCommands = INVALID_HANDLE;
new Handle:disturbScaleMaxCommands = INVALID_HANDLE;
new Handle:disturbScaleType = INVALID_HANDLE;
new Handle:disturbScaleRate = INVALID_HANDLE;
new Handle:disturbScaleSteps = INVALID_HANDLE;
new Handle:disturbScaleDifficulty = INVALID_HANDLE;
new Handle:disturbScaleDifficultyNormal = INVALID_HANDLE;
new Handle:disturbScaleDifficultyHard = INVALID_HANDLE;
new Handle:disturbScaleDifficultyImpossible = INVALID_HANDLE;
new Handle:disturbScaleGameTypeVersus = INVALID_HANDLE;
new Handle:disturbScaleGameTypeCoop = INVALID_HANDLE;
new Handle:disturbScaleGameTypeSurvival = INVALID_HANDLE;
new Handle:disturbScaleGameTypeScavenge = INVALID_HANDLE;

new Handle:disturbTimer = INVALID_HANDLE;
new Handle:disturbWeaponTrie = INVALID_HANDLE;
new Handle:disturbExTrie = INVALID_HANDLE;
new Handle:disturbCommandTrie = INVALID_HANDLE;

//Cache Entries
//Floats
new Float:disturb_calc_shots_cache;
new Float:disturb_calm_rate_cache;
new Float:disturb_action_time_cache;
new Float:disturb_scale_rate_cache;
new Float:disturb_scale_linear_rate_cache;
new Float:disturb_scale_logarithmic_rate_cache;
new Float:disturb_scale_exponential_rate_cache;
new Float:disturb_scale_difficulty_cache;
new Float:disturb_scale_gametype_versus_cache;
new Float:disturb_scale_gametype_coop_cache;
new Float:disturb_scale_gametype_survival_cache;
new Float:disturb_scale_gametype_scavenge_cache;
//Strings
new String:disturb_game_type_enabled_cache[MTS];
new String:disturb_scale_min_cache[MTS];
new String:disturb_scale_low_cache[MTS];
new String:disturb_scale_med_cache[MTS];
new String:disturb_scale_mid_cache[MTS];
new String:disturb_scale_high_cache[MTS];
new String:disturb_scale_higher_cache[MTS];
new String:disturb_scale_max_cache[MTS];

//Integers
new disturb_admin_flags_cache;
new disturb_bot_exception_cache;
new disturb_enable_spawns_cache;
new disturb_action_delay_cache;
new disturb_post_action_delay_cache;
new disturb_post_full_cache;
new disturb_car_alarm_cache;
new disturb_advertise_cache;
new disturb_displaybar_cache;
new disturb_display_admin_cache;
new disturb_max_common_cache;
new disturb_max_specials_cache;
new disturb_max_tanks_cache;
new disturb_max_witches_cache;
new disturb_max_hunters_cache;
new disturb_max_smokers_cache;
new disturb_max_spitters_cache;
new disturb_max_boomers_cache;
new disturb_max_chargers_cache;
new disturb_max_jockeys_cache;
new disturb_scale_type_cache;
new disturb_scale_steps_cache;
new gameDifficulty;
new gameType;

//Regex
new Handle:disturbWeaponRegEx = INVALID_HANDLE;
new Handle:disturbDifficultyRegEx = INVALID_HANDLE;
new Handle:disturbGameTypeRegEx = INVALID_HANDLE;
//Server Data
new String:ServerInfo[3][MDU];
new String:CurrentMap[MDU];
new String:weaponPattern[MRS];
new String:gameTypePattern[MRS];
new String:difficultyPattern[MRS];
//Testing
new disturbBulletCount = 0;
new disturbTotalShotCount = 0;
new disturbValue = 0;
new disturbValueLast = 0;
new disturbTimerRuns = 0;
new disturbCurrentRun = 0;
new disturbZombiesLeft = 0;
new disturbWitchesLeft = 0;
new disturbWaitActions = 0;
new disturbOutsideEventValue = 0;

//All individual stats for Calculation
new Float:weaponStats[3][WEAPON_COUNT];
/*
*   0: Disturb value part...just for stats at this time
*   1: Ramping quotient as decimal.
*   2: Total attacks from this weapon.
* 
*/
new Float:weaponStatsCache[1][WEAPON_COUNT]; //Use this to timeout shots
new String:weaponArray[WEAPON_COUNT][WEAPON_SIZE] = {
    "autoshotgun",
    "grenade_launcher",
    "hunting_rifle",
    "pistol",
    "pistol_magnum",
    "pumpshotgun",
    "rifle",
    "rifle_ak47",
    "rifle_desert",
    "rifle_m60",
    "rifle_sg552",
    "shotgun_chrome",
    "shotgun_spas",
    "smg",
    "smg_mp5",
    "smg_silenced",
    "sniper_awp",
    "sniper_military",
    "sniper_scout",
    "baseball_bat",
    "cricket_bat",
    "crowbar",
    "electric_guitar",
    "fireaxe",
    "frying_pan",
    "golfclub",
    "katana",
    "machete",
    "tonfa",
    "knife",
    "chainsaw",
    "adrenaline",
    "defibrillator",
    "first_aid_kit",
    "pain_pills",
    "fireworkcrate",
    "gascan",
    "oxygentank",
    "propanetank",
    "molotov",
    "pipe_bomb",
    "vomitjar",
    "ammo_spawn",
    "upgradepack_explosive",
    "upgradepack_incendiary",
    "gnome",
    "cola_bottles",
    "melee"
};

new Float:weaponModifiers[WEAPON_COUNT] = {
    1.0,
    10.0,
    2.0,
    0.5,
    1.0,
    1.0,
    1.0,
    1.0,
    1.0,
    2.0,
    2.0,
    1.0,
    1.0,
    0.8,
    0.8,
    0.1,
    2.0,
    2.0,
    3.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    5.0,
    0.0,
    0.0,
    0.0,
    0.0,
    10.0,
    5.0,
    10.0,
    10.0,
    5.0,
    10.0,
    0.0,
    0.0,
    2.0,
    2.0,
    0.0,
    0.0,
    0.0
};

new String:commandArray[][][MDU] = {
    { "common","Spawn" },
    { "mob", "Spawn" },
    { "hunter", "Spawn" },
    { "smoker", "Spawn" },
    { "spitter","Spawn" },
    { "boomer","Spawn" },
    { "charger","Spawn" },
    { "jockey","Spawn" },
    { "tank","Spawn" },
    { "witch","Spawn" },
    { "special","SpawnRandomSpecial" },
    { "tankorwitch","SpawnRandomTorW" },
    { "pause","Pause" },
    { "reset","Reset" },
    { "full","GoToMax" },
    { "calm","Calm" }
};

new String:specialArray[SPECIALS_NO_TANK_OR_WITCH][MDU] = {
    "hunter",
    "smoker",
    "spitter",
    "boomer",
    "charger",
    "jockey"
};
new String:specialTankWitch[2][MDU] = {
    "tank",
    "witch"
};

new String:difficultyArray[4][MDU] = {
    "easy",
    "normal",
    "hard",
    "impossible"
};

new Float:difficultyModArray[4] = {
    1.000,
    1.000,
    1.000,
    1.000
};


new String:gameTypeArray[4][MDU] = {
    "versus",
    "coop",
    "survival",
    "scavenge"
};

new Float:gameTypeModArray[4] = {
    1.000,
    1.000,
    1.000,
    1.000
};

/*=======================================================================================
*   OnPluginStart
* 
*   Setup the plugin, create ConVar's, hook all events and changes, first initialization
========================================================================================*/
public OnPluginStart()
{
    new initializeTrieError;
    new regExError;
    //Load those Phrases
    LoadTranslations("l4d2_disturbed.phrases.txt");
    
    //First thing is to identify the process
    HookEvent("server_spawn", IdentifyServer);
    //Hook Reference Points
    HookEvent("round_start", RoundStartCheck);
    HookEvent("round_end", RoundEndCheck);
    HookEvent("player_left_start_area", PlayerLeftStartCheck);
    //Testing this...supposed to be network only
    HookEvent("weapon_fire", WeaponFire);
    //Car Alarm
    HookEvent("triggered_car_alarm", CarAlarm, EventHookMode_PostNoCopy);
    
    //ConVars
    disturbVersion = CreateConVar("l4d2_disturbed_version", PLUGIN_VERSION, "Disturbed Version",FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_DONTRECORD);
    disturbEnableSpawns = CreateConVar("l4d2_disturbed_enable_spawns", "1", "Enable spawns.",CVAR_FLAGS, true, 0.0, true, 1.0);
    disturbAdminFlags = CreateConVar("l4d2_disturbed_admin_flags", "az",    "Flags to allow administration of the plugin in game.",CVAR_FLAGS);
    maxZombiesPerAction = CreateConVar("l4d2_disturbed_max_common_per_action", "30", "Maximum number of common zombies to spawn per spawn window.",CVAR_FLAGS, true, 1.0, true, 100.0); //Danger!!!
    maxSpecials = CreateConVar("l4d2_disturbed_max_specials", "3", "Maximum number of specials to exist at any given time.",CVAR_FLAGS, true, 0.0, true, 10.0);
    maxTanks = CreateConVar("l4d2_disturbed_max_tanks", "1", "Maximum number of tanks to exist at any given time.",CVAR_FLAGS, true, 0.0, true, 3.0);
    maxWitches = CreateConVar("l4d2_disturbed_max_witches", "1", "Maximum number of witches to exist at any given time..",CVAR_FLAGS, true, 0.0, true, 5.0);
    maxHunters = CreateConVar("l4d2_disturbed_max_hunters", "1", "Maximum number of hunters to exist at any given time..",CVAR_FLAGS, true, 0.0, true, 5.0);
    maxSmokers = CreateConVar("l4d2_disturbed_max_smokers", "1", "Maximum number of smokers to exist at any given time..",CVAR_FLAGS, true, 0.0, true, 5.0);
    maxBoomers = CreateConVar("l4d2_disturbed_max_witches", "1", "Maximum number of boomers to exist at any given time..",CVAR_FLAGS, true, 0.0, true, 5.0);
    maxSpitters = CreateConVar("l4d2_disturbed_max_spitters", "1", "Maximum number of spitters to exist at any given time..",CVAR_FLAGS, true, 0.0, true, 5.0);
    maxJockeys = CreateConVar("l4d2_disturbed_max_jockeys", "1", "Maximum number of jockeys to exist at any given time..",CVAR_FLAGS, true, 0.0, true, 5.0);
    maxChargers = CreateConVar("l4d2_disturbed_max_chargers", "1", "Maximum number of chargers to exist at any given time..",CVAR_FLAGS, true, 0.0, true, 5.0);
    disturbCalcShotsTime = CreateConVar("l4d2_disturbed_calc_shots_time", "10.0", "Time in seconds for calculating disturb values.",CVAR_FLAGS, true, 0.999, true, 180.1);
    disturbCalmRate = CreateConVar("l4d2_disturbed_calm_rate", "0.5", "Calming rate.",CVAR_FLAGS, true, 0.000001, true, 6.0);
    disturbActionTime = CreateConVar("l4d2_disturbed_action_time", "1.0", "Timer intervals for actually spawning zombies.",CVAR_FLAGS, true, 1.0, true, 30.0);
    disturbActionDelay = CreateConVar("l4d2_disturbed_action_delay", "0", "Number of timer intervals before taking actions. Based on action timer interval.",CVAR_FLAGS, true, 0.0, true, 100.0);
    disturbPostActionDelay = CreateConVar("l4d2_disturbed_post_action_delay", "0", "Number of timer intervals to not calculate new shots. Based on action timer interval.",CVAR_FLAGS, true, 0.0, true, 100.0);
    disturbPostFullDelay = CreateConVar("l4d2_disturbed_post_full_delay", "6.0", "Number of timer intervals to not calculate new shots after getting to Full.",CVAR_FLAGS, true, 0.0, true, 100.0);
    disturbAdvertise = CreateConVar("l4d2_disturbed_advertise", "1", "Display advertisement of the plugin.",CVAR_FLAGS, true, 0.0, true, 1.0);
    disturbDisplayBar = CreateConVar("l4d2_disturbed_displaybar", "1", "Display the percentage bar in text.0=off,1=Chat,2=Hint text,3=Both",CVAR_FLAGS, true, 0.0, true, 3.0);
    disturbDisplayAdminChanges = CreateConVar("l4d2_disturbed_display_adminchanges", "1", "Display admin settings changes,0=Off,1=Chat,2=Hint text,3=Both",CVAR_FLAGS, true, 0.0, true, 3.0);
    disturbCarAlarm = CreateConVar("l4d2_car_alarm_value", "1000", "Add this value to the disturb value when a car alarm is triggered.",CVAR_FLAGS, true, 0.0, true, 1000.0);
    disturbWeaponModifiers = CreateConVar("l4d2_disturbed_weapon_modifiers", "", "Change the weapon rate modifier Ex: weapon_name:10.0 .",CVAR_FLAGS);
    disturbBotExceptions = CreateConVar("l4d2_disturbed_bot_exception", "1", "Count bot weapons shots in the disturb value",CVAR_FLAGS, true, 0.0, true, 1.0);
    disturbGameTypeEnabled = CreateConVar("l4d2_disturbed_game_type_enabled", "", "Game types that will be enabled. If blank all are allowed (Ex: versus,coop,survival,scavenge)",CVAR_FLAGS);
    //
    disturbScaleMinCommands = CreateConVar("l4d2_disturbed_scale_min_commands", "", "Commands to run when disturb value greater than or equal to 0.",CVAR_FLAGS);
    disturbScaleLowCommands = CreateConVar("l4d2_disturbed_scale_low_commands", "common[scale]",    "Commands to run when disturb value greater than or equal to 10%.",CVAR_FLAGS);
    disturbScaleMedCommands = CreateConVar("l4d2_disturbed_scale_med_commands", "", "Commands to run when disturb value greater than or equal to 30%.",CVAR_FLAGS);
    disturbScaleMidCommands = CreateConVar("l4d2_disturbed_scale_mid_commands", "mob[scale],special",   "Commands to run when disturb value greater than or equal to 50%.",CVAR_FLAGS);
    disturbScaleHighCommands = CreateConVar("l4d2_disturbed_scale_high_commands", "special", "Commands to run when disturb value greater than or equal to 70%.",CVAR_FLAGS);
    disturbScaleHigherCommands = CreateConVar("l4d2_disturbed_scale_higher_commands", "witch", "Commands to run when disturb value greater than or equal to 90%.",CVAR_FLAGS);
    disturbScaleMaxCommands = CreateConVar("l4d2_disturbed_scale_max_commands", "tank,stop",    "Commands to run when disturb value equal to 100%.",CVAR_FLAGS);
    disturbScaleRate = CreateConVar("l4d2_disturbed_scale_rate", "3.0", "Rate at which modifiers are calculated.",CVAR_FLAGS, true, 0.10, true, 6.0);
    disturbScaleType = CreateConVar("l4d2_disturbed_scale_type", "0", "0=Linear,1=Logarithmic,2=Exponential",CVAR_FLAGS,true, 0.0, true, 2.0);
    disturbScaleSteps = CreateConVar("l4d2_disturbed_scale_steps", "5", "How many trigger points to create.",CVAR_FLAGS,true, 2.0, true, 20.0);
    disturbScaleDifficulty = CreateConVar("l4d2_disturbed_scale_difficulty", "versus:1.0,coop:1.0,survival:1.0,scavenge:1.0", "Change rate based on difficulty. Ex: versus:1.0,coop:1.0...you can change them individually or as a list.", CVAR_FLAGS);
    disturbScaleGameTypeVersus = CreateConVar("l4d2_disturbed_scale_gametype_versus", "1.0", "Change rate based on gametype.",CVAR_FLAGS,true, 0.1, true, 10.0);
    disturbScaleGameTypeCoop = CreateConVar("l4d2_disturbed_scale_gametype_coop", "1.0", "Change rate based on gametype.",CVAR_FLAGS,true, 0.1, true, 10.0);
    disturbScaleGameTypeSurvival = CreateConVar("l4d2_disturbed_scale_gametype_survival", "1.0", "Change rate based on gametype.",CVAR_FLAGS,true, 0.1, true, 10.0);
    disturbScaleGameTypeScavenge = CreateConVar("l4d2_disturbed_scale_gametype_scavenge", "1.0", "Change rate based on gametype.",CVAR_FLAGS,true, 0.1, true, 10.0);
    
    //Hook ConVar Changes
    HookConVarChange(disturbVersion, DisturbedVersionStatic); //Don't change the version outside of code
    HookConVarChange(disturbEnableSpawns, DisturbEnableSpawnsChanged);
    HookConVarChange(disturbAdminFlags, DisturbAdminFlagsChanged);
    HookConVarChange(maxZombiesPerAction, MaxCommonChanged);
    HookConVarChange(disturbCalcShotsTime, CalcShotsChanged);
    HookConVarChange(disturbCalmRate, CalmRateChanged);
    HookConVarChange(disturbCarAlarm, CarAlarmChanged);
    HookConVarChange(disturbActionTime, ActionTimeChanged);
    HookConVarChange(disturbActionDelay, ActionDelayChanged);
    HookConVarChange(disturbPostActionDelay, PostActionDelayChanged);
    HookConVarChange(disturbPostFullDelay, PostFullDelayChanged);
    HookConVarChange(disturbAdvertise, AdvertiseChanged);
    HookConVarChange(disturbDisplayBar, DisplayBarChanged);
    HookConVarChange(disturbDisplayAdminChanges, DisplayAdminChangesChanged);
    HookConVarChange(disturbWeaponModifiers, WeaponModifiersChanged);
    HookConVarChange(disturbBotExceptions, BotExceptionChanged);
    HookConVarChange(disturbGameTypeEnabled, DisturbGameTypeEnabledChanged);
    HookConVarChange(disturbScaleType, DisturbScaleTypeChanged);
    HookConVarChange(disturbScaleRate, DisturbScaleRateChanged);
    HookConVarChange(disturbScaleDifficulty, DisturbScaleDifficultyChanged);
    HookConVarChange(disturbScaleGameTypeVersus, DisturbScaleGameTypeVersusChanged);
    HookConVarChange(disturbScaleGameTypeCoop, DisturbScaleGameTypeCoopChanged);
    HookConVarChange(disturbScaleGameTypeSurvival, DisturbScaleGameTypeSurvivalChanged);
    HookConVarChange(disturbScaleGameTypeScavenge, DisturbScaleGameTypeScavengeChanged);
    HookConVarChange(maxSpecials, MaxSpecialsChanged);
    HookConVarChange(maxTanks, MaxTanksChanged);
    HookConVarChange(maxWitches, MaxWitchesChanged);
    HookConVarChange(maxHunters, MaxHuntersChanged);
    HookConVarChange(maxSmokers, MaxSmokersChanged);
    HookConVarChange(maxBoomers, MaxBoomersChanged);
    HookConVarChange(maxSpitters, MaxSpittersChanged);
    HookConVarChange(maxJockeys, MaxJockeysChanged);
    HookConVarChange(maxChargers, MaxChargersChanged);
    
    //Default Cache Values --Important! Need to initialize for default values --do not change defaults and not change these
    disturb_enable_spawns_cache = 1;
    disturb_admin_flags_cache = ReadFlagString("az");
    disturb_calc_shots_cache = 10.0;
    disturb_calm_rate_cache = 0.5;
    disturb_action_time_cache = 1.0;
    disturb_action_delay_cache = 0;
    disturb_post_action_delay_cache = 0;
    disturb_post_full_cache = 6;
    disturb_car_alarm_cache = 1000;
    disturb_bot_exception_cache = 1;
    disturb_game_type_enabled_cache = "";
    disturb_advertise_cache = 1;
    disturb_displaybar_cache = 1;
    disturb_display_admin_cache = 1;
    disturb_max_common_cache = 30;
    disturb_max_specials_cache = 5;
    disturb_max_tanks_cache = 1;
    disturb_max_witches_cache = 1;
    disturb_max_hunters_cache = 1;
    disturb_max_smokers_cache = 1;
    disturb_max_spitters_cache = 1;
    disturb_max_boomers_cache = 1;
    disturb_max_chargers_cache = 1;
    disturb_max_jockeys_cache = 1;
    disturb_scale_rate_cache = 1.0;
    disturb_scale_type_cache = 0; //0=Linear, 1 = Logarithmic, 2 = Exponential
    disturb_scale_steps_cache = 5;
    disturb_scale_difficulty_cache = 0.5;
    disturb_scale_gametype_versus_cache = 1.0;
    disturb_scale_gametype_coop_cache = 1.0;
    disturb_scale_gametype_survival_cache = 1.0;
    disturb_scale_gametype_scavenge_cache = 1.0;
    gameType = -1;
    gameDifficulty = -1;
    
    
    //Write the config if not already done --Important to be after ConVar hooks and default cache values
    AutoExecConfig(true,"l4d2_disturbed");
    
    //Register our client commands
    RegConsoleCmd("sm_disturb", SayDisturb);
    RegConsoleCmd("sm_disturbed", SayDisturb);
    RegAdminCmd("sm_disturb_admin", SayDisturbAdmin, disturb_admin_flags_cache);
    RegAdminCmd("sm_disturbed_admin", SayDisturbAdmin, disturb_admin_flags_cache);
    
    //Determine the action divisor
    disturbTimerRuns = RoundFloat(disturb_action_time_cache);
    
    //Counting
    disturbBulletCount = 0;
    disturbTotalShotCount = 0;
    
    //Setup the Trie's
    initializeTrieError = InitializeWeaponTrie();
    #if DEBUG 1
    if(initializeTrieError == 1) LogMessage("OnPluginStart->InitializeTrieError: True");
    #endif
    
    InitializeWeaponTrie();
    InitializeCommandTrie();
    
    //Format our Pattern and Compile our Regex
    Format(weaponPattern,MAX_REGEX_STRING,"([a-zA-Z0-9_]+):([0-9.]+)");
    disturbWeaponRegEx = CompileRegex(weaponPattern,0,"",regExError);
    if (regExError != 0 ) disturbWeaponRegEx = INVALID_HANDLE;
    
    Format(gameTypePattern,MAX_REGEX_STRING,"([a-zA-Z]+)");
    disturbGameTypeRegEx = CompileRegex(gameTypePattern,0,"",regExError);
    if (regExError != 0 ) disturbGameTypeRegEx = INVALID_HANDLE;
    
    Format(difficultyPattern,MAX_REGEX_STRING,"([a-zA-Z]+):([0-9.]+)");
    disturbDifficultyRegEx = CompileRegex(difficultyPattern,0,"",regExError);
    if (regExError != 0 ) disturbDifficultyRegEx = INVALID_HANDLE;
    
}

public OnPluginEnd()
{
    //Write out the config if not already done
    //Just Incase----------------------
    if((disturbTimer !=INVALID_HANDLE)) CloseHandle(disturbTimer);
}

/*======================
*   Server ID
=======================*/
public Action:IdentifyServer(Handle:event, const String:name[], bool:dontBroadcast)
{
    
    GetEventString(event, "address", ServerInfo[0][0], MDU);
    GetEventString(event, "port", ServerInfo[1][0], MDU);
    GetEventString(event, "hostname", ServerInfo[2][0], MDU);
    #if DEBUG 1
    LogMessage("Disturbed(IdentifyServer): Server Address->%s", ServerInfo[0][0]);
    LogMessage("Disturbed(IdentifyServer): Server Port->%s", ServerInfo[1][0]);
    LogMessage("Disturbed(IdentifyServer): Server HostName->%s", ServerInfo[2][0]);
    #endif
}

/*=====================================================================
*   OnConfigsExecuted
======================================================================*/
public OnConfigsExecuted()
{
    new String:conVarStrTemp[MDU];
    //To be or not to be
    #if DEBUG 1
    GetConVarString(FindConVar("l4d2_disturbed_displaybar"), conVarStrTemp, MDU);
    LogMessage("Disturbed(OnConfigsExecuted): ->%s", conVarStrTemp);
    #endif
}

/*=======================================
*   OnClientPutinServer
* 
*   Display instructions if necessary
========================================*/
public OnClientPutInServer(client)
{
    AdvertiseToClients(client);
}

/*===============================================
*   WeaponFire
* 
*   Here we hook the weapon_fire even and "Trie"
*   to set a value as quickly as possible. Punny.
================================================*/
public Action:WeaponFire(Handle:event, String:event_name[], bool:dontBroadcast)
{
    //new tempBulletCount = 0;
    new bool:success = false;
    new weaponID = -1;
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    decl String:weapon[WEAPON_SIZE];
    if(client > 0 && IsValidEntity(client) && IsValidEdict(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
    {
        if(disturb_bot_exception_cache == 1 && IsFakeClient(client)) { return Plugin_Continue; }
        GetEventString(event, "weapon", weapon, sizeof(weapon));
        success = GetTrieValue(disturbWeaponTrie,weapon,weaponID);
        if((weaponID >=0) && (weaponID < WEAPON_COUNT) && success) {
            weaponStats[2][weaponID] = FloatAdd(weaponStats[2][weaponID],1.0);
            disturbBulletCount++;
            disturbTotalShotCount++;
        }
    }
    return Plugin_Continue;
}

/*==============================================
*   CarAlarm
*   
*   If the car alarm goes off and the 
*   setting is turned on go to Max immediately!
===============================================*/
public Action:CarAlarm(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(disturb_car_alarm_cache > 0 )
    {
        if(disturbOutsideEventValue + disturb_car_alarm_cache < DISTURB_SCALE_MAX)
        {
            disturbOutsideEventValue = disturbValue + disturb_car_alarm_cache;
        } else { disturbOutsideEventValue = DISTURB_SCALE_MAX; }
        #if DEBUG 1
        LogMessage("Disturbed(CarAlarm): Triggered::disturbValue->%i", disturbOutsideEventValue);
        #endif
    }
    return Plugin_Continue;
}

/*================================================
*   RoundStartCheck - RoundEndCheck
* 
*   Let the counting begin and end
*   perhaps maybe kinda...
=================================================*/
public Action:RoundStartCheck(Handle:event, const String:name[], bool:dontBroadcast)
{
    #if DEBUG 1
    LogMessage("Disturbed(RoundStartCheck): StartTimer->%f", disturb_calc_shots_cache);
    #endif
    //Disturbed Timers
    /*if((disturbTimer == INVALID_HANDLE))
    {
        disturbTimer = CreateTimer(disturb_calc_shots_cache,DisturbTimerSprung,_,TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
    
    Reset();
    disturbCurrentRun = 0;*/
    
    return Plugin_Continue;
}

public Action:RoundEndCheck(Handle:event, const String:name[], bool:dontBroadcast)
{
    if((disturbTimer !=INVALID_HANDLE))
    {
        CloseHandle(disturbTimer);
        disturbTimer = INVALID_HANDLE;
    }
    return Plugin_Continue;
}

public Action:PlayerLeftStartCheck(Handle:event, const String:name[], bool:dontBroadcast)
{
    #if DEBUG 1
    LogMessage("Disturbed(PlayerLeftStartCheck): StartTimer->%f", disturb_calc_shots_cache);
    #endif
    //Disturb Timer
    if((disturbTimer == INVALID_HANDLE))
    {
        disturbTimer = CreateTimer(disturb_calc_shots_cache,DisturbTimerSprung,_,TIMER_REPEAT);
    }
    return Plugin_Continue;
}

/*=====================================================
*   OnMapStart - OnMapEnd
* 
*   Initialize our variables at the 
*   beginning and end of maps
=====================================================*/
public OnMapStart()
{   
    GetCurrentMap(CurrentMap,MDU);
    InitializeWeaponArray();
    disturbValue = 0;
    #if DEBUG 1
    LogMessage("Disturbed(OnMapStart): Loading Map->%s", CurrentMap);
    #endif
    #if DEBUG 1
    LogMessage("Disturbed(OnMapStart): Calc Interval->%f", disturb_calc_shots_cache);
    #endif
    if (disturbCurrentRun != 0)
    {
        //This should be 0 unless the last map didn't end.
        disturbCurrentRun = 0;
    }
    
    //Get Difficulty and GameType for rate modifications
    //CheckGameType();
    //CheckDifficulty();
}

public OnMapEnd()
{
    Reset();
    //Tells the plugin that we actually made it to map end (important!)
    disturbCurrentRun = 0;
}

/*==================================================
*   SayDisturb
*   
*   Command Structure proceeds
* ===================================================*/
public Action:SayDisturb(client, args)
{
    new String:command[MAX_ARG_LEN];
    GetCmdArg(1,command, MAX_ARG_LEN);
    if(StrEqual(command,""))
    {
        HelpPanel(client);
    } 
    else if(StrEqual(command,"mod") || StrEqual(command,"mods") || StrEqual(command,"modifiers"))
    {
        ModifiersPanel(client);
    } 
    else if(StrEqual(command,"stat") || StrEqual(command,"stats") || StrEqual(command,"statistics"))
    {
        StatsPanel(client);
    } 
    else {
        //Help
        HelpPanel(client);
        
    }
    return Plugin_Handled;
}

/*==================================================
*   SayDisturbAdmin
*   
*   Command Structure proceeds
* ===================================================*/
public Action:SayDisturbAdmin(client, args)
{
    new String:command[MAX_ARG_LEN], String:tempMod[MAX_ARG_LEN];
    new bool:checkSet;
    new Float:checkFloat;
    
    GetCmdArg(1,command, MAX_ARG_LEN);
    if(StrEqual(command,"mod", false) || StrEqual(command,"mods", false) || StrEqual(command,"modifiers", false) || StrEqual(command,"modifier", false))
    {
        GetCmdArg(2,tempMod, MAX_ARG_LEN);
        if(StrEqual(tempMod, "") == false)
        {
            GetCmdArg(3,command, MAX_ARG_LEN);
            StrCat(tempMod,MAX_ARG_LEN,":");
            StrCat(tempMod,MAX_ARG_LEN,command);
            checkSet = WeaponModifier(tempMod);
            if(checkSet)
            {
                //Notify the User
                DisplayAdminText(client, "%t%t","Banner","Weapon Modifier Changed");
            }
            else
            {
                //Notify the User
                DisplayAdminText(client, "%t%t","Banner","Bad Weapon Modifier");
            }
            return Plugin_Handled;
        }
    } 
    else if(StrEqual(command,"rate"))
    {
        GetCmdArg(2,command, MAX_ARG_LEN);
        if(StrEqual(command,"linear"))
        {
            SetConVarInt(disturbScaleType,0,false,false);
            GetCmdArg(3,command, MAX_ARG_LEN);
            if(StrEqual(command,"") == false)
            {
                checkFloat = StringToFloat(command);
                SetConVarFloat(disturbScaleRate,checkFloat,false,false);
            }
            //Notify the User
            DisplayAdminText(client, "%t%t","Banner","Linear Scaling", checkFloat);
            return Plugin_Handled;
        } 
        else if(StrEqual(command,"logarithm"))
        {
            SetConVarInt(disturbScaleType,1,false,false);
            GetCmdArg(3,command, MAX_ARG_LEN);
            if(StrEqual(command,"") == false)
            {
                checkFloat = StringToFloat(command);
                SetConVarFloat(disturbScaleRate,checkFloat,false,false);
            }
            //Notify the User               
            DisplayAdminText(client, "%t%t","Banner","Logarithmic Scaling", checkFloat);
            return Plugin_Handled;
        } 
        else if(StrEqual(command,"exponential"))
        {
            SetConVarInt(disturbScaleType,2,false,false);
            GetCmdArg(3,command, MAX_ARG_LEN);
            if(StrEqual(command,"") == false)
            {
                checkFloat = StringToFloat(command);
                SetConVarFloat(disturbScaleRate,checkFloat,false,false);
            }
            //Notify the User
            DisplayAdminText(client, "%t%t","Banner","Exponential Scaling", checkFloat);
            return Plugin_Handled;
        }
        else
        {
            //Notify the User
            DisplayAdminText(client, "%t%t","Banner","Bad Scale");
            return Plugin_Handled;
        }
    } 
    else if(StrEqual(command,"botexceptions")|| StrEqual(command,"bot")||StrEqual(command,"bots"))
    {
        GetCmdArg(2,command, MAX_ARG_LEN);
        if(StrEqual(command,"off"))
        {
            SetConVarInt(disturbBotExceptions,0,false,false);
            DisplayAdminText(client, "%t%t","Banner","Bot Exception Off");
        } 
        else if(StrEqual(command,"on"))
        {
            SetConVarInt(disturbBotExceptions,1,false,false);
            DisplayAdminText(client, "%t%t","Banner","Bot Exception On");
        }
    }
    else if(StrEqual(command,"calm")|| StrEqual(command,"cal"))
    {
        GetCmdArg(2,command, MAX_ARG_LEN);
        if(StrEqual(command,"") == false)
        {
            checkFloat = StringToFloat(command);
            SetConVarFloat(disturbCalmRate,checkFloat,false,false);
        }
    } 
    else 
    {
        //Help
        HelpAdminPanel(client);
    }
    return Plugin_Handled;
}

/*==================================================
*   DisplayAdminText
*   
*   Base output from admin commands on output type
===================================================*/
public DisplayAdminText(int client,const String:formatString[], any:...)
{
    new String:fullString[strlen(formatString)+255];
    VFormat(fullString, strlen(fullString),formatString, 3);
    if(disturb_display_admin_cache % 2 == 1)
    {
        PrintToChat(client,fullString);
    }
    if(disturb_display_admin_cache > 1)
    {
        PrintHintText(client, fullString);
    }
}

/*==================================================
*   Panels and Menus
*   
*   Output Panels
===================================================*/
public StatsPanel(client)
{
    new Handle:panel = CreatePanel();
    new String:textHold[PANEL_STRING_SIZE];
    
    //Heading
    SetPanelTitle(panel, "Disturbed Stats");
    DrawPanelText(panel, " ");
    //Current Stats for this round
    
    Format(textHold, PANEL_STRING_SIZE, "Current Bullet Count:      %i", disturbBulletCount);
    DrawPanelText(panel, textHold);
    Format(textHold, PANEL_STRING_SIZE, "Disturb Value:             %i", disturbValue);
    DrawPanelText(panel, textHold);
    for(new i=0; i<WEAPON_COUNT; i++)
    {
        if (FloatCompare(weaponStats[2][i],0.0) == 0)
        {
            new Float:floatValue;
            if((FloatCompare(weaponModifiers[i],0.0) >=0 ))
            {
                if(FloatCompare(weaponStats[2][i], 0.0) == 1) floatValue = FloatMul(weaponStats[0][i], 0.1);
                if(floatValue > float(DISTURB_SCALE_MAX)) floatValue = float(DISTURB_SCALE_MAX);
            }
            Format(textHold, PANEL_STRING_SIZE, "%s:      %i%%", weaponArray[i], RoundFloat(floatValue));
            DrawPanelText(panel, textHold);
        }
    }
    //Close
    Format(textHold, PANEL_STRING_SIZE, "Close");
    DrawPanelItem(panel, textHold);
    //Display
    SendPanelToClient(panel, client, StatsPanelHandler, DISTURB_PANEL_VISIBLE_TIMEOUT);
    //Free
    CloseHandle(panel);
}
public StatsPanelHandler(Handle:menu, MenuAction:action, param1, param2) { return; }

/*==========================================
*   ModifiersPanel
* 
*   Displays weapon modifiers
*===========================================*/
public ModifiersPanel(client)
{
    new Handle:panel = CreatePanel();
    new String:textHold[PANEL_STRING_SIZE], String:tempWeaponValue[WEAPON_SIZE], String:tempRate[MAX_DATA_UNIT];
    
    //Heading
    SetPanelTitle(panel, "Weapon Modifiers");
    DrawPanelText(panel, " ");
    
    
    switch (disturb_scale_type_cache)
    {
        case 0: //Linear
        {
            Format(textHold, PANEL_STRING_SIZE, "Rate-Type:      Linear");
            DrawPanelText(panel, textHold);
            
            FloatToString(disturb_scale_rate_cache,tempRate,MAX_DATA_UNIT);
            Format(textHold, PANEL_STRING_SIZE, "Rate:      %s", tempRate) ;
            DrawPanelText(panel, textHold);
            DrawPanelText(panel, " ");
        }
        case 1: //Logarithmic
        {
            Format(textHold, PANEL_STRING_SIZE, "Rate-Type:      Logarithmic");
            DrawPanelText(panel, textHold);
            
            FloatToString(FloatDiv(FloatAdd(-disturb_scale_rate_cache,30.0), DISTURB_SCALE_LOG_MOD),tempRate,MAX_DATA_UNIT);
            Format(textHold, PANEL_STRING_SIZE, "Rate:      %s", tempRate) ;
            DrawPanelText(panel, textHold);
            DrawPanelText(panel, " ");
        }
        case 2: //Exponential
        {
            Format(textHold, PANEL_STRING_SIZE, "Rate-Type:      Exponential");
            DrawPanelText(panel, textHold);
            
            FloatToString(FloatDiv(disturb_scale_rate_cache,10.0),tempRate,MAX_DATA_UNIT);
            Format(textHold, PANEL_STRING_SIZE, "Rate:      %s", tempRate) ;
            DrawPanelText(panel, textHold);
            DrawPanelText(panel, " ");
        }
        
    }
    
    
    for(new i=0; i<WEAPON_COUNT; i++)
    {
        FloatToString(weaponModifiers[i],tempWeaponValue, WEAPON_SIZE);
        Format(textHold, PANEL_STRING_SIZE, "%s:      %s", weaponArray[i], tempWeaponValue);
        DrawPanelText(panel, textHold);
    }
    //Close
    Format(textHold, PANEL_STRING_SIZE, "Close");
    DrawPanelItem(panel, textHold);
    //Display
    SendPanelToClient(panel, client, ModifiersPanelHandler, DISTURB_PANEL_VISIBLE_TIMEOUT);
    //Free
    CloseHandle(panel);
}
public ModifiersPanelHandler(Handle:menu, MenuAction:action, param1, param2) { return; }

/*==========================================
*   HelpPanel
* 
*   Help for standard chat commands
*===========================================*/
public HelpPanel(client)
{
    new Handle:panel = CreatePanel();
    new String:textHold[PANEL_STRING_SIZE];
    
    //Heading
    SetPanelTitle(panel, "Disturbed Command Help");
    DrawPanelText(panel, " ");
    
    //Stats
    Format(textHold, PANEL_STRING_SIZE, "Stats:                 !disturbed stats");
    DrawPanelText(panel, textHold);
    //Modifiers
    Format(textHold, PANEL_STRING_SIZE, "Modifiers:                 !disturbed modifiers");
    DrawPanelText(panel, textHold);
    //Help
    Format(textHold, PANEL_STRING_SIZE, "Help:                  !disturbed help");
    DrawPanelText(panel, textHold);
    //Close
    Format(textHold, PANEL_STRING_SIZE, "Close");
    DrawPanelItem(panel, textHold);
    
    //Display
    SendPanelToClient(panel, client, HelpPanelHandler, DISTURB_PANEL_VISIBLE_TIMEOUT);
    //Free
    CloseHandle(panel);
}
public HelpPanelHandler(Handle:menu, MenuAction:action, param1, param2) { return; }

/*==========================================
*   HelpAdminPanel
* 
*   Help for admin chat commands
*===========================================*/
public HelpAdminPanel(client)
{
    new Handle:panel = CreatePanel();
    new String:textHold[PANEL_STRING_SIZE];
    
    //Heading
    SetPanelTitle(panel, "Disturbed Admin Command Help");
    DrawPanelText(panel, " ");
    
    //Modifiers
    Format(textHold, PANEL_STRING_SIZE, "Modifier:              !disturbed_admin modifier weapon_name <num>");
    DrawPanelText(panel, textHold);
    //Rate
    Format(textHold, PANEL_STRING_SIZE, "Rate:              !disturbed_admin rate <linear|logarithm|exponential> <num>");
    DrawPanelText(panel, textHold);
    //Bot Exception
    Format(textHold, PANEL_STRING_SIZE, "Bot Exceptions:                !disturbed_admin botexceptions <on|off>");
    DrawPanelText(panel, textHold);
    //Help
    Format(textHold, PANEL_STRING_SIZE, "Help:                  !disturbed_admin help");
    DrawPanelText(panel, textHold);
    //Close
    Format(textHold, PANEL_STRING_SIZE, "Close");
    DrawPanelItem(panel, textHold);
    
    //Display
    SendPanelToClient(panel, client, HelpAdminPanelHandler, DISTURB_PANEL_VISIBLE_TIMEOUT);
    //Free
    CloseHandle(panel);
}
public HelpAdminPanelHandler(Handle:menu, MenuAction:action, param1, param2) { return; }

/*==========================================
*   DrawStatusBar
*   
*   Chat-based status bar
===========================================*/
public DrawStatusBar(value, String:sign[])
{
    new Float:floatValue;
    new const String:dashes[] = "-";
    new String:tempText[MDU];
    new String:left[MDU],String:right[MDU];
    new leftLen,rightLen;
    
    if(disturb_displaybar_cache > 0)
    {
        floatValue = FloatMul(float(value), 0.001);
        rightLen= RoundToFloor(FloatDiv(24 - FloatMul(floatValue,24.0),1.0));
        leftLen = RoundToFloor(FloatDiv(FloatMul(floatValue,24.0),1.0));
        
        for(new i=0; i<leftLen; i++)
        {
            StrCat(left,MDU,dashes);
        }
        for(new i=0; i < rightLen; i++)
        {
            StrCat(right,MDU,dashes);
        }
        Format(tempText,MDU, "<:%s %3i%% %s:>", sign, RoundToFloor(FloatMul(floatValue,100.0)), sign);
        #if DEBUG 1
        LogMessage("DrawStatusBar: %s", tempText);
        #endif
        if(disturb_enable_spawns_cache == 1)
        {
            if(disturb_displaybar_cache %2 == 1)
            {
                PrintToChatAll("\x05%t\x04[%s\x05%s\x04%s]","Banner Bar On",left,tempText,right);
            }
            if(disturb_displaybar_cache > 1)
            {
                PrintHintTextToAll("%t[%s%s%s]","Banner Bar On",left,tempText,right);
            }
        } 
        else
        {
            PrintToChatAll("\x05%t\x04[%s\x05%s\x04%s]","Banner Bar Off",left,tempText,right);
        }
        //[<:  0% :>------------------------]
    }
}

/*==========================================
*   DisturbTimerSprung
* 
*   Just a wrapper
===========================================*/
public Action:DisturbTimerSprung(Handle:timer)
{
    
    #if DEBUG 1
    LogMessage("DisturbTimerSpring->OutsideRun::disturbValue:%i", disturbValue);
    LogMessage("DisturbTimerSpring->OutsideRun::disturbCurrentRun:%i", disturbCurrentRun);
    #endif
    //Separate Calculations from Actions
    if((disturbCurrentRun >=0) && (disturbCurrentRun <= RoundFloat(disturb_action_time_cache)))
    {
        
        #if DEBUG 1 
        LogMessage("Disturbed(DisturbTimerSprung): BulletCount->%i",disturbBulletCount);
        #endif
        disturbValueLast = disturbValue;
        DisturbCalc();
        //disturbCurrentRun++;
        if(disturbValueLast > disturbValue)
        {
            DrawStatusBar(disturbValue,"-");
        } else if(disturbValueLast < disturbValue)
        {
            DrawStatusBar(disturbValue,"+");
        } else if(disturbValueLast == disturbValue)
        {
            DrawStatusBar(disturbValue,"=");
        }
        
        if((disturbCurrentRun == RoundFloat(disturb_action_time_cache)))
        {
            //Try to spawn at least one special
            #if DEBUG 1
            LogMessage("DisturbTimerSpring->Action::disturbValue:%i", disturbValue);
            #endif
            if((disturb_enable_spawns_cache == 1) && (disturbWaitActions == 0))
            {
                new Float:commonValue;
                if(disturbValue >= DISTURB_SCALE_LOW)
                {
                    for(new r=0; r<SPECIALS_NO_TANK_OR_WITCH; r++)
                    {
                        new bool:stat = SpawnRandomSpecial();
                        if(stat == true) break;
                        #if DEBUG 1
                        LogMessage("DisturbTimerSprung->Spawn:special");
                        #endif
                    }
                }
                if(disturbValue >= DISTURB_SCALE_MED)
                {
                    
                    for(new r=0; r < SPECIALS_NO_TANK_OR_WITCH; r++)
                    {
                        new bool:stat = SpawnRandomSpecial();
                        if(stat == true) break;
                        #if DEBUG 1
                        LogMessage("DisturbTimerSprung->Spawn:special");
                        #endif
                    }
                }
                commonValue = FloatDiv(float(disturbValue),100.0);
                if((disturbValue <= DISTURB_SCALE_MAX) && (disturbValue >= DISTURB_SCALE_LOW))
                {
                    new spawned = 0;
                    #if DEBUG 1
                    LogMessage("DisturbTimerSprung->Spawn:common:%f",commonValue);
                    #endif
                    for(new t=0;t<RoundToFloor(commonValue);t++)
                    {
                        if((t<=spawned) && (t<=disturb_max_common_cache))
                        {
                            
                            new bool:stat = Spawn("common");
                            
                            if(stat == false) break;
                            spawned++;
                        }
                    }
                }
                if(disturbValue >= DISTURB_SCALE_MID)
                {   
                    Spawn("mob");
                }
                if(disturbValue >= DISTURB_SCALE_HIGH)
                {
                    Spawn("witch");
                }
                if(disturbValue >= DISTURB_SCALE_HIGHER) {
                    {   
                        SpawnRandomTorW();
                        disturbWaitActions = disturb_post_full_cache;
                    }
                } 
            } else { if(disturbWaitActions > 0) disturbWaitActions--; }
            //disturbCurrentRun = 0;
        }
    } else { 
        disturbCurrentRun = 0;
        #if DEBUG 1
        LogMessage("DisturbTimerSpring->Reset");
        #endif
    }
    Calm();
    disturbCurrentRun++;
    return Plugin_Continue;
}

/*==========================================
*   DisturbCalc
* 
*   Calculate the disturb value
===========================================*/
public DisturbCalc()
{
    new Float:floatBuffer,Float:weaponStat,Float:weaponMod, Float:weaponTemp;
    new Float:logTemp, Float:difficultyModTemp;
    
    
    if(FloatCompare(disturb_scale_gametype_versus_cache,0.0) == 1)
    {
        difficultyModTemp = disturb_scale_gametype_versus_cache;
    } 
    else 
    { 
        difficultyModTemp = 1.0;
    }
    
    for (new i=0; i < WEAPON_COUNT;i++)
    {
        //weaponStats[2][i] = weaponStats[2][i] - weaponStatsCache[0][i];
        if((weaponModifiers[i] >= 0) && (weaponStats[2][i] >= 0))
        {
            weaponStat = weaponStats[2][i];
            weaponMod = weaponModifiers[i];
            if(disturb_scale_type_cache == DISTURB_SCALE_LINEAR)
            {
                weaponTemp = FloatMul(weaponStat,weaponMod);
                weaponStats[0][i] = weaponTemp;
                floatBuffer = FloatAdd(floatBuffer,weaponTemp);
                
                
            } 
            else if(disturb_scale_type_cache == DISTURB_SCALE_LOGARITHMIC) 
            {
                logTemp = FloatMul(weaponStat,weaponMod);
                if(FloatCompare(logTemp, 0.0) == 1)
                {
                    weaponTemp = FloatMul(FloatDiv(float(DISTURB_SCALE_MAX),disturb_scale_rate_cache),Logarithm(logTemp));
                    weaponStats[0][i] = weaponTemp;
                    #if DEBUG 1
                    LogMessage("DisturbCalc->weaponTemp:%f", weaponTemp);
                    #endif
                    floatBuffer = FloatAdd(floatBuffer,weaponTemp);
                }
                
            } 
            else if(disturb_scale_type_cache == DISTURB_SCALE_EXPONENTIAL) 
            {
                weaponTemp = FloatMul(FloatDiv(disturb_scale_rate_cache,float(DISTURB_SCALE_MAX)), FloatMul(FloatMul(weaponStat,weaponMod),FloatMul(weaponStat,weaponMod)));
                weaponStats[0][i] = weaponTemp;
                floatBuffer = FloatAdd(floatBuffer,weaponTemp);
                
        }
            if(floatBuffer > float(DISTURB_SCALE_MAX)) floatBuffer = float(DISTURB_SCALE_MAX);
            #if DEBUG 1
            LogMessage("DisturbCalc->disturbValue:%f", floatBuffer);
            #endif
        } 
        else 
        {
            #if DEBUG 1
            LogMessage("DisturbCalc->Zero modifier and stats!");
            #endif
        }
    }
    //Handicap rather than not counting bots at all...save for later
    /*if(disturb_bot_exception_cache == 0)
    { 
    counts[] = CheckSurvivors();
    if(counts[0] > 0 && counts[1] > 0)
    {
    playerTotal = counts[0] + counts[1];
    #if DEBUG 1
    LogMessage("DisturbCalc->survivorCount:%i",counts[0]);
    LogMessage("DisturbCalc->botCount:%i",counts[1]);
    #endif
    floatBuffer = FloatMul(floatBuffer,float(counts[0]/playerTotal));
    }
    }*/
    if(RoundToFloor(floatBuffer) + disturbOutsideEventValue < DISTURB_SCALE_MAX)
    {
        disturbValue = RoundToFloor(floatBuffer) + disturbOutsideEventValue;
    } 
    else { disturbValue = DISTURB_SCALE_MAX;}   
    return;
    
}

/*==========================================
*   Calm
* 
*   Decrement the counts at the configured rate
===========================================*/
public Calm()
{
    new testValue;
    new Float:tempValue;
    for (new i=0; i<WEAPON_COUNT;i++)
    {
        tempValue = FloatSub(weaponStats[2][i],FloatMul(weaponStats[2][i],disturb_calm_rate_cache));
        testValue = FloatCompare(tempValue,0.000000);
        if(testValue == 1)
        {
            weaponStats[2][i] = tempValue;
            #if DEBUG 1
            LogMessage("Calm::WeaponStats->%f",weaponStats[2][i]);
            #endif
        }
        else { weaponStats[2][i] = 0.00000;}
    }
    testValue = disturbBulletCount - RoundToCeil(FloatMul(float(disturbBulletCount),disturb_calm_rate_cache));
    if(testValue >= 1)
    {
        disturbBulletCount = testValue;
        
    } 
    else { disturbBulletCount = 0;}
    testValue = disturbOutsideEventValue - RoundToCeil(FloatMul(float(disturbOutsideEventValue),disturb_calm_rate_cache));
    if(testValue >= 1)
    {
        disturbOutsideEventValue = testValue;
        
    } 
    else { disturbOutsideEventValue = 0;}
    //return Plugin_Continue;
    #if DEBUG 1
    LogMessage("Calm->%i:%i:%f", disturbBulletCount,disturbValue,(FloatMul(float(disturbBulletCount),disturb_calm_rate_cache)));
    #endif
    return;
}

/*==========================================
*   Reset
* 
*   Reset to nothing
===========================================*/
public Reset()
{
    InitializeWeaponArray();
    disturbBulletCount = 0;
    disturbValue = 0;
    disturbValueLast = 0;
    disturbWaitActions = 0;
    disturbOutsideEventValue = 0;
    return;
}

/*==========================================
*   InitializeWeaponTrie
* 
*   Populate a Trie object 
*   with all the weapon names as keys and
*   zero it out
===========================================*/
bool:InitializeWeaponTrie()
{
    //Need a good array or it should fail completely
    if(StrContains(weaponArray[0], "weapon", false) == -1)
    {
        disturbWeaponTrie = CreateTrie();
        for(new i=0; i<WEAPON_COUNT; i++)
        {
            if(StrContains(weaponArray[i],"weapon",false) == -1)
            {
                SetTrieValue(disturbWeaponTrie,weaponArray[i],i,true);
                #if DEBUG 1
                LogMessage("InitializeWeaponTrie->%s:   %i", weaponArray[i],i);
                #endif
            }
        }
        return true;
    }
    
    return false;
}

/*==========================================
*   InitializeCommandTrie
* 
*   Populate a Trie object 
*   with all the command names as keys and
*   zero it out
===========================================*/
bool:InitializeCommandTrie()
{
    new arrSize;
    arrSize = sizeof(commandArray);
    //Need a good array or it should fail completely
    if(StrEqual(commandArray[0][0], "") == false)
    {
        disturbCommandTrie = CreateTrie();
        for(new i=0; i < arrSize; i++)
        {
            if(StrEqual(commandArray[i][0],"") == false)
            {
                SetTrieValue(disturbCommandTrie,commandArray[i][0],i,true);
                #if DEBUG 1
                LogMessage("InitializeCommandTrie->%s:  %i", commandArray[i],i);
                #endif
            }
        }
        return true;
    }
    return false;
}

/*==========================================
*   InitializeWeaponArray
* 
*   Zero out the third dimension
===========================================*/
InitializeWeaponArray()
{
    //Initialize the array values
    for(new i=0; i<WEAPON_COUNT; i++)
    {
        //Fire Count Stats
        weaponStats[2][i] = 0.000000;
    }
    return;
}

/*==========================================
*   SpawnRandomTorW
* 
*   Spawn one or the other at random
===========================================*/
public bool:SpawnRandomTorW()
{
    //if(CheckSpecialSpawns(ZOMBIE_CLASS_TANK, disturb_max_tanks_cache)
    new randVal = GetRandomInt(0, 1);
    #if DEBUG 1
    LogMessage("SpawnRandomTorW->randVal:%i",randVal);
    #endif
    if(Spawn(specialTankWitch[randVal]) == true) return true;
    return false;
}

/*==========================================
*   SpawnRandomSpecial
* 
*   Spawn one random special zombie
===========================================*/
public bool:SpawnRandomSpecial()
{
    SetRandomSeed(GetURandomInt());
    new randVal = GetRandomInt(0, SPECIALS_NO_TANK_OR_WITCH - 1);
    #if DEBUG 1
    LogMessage("SpawnRandomSpecial->randVal:%i",randVal);
    #endif
    if(Spawn(specialArray[randVal]) == true) return true;
    return false;
}

/*==========================================
*   Spawn
* 
*   Spawn infected
===========================================*/
public bool:Spawn(String:type[])
{
    new client;
    if (strcmp(type[0],"hunter",false) == 0)
    {
        if (CheckSpecialSpawns(ZOMBIE_CLASS_HUNTER, disturb_max_hunters_cache) == false)
        {
            client = GetAnyClient();
            if(client > 0)
            {
                CheatCommand(client, "z_spawn_old", "hunter auto");
                return true;
            } else return false;
        } else { return false;}
    }
    if (strcmp(type[0],"smoker",false) == 0)
    {
        if (CheckSpecialSpawns(ZOMBIE_CLASS_SMOKER, disturb_max_smokers_cache) == false)
        {
            client = GetAnyClient();
            if(client > 0)
            {
                CheatCommand(client, "z_spawn_old", "smoker auto");
                return true;
            } else return false;
        } else return false;
    }
    if (strcmp(type[0],"boomer",false) == 0)
    {
        if (CheckSpecialSpawns(ZOMBIE_CLASS_BOOMER, disturb_max_boomers_cache) == false)
        {
            client = GetAnyClient();
            if(client > 0)
            {
                CheatCommand(client, "z_spawn_old", "boomer auto");
                return true;
            } else return false;
        } else return false;
    }
    if (strcmp(type[0],"spitter",false) == 0)
    {
        if (CheckSpecialSpawns(ZOMBIE_CLASS_SPITTER, disturb_max_spitters_cache) == false)
        {
            client = GetAnyClient();
            if(client > 0)
            {
                CheatCommand(client, "z_spawn_old", "spitter auto");
                return true;
            } else return false;
        } else return false;
    }
    if (strcmp(type[0],"charger",false) == 0)
    {
        if (CheckSpecialSpawns(ZOMBIE_CLASS_CHARGER, disturb_max_chargers_cache) == false)
        {
            client = GetAnyClient();
            if(client > 0)
            {
                CheatCommand(client, "z_spawn_old", "charger auto");
                return true;
            } else return false;
        } else return false;
    }
    if (strcmp(type[0],"jockey",false) == 0)
    {
        if (CheckSpecialSpawns(ZOMBIE_CLASS_JOCKEY, disturb_max_jockeys_cache) == false)
        {
            client = GetAnyClient();
            if(client > 0)
            {
                CheatCommand(client, "z_spawn_old", "jockey auto");
                return true;
            } else return false;
        } else return false;
    }
    if (strcmp(type[0],"witch",false) == 0)
    {
        if (CheckSpecialSpawns(ZOMBIE_CLASS_WITCH, disturb_max_witches_cache) == false)
        {
            client = GetAnyClient();
            if(client > 0)
            {
                CheatCommand(client, "z_spawn_old", "witch auto");
                return true;
            } else return false;
        } else return false;
    }
    if (strcmp(type[0],"tank",false) == 0)
    {
        if (CheckSpecialSpawns(ZOMBIE_CLASS_TANK, disturb_max_tanks_cache) == false)
        {
            client = GetAnyClient();
            if(client > 0)
            {
                CheatCommand(client, "z_spawn_old", "tank auto");
                return true;
            } else return false;
        } else return false;
    }
    if (strcmp(type[0],"common",false) == 0)
    {
        client = GetAnyClient();
        if(client > 0)
        {
            CheatCommand(client, "z_spawn_old", "common auto");
            return true;
        } else return false;
    }
    if (strcmp(type[0],"mob",false) == 0)
    {
        client = GetAnyClient();
        if(client > 0)
        {
            CheatCommand(client, "z_spawn_old", "mob auto");
            return true;
        } else return false;
    }
    if (strcmp(type[0],"special",false) == 0)
    {
        return SpawnRandomSpecial();
    }
    return true;
}

/*==========================================
*   CheckSpecialSpawns
* 
*   Check if over the limit for Specials
===========================================*/
bool:CheckSpecialSpawns(zombieClass, max)
{
    new specialCount = 0;
    for (new i=1; i<=MaxClients; i++)
    {
        #if DEBUG 1
        LogMessage("CheckSpecialSpawns->i:%i",i);
        #endif
        if(IsClientInGame(i))
        {
            if(GetClientTeam(i) == 3)
            {
                if (GetEntProp(i, Prop_Send, "m_zombieClass") == zombieClass)
                {
                    //That's the sign
                    #if DEBUG 1
                    LogMessage("CheckSpecialSpawns->Match::i:%i",i);
                    #endif
                    if (specialCount >= max ) return true;
                    specialCount++;
                }
            }
        }
    }
    return false;
}

/*==========================================
*   CheckSurvivors
* 
*   Count Survivors
===========================================*/
CheckSurvivors()
{
    new counts[2];
    for (new i=1; i<=MaxClients; i++)
    {
        #if DEBUG 1
        LogMessage("CheckSurvivors->i:%i",i);
        #endif
        if(IsClientInGame(i))
        {
            if(GetClientTeam(i) == 2)
            {
                if(!IsFakeClient(i))
                {
                    //survivorCount++;
                    counts[0]++;
                    #if DEBUG 1
                    LogMessage("CheckSurvivors->Survivor::i:%i",i);
                    #endif
                } else
                {
                    //botCount++;
                    counts[1]++;
                    #if DEBUG 1
                    LogMessage("CheckSurvivors->Bot::i:%i",i);
                    #endif
                }
            }
        }
    }
    return counts;
}

/*==========================================
*   CheckDifficulty
* 
*   Return difficulty
===========================================*/
CheckDifficulty()
{
    new String:difficultyStrTemp[MDU];
    
    GetConVarString(FindConVar("z_difficulty"), difficultyStrTemp, MDU);
    
    for(new i=0; i < sizeof(difficultyArray); i++)
    {
        if(StrContains(difficultyStrTemp, difficultyArray[i],false) > -1)
        {
            gameDifficulty = i;
            #if DEBUG 1
            LogMessage("Disturbed(CheckDifficulty): gameDifficulty->%s", difficultyArray[gameDifficulty]);
            #endif
        }
    }
    return;
}

/*==========================================
*   CheckGameType
* 
*   Return Game Type
===========================================*/
CheckGameType()
{
    new String:modeTemp[MDU];
    
    GetConVarString(FindConVar("mp_gamemode"), modeTemp, MDU);
    
    for(new i=0; i < sizeof(gameTypeArray); i++)
    {
        if(StrContains(modeTemp, gameTypeArray[i],false) > -1)
        {
            gameType = i;
            #if DEBUG 1
            LogMessage("Disturbed(CheckGameType): gameType->%s", gameTypeArray[i]);
            #endif
        }
    }
    return;
}

/*==========================================
*   ParseCommand
* 
*   Parse a spawn command
===========================================*/
public bool:ParseCommand(String:type[])
{
    new bool:success;
    new commandID;
    success = GetTrieValue(disturbWeaponTrie,type,commandID);
    if(success)
    {
        if(strcmp(commandArray[commandID][1], "Spawn", false) == 0)
        {
            Spawn(commandArray[commandID][0]);
            return true;
        }
        if (strcmp(commandArray[commandID][1],"SpawnRandomSpecial",false) == 0)
        {
            return SpawnRandomSpecial();
        }
        if (strcmp(commandArray[commandID][1],"SpawnRandomTorW",false) == 0)
        {
            return SpawnRandomTorW();
        }
    }
    return false; //Bad Command
}

/*==========================================
*   WeaponModifier
* 
*   Parse and set a weapon:<num> combination
===========================================*/
bool:WeaponModifier(String:mods[])
{
    new value;
    new bool:test, bool:weaponCheck, bool:valueCheck;
    new String:weaponString[MTS];
    new String:valueString[MTS];
    new Float:valueFloat;
    if ((disturbWeaponRegEx != INVALID_HANDLE) && (disturbWeaponTrie != INVALID_HANDLE))
    {
        #if DEBUG 1
        LogMessage("Disturbed(WeaponModifier): Changed::Start");
        #endif
        #if DEBUG 1
        LogMessage("Disturbed(WeaponModifier): Changed::disturbWeaponRegex->MatchRegex:%i::%s", MatchRegex(disturbWeaponRegEx,mods), mods);
        #endif
        if((MatchRegex(disturbWeaponRegEx,mods) % 3 == 0))
        {
            weaponCheck = GetRegexSubString(disturbWeaponRegEx,1,weaponString,MTS);
            if (weaponCheck)
            {
                #if DEBUG 1
                LogMessage("Disturbed(WeaponModifier): Changed::disturbWeaponRegex->GetRegexSubString:%i", weaponCheck);
                #endif
                value = 0;
                test = GetTrieValue(disturbWeaponTrie,weaponString,value);
                if (test) //Good Weapon Value
                {
                    valueCheck = GetRegexSubString(disturbWeaponRegEx,2,valueString,MTS);
                    if (valueCheck)
                    {
                        valueFloat = StringToFloat(valueString);
                        if(FloatCompare(valueFloat,float(DISTURB_SCALE_MAX)) == -1)
                        {
                            weaponModifiers[value] = valueFloat;
                            
                            #if DEBUG 1
                            LogMessage("Disturbed(WeaponModifier): Changed::weaponModifier->%s:%f",weaponString,valueFloat);
                            #endif
                            return true;
                        }
                    }
                }
            }
        }
    }
    return false;
}

/*==========================================
*   DifficultyModifier
* 
*   Parse and set a difficulty:<num> combination
===========================================*/
bool:DifficultyModifier(String:mods[])
{
    new value, regexCount;
    new bool:test, bool:difficultyCheck, bool:valueCheck;
    new String:difficultyString[MTS];
    new String:valueString[MTS];
    new Float:valueFloat;
    
    if ((disturbDifficultyRegEx != INVALID_HANDLE) && (disturbWeaponTrie != INVALID_HANDLE))
    {
        #if DEBUG 1
        LogMessage("Disturbed(DifficultyModifier): Changed::Start");
        #endif
        #if DEBUG 1
        LogMessage("Disturbed(DifficultyModifier): Changed::disturbDifficultyRegex->MatchRegex:%i::%s", MatchRegex(disturbDifficultyRegEx,mods), mods);
        #endif
        regexCount = MatchRegex(disturbDifficultyRegEx,mods);
        if(regexCount % 3 == 0)
        {
            for(new i=0; i < regexCount; i+3 )
            {
                difficultyCheck = GetRegexSubString(disturbDifficultyRegEx,i+1,difficultyString,MTS);
                if (difficultyCheck)
                {
                    #if DEBUG 1
                    LogMessage("Disturbed(DifficultyModifier): Changed::disturbWeaponRegex->GetRegexSubString:%i", difficultyCheck);
                    #endif
                    for(new r=0; r < sizeOf(difficultyArray[]); r++)
                    {
                        value = 0;
                        test = strcmp(difficultyArray[r],difficultyCheck)
                        if (test==0) //Good Difficulty Value
                        {
                            valueCheck = GetRegexSubString(disturbDifficultyRegEx,i+2,valueString,MTS);
                            if (valueCheck)
                            {
                                valueFloat = StringToFloat(valueString);
                                difficultyModArray[value] = valueFloat;
                                #if DEBUG 1
                                LogMessage("Disturbed(DifficultyModifier): Changed::difficultyModArray->%s:%f",difficultyString,valueFloat);
                                #endif
                            }
                        }
                    }
                }
            }
            return true;
        }
    }
    return false;
}

/*==========================================
*   AdvertiseToClients
* 
*   Separate the Advertising so it can be
*   run at intervals via timer if
*   necessary
===========================================*/
AdvertiseToClients(client)
{
    //Only advertise if we are running silent and ad is turned on
    if ((disturb_advertise_cache==1))
    {
        PrintToChat(client,"\x05%t\x04%t...", "Banner", "Advertise Line 1");
        PrintToChat(client,"\x05%t\x04%t...", "Banner", "Advertise Line 2");
        PrintToChat(client,"\x05%t\x04%t...", "Banner", "Advertise Line 3");
    }   
}

/*==========================================
*   ModifyDisturbRate
* 
*   Allow the user to set one rate 
*   and get equivalent results for each
*   scale type.
===========================================*/
public Float:ModifyDisturbRate(const String:newValue[])
{
    new Float:tempValue;
    
    switch(disturb_scale_type_cache)
    {
        case DISTURB_SCALE_LINEAR:
        {
            return StringToFloat(newValue);
        }
        case DISTURB_SCALE_LOGARITHMIC: 
        {
            tempValue = FloatMul(StringToFloat(newValue), DISTURB_SCALE_LOG_MOD);
            return FloatSub(DISTURB_SCALE_LOG_MAX,tempValue);
            
        }
        case DISTURB_SCALE_EXPONENTIAL: 
        {
            tempValue = FloatMul(StringToFloat(newValue),10.0);
            return tempValue;
        }
        default:
        {
            return StringToFloat(newValue);
        }
    }
    return 0.1;
}

/*======================
*   ConVar Functions
=======================*/
public DisturbedVersionStatic(Handle:convar, const String:oldValue[], const String:newValue[])
{
    SetConVarString(convar, PLUGIN_VERSION);    
}

public DisturbEnableSpawnsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_enable_spawns_cache = StringToInt(newValue);
}

public DisturbAdminFlagsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_admin_flags_cache = ReadFlagString(newValue);
}

public MaxCommonChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_common_cache = StringToInt(newValue);
}   

public CalcShotsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_calc_shots_cache = StringToFloat(newValue);
}   

public CalmRateChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_calm_rate_cache = StringToFloat(newValue);
}   

public ActionTimeChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_action_time_cache = StringToFloat(newValue);
}   

public ActionDelayChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_action_delay_cache = StringToInt(newValue);
}

public PostActionDelayChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_post_action_delay_cache = StringToInt(newValue);
}

public PostFullDelayChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_post_full_cache = StringToInt(newValue);
}

public AdvertiseChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_advertise_cache = StringToInt(newValue);
}

public DisplayBarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_displaybar_cache = StringToInt(newValue);
}

public DisplayAdminChangesChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_display_admin_cache = StringToInt(newValue);
}

public CarAlarmChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_car_alarm_cache = StringToInt(newValue);
}

public BotExceptionChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    switch(StringToInt(newValue))
    {
        case 0:
        {
            disturb_bot_exception_cache = 0;
        }
        case 1:
        {
            disturb_bot_exception_cache = 1;
        }
        default:
        {
            //Do Nothing
        }
    }
}

public DisturbGameTypeEnabledChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if(!StrEqual(newValue,""))
    {
        
    }
}

public WeaponModifiersChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    new bool:test;
    new String:tempValue[MAX_DATA_UNIT];
    strcopy(tempValue,MAX_DATA_UNIT, newValue);
    test = WeaponModifier(tempValue);
}

public MaxSpecialsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_specials_cache = StringToInt(newValue);
}

public MaxHuntersChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_hunters_cache = StringToInt(newValue);
}

public MaxSmokersChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_smokers_cache = StringToInt(newValue);
}

public MaxSpittersChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_spitters_cache = StringToInt(newValue);
}

public MaxBoomersChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_boomers_cache = StringToInt(newValue);
}

public MaxJockeysChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_jockeys_cache = StringToInt(newValue);
}

public MaxChargersChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_chargers_cache = StringToInt(newValue);
}

public MaxTanksChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_tanks_cache = StringToInt(newValue);
}

public MaxWitchesChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_max_witches_cache = StringToInt(newValue);
}

public DisturbScaleRateChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_scale_rate_cache = ModifyDisturbRate(newValue);
}

public DisturbScaleTypeChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    switch(StringToInt(newValue))
    {
        case DISTURB_SCALE_LINEAR:
        {   
            disturb_scale_type_cache = DISTURB_SCALE_LINEAR;
            disturb_scale_rate_cache = ModifyDisturbRate(newValue);
        }
        case DISTURB_SCALE_LOGARITHMIC:
        {
            disturb_scale_type_cache = DISTURB_SCALE_LOGARITHMIC;
            disturb_scale_rate_cache = ModifyDisturbRate(newValue);
        }
        case DISTURB_SCALE_EXPONENTIAL:
        {
            disturb_scale_type_cache = DISTURB_SCALE_EXPONENTIAL;
            disturb_scale_rate_cache = ModifyDisturbRate(newValue);
        }
        default: 
        { 
            #if DEBUG 1
            LogMessage("DisturbScaleTypeChanged->default:%s",newValue);
            #endif
            disturb_scale_type_cache = StringToInt(oldValue);
            disturb_scale_rate_cache = ModifyDisturbRate(newValue);
        }
    }
}

public DisturbScaleDifficultyChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_scale_difficulty_cache = StringToFloat(newValue);
}

public DisturbScaleGameTypeVersusChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_scale_gametype_versus_cache = StringToFloat(newValue);
}

public DisturbScaleGameTypeCoopChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_scale_gametype_coop_cache = StringToFloat(newValue);
}

public DisturbScaleGameTypeSurvivalChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_scale_gametype_survival_cache = StringToFloat(newValue);
}

public DisturbScaleGameTypeScavengeChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    disturb_scale_gametype_scavenge_cache = StringToFloat(newValue);
}

/*==========================================
*   Send Commands from l4d_spawnuncommons
*   by AtomicStryker
==========================================*/
GetAnyClient()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            #if DEBUG 1
            LogMessage("GetAnyClient->id:%i",i);
            #endif
            return i;
        }
    }
    return 0;
}

CheatCommand(client, const String:command[], const String:arguments[]="")
{
    if (!client) return;
    new admindata = GetUserFlagBits(client);
    SetUserFlagBits(client, ADMFLAG_ROOT);
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
    SetUserFlagBits(client, admindata);
    #if DEBUG 1
    LogMessage("CheatCommand->%s:   %s", command, arguments);
    #endif
}
