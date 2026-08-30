#!/bin/bash

set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

cat >"$test_dir/pactl" <<'EOF'
#!/bin/bash
case "$*" in
"get-default-sink") echo effect_input.filter-chain-speakers ;;
"list sinks") cat <<'OUT'
Sink #10
        Name: effect_input.filter-chain-speakers
        node.link-group = "link-group-42"
OUT
  ;;
"list sink-inputs") cat <<'OUT'
Sink Input #20
        Sink: 42
        node.link-group = "link-group-42"
        node.name = "effect_output.filter-chain-speakers"
OUT
  ;;
"list sinks short") echo '42 alsa_output.pci-0000_04_00.3.HiFi__Speaker__sink PipeWire s32le 6ch 48000Hz RUNNING' ;;
*) exit 1 ;;
esac
EOF
chmod 0755 "$test_dir/pactl"

PATH="$test_dir:$PATH" "$project_dir/libexec/omarchy-t2-audio-output-sink" |
  grep -Fxq 'alsa_output.pci-0000_04_00.3.HiFi__Speaker__sink'
PATH="$test_dir:$PATH" "$project_dir/libexec/omarchy-t2-audio-output-sink" bluez_output.test |
  grep -Fxq 'bluez_output.test'

echo "All audio output sink tests passed"
