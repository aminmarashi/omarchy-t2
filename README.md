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
```

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

## Development

Tests install into an isolated temporary root and never change the host:

```bash
make test
```

To stage a complete package tree, pass a checkout of the speaker DSP branch:

```bash
make DESTDIR=/tmp/omarchy-t2-stage \
  DSP_SOURCE=/path/to/t2-apple-audio-dsp install
```

## Author

Amin Marashi <me@amin.codes>
