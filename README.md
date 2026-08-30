# omarchy-t2

`omarchy-t2` adds model-specific hardware support and conservative defaults for
Intel MacBook Pros with Apple's T2 chip. The first release supports the 2019
16-inch `MacBookPro16,1` exactly and refuses to change hardware on other models.

It is a companion package for Omarchy, not a fork of the distribution.

## Install

Install from the AUR through Omarchy, then run the explicit setup:

```bash
omarchy pkg aur add omarchy-t2
omarchy-t2 setup
```

The setup shows its plan, asks for confirmation, backs up replaced files, and
applies all defaults in one pass. It never reboots automatically. Preview it
without changing anything:

```bash
omarchy-t2 setup --dry-run
```

## Defaults

- Internal touchpad classification so libinput palm rejection works
- US Mac ISO keyboard layout with tap-to-click disabled
- 95% battery charge ceiling
- Linear dual-fan curve from 40–60°C, matching the current tested setup
- Adaptive power policy for Radeon, AC/battery profiles, Wi-Fi, external USB,
  and temperature-aware CPU idle time
- Protected six-channel speaker DSP for `MacBookPro16,1`
- Normalized, limited mono microphone DSP using the working array channel
- Bluetooth passkey display and A2DP auto-connect
- Compatibility helper for Omarchy's T2 GPU toggle
- Optional React DRM Touch Bar control center from the AminMarashi fork
- Optional Qwen3-TTS reading on the Radeon through Vulkan

The DSP input stays at 100%; a packaged PipeWire link-group resolver
makes Omarchy's panel and media keys adjust the physical Apple speaker sink,
which starts at 25%. Raise that physical output cautiously.
Microphone selection remains automatic: external microphones take precedence
when connected, with the processed internal microphone as the fallback.
Enabling microphone DSP clears the source preference saved by version 0.1.0;
select a source again afterward only if you want to override automatic routing.
The configuration includes a hard limiter, but model-specific speaker tuning is
still experimental and should never be used on a different Mac model.

## Personalize

```bash
omarchy-t2 battery limit 80
omarchy-t2 fan profile balanced
omarchy-t2 fan max
omarchy-t2 fan normal
omarchy-t2 power status
omarchy-t2 power thermal on 45 65 15 50
omarchy-t2 power gpu-saving off
omarchy-t2 input keyboard us mac-iso
omarchy-t2 input tap on
omarchy-t2 audio speakers off
omarchy-t2 audio mic on
omarchy-t2 bluetooth disable
omarchy toggle hybrid gpu
omarchy-t2 touchbar setup
omarchy-t2 tts setup
```

## Touch Bar

