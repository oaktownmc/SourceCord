void InitializeConfig() {
	g_cvConfigFile = CreateConVar("sc_config_file", "sourcecord", "Settings config file name (use sm_cvar in server.cfg for per-server configs)", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvCredentialsFile = CreateConVar("sc_credentials_file", "sourcecord", "Credentials config file name (use sm_cvar in server.cfg for per-server configs)", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvUpdateInterval = CreateConVar("sc_interval", "1.0", "Discord check interval (seconds)", FCVAR_NOTIFY, true, 1.0, true, 10.0);
	g_cvLogConnections = CreateConVar("sc_log_connections", "1", "Log player connect/disconnects (off, basic, with IP)", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvLogMapChanges = CreateConVar("sc_log_map_changes", "0", "Log map changes to Discord when players are connected", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvUseRoleColors = CreateConVar("sc_use_role_colors", "1", "Use Discord role colors for usernames", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvUseNicknames = CreateConVar("sc_use_nicknames", "1", "Use Discord server nicknames instead of global usernames", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvShowSteamId = CreateConVar("sc_show_steam_id", "1", "Show Steam ID in Discord messages (off, steamID3, steamID)", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvShowDiscordPrefix = CreateConVar("sc_show_discord_prefix", "1", "Show [Discord] prefix in chat messages", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvDiscordColor = CreateConVar("sc_discord_color", DISCORD_DEFAULT_COLOR, "Hex color code for Discord usernames (without # prefix)", FCVAR_NOTIFY);
	g_cvAllowUserPings = CreateConVar("sc_allow_user_pings", "0", "Allow in-game users to ping Discord users via @username", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvAllowRolePings = CreateConVar("sc_allow_role_pings", "0", "Allow in-game users to ping Discord roles via @rolename", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	// hook convar changes
	g_cvCredentialsFile.AddChangeHook(OnCredentialsFileChanged);
	g_cvUpdateInterval.AddChangeHook(OnIntervalChanged);
	g_cvLogConnections.AddChangeHook(OnSettingsChanged);
	g_cvLogMapChanges.AddChangeHook(OnSettingsChanged);
	g_cvUseRoleColors.AddChangeHook(OnSettingsChanged);
	g_cvUseNicknames.AddChangeHook(OnSettingsChanged);
	g_cvShowSteamId.AddChangeHook(OnSettingsChanged);
	g_cvShowDiscordPrefix.AddChangeHook(OnSettingsChanged);
	g_cvDiscordColor.AddChangeHook(OnSettingsChanged);
	g_cvAllowUserPings.AddChangeHook(OnSettingsChanged);
	g_cvAllowRolePings.AddChangeHook(OnSettingsChanged);

	AutoExecConfig(true, "sourcecord");
}


public void OnCredentialsFileChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	LoadCredentials();
}


public void OnIntervalChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	StartTimer();
}


public void OnSettingsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	CacheSettings();
}


void CacheSettings() {
	g_fUpdateInterval = g_cvUpdateInterval.FloatValue;
	g_iLogConnections = g_cvLogConnections.IntValue;
	g_bLogMapChanges = g_cvLogMapChanges.BoolValue;
	g_bUseRoleColors = g_cvUseRoleColors.BoolValue;
	g_bUseNicknames = g_cvUseNicknames.BoolValue;
	g_iShowSteamId = g_cvShowSteamId.IntValue;
	g_bShowDiscordPrefix = g_cvShowDiscordPrefix.BoolValue;
	g_cvDiscordColor.GetString(g_sDiscordColor, sizeof g_sDiscordColor);
	g_bAllowUserPings = g_cvAllowUserPings.BoolValue;
	g_bAllowRolePings = g_cvAllowRolePings.BoolValue;

	if (!IsValidHexColor(g_sDiscordColor)) {
		LogMessage("Invalid hex color format '%s'", g_sDiscordColor);
		strcopy(g_sDiscordColor, sizeof g_sDiscordColor, DISCORD_DEFAULT_COLOR);
	}
}

bool g_bCredHalted;
bool g_bCredFailed;
int g_iCredLineNo;
char g_sCredSection[256];

void Cred_ParseStart(SMCParser smc) {
	g_bCredHalted = false;
	g_bCredFailed = false;

	g_sBotToken[0] = 0;
	g_sChannelId[0] = 0;
	g_sGuildId[0] = 0;
	g_sWebhookUrl[0] = 0;

	g_sSteamApiKey[0] = 0;
}

void Cred_ParseEnd(SMCParser smc, bool halted, bool failed) {
	g_bCredHalted = halted;
	g_bCredFailed = failed;
}

SMCResult Cred_NewSection(SMCParser smc, const char[] name, bool opt_quotes) {
	if (strlen(g_sCredSection) == 0) {
		strcopy(g_sCredSection, sizeof g_sCredSection, name);
		return SMCParse_Continue;
	}

	LogError("line %d: cannot nest sections", g_iCredLineNo);

	return SMCParse_HaltFail;
}

SMCResult Cred_EndSection(SMCParser smc) {
	g_sCredSection[0] = 0;

	return SMCParse_Continue;
}

SMCResult Cred_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
	if (StrEqual(g_sCredSection, "Discord")) {
		if (StrEqual(key, "bot_token")) {
			strcopy(g_sBotToken, sizeof g_sBotToken, value);
			return SMCParse_Continue;
		} else if (StrEqual(key, "channel_id")) {
			strcopy(g_sChannelId, sizeof g_sChannelId, value);
			return SMCParse_Continue;
		} else if (StrEqual(key, "guild_id")) {
			strcopy(g_sGuildId, sizeof g_sGuildId, value);
			return SMCParse_Continue;
		} else if (StrEqual(key, "webhook_url")) {
			strcopy(g_sWebhookUrl, sizeof g_sWebhookUrl, value);
			return SMCParse_Continue;
		}
	} else if (StrEqual(g_sCredSection, "Steam")) {
		if (StrEqual(key, "api_key")) {
			strcopy(g_sSteamApiKey, sizeof g_sSteamApiKey, value);
			return SMCParse_Continue;
		}
	}

	if (strlen(g_sCredSection) > 0)
		LogError("line %d: unknown key %s", g_iCredLineNo, key);
	else
		LogError("line %d: unknown key %s in section %s", g_iCredLineNo, g_sCredSection);
	return SMCParse_HaltFail;
}

SMCResult Cred_RawLine(SMCParser smc, const char[] line, int lineno)
{
	g_iCredLineNo = lineno;

	return SMCParse_Continue;
}

void LoadCredentials() {
	SMCParser smc = new SMCParser();
	smc.OnStart = Cred_ParseStart;
	smc.OnEnd = Cred_ParseEnd;
	smc.OnEnterSection = Cred_NewSection;
	smc.OnLeaveSection = Cred_EndSection;
	smc.OnKeyValue = Cred_KeyValue;
	smc.OnRawLine = Cred_RawLine;

	char credentialsFile[64];
	g_cvCredentialsFile.GetString(credentialsFile, sizeof credentialsFile);

	char configPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configPath, sizeof configPath, "configs/%s.cfg", credentialsFile);

	char settingsFile[64];
	g_cvConfigFile.GetString(settingsFile, sizeof settingsFile);

	bool errored = false;

	SMCError smcerr = smc.ParseFile(configPath);
	delete smc;

	if (smcerr != SMCError_Okay) {
		errored = true;

		char errstr[256];
		SMC_GetErrorString(smcerr, errstr, sizeof errstr);

		bool exists = FileExists(credentialsFile);

		LogError("Failed to load credentials config '%s': %s", configPath, errstr);
		if (exists)
			LogMessage("Remove it to auto-generate a new config.", settingsFile);
		LogMessage("Operational settings (cvars) are located in cfg\\sourcemod\\%s.cfg", settingsFile);

		if (!exists)
			CreateExampleCredentials(configPath, settingsFile);

		return;
	}

	if (strlen(g_sBotToken) == 0) {
		LogError("Discord.bot_token not configured!");
		errored = true;
	}

	if (strlen(g_sChannelId) == 0) {
		LogError("Discord.channel_id not configured!");
		errored = true;
	}

	if (errored) {
		SetFailState("Credentials file failed to load. Please edit credentials config and reload plugin: %s", configPath);
	}

	LogMessage("Credentials loaded successfully from %s", configPath);
	LogMessage("Operational settings (cvars) are located in cfg\\sourcemod\\%s.cfg", settingsFile);
}


void CreateExampleCredentials(const char[] configPath, const char[] settingsFile) {
	File file = OpenFile(configPath, "w");
	if (file == null) {
		LogError("Failed to create example credentials config at %s", configPath);
		return;
	}

	file.WriteLine("\"Discord\" {");
	file.WriteLine("    \"bot_token\"     \"\"  // Discord Bot token");
	file.WriteLine("    \"channel_id\"    \"\"  // Discord channel ID");
	file.WriteLine("    \"guild_id\"      \"\"  // Discord guild/server ID");
	file.WriteLine("    \"webhook_url\"   \"\"  // Discord Webhook URL");
	file.WriteLine("}");
	file.WriteLine("");
	file.WriteLine("\"Steam\" {");
	file.WriteLine("    \"api_key\"       \"\"  // Steam API key");
	file.WriteLine("}");

	file.Close();
	LogMessage("Created example credentials config at %s", configPath);
	LogMessage("Edit this file with your bot token, webhook URL, and Steam API key, then restart the plugin.");
	LogMessage("Operational settings (cvars) will auto-generate in cfg\\sourcemod\\%s.cfg", settingsFile);
}
