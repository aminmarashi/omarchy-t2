PREFIX ?= /usr
SYSCONFDIR ?= /etc
DESTDIR ?=
DSP_SOURCE ?=
QWEN_TTS_BINARY ?=
QWEN_TTS_LICENSE ?=
GGML_LICENSE ?=

PACKAGE_SHARE := $(DESTDIR)$(PREFIX)/share/omarchy-t2
PACKAGE_LIB := $(DESTDIR)$(PREFIX)/lib/omarchy-t2

.PHONY: install test

install:
	@test -n "$(DSP_SOURCE)" || { echo "DSP_SOURCE must point to t2-apple-audio-dsp speakers_161" >&2; exit 1; }
	@test -f "$(DSP_SOURCE)/config/10-t2_161_speakers.conf"
	@test -x "$(QWEN_TTS_BINARY)" || { echo "QWEN_TTS_BINARY must point to a Vulkan qwen-tts executable" >&2; exit 1; }
	@test -f "$(QWEN_TTS_LICENSE)" || { echo "QWEN_TTS_LICENSE must point to qwentts.cpp's license" >&2; exit 1; }
	@test -f "$(GGML_LICENSE)" || { echo "GGML_LICENSE must point to ggml's license" >&2; exit 1; }
	install -Dm755 bin/omarchy-t2 "$(DESTDIR)$(PREFIX)/bin/omarchy-t2"
	install -Dm755 libexec/omarchy-tts "$(DESTDIR)$(PREFIX)/bin/omarchy-tts"
	install -Dm755 "$(QWEN_TTS_BINARY)" "$(PACKAGE_LIB)/qwen-tts"
	install -Dm755 libexec/omarchy-t2-apply-battery-limit "$(PACKAGE_LIB)/apply-battery-limit"
	install -Dm755 libexec/omarchy-t2-bluetooth-agent "$(PACKAGE_LIB)/bluetooth-agent"
	install -Dm755 libexec/omarchy-t2-mic-guard "$(PACKAGE_LIB)/mic-guard"
	install -Dm644 systemd/omarchy-t2-battery-limit.service "$(DESTDIR)$(PREFIX)/lib/systemd/system/omarchy-t2-battery-limit.service"
	install -Dm644 systemd/omarchy-t2-mic-guard.service "$(DESTDIR)$(PREFIX)/lib/systemd/user/omarchy-t2-mic-guard.service"
	install -Dm644 rules/90-omarchy-t2-battery.rules "$(PACKAGE_SHARE)/rules/90-omarchy-t2-battery.rules"
	install -Dm644 rules/99-omarchy-apple-t2-touchpad.rules "$(PACKAGE_SHARE)/rules/99-omarchy-apple-t2-touchpad.rules"
	install -Dm644 config/omarchy-t2.conf "$(DESTDIR)$(SYSCONFDIR)/omarchy-t2.conf"
	install -Dm644 config/omarchy-t2.conf "$(PACKAGE_SHARE)/defaults/omarchy-t2.conf"
	install -Dm644 config/input.conf "$(PACKAGE_SHARE)/defaults/input.conf"
	install -Dm644 config/t2fand-balanced.conf "$(PACKAGE_SHARE)/fan/t2fand-balanced.conf"
	install -Dm644 config/t2fand-cool.conf "$(PACKAGE_SHARE)/fan/t2fand-cool.conf"
	install -Dm644 config/t2fand-quiet.conf "$(PACKAGE_SHARE)/fan/t2fand-quiet.conf"
	install -Dm644 config/10-omarchy-t2-mic.conf "$(PACKAGE_SHARE)/audio/10-omarchy-t2-mic.conf"
	install -Dm644 config/bluetooth-a2dp-autoconnect.conf "$(PACKAGE_SHARE)/wireplumber/bluetooth-a2dp-autoconnect.conf"
	# Preserve legacy link targets without carrying a second copy of Omarchy's GPU policies.
	install -d "$(PACKAGE_SHARE)/rules" "$(PACKAGE_SHARE)/uwsm"
	ln -sfn /usr/share/omarchy/default/udev/rules.d/30-omarchy-t2-amdgpu-pm.rules "$(PACKAGE_SHARE)/rules/30-omarchy-t2-amdgpu-pm.rules"
	ln -sfn /usr/share/omarchy/default/uwsm/env-hyprland.d/20-omarchy-t2-gpu "$(PACKAGE_SHARE)/uwsm/20-omarchy-t2-gpu"
	install -Dm644 "$(DSP_SOURCE)/config/10-t2_161_speakers.conf" "$(PACKAGE_SHARE)/audio/10-omarchy-t2-speakers.conf"
	patch --quiet "$(PACKAGE_SHARE)/audio/10-omarchy-t2-speakers.conf" patches/speakers-pipewire-1.6.patch
	install -d "$(DESTDIR)$(PREFIX)/share/pipewire/devices/apple"
	install -m644 "$(DSP_SOURCE)"/firs/macbook_pro_t2_16_1_*_4-44k.wav "$(DESTDIR)$(PREFIX)/share/pipewire/devices/apple/"
	install -m644 "$(DSP_SOURCE)"/firs/macbook_pro_t2_16_1_*_4-48k.wav "$(DESTDIR)$(PREFIX)/share/pipewire/devices/apple/"
	install -m644 "$(DSP_SOURCE)"/firs/macbook_pro_t2_16_1_*_4-96k.wav "$(DESTDIR)$(PREFIX)/share/pipewire/devices/apple/"
	install -Dm644 LICENSE "$(DESTDIR)$(PREFIX)/share/licenses/omarchy-t2/LICENSE"
	install -Dm644 "$(DSP_SOURCE)/LICENSE" "$(DESTDIR)$(PREFIX)/share/licenses/omarchy-t2/t2-apple-audio-dsp-LICENSE"
	install -Dm644 "$(QWEN_TTS_LICENSE)" "$(DESTDIR)$(PREFIX)/share/licenses/omarchy-t2/qwentts.cpp-LICENSE"
	install -Dm644 "$(GGML_LICENSE)" "$(DESTDIR)$(PREFIX)/share/licenses/omarchy-t2/ggml-LICENSE"
	install -Dm644 README.md "$(DESTDIR)$(PREFIX)/share/doc/omarchy-t2/README.md"

test:
	bash tests/test-cli.sh
