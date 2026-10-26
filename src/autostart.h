#pragma once

// Handles the tiny, GUI-free `--autostart` control command. Returns -1 when
// the option was not requested; otherwise the process exit code.
int handleAutostartCli(int argc, char *argv[]);