Install the React DRM Touch Bar control center from
[`aminmarashi/react-drm-for-touchbar`](https://github.com/aminmarashi/react-drm-for-touchbar):

```bash
omarchy-t2 touchbar setup
```

The command reuses `~/react-drm` when it is already connected to the
AminMarashi fork, or clones the fork there on first use. It then hands control
to react-drm's own installer, which analyzes the machine before making changes
and separately confirms removal of a conflicting `tiny-dfr` or
`mac-touchbar-plus` installation. The checkout remains editable so the Touch
Bar's `config.ts` and graphical config editor continue to work as designed.

Inspect an existing checkout without making changes, update it with a
fast-forward pull, or control the installed user service with:

```bash
omarchy-t2 touchbar analyze
omarchy-t2 touchbar update
omarchy-t2 touchbar status
omarchy-t2 touchbar disable
omarchy-t2 touchbar enable
```

`omarchy-t2 touchbar uninstall` runs react-drm's own uninstaller. It removes
the service and udev integration but intentionally keeps the editable checkout,
npm dependencies, installed system packages, and user group memberships.

## Power and cooling

The default power policy reproduces the final tested laptop state:

- Keep the Radeon on its `POWER_SAVING` profile.
- Select `performance` on AC and `power-saver` on battery.
- Enable Wi-Fi power saving and safe external-USB autosuspend on battery.
- Only in power-saver, linearly increase Intel PowerClamp forced idle from 15%
  at 45°C to 50% at 65°C. Recovery thresholds are 40°C and 60°C.
- Keep CPU Turbo Boost, CPU frequency limits, PCIe policy, audio power saving,
  brightness, resolution, scale, and refresh rate untouched.

Every part is configurable:

```bash
omarchy-t2 power profiles performance power-saver
omarchy-t2 power profile-switching on
omarchy-t2 power gpu-saving on
omarchy-t2 power wifi-saving on
omarchy-t2 power usb-autosuspend on
omarchy-t2 power thermal on 45 65 15 50
omarchy-t2 power thermal off
omarchy-t2 power disable
```

The `cool` fan profile is the tested 40–60°C linear curve. `balanced` and
`quiet` remain available. `omarchy-t2 fan toggle` temporarily forces both fans
to their hardware maximum and restores normal `t2fanrd` control on the next
toggle; it does not change the saved profile.

Graphics policy is implemented by Omarchy. The compatibility forms
`omarchy-t2 gpu integrated` and `omarchy-t2 gpu dedicated` check the current
GMUX state and delegate required changes to `omarchy toggle hybrid gpu`,
including its confirmation and reboot flow.

## GPU text-to-speech

Run the optional setup once to download and verify the Q4 models (about 1.4
GB):

```bash
omarchy-t2 tts setup
```

Text-to-speech uses Qwen3-TTS 1.7B CustomVoice with the Vivian voice. Its
delivery is friendly and calm, and pitch-preserving playback runs 25% faster
than the generated pace. Long selections are cleaned of URLs and filename-like
noise, split at sentence boundaries, and queued as complete waveforms. Playback
starts when the first section is ready while the remaining sections render in
the background, so articles and book chapters do not exceed Qwen's single-prompt
limits or break into syllable-sized underruns.

- `ALT + R` reads the current primary selection from the beginning.
- `ALT + E` pauses or resumes playback.

The setup unbinds those keys before installing its bindings, stores models in
`~/.local/share/omarchy-t2/tts`, and leaves the model files out of the package.
Disable the bindings without deleting models with `omarchy-t2 tts disable`.
Remove the downloaded models with `omarchy-t2 tts remove`.

Inspect the machine with `omarchy-t2 status` and `omarchy-t2 doctor`. Restore
the files that were present before setup with:

```bash
omarchy-t2 restore
```

Then remove the package normally.

## What the package owns

Static executables, systemd units, power/fan helpers, templates, and audio assets live under
`/usr`. Setup creates small links or managed configuration under `/etc` and the
current user's XDG configuration directories. Original files are backed up in
`/var/lib/omarchy-t2` and `~/.local/state/omarchy-t2`.

The package expects Omarchy's existing T2 base support to provide the T2 kernel,
Apple firmware, ALSA UCM profiles, and `t2fanrd`.

## Upstream work and attribution

The hardened touchpad classification is derived from Amin Marashi's Omarchy
contribution [#6928](https://github.com/basecamp/omarchy/pull/6928). Graphics
mode is owned by Omarchy's
[#6929](https://github.com/basecamp/omarchy/pull/6929); this package only keeps
a compatibility helper for that command.

The optional Touch Bar workflow installs Amin Marashi's GPL-3.0-or-later
[`react-drm-for-touchbar`](https://github.com/aminmarashi/react-drm-for-touchbar)
fork through its own analysis, build, and deployment scripts. Its source and
runtime files remain outside the MIT-licensed `omarchy-t2` package.

Speaker filters and FIRs come from the MIT-licensed
[`lemmyg/t2-apple-audio-dsp`](https://github.com/lemmyg/t2-apple-audio-dsp)
`speakers_161` branch. The package adapts only its current PipeWire UCM target
and six-channel positions. The microphone chain is adapted from the same
project's `mic` work.

GPU text-to-speech uses the MIT-licensed
[`qwentts.cpp`](https://github.com/ServeurpersoCom/qwentts.cpp) runtime and
Apache-2.0 Qwen3-TTS GGUF weights published by
[`Serveurperso/Qwen3-TTS-GGUF`](https://huggingface.co/Serveurperso/Qwen3-TTS-GGUF).

## Development

Tests install into an isolated temporary root and never change the host:

```bash
make test
```

To stage a complete package tree, pass a checkout of the speaker DSP branch:

```bash
make DESTDIR=/tmp/omarchy-t2-stage \
  DSP_SOURCE=/path/to/t2-apple-audio-dsp \
  QWEN_TTS_BINARY=/path/to/qwen-tts \
  QWEN_TTS_LICENSE=/path/to/qwentts.cpp/LICENSE \
  GGML_LICENSE=/path/to/qwentts.cpp/ggml/LICENSE \
  install
```

## Author

Amin Marashi <me@amin.codes>
