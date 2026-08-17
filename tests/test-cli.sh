#!/bin/bash

set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
root="$test_dir/root"
home="$test_dir/home"
dsp="$test_dir/dsp"

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

make -s -C "$project_dir" DESTDIR="$root" DSP_SOURCE="$dsp" install

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
export XDG_STATE_HOME="$home/.local/state"
export OMARCHY_T2_ROOT="$root"
export OMARCHY_T2_SKIP_RUNTIME=true

cli="$root/usr/bin/omarchy-t2"
"$cli" version | grep -q '^omarchy-t2 0.1.0$'
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
if grep -q '^-- omarchy-t2:start$' "$home/.config/hypr/hyprland.lua"; then
  fail "Hyprland include survived restore"
fi

printf 'MacBookPro18,3\n' >"$root/sys/devices/virtual/dmi/id/product_name"
if "$cli" battery limit 90 >/dev/null 2>&1; then
  fail "unsupported model accepted a hardware change"
fi

echo "All omarchy-t2 CLI tests passed"
