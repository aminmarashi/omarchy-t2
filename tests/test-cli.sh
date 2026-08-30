#!/bin/bash

set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
root="$test_dir/root"
home="$test_dir/home"
dsp="$test_dir/dsp"
qwen_tts="$test_dir/qwen-tts"
touchbar="$home/react-drm"
TTS_TALKER=qwen-talker-1.7b-customvoice-Q4_K_M.gguf
TTS_CODEC=qwen-tokenizer-12hz-Q4_K_M.gguf

cleanup() {
  [[ $test_dir == /tmp/* ]] && rm -rf "$test_dir"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file=$1
  local expected=$2
  grep -Fq -- "$expected" "$file" || fail "$file does not contain: $expected"
}

assert_exists() {
  [[ -e $1 || -L $1 ]] || fail "missing: $1"
}

assert_not_exists() {
  [[ ! -e $1 && ! -L $1 ]] || fail "unexpected path: $1"
}

assert_link_target() {
  [[ -L $1 && $(readlink "$1") == "$2" ]] || fail "$1 does not link to: $2"
}

install -d "$dsp/config" "$dsp/firs" "$root/sys/devices/virtual/dmi/id" \
  "$root/sys/devices/platform/APP0001:00" "$root/etc/udev/rules.d" \
  "$root/etc/pipewire/pipewire.conf.d" "$root/etc/modprobe.d" \
  "$home/.config/hypr" "$home/.config/systemd/user/bt-agent.service.d" \
  "$home/.config/pipewire/pipewire.conf.d"

install -d "$touchbar/linux-touchbar-control-center/dist"
cat >"$touchbar/install.sh" <<'EOF'
#!/bin/bash
printf 'install %s\n' "$*" >>"$TOUCHBAR_CALLS"
EOF
cat >"$touchbar/uninstall.sh" <<'EOF'
#!/bin/bash
printf 'uninstall %s\n' "$*" >>"$TOUCHBAR_CALLS"
EOF
chmod 0755 "$touchbar/install.sh" "$touchbar/uninstall.sh"
: >"$touchbar/linux-touchbar-control-center/dist/index.js"
git -C "$touchbar" init -q
git -C "$touchbar" remote add fork https://github.com/aminmarashi/react-drm-for-touchbar.git
git -C "$touchbar" add install.sh uninstall.sh linux-touchbar-control-center/dist/index.js
git -C "$touchbar" -c user.name=Test -c user.email=test@example.com commit -qm fixture

cat >"$dsp/config/10-t2_161_speakers.conf" <<'EOF'
context.modules = [
    { name = libpipewire-module-filter-chain
        args = {
            playback.props = {
                node.name = "effect_output.filter-chain-speakers"
                node.target = "alsa_output.pci-0000_04_00.3.Speakers"
                node.passive = true
                audio.channels = 6
                audio.position = [ AUX0 AUX1 AUX2 AUX3 AUX4 AUX5 ]
            }
        }
    }
]
EOF
printf 'MIT test fixture\n' >"$dsp/LICENSE"
for kind in tweeters woofers; do
  for rate in 44k 48k 96k; do
    : >"$dsp/firs/macbook_pro_t2_16_1_${kind}_4-${rate}.wav"
  done
done

printf '#!/bin/sh\nexit 0\n' >"$qwen_tts"
chmod 0755 "$qwen_tts"

make -s -C "$project_dir" \
  DESTDIR="$root" \
  DSP_SOURCE="$dsp" \
  QWEN_TTS_BINARY="$qwen_tts" \
  QWEN_TTS_LICENSE="$dsp/LICENSE" \
  GGML_LICENSE="$dsp/LICENSE" \
  install

assert_link_target \
  "$root/usr/share/omarchy-t2/rules/30-omarchy-t2-amdgpu-pm.rules" \
  /usr/share/omarchy/default/udev/rules.d/30-omarchy-t2-amdgpu-pm.rules
assert_link_target \
  "$root/usr/share/omarchy-t2/uwsm/20-omarchy-t2-gpu" \
  /usr/share/omarchy/default/uwsm/env-hyprland.d/20-omarchy-t2-gpu

printf 'MacBookPro16,1\n' >"$root/sys/devices/virtual/dmi/id/product_name"
printf '100\n' >"$root/sys/devices/platform/APP0001:00/battery_charge_limit"
printf 'old fan config\n' >"$root/etc/t2fand.conf"
printf 'old touchpad rule\n' >"$root/etc/udev/rules.d/99-omarchy-apple-t2-touchpad.rules"
printf 'options apple-gmux force_igd=n\n' >"$root/etc/modprobe.d/apple-gmux.conf"
printf 'old speaker config\n' >"$root/etc/pipewire/pipewire.conf.d/10-t2_161_speakers.conf"
printf 'require("default.hypr.omarchy")\nrequire("hypr.input")\n' >"$home/.config/hypr/hyprland.lua"
printf 'old mic config\n' >"$home/.config/pipewire/pipewire.conf.d/10-omarchy-t2-mic.conf"
printf '[Service]\nExecStart=/old-agent\n' >"$home/.config/systemd/user/bt-agent.service.d/upstream-fix.conf"
printf '[Service]\nExecStart=/usr/bin/true\n' >"$home/.config/systemd/user/react-drm.service"

export HOME="$home"
export XDG_CONFIG_HOME="$home/.config"
export XDG_DATA_HOME="$home/.local/share"
export XDG_STATE_HOME="$home/.local/state"
export XDG_RUNTIME_DIR="$test_dir/runtime"
export OMARCHY_T2_ROOT="$root"
export OMARCHY_T2_SKIP_RUNTIME=true
export OMARCHY_T2_TOUCHBAR_DIR="$touchbar"
export TOUCHBAR_CALLS="$test_dir/touchbar-calls"
install -d "$XDG_RUNTIME_DIR"

stub_bin="$test_dir/bin"
install -d "$stub_bin"
cat >"$stub_bin/omarchy" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$OMARCHY_CALLS"
EOF
chmod 0755 "$stub_bin/omarchy"
export OMARCHY_CALLS="$test_dir/omarchy-calls"
export PATH="$stub_bin:$PATH"

printf 'talker fixture\n' >"$test_dir/$TTS_TALKER"
printf 'codec fixture\n' >"$test_dir/$TTS_CODEC"
export OMARCHY_T2_TTS_TALKER_URL="file://$test_dir/$TTS_TALKER"
export OMARCHY_T2_TTS_CODEC_URL="file://$test_dir/$TTS_CODEC"
export OMARCHY_T2_TTS_TALKER_SHA256
OMARCHY_T2_TTS_TALKER_SHA256=$(sha256sum "$test_dir/$TTS_TALKER" | awk '{print $1}')
export OMARCHY_T2_TTS_CODEC_SHA256
OMARCHY_T2_TTS_CODEC_SHA256=$(sha256sum "$test_dir/$TTS_CODEC" | awk '{print $1}')

cli="$root/usr/bin/omarchy-t2"
"$cli" version | grep -q '^omarchy-t2 0.4.0$'
"$cli" setup --dry-run
assert_file_contains "$root/etc/t2fand.conf" 'old fan config'
assert_file_contains "$root/etc/modprobe.d/apple-gmux.conf" 'force_igd=n'
assert_not_exists "$home/.config/hypr/omarchy-t2.lua"
"$cli" setup --yes

assert_exists "$root/etc/udev/rules.d/99-omarchy-t2-touchpad.rules"
assert_file_contains "$root/usr/bin/omarchy-tts" 'qwen-talker-1.7b-customvoice-Q4_K_M.gguf'
assert_file_contains "$root/usr/bin/omarchy-tts" 'kill -CONT "${job_pids[@]}"'
assert_exists "$root/usr/lib/omarchy-t2/tts-queue"
assert_exists "$root/usr/lib/omarchy-t2/power-optimizer"
assert_exists "$root/usr/lib/omarchy-t2/fan-control"
assert_exists "$root/usr/lib/omarchy-t2/audio-output-sink"
assert_exists "$root/usr/lib/systemd/system/power-optimizer.service"
assert_file_contains "$root/usr/bin/omarchy-tts" '--stream-by-line'
assert_file_contains "$root/usr/bin/omarchy-tts" 'Preparing $total speech sections'
assert_file_contains "$root/usr/bin/omarchy-tts" 'pw-play "$playback_audio"'
assert_file_contains "$root/usr/bin/omarchy-tts" '"Preparing speech…"'
assert_not_exists "$root/etc/udev/rules.d/99-omarchy-apple-t2-touchpad.rules"
assert_file_contains "$root/etc/omarchy-t2.conf" 'BATTERY_LIMIT=95'
assert_file_contains "$root/etc/t2fand.conf" 'low_temp=40'
assert_file_contains "$root/etc/t2fand.conf" 'high_temp=60'
assert_file_contains "$root/etc/t2fand.conf" 'speed_curve=linear'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_ENABLED=true'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_WARM_C=45'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_HOT_C=65'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_WARM_IDLE_PERCENT=15'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_HOT_IDLE_PERCENT=50'
assert_link_target \
  "$root/etc/systemd/system/power-optimizer.service" \
  "$root/usr/lib/systemd/system/power-optimizer.service"
assert_file_contains "$root/etc/modprobe.d/apple-gmux.conf" 'force_igd=n'
assert_not_exists "$root/etc/udev/rules.d/30-omarchy-t2-amdgpu-pm.rules"
assert_exists "$root/etc/pipewire/pipewire.conf.d/10-omarchy-t2-speakers.conf"
assert_link_target \
  "$home/.local/bin/omarchy-audio-output-sink" \
  "$root/usr/lib/omarchy-t2/audio-output-sink"
assert_file_contains "$root/usr/lib/omarchy-t2/audio-output-sink" 'node\.link-group'
assert_file_contains "$cli" 'pactl set-sink-volume effect_input.filter-chain-speakers 100%'
assert_file_contains "$cli" 'pactl set-sink-volume alsa_output.pci-0000_04_00.3.HiFi__Speaker__sink 25%'
assert_file_contains "$home/.config/hypr/hyprland.lua" '-- omarchy-t2:start'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'kb_variant = "mac-iso"'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'tap_to_click = false'
assert_exists "$home/.config/pipewire/pipewire.conf.d/10-omarchy-t2-mic.conf"
assert_exists "$home/.config/systemd/user/bt-agent.service.d/omarchy-t2.conf"
mic_config="$home/.config/pipewire/pipewire.conf.d/10-omarchy-t2-mic.conf"
assert_file_contains "$mic_config" 'target.object        = "alsa_input.pci-0000_04_00.3.HiFi__Mic__source"'
assert_file_contains "$mic_config" 'priority.session    = 1800'
assert_file_contains "$mic_config" 'state.default-volume = 1.0'
assert_file_contains "$cli" 'wpctl clear-default 1'
assert_file_contains "$cli" 'pactl set-source-volume effect_output.filter-chain-t2-mic 100%'
if grep -Fq 'node.target' "$mic_config"; then
  fail "microphone filter uses the ignored node.target property"
fi
if grep -Fq 'pactl set-default-source' "$cli"; then
  fail "CLI pins a microphone instead of allowing automatic routing"
fi

"$cli" tts setup --dry-run
assert_not_exists "$home/.local/share/omarchy-t2/tts"
"$cli" tts setup --yes
assert_exists "$home/.local/share/omarchy-t2/tts/models/$TTS_TALKER"
assert_exists "$home/.local/share/omarchy-t2/tts/models/$TTS_CODEC"
assert_file_contains "$home/.config/omarchy-t2/config" 'TTS_ENABLED=true'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'hl.unbind("ALT + R")'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'o.bind("ALT + E", "Pause or resume selected text", "omarchy-tts toggle-pause")'
"$cli" tts status | grep -q '^enabled=true models=ready engine=ready$'
"$cli" tts disable
assert_file_contains "$home/.config/omarchy-t2/config" 'TTS_ENABLED=false'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'if false then'
"$cli" tts enable
assert_file_contains "$home/.config/omarchy-t2/config" 'TTS_ENABLED=true'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'if true then'

"$cli" touchbar status | grep -q '^source=ready .* service=unavailable$'
"$cli" touchbar analyze
"$cli" touchbar setup
"$cli" touchbar enable
"$cli" touchbar disable
"$cli" touchbar uninstall
assert_file_contains "$TOUCHBAR_CALLS" 'install analyze'
assert_file_contains "$TOUCHBAR_CALLS" 'install '
assert_file_contains "$TOUCHBAR_CALLS" 'uninstall '

"$cli" battery limit 80
"$cli" fan profile quiet
"$cli" power thermal on 50 70 20 45
if "$cli" power thermal on 70 50 20 45 >/dev/null 2>&1; then
  fail "invalid descending thermal range was accepted"
fi
"$cli" power profile-switching off
"$cli" power profiles balanced power-saver
"$cli" power gpu-saving off
"$cli" power wifi-saving off
"$cli" power usb-autosuspend off
"$cli" power status | grep -q '^enabled=true$'
"$cli" power disable
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_ENABLED=false'
"$cli" power enable
"$cli" input tap on
"$cli" gpu status | grep -q '^dedicated$'
"$cli" gpu dedicated
assert_not_exists "$OMARCHY_CALLS"
"$cli" gpu integrated
grep -Fxq 'toggle hybrid gpu' "$OMARCHY_CALLS" || fail "GPU helper does not delegate to Omarchy"
printf 'options apple-gmux force_igd=y\n' >"$root/etc/modprobe.d/apple-gmux.conf"
"$cli" gpu status | grep -q '^integrated$'
"$cli" gpu dedicated
"$cli" gpu toggle
[[ $(wc -l <"$OMARCHY_CALLS") == 3 ]] || fail "GPU helper delegates each requested change exactly once"
assert_file_contains "$root/etc/omarchy-t2.conf" 'BATTERY_LIMIT=80'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_WARM_C=50'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_HOT_C=70'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_WARM_IDLE_PERCENT=20'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_HOT_IDLE_PERCENT=45'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_AC_PROFILE=balanced'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_PROFILE_SWITCHING=true'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_GPU_SAVING=false'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_WIFI_SAVING=false'
assert_file_contains "$root/etc/omarchy-t2.conf" 'POWER_USB_AUTOSUSPEND=false'
assert_file_contains "$root/etc/t2fand.conf" 'low_temp=55'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'tap_to_click = true'
assert_not_exists "$root/etc/udev/rules.d/30-omarchy-t2-amdgpu-pm.rules"

"$cli" status | grep -q 'Model:          MacBookPro16,1'
"$cli" status | grep -q 'Touch Bar UI:   unavailable (source: ready)'
printf 'canonical Radeon policy\n' >"$root/etc/udev/rules.d/30-omarchy-t2-amdgpu-pm.rules"
install -d "$home/.config/uwsm/env-hyprland.d"
printf 'canonical renderer policy\n' >"$home/.config/uwsm/env-hyprland.d/20-omarchy-t2-gpu"
"$cli" restore --yes
assert_file_contains "$root/etc/t2fand.conf" 'old fan config'
assert_not_exists "$root/etc/systemd/system/power-optimizer.service"
assert_file_contains "$root/etc/modprobe.d/apple-gmux.conf" 'force_igd=y'
assert_file_contains "$root/etc/udev/rules.d/30-omarchy-t2-amdgpu-pm.rules" 'canonical Radeon policy'
assert_file_contains "$home/.config/uwsm/env-hyprland.d/20-omarchy-t2-gpu" 'canonical renderer policy'
assert_file_contains "$root/etc/udev/rules.d/99-omarchy-apple-t2-touchpad.rules" 'old touchpad rule'
assert_file_contains "$root/etc/pipewire/pipewire.conf.d/10-t2_161_speakers.conf" 'old speaker config'
assert_not_exists "$home/.local/bin/omarchy-audio-output-sink"
assert_file_contains "$home/.config/pipewire/pipewire.conf.d/10-omarchy-t2-mic.conf" 'old mic config'
assert_not_exists "$home/.config/hypr/omarchy-t2.lua"
assert_not_exists "$home/.local/share/omarchy-t2/tts"
if grep -q '^-- omarchy-t2:start$' "$home/.config/hypr/hyprland.lua"; then
  fail "Hyprland include survived restore"
fi

printf 'MacBookPro18,3\n' >"$root/sys/devices/virtual/dmi/id/product_name"
if "$cli" battery limit 90 >/dev/null 2>&1; then
  fail "unsupported model accepted a hardware change"
fi

echo "All omarchy-t2 CLI tests passed"
