#!/usr/bin/env python3
"""
extract-openclaw-keys.py — Extract API keys from an OpenClaw installation.

Reads ~/.openclaw/openclaw.json and any .env files under ~/.openclaw/,
then prints KEY=VALUE lines suitable for appending to ~/.hermes/.env.

Called by migrate-to-hermes.sh during live migration. Safe to run multiple
times — output is idempotent (callers deduplicate before writing).

Exit codes:
  0 — success (keys found or not, either way)
  1 — openclaw.json not found
"""
import json, os, sys, glob, re

home = os.path.expanduser("~")
oc_path = os.path.join(home, ".openclaw", "openclaw.json")

if not os.path.exists(oc_path):
    print(f"# WARNING: {oc_path} not found — no OpenClaw keys extracted", file=sys.stderr)
    sys.exit(1)

results = {}

# ── 1. openclaw.json ─────────────────────────────────────────────────────────
with open(oc_path) as f:
    d = json.load(f)

def get(obj, *keys, default=""):
    for k in keys:
        if not isinstance(obj, dict):
            return default
        obj = obj.get(k, {})
    return obj if isinstance(obj, str) else default

# Discord bot token (per-node — do NOT replace with elven-path token)
tok = get(d, "channels", "discord", "token")
if tok:
    results["DISCORD_BOT_TOKEN"] = tok

# Discord home channel (first guild's first channel, if set)
guilds = d.get("channels", {}).get("discord", {}).get("guilds", {})
if guilds:
    first_guild = next(iter(guilds.values()), {})
    home_ch = first_guild.get("homeChannelId") or first_guild.get("defaultChannel", "")
    if home_ch:
        results["DISCORD_HOME_CHANNEL_ID"] = home_ch

# Web search key (Brave/SerpApi)
ws = get(d, "tools", "web", "search", "apiKey")
if ws and ws not in ("", "undefined", "null"):
    results["BRAVE_SEARCH_API_KEY"] = ws

# Skill-level API keys (openai image, whisper, etc.)
for skill_name, skill_cfg in d.get("skills", {}).get("entries", {}).items():
    if isinstance(skill_cfg, dict) and skill_cfg.get("apiKey"):
        env_key = f"OPENCLAW_SKILL_{skill_name.upper().replace('-','_')}_API_KEY"
        results[env_key] = skill_cfg["apiKey"]

# ── 2. auth-profiles.json — primary Anthropic key source ────────────────────
# openclaw.json does NOT contain the Anthropic key directly; it lives in
# ~/.openclaw/agents/main/agent/auth-profiles.json as profiles[name]["token"]
auth_profiles_path = os.path.join(home, ".openclaw", "agents", "main", "agent", "auth-profiles.json")
if os.path.exists(auth_profiles_path):
    try:
        with open(auth_profiles_path) as f:
            ap = json.load(f)
        profiles = ap.get("profiles", {})
        last_good = ap.get("lastGood", {}).get("anthropic", "")
        # Prefer lastGood profile, then fall back through all profiles
        candidates = ([last_good] if last_good and last_good in profiles else []) + list(profiles.keys())
        for pname in candidates:
            p = profiles.get(pname, {})
            token = p.get("token", "") or p.get("apiKey", "")
            if token and token.startswith("sk-ant-"):
                results.setdefault("ANTHROPIC_API_KEY", token)
                break
    except Exception as e:
        print(f"# WARNING: could not parse auth-profiles.json: {e}", file=sys.stderr)

# ── 3. .env files under ~/.openclaw (skip node_modules) ─────────────────────
KEY_RE = re.compile(
    r'^(ANTHROPIC_API_KEY|OPENROUTER_API_KEY|OPENAI_API_KEY|FIRECRAWL_API_KEY'
    r'|WANDB_API_KEY|PARALLEL_API_KEY|FAL_KEY|HONCHO_API_KEY|HASS_TOKEN|HASS_URL'
    r'|KIMI_API_KEY|MINIMAX_API_KEY|TINKER_API_KEY|VOICE_TOOLS_OPENAI_KEY'
    r'|BROWSERBASE_API_KEY|BROWSERBASE_PROJECT_ID|GLM_API_KEY|DISCORD_ALLOWED_USERS)$'
)
for root, dirs, files in os.walk(os.path.join(home, ".openclaw")):
    dirs[:] = [d for d in dirs if d not in ("node_modules", ".git")]
    for fname in files:
        if fname.endswith(".env") or fname == ".env":
            try:
                for line in open(os.path.join(root, fname)):
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, _, v = line.partition("=")
                    if KEY_RE.match(k.strip()) and v.strip():
                        results.setdefault(k.strip(), v.strip())
            except Exception:
                pass

# ── 3. Output ────────────────────────────────────────────────────────────────
for k, v in sorted(results.items()):
    print(f"{k}={v}")
