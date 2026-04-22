# kvmd-paste-clipboard

Floating paste-from-clipboard button for PiKVM Web UI. One click = reads your clipboard and types it into the target machine via kvmd's HID paste.

## Features

- Small floating button (bottom-right of stream view) with paste icon
- Click → browser permission prompt (first time) → types clipboard text
- Uses the same `/api/hid/print` endpoint as kvmd's built-in Paste — honors current keymap + delay
- Auto-hides if browser doesn't support the Clipboard API (HTTP-only, unsupported browsers)
- Fully CSS-themable via custom properties

## Requirements

- **HTTPS only** — `navigator.clipboard.readText()` is blocked on plain HTTP
- User must grant clipboard permission (browser prompts once, then remembers)

## Install

```bash
makepkg -si
# Or:
pacman -U kvmd-paste-clipboard-1.0.0-1-any.pkg.tar.zst
```

## CSS customization

Override in `/etc/kvmd/web.css`:

```css
:root {
    --cs-paste-clip-bottom: 6px;
    --cs-paste-clip-right: 6px;
    --cs-paste-clip-size: 22px;
    --cs-paste-clip-bg: rgba(0,0,0,0.4);
}
```
