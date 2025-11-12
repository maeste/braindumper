@echo off
REM ============================================================
REM Launch Claude Code with Z.ai GLM models (Windows .bat)
REM - Uses Z.ai's Anthropic-compatible API endpoint
REM - Passes through any CLI args to Claude: %*
REM ============================================================

REM ---- Z.ai endpoint and auth (EDIT THIS) ----
SET "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic"
SET "ANTHROPIC_AUTH_TOKEN=your-zai-api-key"
REM TODO: replace with your real Z.ai API key

REM ---- Optional: model mappings (EDIT AS YOU LIKE) ----
SET "ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air"
SET "ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.6"
SET "ANTHROPIC_DEFAULT_OPUS_MODEL=glm-4.6"

REM ---- Path to Claude binary (adjust if different) ----
SET "CLAUDE_BIN=%USERPROFILE%\AppData\Roaming\npm\claude.cmd"


IF NOT EXIST "%CLAUDE_BIN%" (
  ECHO [ERROR] Claude executable not found at: "%CLAUDE_BIN%"
  ECHO        Please update CLAUDE_BIN to the correct path, e.g. "C:\Users\TUO_USER\.claude\local\claude.exe"
  EXIT /B 1
)

REM ---- Launch Claude with current environment ----
"%CLAUDE_BIN%" %*
