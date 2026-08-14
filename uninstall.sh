#!/usr/bin/env bash
# Remove cosmic-image-resize and its COSMIC Files context action.
set -euo pipefail

TARGET="${HOME}/.local/bin/cosmic-image-resize"
CONFIG="${HOME}/.config/cosmic/com.system76.CosmicFiles/v1/context_actions"

say() { printf '%s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }

if [[ -e "$TARGET" ]]; then
    rm -f "$TARGET"
    say "removed    ${TARGET}"
else
    say "not found  ${TARGET}"
fi

if [[ -s "$CONFIG" ]] && grep -q 'cosmic-image-resize' "$CONFIG"; then
    backup="${CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG" "$backup"
    say "backed up  ${backup}"

    # Drop the whole "( ... )," block that mentions this tool, keeping any others.
    python3 - "$CONFIG" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
blocks = re.findall(r"^[ \t]*\(.*?^[ \t]*\),[ \t]*$", text, re.S | re.M)
kept = [b for b in blocks if "cosmic-image-resize" not in b]
if len(kept) == len(blocks):
    sys.exit("could not locate the entry; left the config alone")
open(path, "w").write("[\n" + "\n".join(kept) + ("\n" if kept else "") + "]\n")
print(f"removed 1 entry, kept {len(kept)}")
PY
    say "updated    ${CONFIG}"
else
    say "no context action registered in ${CONFIG}"
fi

say ""
say "Restart COSMIC Files to drop the menu entry:"
say "    pkill -x cosmic-files && setsid cosmic-files >/dev/null 2>&1 &"
say ""
say "Note: images already rewritten are not restored, but their originals are in the trash."
