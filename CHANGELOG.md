## [2.1.0] 2026-03-07

### Removed

- OnClientSettingsChanged() trigger due to continued race condition issues with client name updates when joining a server.

## [2.0.0] 2026-03-01

An almost complete rewrite of the original version to focus on modernization and stability in accordance with modern versions of the Source Engine and SourceMod.

### Added

* Error checking on logic and function calls.
* OnPluginStart() improvements to prevent the plugin from running without critical components, such as the tag key/value file.
* The ability so specify a SourceMod admin flag in the AutoExecConfig file.
* Color coding for plugin announcements and command replies in chat.
* Full code commenting.
* Additional logging to the server log.

### Changed

* Modern code standards and formatting.
* Relocated code to the appropriate functions to reduce complexity.

### Removed

* Timer-based name changes and kicking due to race conditions and name change cooldowns in the Source engine.
* Global variables previously used to track work arounds that mitigated Source engine limitations.
