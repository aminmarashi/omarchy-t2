#!/bin/bash

set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
root="$test_dir/root"
home="$test_dir/home"
dsp="$test_dir/dsp"
qwen_tts="$test_dir/qwen-tts"
TTS_TALKER=qwen-talker-1.7b-customvoice-Q8_0.gguf
TTS_CODEC=qwen-tokenizer-12hz-Q8_0.gguf

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

install -d "$dsp/config" "$dsp/firs" "$root/sys/devices/virtual/dmi/id" \
  "$root/sys/devices/platform/APP0001:00" "$root/etc/udev/rules.d" \
  "$root/etc/pipewire/pipewire.conf.d" "$root/etc/modprobe.d" \
  "$home/.config/hypr" "$home/.config/systemd/user/bt-agent.service.d" \
  "$home/.config/pipewire/pipewire.conf.d"

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

printf 'MacBookPro16,1\n' >"$root/sys/devices/virtual/dmi/id/product_name"
printf '100\n' >"$root/sys/devices/platform/APP0001:00/battery_charge_limit"
printf 'old fan config\n' >"$root/etc/t2fand.conf"
printf 'old touchpad rule\n' >"$root/etc/udev/rules.d/99-omarchy-apple-t2-touchpad.rules"
printf 'options apple-gmux force_igd=n\n' >"$root/etc/modprobe.d/apple-gmux.conf"
printf 'old speaker config\n' >"$root/etc/pipewire/pipewire.conf.d/10-t2_161_speakers.conf"
printf 'require("default.hypr.omarchy")\nrequire("hypr.input")\n' >"$home/.config/hypr/hyprland.lua"
printf 'old mic config\n' >"$home/.config/pipewire/pipewire.conf.d/10-omarchy-t2-mic.conf"
printf '[Service]\nExecStart=/old-agent\n' >"$home/.config/systemd/user/bt-agent.service.d/upstream-fix.conf"

export HOME="$home"
export XDG_CONFIG_HOME="$home/.config"
export XDG_DATA_HOME="$home/.local/share"
export XDG_STATE_HOME="$home/.local/state"
export XDG_RUNTIME_DIR="$test_dir/runtime"
export OMARCHY_T2_ROOT="$root"
export OMARCHY_T2_SKIP_RUNTIME=true
install -d "$XDG_RUNTIME_DIR"

printf 'talker fixture\n' >"$test_dir/$TTS_TALKER"
printf 'codec fixture\n' >"$test_dir/$TTS_CODEC"
export OMARCHY_T2_TTS_TALKER_URL="file://$test_dir/$TTS_TALKER"
export OMARCHY_T2_TTS_CODEC_URL="file://$test_dir/$TTS_CODEC"
export OMARCHY_T2_TTS_TALKER_SHA256
OMARCHY_T2_TTS_TALKER_SHA256=$(sha256sum "$test_dir/$TTS_TALKER" | awk '{print $1}')
export OMARCHY_T2_TTS_CODEC_SHA256
OMARCHY_T2_TTS_CODEC_SHA256=$(sha256sum "$test_dir/$TTS_CODEC" | awk '{print $1}')

cli="$root/usr/bin/omarchy-t2"
"$cli" version | grep -q '^omarchy-t2 0.2.0$'
"$cli" setup --dry-run
assert_file_contains "$root/etc/t2fand.conf" 'old fan config'
assert_file_contains "$root/etc/modprobe.d/apple-gmux.conf" 'force_igd=n'
assert_not_exists "$home/.config/hypr/omarchy-t2.lua"
"$cli" setup --yes

assert_exists "$root/etc/udev/rules.d/99-omarchy-t2-touchpad.rules"
assert_not_exists "$root/etc/udev/rules.d/99-omarchy-apple-t2-touchpad.rules"
assert_file_contains "$root/etc/omarchy-t2.conf" 'BATTERY_LIMIT=95'
assert_file_contains "$root/etc/t2fand.conf" 'low_temp=40'
assert_file_contains "$root/etc/modprobe.d/apple-gmux.conf" 'force_igd=y'
assert_exists "$root/etc/udev/rules.d/30-omarchy-t2-amdgpu-pm.rules"
assert_exists "$root/etc/pipewire/pipewire.conf.d/10-omarchy-t2-speakers.conf"
assert_file_contains "$home/.config/hypr/hyprland.lua" '-- omarchy-t2:start'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'kb_variant = "mac-iso"'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'tap_to_click = false'
assert_exists "$home/.config/pipewire/pipewire.conf.d/10-omarchy-t2-mic.conf"
assert_exists "$home/.config/systemd/user/bt-agent.service.d/omarchy-t2.conf"

"$cli" tts setup --dry-run
assert_not_exists "$home/.local/share/omarchy-t2/tts"
"$cli" tts setup --yes
assert_exists "$home/.local/share/omarchy-t2/tts/models/$TTS_TALKER"
assert_exists "$home/.local/share/omarchy-t2/tts/models/$TTS_CODEC"
assert_file_contains "$home/.config/omarchy-t2/config" 'TTS_ENABLED=true'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'hl.unbind("SUPER + R")'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'o.bind("SUPER + E", "Pause or resume selected text", "omarchy-tts toggle-pause")'
"$cli" tts status | grep -q '^enabled=true models=ready engine=ready$'
"$cli" tts disable
assert_file_contains "$home/.config/omarchy-t2/config" 'TTS_ENABLED=false'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'if false then'
"$cli" tts enable
assert_file_contains "$home/.config/omarchy-t2/config" 'TTS_ENABLED=true'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'if true then'

"$cli" battery limit 80
"$cli" fan profile quiet
"$cli" input tap on
"$cli" gpu dedicated
assert_file_contains "$root/etc/omarchy-t2.conf" 'BATTERY_LIMIT=80'
assert_file_contains "$root/etc/t2fand.conf" 'low_temp=55'
assert_file_contains "$home/.config/hypr/omarchy-t2.lua" 'tap_to_click = true'
assert_file_contains "$root/etc/modprobe.d/apple-gmux.conf" 'force_igd=n'
assert_not_exists "$root/etc/udev/rules.d/30-omarchy-t2-amdgpu-pm.rules"

"$cli" status | grep -q 'Model:          MacBookPro16,1'
"$cli" restore --yes
assert_file_contains "$root/etc/t2fand.conf" 'old fan config'
assert_file_contains "$root/etc/modprobe.d/apple-gmux.conf" 'force_igd=n'
assert_file_contains "$root/etc/udev/rules.d/99-omarchy-apple-t2-touchpad.rules" 'old touchpad rule'
assert_file_contains "$root/etc/pipewire/pipewire.conf.d/10-t2_161_speakers.conf" 'old speaker config'
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
