#!/usr/bin/env bash
# Zenbook A14 설치 때 지울 파티션 고르기를 실제 디스크 배치(lsblk -J)로 확인한다.
set -euo pipefail

backend=${RYOKU_INSTALL_BACKEND_SOURCE:?}

extract_function() {
  awk -v start="$1() {" '
    $0 == start { printing=1 }
    printing { print }
    printing && $0 == "}" { exit }
  ' "$backend"
}

eval "$(grep '^zenbook_platform_partlabels=' "$backend")"
eval "$(extract_function zenbook_partitions_to_replace)"
eval "$(extract_function path_prefix_exists)"

fixture=""
lsblk() { printf '%s\n' "$fixture"; }

expect() {
  local name=$1 want=$2 got
  got="$(zenbook_partitions_to_replace /dev/nvme0n1 | paste -sd' ' -)"
  [ "$got" = "$want" ] || {
    printf '%s: expected [%s], got [%s]\n' "$name" "$want" "$got" >&2
    exit 1
  }
}

platform='{"partn":1,"partlabel":"ToolsFv","label":null,"type":"part"},
{"partn":2,"partlabel":"LogFs","label":null,"type":"part"},
{"partn":3,"partlabel":"EnterpriseFV","label":null,"type":"part"},
{"partn":4,"partlabel":"ToolsFv_BACKUP","label":null,"type":"part"},
{"partn":5,"partlabel":"UpdateCapsule","label":null,"type":"part"},
{"partn":6,"partlabel":"NHLOS","label":null,"type":"part"},
{"partn":7,"partlabel":"core_nhlos_a","label":null,"type":"part"},
{"partn":8,"partlabel":"quantumsdk","label":null,"type":"part"},
{"partn":9,"partlabel":"quantumfv","label":null,"type":"part"},
{"partn":10,"partlabel":"catecontentfv","label":null,"type":"part"},
{"partn":11,"partlabel":"logdump","label":null,"type":"part"}'
myasus='{"partn":16,"partlabel":"Basic data partition","label":"MYASUS","type":"part"}'

# 공장 Windows 배치. BitLocker를 읽기 전용으로 열어 둔 crypt 매핑도 함께 보인다.
fixture='{"blockdevices":[{"partn":null,"partlabel":null,"label":null,"type":"disk"},'"$platform"',
{"partn":12,"partlabel":"EFI system partition","label":"SYSTEM","type":"part"},
{"partn":13,"partlabel":"Microsoft reserved partition","label":null,"type":"part"},
{"partn":14,"partlabel":"Basic data partition","label":"JIMAN OS 2025-04-02","type":"part"},
{"partn":null,"partlabel":null,"label":null,"type":"crypt"},
{"partn":15,"partlabel":null,"label":null,"type":"part"},'"$myasus"']}'
expect windows-factory-layout '12 13 14 15'

# Ryoku를 한 번 설치한 뒤 다시 설치하는 경우.
fixture='{"blockdevices":[{"partn":null,"partlabel":null,"label":null,"type":"disk"},'"$platform"',
{"partn":12,"partlabel":"EFI","label":"EFI","type":"part"},
{"partn":13,"partlabel":"nixos","label":"nixos","type":"part"},'"$myasus"']}'
expect reinstall-layout '12 13'

# 플랫폼 파티션이 없는 디스크는 비워 두고 기본 방식(디스크 전체)으로 넘긴다.
fixture='{"blockdevices":[{"partn":null,"partlabel":null,"label":null,"type":"disk"},
{"partn":1,"partlabel":"EFI system partition","label":"SYSTEM","type":"part"},
{"partn":2,"partlabel":"Basic data partition","label":"Windows","type":"part"}]}'
expect generic-disk ''

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
touch "$tmp/qcadsp8380.mbn.zst"
path_prefix_exists "$tmp/qcadsp8380.mbn" || { echo 'compressed firmware was not found' >&2; exit 1; }
if path_prefix_exists "$tmp/qccdsp8380.mbn"; then echo 'missing firmware was reported present' >&2; exit 1; fi

printf 'installer-zenbook-partitions: PASS\n'
