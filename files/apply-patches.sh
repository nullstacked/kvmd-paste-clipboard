#!/bin/bash
set -e

SHARE_DIR="/usr/share/kvmd-paste-clipboard"
LOG_PREFIX="kvmd-paste-clipboard"
WEB_DIR="/usr/share/kvmd/web"

log() { echo "[$LOG_PREFIX] $*"; }
warn() { echo "[$LOG_PREFIX] WARNING: $*" >&2; }

# Copy CSS
dest="$WEB_DIR/share/css/kvm/paste-clipboard.css"
mkdir -p "$(dirname "$dest")"
if [ -f "$dest" ] && cmp -s "$SHARE_DIR/paste-clipboard.css" "$dest"; then
    log "SKIPPED (unchanged): paste-clipboard.css"
else
    cp "$SHARE_DIR/paste-clipboard.css" "$dest"
    log "PATCHED: paste-clipboard.css"
fi

# Patch index.html + session.js via Python
python3 <<'PYEOF'
import os, sys

WEB_DIR = "/usr/share/kvmd/web"

# ============================================================
# Patch index.html — add CSS link + floating button
# ============================================================
path = os.path.join(WEB_DIR, "kvm", "index.html")
if os.path.exists(path):
    content = open(path).read()
    changed = False

    if "paste-clipboard.css" not in content:
        last_css = content.rfind('<link rel="stylesheet"')
        if last_css >= 0:
            eol = content.find("\n", last_css)
            if eol >= 0:
                link = '\n\t\t<link rel="stylesheet" href="../share/css/kvm/paste-clipboard.css">'
                content = content[:eol] + link + content[eol:]
                changed = True

    if 'id="paste-clip-btn"' not in content:
        # Place at body level so position:fixed anchors to viewport (not stream-box)
        body_end = content.rfind("</body>")
        if body_end >= 0:
            btn = ('\t\t<button id="paste-clip-btn" class="paste-clip-btn" '
                   'title="Paste from clipboard (types the copied text)">'
                   '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
                   '<path d="M19 2h-4.18C14.4.84 13.3 0 12 0c-1.3 0-2.4.84-2.82 2H5c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-7 0c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zm2 18H7v-2h7v2zm3-4H7v-2h10v2zm0-4H7V10h10v2z"/>'
                   '</svg></button>\n')
            content = content[:body_end] + btn + content[body_end:]
            changed = True

    if changed:
        open(path, "w").write(content)
        print("[kvmd-paste-clipboard] PATCHED: index.html")
    else:
        print("[kvmd-paste-clipboard] SKIPPED (already applied): index.html")
else:
    print("[kvmd-paste-clipboard] FAILED: index.html not found"); sys.exit(1)

# ============================================================
# Patch session.js — wire up button click to clipboard + paste
# ============================================================
path = os.path.join(WEB_DIR, "share", "js", "kvm", "session.js")
if os.path.exists(path):
    content = open(path).read()

    if "__pasteClipBtnInit" in content:
        print("[kvmd-paste-clipboard] SKIPPED (already applied): session.js")
    else:
        # Inject the init function + activation into __init__ via the wm.showWindow anchor
        # Easiest: inject at the top of the outer module init, using the __streamer.ensureDeps anchor (stable across kvmd).
        func_code = (
            '\n\tvar __pasteClipBtnInit = function() {\n'
            '\t\tlet btn = document.getElementById("paste-clip-btn");\n'
            '\t\tif (!btn || btn.dataset.initialized) return;\n'
            '\t\tif (!navigator.clipboard || !navigator.clipboard.readText) {\n'
            '\t\t\tbtn.style.display = "none";\n'
            '\t\t\treturn;\n'
            '\t\t}\n'
            '\t\tbtn.dataset.initialized = "1";\n'
            '\t\t// Prevent button from stealing focus on mousedown — keep stream focus intact\n'
            '\t\tbtn.addEventListener("mousedown", function(e) { e.preventDefault(); });\n'
            '\t\tbtn.addEventListener("click", function(e) {\n'
            '\t\t\te.preventDefault();\n'
            '\t\t\tif (btn.disabled) return;\n'
            '\t\t\tbtn.disabled = true;\n'
            '\t\t\t// Read clipboard (must be in user-gesture — .then/.catch keeps this sync path)\n'
            '\t\t\tnavigator.clipboard.readText().then(function(text) {\n'
            '\t\t\t\tif (!text) { btn.disabled = false; wm.info("Clipboard is empty"); return; }\n'
            '\t\t\t\tlet keymapSel = document.getElementById("hid-pak-keymap-selector");\n'
            '\t\t\t\tlet keymap = keymapSel ? keymapSel.value : "en-us";\n'
            '\t\t\t\tlet delaySlider = document.getElementById("hid-pak-delay-slider");\n'
            '\t\t\t\tlet delay = delaySlider ? (delaySlider.valueAsNumber || 20) : 20;\n'
            '\t\t\t\t// Match built-in paste exactly — use tools.httpPost with text/plain body\n'
            '\t\t\t\ttools.httpPost("api/hid/print", {"limit": 0, "keymap": keymap, "delay": delay / 1000}, function(http) {\n'
            '\t\t\t\t\tbtn.disabled = false;\n'
            '\t\t\t\t\tif (http.status === 413) wm.error("Clipboard text too long for paste");\n'
            '\t\t\t\t\telse if (http.status !== 200) wm.error("HID paste error", http.responseText || http.statusText);\n'
            '\t\t\t\t}, text, "text/plain", 7 * 24 * 3600);\n'
            '\t\t\t}).catch(function(err) {\n'
            '\t\t\t\tbtn.disabled = false;\n'
            '\t\t\t\tif (err && err.name === "NotAllowedError") wm.error("Clipboard access denied. Allow clipboard permission and try again.");\n'
            '\t\t\t\telse wm.error("Clipboard read failed: " + (err && err.message ? err.message : err));\n'
            '\t\t\t});\n'
            '\t\t});\n'
            '\t};\n'
            '\tdocument.addEventListener("DOMContentLoaded", __pasteClipBtnInit);\n'
            '\tif (document.readyState !== "loading") __pasteClipBtnInit();\n\n'
        )
        target = '\tvar __wsJsonHandler = function(ev_type, ev) {'
        if target in content:
            content = content.replace(target, func_code + target, 1)
            open(path, "w").write(content)
            print("[kvmd-paste-clipboard] PATCHED: session.js")
        else:
            print("[kvmd-paste-clipboard] FAILED: session.js anchor not found"); sys.exit(1)
else:
    print("[kvmd-paste-clipboard] FAILED: session.js not found"); sys.exit(1)
PYEOF

# Restart kvmd if running (for webCS changes to take effect? Not strictly needed)
log "Done"
