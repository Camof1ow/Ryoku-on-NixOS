# Zenbook A14 설치 ISO 로컬 빌드

ASUS Zenbook A14 UX3407RA(Snapdragon X Elite, arm64)용 설치 ISO를 내 PC에서 직접 만드는 방법입니다.

- 결과물: `ryoku-nixos-<버전>-main-<커밋>-aarch64-linux.iso` (약 7GB)
- 빌드할 곳: arm64 Windows PC의 WSL2 Ubuntu. Zenbook A14 자체에서 해도 됩니다(Windows를 지우기 전).
- x64 PC는 권장하지 않습니다. 아래 "x64 PC에서는?"을 보세요.
- 필요한 공간: Windows C:에 70GB 이상
- 걸리는 시간(추정): 처음에는 45~75분. 대부분 패키지 다운로드 시간입니다.

## 1. WSL2 Ubuntu 준비 (처음 한 번)

관리자 PowerShell에서 실행합니다.

```powershell
wsl --install -d Ubuntu-24.04
```

- 재부팅하라고 하면 재부팅한 뒤 같은 명령을 다시 실행합니다.
- Ubuntu 창이 열리면 사용자 이름과 비밀번호를 만듭니다.

Ubuntu 창에서 systemd가 켜져 있는지 확인합니다.

```bash
ps -p 1 -o comm=
```

`systemd`가 아니면 아래를 실행하고, PowerShell에서 `wsl --shutdown` 후 Ubuntu를 다시 엽니다.

```bash
printf '[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf
```

## 2. Nix 설치 (처음 한 번)

```bash
sudo apt-get update && sudo apt-get install -y curl git xz-utils
bash <(curl -L https://nixos.org/nix/install) --daemon
```

- 설치가 끝나면 Ubuntu 창을 닫고 새로 엽니다.
- `nix --version`이 버전을 출력하면 됩니다.

## 3. Nix 설정 (처음 한 번)

```bash
sudo tee -a /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
extra-substituters = https://ryoku-arm.cachix.org
extra-trusted-public-keys = ryoku-arm.cachix.org-1:IBvBuhs6b5jCptOS/vzEWhNXxg36TBKWJYHanaTsWR4=
EOF
sudo systemctl restart nix-daemon
```

- `ryoku-arm`은 이 포크의 CI가 빌드 결과를 올려 둔 캐시입니다. Hyprland·niri·quickshell을 직접 빌드하지 않고 받아 옵니다.
- 이 설정은 꼭 `/etc/nix/nix.conf`에 넣습니다. 사용자 설정(`~/.config/nix`)에 넣으면 캐시가 무시됩니다.

## 4. 소스 받기

```bash
git clone https://github.com/Camof1ow/Ryoku-on-NixOS.git
cd Ryoku-on-NixOS
```

이미 받아 두었으면 `git pull`만 합니다.

## 5. 캐시가 먹는지 확인 (몇 분)

```bash
nix build .#packages.aarch64-linux.ryoku-iso-zenbook-a14 --dry-run 2>&1 | grep -E '(hyprland-0|niri-2|quickshell-0)[^ ]*\.drv'
```

- 아무것도 안 나오면 정상입니다. 큰 패키지는 빌드하지 않고 캐시에서 받습니다.
- `….drv`로 끝나는 `hyprland`·`niri`·`quickshell` 줄이 나오면, 3단계 설정이 적용되지 않아 직접 빌드하려는 것입니다. `/etc/nix/nix.conf`를 확인하고 `sudo systemctl restart nix-daemon`을 실행합니다.

## 6. 빌드

```bash
nix build .#packages.aarch64-linux.ryoku-iso-zenbook-a14 -o result-iso
```

- 처음에는 다운로드가 대부분입니다.
- Ryoku 자체 패키지(셸·설정 앱·QML 모듈)는 커밋이 바뀔 때마다 다시 빌드됩니다. 저장소 전체를 소스로 쓰기 때문입니다.
- 실패하면 마지막 줄에 나오는 `nix log /nix/store/…drv` 명령을 실행하고 그 출력을 공유합니다.

## 7. 확인

```bash
ls -lh result-iso/iso/
sha256sum result-iso/iso/*.iso
nix eval --json .#nixosConfigurations.ryoku-iso-zenbook-a14.config.boot.initrd.kernelModules
```

마지막 줄의 목록에 `"dm_mod"`가 있어야 합니다. Ventoy가 리눅스에 ISO를 넘겨줄 때 이 모듈이 필요합니다.

## 8. USB에 넣기

```bash
WIN_DL="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")/Downloads"
cp -L result-iso/iso/*.iso "$WIN_DL/"
```

- Windows 탐색기에서 다운로드 폴더의 ISO를 Ventoy USB로 복사합니다.
- 예전 ISO(`…-f3978a3-…`)는 USB에서 지웁니다. 파일 이름의 커밋 부분으로 새것과 구분할 수 있습니다.

## 9. 부팅

1. 노트북을 끄고, 전원 버튼을 누르자마자 Esc를 연타합니다.
2. 부팅 메뉴에서 `UEFI: (USB 이름)`을 고릅니다.
3. Ventoy 목록에서 새 ISO를 고릅니다. 부팅 방식을 물으면 normal mode를 고릅니다.

그래도 `waiting for device …`나 `An error occurred in stage 1`이 뜨면 Ventoy를 쓰지 않습니다. 다른 USB(8GB 이상)에 Rufus로 ISO를 굽고, Rufus가 물으면 "DD 이미지 모드"를 고릅니다.

## 다시 빌드할 때

```bash
cd Ryoku-on-NixOS
git pull
nix build .#packages.aarch64-linux.ryoku-iso-zenbook-a14 -o result-iso
```

디스크가 부족하면 `rm result-iso` 후 `nix-collect-garbage -d`로 지난 빌드를 지웁니다.

## x64 PC에서는?

- x64 PC에서 aarch64 패키지를 만들려면 QEMU 에뮬레이션이 필요합니다. 몇 시간 걸려서 권장하지 않습니다.
- 대신 `main`에 push하면 GitHub Actions가 같은 ISO를 만듭니다. Actions → "Zenbook A14 ISO (aarch64)" 실행 → Artifacts에서 받습니다.

## 자주 나는 오류

- `experimental Nix feature 'nix-command' is disabled`: 3단계 설정을 확인하고 `sudo systemctl restart nix-daemon`을 실행합니다.
- `ignoring untrusted substituter`: 캐시 설정이 `/etc/nix/nix.conf`에 있는지 확인합니다.
- `No space left on device`: C: 여유 공간을 늘리거나 `nix-collect-garbage -d`를 실행합니다.
