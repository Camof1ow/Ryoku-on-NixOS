# Ryoku on NixOS ISO

The Ryoku ISO is a bootable NixOS installer image that carries the exact Ryoku
source revision used to build it and launches `ryoku-install --iso` on the first
local TTY1 login.

## Live environment

The live image provides:

- current Nix with flakes enabled;
- NetworkManager and SSH for recovery/testing;
- the guided Ryoku terminal installer;
- the exact Ryoku source tree embedded at `/etc/ryoku/source`;
- the standard NixOS installation/recovery toolbox.

Closing the installer returns to the live shell. Run `ryoku-install --iso` to
open it again.

## Guided installation

The ISO uses one continuous Bubble Tea wizard for the complete whole-disk flow.
The backend receives a fully validated non-interactive install plan; it does not
fall back to shell prompts halfway through the installation. The wizard covers:

- HTTPS connectivity to `cache.nixos.org`, with NetworkManager `nmtui` recovery;
- target disk and ext4/Btrfs filesystem;
- hostname, username and a masked/confirmed password;
- timezone, locale and keyboard layout;
- kernel policy: NixOS default, latest, or Zen from the pinned nixpkgs;
- Ryoku compositor: Hyprland, niri, or MangoWM;
- browser, shell and optional Ryoku apps/tools;
- generated Ryoku configuration, or advanced input-only import of an existing
  NixOS flake;
- final review and exact target-disk confirmation.

GPU vendors and UEFI/BIOS mode are still detected by the backend. Password
plaintext never enters backend argv, a temporary file, or installer logs: the
TUI sends only its yescrypt hash through the backend environment.

Before partitioning, the user must type the exact target disk path. The backend
validates the same path again before `wipefs`. Unattended installs require both
`--disk` and a matching `--confirm-disk`. The installer refuses the disk backing
the live medium and writable targets smaller than 16 GiB. The live image also
enables compressed zram and automatically limits Nix build parallelism on
lower-memory machines; 8 GiB RAM is the tested minimum for the default full
desktop installation.

### Import existing NixOS flake

Import mode is deliberately conservative. It copies the selected flake into the
new system, adds only the `ryoku` flake input, and leaves the imported modules,
users, packages, desktop policy and nixpkgs input under the user's ownership.
The source directory is never edited in place.

For disk safety, the imported tree must contain a root
`hardware-configuration.nix`; the installer replaces that file with hardware
configuration generated for the new machine. Filesystem/disk declarations
outside that file are rejected instead of guessing whether old UUIDs are safe.
If the flake exposes more than one `nixosConfiguration`, the host must be chosen
explicitly.

**설치 디스크의 일부 파티션만 바꾸기(듀얼 부팅).** 기본은 고른 디스크 전체를 지운다. 다른 OS나 데이터
파티션을 남기려면 지울 파티션 번호를 `RYOKU_INSTALL_REPLACE_PARTITIONS`에 적고 터미널 모드로 실행한다.

```bash
RYOKU_INSTALL_REPLACE_PARTITIONS="1 2" ryoku-install --iso --cli --disk /dev/nvme1n1
```

적은 파티션만 지우고, 가장 큰 빈 구간에 ESP(1GiB)와 루트를 만든다. 나머지 파티션은 그대로 둔다.
설치기는 지울 번호와 디스크 파티션 표를 보여 준 뒤 디스크 경로를 다시 입력받는다. 번호가 디스크에
없거나 숫자가 아니면 디스크를 건드리기 전에 멈춘다. UEFI에서만 쓸 수 있다. 다른 디스크에 있는
Windows는 systemd-boot 메뉴에 저절로 나오지 않으므로 펌웨어 부팅 메뉴에서 고르거나
`boot.loader.systemd-boot.windows`를 쓴다.

## Installed `/etc/nixos`

The canonical installed config comes from [`../iso-configs`](../iso-configs):

```text
/etc/nixos/
├── flake.nix
├── configuration.nix
├── hardware-configuration.nix
├── install-values.nix
├── pkgs.nix
├── ryoku.nix
├── hardware/
│   └── gpu/
│       ├── common.nix
│       ├── nvidia.nix
│       ├── amd.nix
│       └── intel.nix
└── modules/
    └── module-example.nix
```

Only `install-values.nix` and `hardware-configuration.nix` are machine-specific.
The other files stay clean and user-editable. The installed `flake.nix` keeps
moving branch URLs: `nixos-unstable` for Nixpkgs and the branch the ISO was
built from for Ryoku (`unstable-dev` for `ryoku-iso`, `main` for
`ryoku-iso-stable`). The generated `flake.lock` pins both to the exact revisions
in the image, so a later `nix flake update` advances along that branch.
`ryoku track stable|unstable` switches the branch afterwards.

Rebuild an installed system with:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#ryoku
```

## Build

From the repository root:

```bash
nix build .#ryoku-iso
```

The resulting ISO is under `result/iso/`. Its name carries the channel and the
source revision, for example
`ryoku-nixos-0.103.5-beta.20-unstable-dev-586140e-x86_64-linux.iso`.
`.#ryoku-iso-stable` builds the same image for installs that follow `main`.

To build the newest `unstable-dev` without a checkout:

```bash
nix build github:Ryoku-dev/Ryoku-on-NixOS/unstable-dev#ryoku-iso
```
