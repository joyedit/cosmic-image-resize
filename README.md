# cosmic-image-resize

Right-click one or more images in **COSMIC Files** and resize or shrink them in place.

COSMIC Files has no image-editing context menu, but as of **1.5.0** it does have an
undocumented `context_actions` config that can add custom right-click entries — no
recompiling, no extension API, no forked build. This repo uses it to add a single entry
that opens a small picker:

```
┌─ Resize / Compress Images — 3 images ─┐
│ ○ 3440 × 1440      —  fit, keeps aspect │
│ ○ 1024 × 768       —  fit, keeps aspect │
│ ○ 512 × 512        —  square, center crop│
│ ○ 480 × 480        —  square, center crop│
│ ○ 256 × 256        —  square, center crop│
│ ○ 128 × 128        —  square, center crop│
│ ○ Square 1:1       —  center crop, keep size│
│ ○ Shrink file size  − 20 %              │
│ ○ Shrink file size  − 40 %              │
│ ○ Shrink file size  − 60 %              │
│                    [Cancel]  [Apply]    │
└─────────────────────────────────────────┘
```

Files are **replaced in place**. Each original is moved to the trash first (via `gio
trash`), so a batch you regret is fully recoverable from the COSMIC trash.

## Requirements

All of these ship with Pop!\_OS COSMIC except ImageMagick:

| Tool | Package | Used for |
| --- | --- | --- |
| `convert`, `identify` | `imagemagick` | all image work |
| `zenity` | `zenity` | the picker and progress bar |
| `gio` | `libglib2.0-bin` | moving originals to the trash |
| `notify-send` | `libnotify-bin` | the completion summary |
| `python3` | `python3` | the script itself (no third-party modules) |

```sh
sudo apt install imagemagick zenity libglib2.0-bin libnotify-bin
```

Tested against ImageMagick 6 (`convert`/`identify`). ImageMagick 7's `magick` is not
required.

## Install

```sh
git clone https://github.com/joyedit/cosmic-image-resize.git
cd cosmic-image-resize
./install.sh
```

`install.sh` copies the script to `~/.local/bin/`, registers the context action, and
backs up any existing `context_actions` config before merging into it.

Then **restart COSMIC Files** — close every window and reopen. The entry appears at the
bottom of the right-click menu, below a divider.

To remove everything again: `./uninstall.sh`.

## What each preset does

Non-square targets scale to **fit inside** the box, preserving aspect ratio. Square
targets **center-crop to fill**, which is what you want for icons and avatars. Nothing is
ever upscaled, and an image already at or below the target is skipped rather than
needlessly re-encoded.

| Preset | 4000×3000 JPEG (3.7 MB) | 2560×1080 PNG (14 MB) | 800×600 JPEG |
| --- | --- | --- | --- |
| `1024 × 768` | 1024×768, 258 KB | 1024×432, 2.2 MB | skipped (already fits) |
| `3440 × 1440` | 1920×1440, 862 KB | skipped | skipped |
| `512 × 512` | 512×512, 91 KB | 512×512, 1.3 MB | 512×512, 104 KB |
| `Square 1:1` | 3000×3000 | 1080×1080 | 600×600 |
| `− 20 %` | 2.7 MB (73 %) | 11.1 MB (80 %) | 145 KB (72 %) |
| `− 60 %` | 1.4 MB (39 %) | 5.4 MB (39 %) | 79 KB (39 %) |

EXIF orientation is honoured: a 600×900 file tagged `Orientation=6` is treated as the
900×600 landscape image you actually see, and the rotation is baked in on write.

### How the size targets work

`− 40 %` means "end up at 60 % of the original byte count or less". It is a ceiling, not
an exact hit, and the strategy differs by format:

- **Lossy (JPEG, WebP, AVIF, HEIC, JXL)** — binary-searches JPEG quality for the highest
  setting that still meets the target. Resolution is preserved. Because quality is a
  coarse integer dial, results often land a little under the target (asking for −20 %
  may yield −27 %). If even quality 15 is too big, it then downscales.
- **Lossless (PNG, GIF, BMP, TIFF)** — you cannot lose bytes without losing *something*.
  It first tries strip + maximum compression; if that misses, it **downscales**, which is
  finely tunable and lands within a percent or two of the target while keeping full
  colour. Palette reduction (`-colors`) is a last resort only, because on photographic
  images it overshoots wildly — a requested −20 % turned into −72 % in testing.

If you would rather PNGs kept their resolution and gave up colour depth instead, swap the
order of the two branches in `shrink_to_target()`.

## Customising the presets

Edit the `PRESETS` list at the top of `cosmic-image-resize`:

```python
PRESETS = [
    ("3440x1440", "3440 × 1440      —  fit, keeps aspect"),
    ("size20",    "Shrink file size   − 20 %"),
]
```

Keys are parsed, not looked up, so new entries work with no other changes:

- `WxH` — a resolution. Equal width and height means center-crop; otherwise fit-inside.
- `square` — center-crop to 1:1 at the current size.
- `sizeN` — shrink to `(100 − N) %` of the original byte count.

So `("800x600", "800 × 600")` and `("size75", "Shrink − 75 %")` both just work. Re-run
`./install.sh` to push changes to `~/.local/bin/`.

## How the context menu hook works

This is the part worth stealing for other tools. COSMIC Files 1.5.0 reads a RON file at:

```
~/.config/cosmic/com.system76.CosmicFiles/v1/context_actions
```

containing a list of presets ([upstream
definition](https://github.com/pop-os/cosmic-files/blob/master/src/context_action.rs)):

```ron
[
    (
        name: "Resize / Compress Images…",
        confirm: false,
        selection: Files,
        steps: [
            "/home/you/.local/bin/cosmic-image-resize %F",
        ],
    ),
]
```

- `selection` is `Any`, `Files`, or `Folders` — controls which selections show the entry.
- `confirm: true` adds a "Run X?" dialog before the command fires.
- `steps` are Exec-style strings parsed by the same code that launches desktop entries, so
  `%F` (all selected paths) and `%f` (one path) work. Each step spawns detached.

Two caveats worth designing around:

1. **Entries render flat**, with no submenu nesting. Ten presets would mean ten rows in
   every right-click. That is precisely why this tool ships one entry that opens a dialog.
2. **There is no MIME filter.** The entry shows for every file selection, so the script
   filters to readable images itself and reports if none were found.

The feature is not in any documentation I could find — it turned up by running `strings`
over `/usr/bin/cosmic-files` and cross-checking `src/context_action.rs` upstream. If a
COSMIC component seems to be missing a feature, that technique is worth repeating.

## License

MIT — see [LICENSE](LICENSE).
