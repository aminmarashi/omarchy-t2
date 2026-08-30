#!/bin/bash

set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

cat >"$test_dir/power.conf" <<'EOF'
POWER_WARM_C=45
POWER_HOT_C=65
POWER_WARM_RECOVERY_C=40
POWER_HOT_RECOVERY_C=60
POWER_WARM_IDLE_PERCENT=15
POWER_HOT_IDLE_PERCENT=50
EOF

export OMARCHY_T2_POWER_CONFIG="$test_dir/power.conf"
# shellcheck source=../libexec/omarchy-t2-power-optimizer
source "$project_dir/libexec/omarchy-t2-power-optimizer"

validate_config
[[ $(forced_idle_percent_for_temperature 45000) == 15 ]]
[[ $(forced_idle_percent_for_temperature 50000) == 24 ]]
[[ $(forced_idle_percent_for_temperature 55000) == 33 ]]
[[ $(forced_idle_percent_for_temperature 60000) == 41 ]]
[[ $(forced_idle_percent_for_temperature 65000) == 50 ]]

echo "All power optimizer tests passed"
