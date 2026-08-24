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
- Cool, responsive dual-fan curve
- Protected six-channel speaker DSP for `MacBookPro16,1`
- Normalized, limited mono microphone DSP using the working array channel
- Bluetooth passkey display and A2DP auto-connect
- Intel-first integrated graphics mode with the Radeon kept at low power
- Optional Qwen3-TTS reading on the Radeon through Vulkan

The speaker DSP initially sets the processed sink to 25%. Raise it cautiously.
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
omarchy-t2 input keyboard us mac-iso
omarchy-t2 input tap on
omarchy-t2 audio speakers off
omarchy-t2 audio mic on
omarchy-t2 bluetooth disable
omarchy-t2 gpu dedicated
omarchy-t2 tts setup
```

## GPU text-to-speech

Run the optional setup once to download and verify the Q4 models (about 1.4
GB):

```bash
omarchy-t2 tts setup
```

Text-to-speech uses Qwen3-TTS 1.7B CustomVoice with the Vivian voice. Its
delivery is friendly and calm, and pitch-preserving playback runs 25% faster
than the generated pace. Audio streams as it is produced instead of waiting
for the complete selection.

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

Static executables, systemd units, templates, and audio assets live under
`/usr`. Setup creates small links or managed configuration under `/etc` and the
current user's XDG configuration directories. Original files are backed up in
`/var/lib/omarchy-t2` and `~/.local/state/omarchy-t2`.

The package expects Omarchy's existing T2 base support to provide the T2 kernel,
Apple firmware, ALSA UCM profiles, and `t2fanrd`.

## Upstream work and attribution

The hardened touchpad classification and Intel-first graphics behavior are
derived from Amin Marashi's Omarchy contributions
[#6928](https://github.com/basecamp/omarchy/pull/6928) and
[#6929](https://github.com/basecamp/omarchy/pull/6929).

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
