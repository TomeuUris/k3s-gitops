#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

printf 'Checking shell scripts...\n'
shellcheck verify-cluster.sh
bash -n verify-cluster.sh

printf 'Checking YAML syntax...\n'
python3 - <<'PY'
from pathlib import Path
import yaml

files = [path for path in Path('.').rglob('*.yaml') if '.git' not in path.parts]
files += [path for path in Path('.').rglob('*.yml') if '.git' not in path.parts]

for path in sorted(set(files)):
    if "templates" in path.parts:
        continue
    yaml.safe_load(path.read_text())
    print(f'  OK {path}')
PY

printf 'Checking Helm charts...\n'
for chart in apps charts/*; do
    if [ -f "$chart/Chart.yaml" ]; then
        if grep -q '^dependencies:' "$chart/Chart.yaml"; then
            helm repo add jetstack https://charts.jetstack.io --force-update
            helm dependency build "$chart"
        fi
        helm lint "$chart"
        helm template "$(basename "$chart")" "$chart" >/dev/null
    fi
done

printf 'Checking rendered Kubernetes resources...\n'
for chart in apps charts/*; do
    if [ -f "$chart/Chart.yaml" ]; then
        helm template "$(basename "$chart")" "$chart" | kubeconform \
            -strict \
            -ignore-missing-schemas \
            -summary \
            -output text
    fi
done

printf 'Validation complete.\n'
