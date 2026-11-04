-- Raycast settings (disabled commands/extensions, script folder), applied to its encrypted database by setup.sh
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_browser', '{
  "disabledCommands" : [
    "builtin_command_install-browser-extension-command",
    "builtin_command_ask-browser"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_calculator', '{
  "disabledCommands" : [
    "builtin_command_ask_calculator"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_calendar', '{
  "disabledCommands" : [
    "builtin_command_calendar_schedule",
    "builtin_command_calendar_stats",
    "builtin_command_ask_calendar"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_default', '{
  "didMigrateQuicklinkFallbackSearch" : true,
  "didMigrateWebSearches" : true,
  "installedNativeExtensionIdentifiers" : [
    "builtin_package_media"
  ],
  "enabledFallbackSearchIdentifiers" : [
    "builtin_command_searchSnippets_fallbackSearch",
    "raycastQuicklink_286F0F79-F58B-489A-AD8F-65F54D7C08BB",
    "builtin_command_searchMenuItems_fallbackSearch",
    "raycastQuicklink_DAE66B09-CB75-4BB5-B11D-C988683EB461"
  ],
  "disabledCommands" : [
    "builtin_command_checkForUpdates",
    "builtin_command_sendFeedback",
    "builtin_command_recenterMainWindow",
    "builtin_command_openRaycastManual",
    "builtin_command_openRaycastChangelog",
    "builtin_command_refreshSystemSource",
    "builtin_command_reloadScriptCommands",
    "builtin_command_createScriptCommand",
    "builtin_command_createQuicklink",
    "builtin_command_manageQuicklinks",
    "builtin_command_importQuicklinks",
    "builtin_command_exportQuicklinks",
    "builtin_command_quitRaycast",
    "builtin_command_windowBounceAnimation",
    "builtin_command_extensionStore",
    "builtin_command_configurationExport",
    "builtin_command_configurationImport",
    "builtin_command_manageFallbackSearches",
    "builtin_command_searchSiriShortcuts",
    "builtin_command_onboardingTasks",
    "builtin_command_confetti",
    "builtin_command_lightsaber",
    "builtin_command_lordOfTheRings",
    "builtin_command_updateInstalledExtensions",
    "builtin_command_showThemeStudio",
    "builtin_command_upgradeToPro",
    "builtin_command_showRaycastWrapped",
    "builtin_command_shareRaycast",
    "builtin_command_runLastCommand",
    "builtin_command_becomeAnAffiliate",
    "builtin_command_openAffiliateDashboard",
    "builtin_command_showOnboardingV2",
    "builtin_command_manageAutoQuits",
    "builtin_command_raycastIOS",
    "builtin_command_registerForRaycast2EarlyAccess",
    "builtin_command_undoRaycast2Migration",
    "builtin_command_raycastV2Upgrade",
    "builtin_command_replaceSpotlightWithRaycast"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_developer', '{
  "disabledCommands" : [
    "builtin_command_developer_createExtension",
    "builtin_command_developer_importExtension",
    "builtin_command_developer_manageExtensions",
    "builtin_command_developer_extensionDiagnostics"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_dictionary', '{
  "disabledCommands" : [
    "builtin_command_dictionary_defineWord"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_emoji', '{
  "disabledCommands" : [

  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_fileSearch', '{
  "disabledCommands" : [

  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_finder', '{
  "disabledCommands" : [
    "builtin_command_ask-finder"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_location', '{
  "disabledCommands" : [
    "builtin_command_ask-location"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_mcp', '{
  "disabledCommands" : [
    "builtin_command_mcp-import-servers",
    "builtin_command_mcp-manage-servers",
    "builtin_command_mcp-install-server"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_open-ai', '{
  "disabledAICommands" : [
    "raycastAICommand_improve-writing",
    "raycastAICommand_fix-spelling-and-grammar",
    "raycastAICommand_explain-this-in-simple-terms",
    "raycastAICommand_make-longer",
    "raycastAICommand_make-shorter",
    "raycastAICommand_change-tone-to-professional",
    "raycastAICommand_change-tone-to-friendly",
    "raycastAICommand_change-tone-to-confident",
    "raycastAICommand_change-tone-to-casual",
    "raycastAICommand_rephrase-as-tweet",
    "raycastAICommand_explain-code",
    "raycastAICommand_find-bugs",
    "raycastAICommand_summarize-website",
    "raycastAICommand_answer-question-about-website"
  ],
  "aiChatDisabledPresets" : [

  ],
  "disabledCommands" : [
    "builtin_command_open-ai-create-ai-command",
    "builtin_command_open-ai-search-ai-commands",
    "builtin_command_open-ai-import-ai-commands",
    "builtin_command_open-ai-chat-gpt",
    "builtin_command_open-ai-send-to-chat-command",
    "builtin_command_open-quick-ai",
    "builtin_command_open-ai-create-chat-preset",
    "builtin_command_open-ai-search-chat-presets",
    "builtin_command_open-ai-import-chat-presets",
    "builtin_command_open-ai-manage-ai-models",
    "builtin_command_open-ai-send-active-window-to-chat-command",
    "builtin_command_open-ai-send-selected-area-to-chat-command",
    "builtin_command_open-ai-send-screen=to-chat-command",
    "builtin_command_open-ai-send-focused-browser-tab-to-chat-command",
    "builtin_command_open-ai-send-focused-window-context-to-chat-command",
    "builtin_command_talkToRaycast",
    "builtin_command_talkToNote"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_organizations', '{
  "disabledCommands" : [
    "builtin_command_raycastManageOrganizations",
    "builtin_command_raycastCopyOrganizationInvite",
    "builtin_command_raycastCreateOrganization",
    "builtin_command_teamWalkthrough",
    "builtin_command_raycastManageOrganizationWebhooks",
    "builtin_command_raycastCreateOrganizationWebhook"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_raycastExtensions', '{
  "nodeDisabledCommands" : [
    "extension_linear.ask-linear{id=a9696c4c-a4e8-4ff1-bf49-c9015f796200}__generated__a9696c4c-a4e8-4ff1-bf49-c9015f796200",
    "extension_color-picker.ask-color-picker{id=40ebc708-964f-473b-8d19-d4e9cbd27ae9}__generated__40ebc708-964f-473b-8d19-d4e9cbd27ae9",
    "extension_kill-process.ask-kill-process{id=c0c9423a-7014-481e-8bb9-44c4c6df53be}__generated__c0c9423a-7014-481e-8bb9-44c4c6df53be"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_raycastFocus', '{
  "disabledCommands" : [
    "builtin_command_startFocusSession",
    "builtin_command_updateFocusSession",
    "builtin_command_stopFocusSession",
    "builtin_command_toggleFocusSession",
    "builtin_command_pauseFocusSession",
    "builtin_command_resumeFocusSession",
    "builtin_command_createFocusCategory",
    "builtin_command_searchFocusCategories",
    "builtin_command_importFocusCategories",
    "builtin_command_askFocus"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_raycastNotes', '{
  "disabledCommands" : [
    "builtin_command_raycastNotes_toggle",
    "builtin_command_raycastNotes_saveToNotes",
    "builtin_command_raycastNotes_createNote",
    "builtin_command_raycastNotes_search",
    "builtin_command_raycastNotes_ask"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_raycastPreferences', '{
  "disabledCommands" : [

  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_scriptCommands', '{
  "scriptCommandsDirectories" : [
    "~\/macos-config\/.config\/raycast\/scripts"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_selected-text', '{
  "disabledCommands" : [
    "builtin_command_ask-selected-text"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_thinking', '{
  "disabledCommands" : [
    "builtin_command_ask-thinking"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_translator', '{
  "disabledCommands" : [
    "builtin_command_translate"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_typingPractice', '{
  "disabledCommands" : [
    "builtin_command_typingPractice_start"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_weather', '{
  "disabledCommands" : [
    "builtin_command_ask-weather"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('builtin_package_windowManagement', '{
  "disabledCommands" : [
    "builtin_command_windowManagementCenter",
    "builtin_command_windowManagementMaximize",
    "builtin_command_windowManagementMaximizeHeight",
    "builtin_command_windowManagementMaximizeWidth",
    "builtin_command_windowManagementMaximizeAlmost",
    "builtin_command_windowManagementLeftHalf",
    "builtin_command_windowManagementRightHalf",
    "builtin_command_windowManagementCenterHalf",
    "builtin_command_windowManagementTopHalf",
    "builtin_command_windowManagementBottomHalf",
    "builtin_command_windowManagementFirstThird",
    "builtin_command_windowManagementFirstTwoThird",
    "builtin_command_windowManagementCenterThird",
    "builtin_command_windowManagementCenterTwoThird",
    "builtin_command_windowManagementLastTwoThird",
    "builtin_command_windowManagementLastThird",
    "builtin_command_windowManagementTopThird",
    "builtin_command_windowManagementTopTwoThird",
    "builtin_command_windowManagementTopCenterTwoThird",
    "builtin_command_windowManagementMiddleThird",
    "builtin_command_windowManagementBottomTwoThird",
    "builtin_command_windowManagementBottomThird",
    "builtin_command_windowManagementTopLeftQuarter",
    "builtin_command_windowManagementTopRightQuarter",
    "builtin_command_windowManagementBottomLeftQuarter",
    "builtin_command_windowManagementBottomRightQuarter",
    "builtin_command_windowManagementNextDisplay",
    "builtin_command_windowManagementPreviousDisplay",
    "builtin_command_windowManagementToggleFullscreen",
    "builtin_command_windowManagementMoveLeft",
    "builtin_command_windowManagementMoveRight",
    "builtin_command_windowManagementMoveUp",
    "builtin_command_windowManagementMoveDown",
    "builtin_command_windowManagementRestore",
    "builtin_command_windowManagementReasonableSize",
    "builtin_command_windowManagementFirstFourth",
    "builtin_command_windowManagementSecondFourth",
    "builtin_command_windowManagementThirdFourth",
    "builtin_command_windowManagementLastFourth",
    "builtin_command_windowManagementTopFirstFourth",
    "builtin_command_windowManagementTopSecondFourth",
    "builtin_command_windowManagementTopThirdFourth",
    "builtin_command_windowManagementTopLastFourth",
    "builtin_command_windowManagementFirstThreeFourth",
    "builtin_command_windowManagementCenterThreeFourth",
    "builtin_command_windowManagementLastThreeFourth",
    "builtin_command_windowManagementTopThreeFourth",
    "builtin_command_windowManagementBottomThreeFourth",
    "builtin_command_windowManagementTopLeftSixth",
    "builtin_command_windowManagementTopCenterSixth",
    "builtin_command_windowManagementTopRightSixth",
    "builtin_command_windowManagementBottomLeftSixth",
    "builtin_command_windowManagementBottomCenterSixth",
    "builtin_command_windowManagementBottomRightSixth",
    "builtin_command_windowManagementNextDesktop",
    "builtin_command_windowManagementPreviousDesktop",
    "builtin_command_windowManagementMakeSmaller",
    "builtin_command_windowManagementMakeLarger",
    "builtin_command_windowManagementCreateCustomLayout",
    "builtin_command_windowManagementCreateCustomAppsLayout"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('remote_package_chart', '{
  "disabledCommands" : [
    "remote_command_chart"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('remote_package_dalle', '{
  "disabledCommands" : [
    "remote_command_dalle"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('remote_package_flux', '{
  "disabledCommands" : [
    "remote_command_flux"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('remote_package_flux-kontext', '{
  "disabledCommands" : [
    "remote_command_flux-kontext"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('remote_package_gpt_image', '{
  "disabledCommands" : [
    "remote_command_gpt_image"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('remote_package_nano_banana', '{
  "disabledCommands" : [
    "remote_command_nano_banana"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('remote_package_nano_banana_lite', '{
  "disabledCommands" : [
    "remote_command_nano_banana_lite"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('remote_package_stable_diffusion', '{
  "disabledCommands" : [
    "remote_command_stable_diffusion"
  ]
}', CURRENT_TIMESTAMP);
INSERT INTO raycastConfiguration (extensionId, configuration, updatedAt) VALUES ('remote_package_web', '{
  "disabledCommands" : [
    "remote_command_web"
  ]
}', CURRENT_TIMESTAMP);
