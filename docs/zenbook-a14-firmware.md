# Zenbook A14 (UX3407RA, X1E80100) 펌웨어·모듈 맵

2026-11-24 기준 Zenbook A14 UX3407RA 한 대(NixOS, 커널 7.2.8 + iris IRQ 패치)에서 실측한 기록이다. 6절은 그 기기의 `/etc/nixos`에서 시험한 로컬 설정이고, 이 저장소의 Zenbook 모듈에는 `cluster_cl5` 완화만 들어 있다. 확인 명령은 맨 아래에 있다.

## 1. 펌웨어 → 장치 → 드라이버

장치 트리의 `firmware-name`이 어떤 파일을 쓸지 정하고, 그 장치에 붙은 드라이버가 파일을 올린다.

| 장치(장치 트리 노드) | 펌웨어 파일 | 출처 | 드라이버(모듈) | 하는 일 |
|---|---|---|---|---|
| aDSP `remoteproc@6800000` (`qcom,x1e80100-adsp-pas`) | `qcom/x1e80100/ASUSTeK/zenbook-a14/qcadsp8380.mbn` + `adsp_dtbs.elf` | Windows 드라이버 | `qcom_q6v5_pas` | 소리, 배터리·충전, USB-C 상태, 센서 |
| cDSP `remoteproc@32300000` (`qcom,x1e80100-cdsp-pas`) | `…/zenbook-a14/qccdsp8380.mbn` + `cdsp_dtbs.elf` | Windows 드라이버 | `qcom_q6v5_pas` | 계산(NPU·AI 연산 맡기기) |
| GPU `gpu@3d00000` | `qcom/gen70500_sqe.fw`, `qcom/gen70500_gmu.bin` | linux-firmware | `msm`(adreno) | GPU 명령 처리기·전원 관리 |
| GPU zap shader `gpu@3d00000/zap-shader` | `…/zenbook-a14/qcdxkmsuc8380.mbn` | Windows 드라이버 | `msm` | GPU 보안 모드 전환(기기 서명 필요) |
| 영상 코덱 `video-codec@aa00000` (`qcom,x1e80100-iris`) | `…/zenbook-a14/qcvss8380.mbn` | ASUS BSP `V1.312.8100.0` | `qcom_iris` | 하드웨어 영상 압축·풀기 |
| 오디오 카드 `X1E80100-ASUS-Zenbook-A14` | `…/zenbook-a14/X1E80100-ASUS-Zenbook-A14-tplg.bin` | linux-firmware | `snd_soc_x1e80100`, `snd_q6apm` | aDSP 오디오 경로 구성(topology) |
| Wi-Fi WCN7850 | `ath12k/WCN7850/hw2.0/amss.bin`, `m3.bin`, `board-2.bin` | linux-firmware | `ath12k_wifi7` | `WLAN.HMT.1.1.c7` |
| 블루투스 WCN7850 | `qca/hmtbtfw20.tlv`, `qca/hmtnv20.b112` | linux-firmware | `hci_uart`(`btqca`) | `BTFW.HAMILTON.2.0.1` |

- Windows 드라이버에서 가져온 파일은 `/etc/nixos/firmware/`에 있고, `configuration.nix`의 `windows-device-firmware` 패키지로 들어간다. 같은 목록이 `boot.initrd.extraFirmwarePaths`로 initrd에도 들어간다.
- `gen70500_sqe.fw`·`gen70500_gmu.bin`도 initrd에 넣었다. 빼면 부팅 초기에 `error -2`가 나고 GPU가 늦게 뜬다.
- linux-firmware에 있는 `qcom/x1e80100/gen70500_zap.mbn`은 쓰지 않는다. 장치 트리가 `qcdxkmsuc8380.mbn`을 가리킨다.
- `qcom_iris`는 하드웨어 모듈에서 블랙리스트돼 있다. `iris-encoder-warmup.service`가 `modprobe`로 직접 올린다. 장치 트리에서 iris를 켜는 것은 `modules/iris-test.nix` 오버레이다.

### Windows 펌웨어 파일 SHA-256(앞 16자리)

| 파일 | SHA-256 |
|---|---|
| `qcadsp8380.mbn` | `537f48ff493a7791` |
| `adsp_dtbs.elf` | `120cb824c03bf3b5` |
| `qccdsp8380.mbn` | `4a67a03367f2eff2` |
| `cdsp_dtbs.elf` | `93941f040da14b83` |
| `qcdxkmsuc8380.mbn` | `f2f6dd1d7b2dc6e8` |
| `qcvss8380.mbn` | `3ee65bc056f47a03` |

## 2. DSP 안의 통신 채널 → 커널 드라이버

DSP가 켜지면 glink 채널을 열어 달라고 알리고, 커널은 채널 이름에 맞는 드라이버를 붙인다.

| DSP | 채널 | 드라이버(모듈) | 용도 |
|---|---|---|---|
| aDSP | `IPCRTR` | `qcom_smd_qrtr`(`qrtr_smd`) | QMI 통신 경로(pd-mapper, sysmon, 배터리 등) |
| aDSP | `PMIC_RTR_ADSP_APPS` | `qcom_pmic_glink_rpmsg`(`pmic_glink`) | 배터리(`qcom-battmgr`), USB-C(`ucsi`), DP alt mode |
| aDSP | `adsp_apps` | `qcom,apr`(`apr`) | 오디오(GPR: `gprsvc:service:2:1` APM 등) |
| aDSP | `fastrpcglink-apps-dsp` | `qcom,fastrpc`(`fastrpc`) | `/dev/fastrpc-adsp` |
| aDSP | `glink_ssr` | `qcom_glink_ssr` | 서브시스템 재시작 알림 |
| aDSP | `APPS_ADSP_PWR_LMTS_GLINK_PORT`, `LOOPBACK_CTL_LPASS`, `PMIC_LOGS_ADSP_APPS`, `sleepmonglink-apps-adsp` | 없음 | 붙는 드라이버 없음 |
| cDSP | `IPCRTR` | `qcom_smd_qrtr`(`qrtr_smd`) | QMI 통신 경로 |
| cDSP | `fastrpcglink-apps-dsp` | `qcom,fastrpc`(`fastrpc`) | `/dev/fastrpc-cdsp`, `/dev/fastrpc-cdsp-secure` |
| cDSP | `LOOPBACK_CTL_CDSP`, `cdsprmglink-apps-dsp`, `ipcliteglink-apps-dsp` | 없음 | 붙는 드라이버 없음 |

- **aDSP를 끄지 말 것.** 배터리·충전과 USB-C가 aDSP 위에서 돈다. 2026-11-24에 aDSP를 재시작하려다 로그 없이 하드웨어 리셋이 났다(종료 기록·panic·pstore 모두 없음). 원인은 확인하지 못했다.
- cDSP는 `/sys/class/remoteproc/remoteproc1/state`에 `stop`/`start`를 써서 다시 켜도 된다. 6번 해서 6번 모두 정상이었다.

## 3. 보호 도메인(PD) → pd-mapper

DSP 펌웨어는 켜지자마자 pd-mapper에 자기 PD와 서비스를 알리고, 다른 PD를 찾는다. 이 기기에서는 커널 모듈 `qcom_pd_mapper`가 이 일을 한다. 커널 안 표(`x1e80100_domains`)가 Windows 쪽 `.jsn` 파일과 같은 내용이다.

| PD | instance | 서비스 | 같은 내용의 `.jsn` |
|---|---|---|---|
| `msm/adsp/root_pd` | 74 | (`.jsn`에는 `tms/pdr_enabled`도 있음) | `adspr.jsn` |
| `msm/adsp/audio_pd` | 74 | `avs/audio` | `adspua.jsn` |
| `msm/adsp/charger_pd` | 74 | - | `battmgr.jsn` |
| `msm/adsp/sensor_pd` | 74 | - | `adsps.jsn` |
| `msm/cdsp/root_pd` | 76 | - | `cdspr.jsn` |

- `.jsn` 파일은 사용자 공간 pd-mapper용이다. 커널 `qcom_pd_mapper`를 쓰는 지금은 읽히지 않는다.

## 4. 부팅 순서와 알려진 에러

시각은 부팅 뒤 경과 초. 왼쪽은 `dsp-early.nix` 적용 전, 오른쪽은 적용 후(세대 13).

| 일 | 적용 전 | 적용 후 |
|---|---|---|
| `qcom_pd_mapper` 로드 | 5.05 (DSP가 켜진 뒤, udev) | ~4.2 (initrd) |
| `qrtr_smd` 로드 | 5.26 | ~4.2 (initrd) |
| `qcom_q6v5_pas` 로드 | 4.79 | 4.98 |
| cDSP / aDSP 켜기 시작 | 4.86 / 4.94 | 5.00 / 5.06 |
| 5초 대기 끝 타임아웃 | ~10.5 | ~10.5 (APM만) |

| 에러 | 뜻 | 세대 9·10(적용 전, 3번 부팅) | 세대 11·12(적용 전, 3번 부팅) | 세대 13(적용 후, 5번 부팅) |
|---|---|---|---|---|
| `qcom-apm gprsvc:service:2:1: CMD timeout for [1001021] opcode` | aDSP 오디오 프레임워크 준비 여부 질문(`APM_CMD_GET_SPF_STATE`)에 5초 안에 답이 없음 | 3/3 | 3/3 | 5/5 |
| `fastrpc`/`qcom_smd_qrtr` … `failed to create endpoint` → `error -12` | cDSP가 glink 채널 열기(`qcom_glink_create_remote`)에 5초 안에 답하지 않음. -12는 `rpmsg_dev_probe`가 붙이는 값이고 실제로는 시간 초과 | 3/3 | 0/3 | 0/5 |
| `qcom_q6v5_pas 32300000.remoteproc: timeout waiting for subsystem event response` | cDSP가 sysmon SSCTL 이벤트(QMI)에 5초 안에 답하지 않음 | 2/3 | 0/3 | 0/5 |
| `qcom-iris … received system error of type 0x5000003` | iris 펌웨어 오류. 전원을 다시 켤 때 잘 남. 런타임 PM을 `on`으로 두면 처음 1~4번 뒤로는 안 남 | - | - | 녹화 시험 때 |
| `qcom_pmic_glink … Failed to create device link (0x180)` | USB-C 커넥터 장치 링크 경고 | 매번 | 매번 | 매번 |

- **APM 타임아웃은 순서 문제가 아니다.** pd-mapper를 먼저 올려도 5/5 그대로다. `q6prm` probe가 `q6apm_is_adsp_ready()`로 aDSP 오디오 프레임워크(SPF)가 준비됐는지 묻는데, 준비 전에는 답이 오지 않아 5초 뒤 타임아웃 → `-EPROBE_DEFER` → 나중에 다시 probe해서 성공한다. 이 드라이버는 무응답을 "아직 안 됨"으로 쓴다. 소리 장치가 부팅 뒤 약 10초에 잡히는 것 말고는 영향이 없다고 본다(소리 지연은 재지 않음).
- **cDSP 에러(`-12`, subsystem)는 적용 후 0/5다.** 하지만 적용 직전 세대 11·12에서도 0/3이라, `dsp-early.nix` 덕분이라고 말할 수 없다. 원인 가설(DSP가 pd-mapper·QRTR보다 먼저 켜짐)은 확인되지 않았다. 부팅 뒤 cDSP를 다시 켜면 6/6 정상(채널 연결까지 약 4ms)이라 부팅 때만 생기는 조건인 것은 맞다.
- `dsp-early.nix`는 해가 없고 순서도 맞으니 유지한다. 다시 나는지는 아래 확인 명령의 "부팅별 DSP 타임아웃 수"로 본다.

## 5. 로그인 화면(SDDM) 커서

증상: 부팅 직후 로그인 화면(SDDM greeter, Material You·Orbital 스킨)에서 터치패드를 움직이면 버튼 hover는 되는데 커서가 보이지 않는다. 로그인 뒤 niri에서는 보인다.

로그인 화면은 niri가 아니라 `weston --shell=kiosk`(SDDM Wayland greeter, NixOS 기본)가 그린다. weston 16에는 cursor-shape 프로토콜이 없어 greeter(Qt)가 커서 그림을 직접 붙인다(`wl_pointer.set_cursor`).

원인: weston 16은 포인터를 터치패드의 **첫 이벤트 때** 만든다(`libweston/libinput-device.c`의 `ensure_pointer_capability`). 부팅 직후 greeter는 키보드만 있는 seat(`wl_seat.capabilities(2)`)에 붙고, 나중에 생긴 `wl_pointer`로 입력(hover)은 받지만 `set_cursor`를 한 번도 부르지 않는다. 그래서 커서 그림이 없다.

| VT 9 실측(실제 화면 출력 weston + greeter 테스트 모드, 시작할 때 터치패드 안 만짐) | 처음 받은 seat | `set_cursor` | 커서 |
|---|---|---|---|
| 패치 전 | 키보드만(2) → 나중에 3 | 0회 | 안 보임 |
| 장치 인식 때 포인터를 만드는 패치 | 키보드+포인터(3) | 17~39회 | 보임 |

수정: 이 저장소 NixOS 모듈(`nix/modules/ryoku.nix`의 SDDM 블록)과 `nix/patches/weston-pointer-at-start.patch`. 처음에는 이 기기 `/etc/nixos/modules/sddm-sw-cursor.nix`로 시험했고, 저장소 모듈만 쓴 평가 결과(weston drv, compositor 명령, SDDM 설정)가 그것과 같다.

- weston 패치 `weston-pointer-at-start.patch`: `evdev_device_create`에서 키보드가 아닌 포인터 장치(터치패드·마우스)는 바로 `ensure_pointer_capability`를 부른다.
- `services.displayManager.sddm.settings.General.GreeterEnvironment`에 `XCURSOR_PATH=/run/current-system/sw/share/icons`, `XCURSOR_THEME`, `XCURSOR_SIZE`. libwayland-cursor 기본 경로(`/usr/share/icons` 등)에는 NixOS 커서 테마가 없다. niri 안 창 시험에서 이 경로 없이는 테마를 못 찾아 기본 그림(10×16)이 쓰였다. 값은 `lib.mkDefault`라 호스트 설정이 이긴다.
- NixOS SDDM 모듈이 `pkgs.weston`을 직접 부르므로 overlay로 weston 전체에 패치를 건다. weston을 쓰는 것이 없으면 빌드되지 않는다. 이 기기에서 weston을 쓰는 것은 SDDM뿐이다(`nix why-depends`).

버린 가설(실측으로 반증):

- **하드웨어 커서 플레인**: niri는 msm DPU 커서 플레인에서 커서가 안 보여 `disable-cursor-plane`을 쓰지만, weston은 커서 플레인을 끄지 않은 빌드로도 커서가 보였다.
- **직접 출력(client buffer scanout)**: `WESTON_FORCE_RENDERER=1` 없이도 보였다. 처음 시험에서 이 값을 켠 회차만 보였던 것은 그때 이미 터치패드를 만지고 있어 포인터가 먼저 생겼기 때문으로 본다(추정).
- **계정·환경변수**: `sddm` 계정·`/var/lib/sddm` 홈·세션 버스·`XDG_DATA_DIRS` 유무로는 결과가 바뀌지 않았다.

참고: [sddm#1996](https://github.com/sddm/sddm/issues/1996)에 "ryoku arch with weston"에서도 같은 증상이라는 보고가 있다(2026-09-12).

## 6. 이 기기에서 바꾼 것 (`/etc/nixos`)

| 파일 | 내용 | 되돌리기 |
|---|---|---|
| `configuration.nix` | `boot.initrd.extraFirmwarePaths`에 GPU 펌웨어 2개 추가 | 백업 `configuration.nix.bak-errfix` |
| `modules/iris-test.nix` | 장치 트리에서 iris 켜기, `qcvss8380.mbn` 지정. 7절 옵션에 들어갔다 | 옵션을 켤 때 imports에서 삭제 |
| `modules/iris-irq-fix.nix` + `patches/iris-irq-sync/` | `qcom_iris` 종료 데드락 수정(Qualcomm v3 시리즈를 7.2.8에 맞춰 옮김), 커널 직접 빌드. 7절 옵션에 들어갔다 | 옵션을 켤 때 imports에서 삭제(커널 빌드 결과는 같다) |
| `modules/iris-encoder.nix` | 부팅 때 `qcom_iris` 로드, `power/control=on`, 펌웨어 미리 깨우기. 7절 옵션에 들어갔다 | 옵션을 켤 때 imports에서 삭제 |
| `modules/x1e-cluster-idle.nix` | `cluster_cl5` 유휴 상태 제거(강제 리셋 완화). 이 저장소 하드웨어 모듈에도 같은 오버레이가 있다 | imports에서 삭제해도 된다(같은 값이 두 번 걸려 있음) |
| `modules/dsp-early.nix` | initrd에서 `qcom_pd_mapper`·`qrtr_smd`를 DSP보다 먼저 로드 | 백업 `configuration.nix.bak-dspearly` |
| `modules/sddm-sw-cursor.nix` + `patches/weston-pointer-at-start.patch` | 로그인 화면 커서(5절). 이 저장소 모듈에 같은 내용이 들어갔다 | flake.lock의 ryoku를 그 커밋 이후로 올릴 때 imports에서 함께 삭제. 남기면 패치가 두 번 걸려 weston 빌드가 실패한다(`Reversed (or previously applied) patch detected!`) |
| `modules/chromium-hwdec.nix` | Chromium 래퍼에 `--use-angle=gles-egl --enable-features=WaylandWindowDecorations,AcceleratedVideoDecoder`. H.264·HEVC·VP9를 iris(V4L2)로 디코딩한다. 7절 옵션에는 AV1(`use_av1_hw_decoder`)과 8K 패치까지 들어갔다 | 옵션을 켤 때 imports에서 삭제 |

## 7. iris 영상 코덱 옵션 (`hardware.asus-zenbook-a14.iris.enable`)

기본은 꺼져 있다. 켜면 `nix/hardware/asus-zenbook-a14-iris.nix`가 다음을 넣는다. 6절의 iris 관련 로컬 파일 네 개와 커널·Chromium 빌드 결과가 같다(평가로 비교).

- 장치 트리에서 iris 노드를 켜고 `qcvss8380.mbn`을 가리킨다. 펌웨어 파일은 호스트가 `/etc/nixos/firmware/qcom/x1e80100/ASUSTeK/zenbook-a14/`에 둔다(ASUS BSP `V1.312.8100.0`).
- 종료 데드락 수정 커널 패치 3개(`nix/patches/iris-irq-sync/`)와 8K 클럭 패치(`nix/patches/iris-8k-max-clock.patch`). 커널을 직접 빌드한다(이 기기에서 29분).
  - iris는 1초 동안 들어온 입력 버퍼 수로 fps를 추정해 클럭을 정한다. 디코딩이 밀리면 입력도 느려져 클럭이 같이 내려가므로(8K60 재생 중 192~240MHz), 클럭 패치는 4K를 넘는 영상에 최대 OPP(481MHz)를 쓰게 한다.
- 부팅 때 `qcom_iris`를 올리고(블랙리스트는 그대로 두고 이름을 지정한 modprobe), 런타임 PM을 끄고, 인코더를 미리 깨운다.
- Chromium: 실행 플래그 `--use-angle=gles-egl --enable-features=WaylandWindowDecorations,AcceleratedVideoDecoder`, GN `use_av1_hw_decoder = true`, `nix/patches/chromium-v4l2-coded-size.patch`. Chromium을 소스에서 빌드한다(이 기기에서 5시간 11분, nixpkgs를 올릴 때마다 다시).

기본으로 켜지 않는 이유: 켜면 새 설치와 CI가 Chromium을 소스에서 빌드해야 하고(CI 러너 6시간 제한), 펌웨어도 호스트가 따로 둬야 한다.

| 실측(2026-11-24~25) | 결과 |
|---|---|
| 1080p H.264·VP9 | 렌더러 CPU 31~36% → 3%, iris 인터럽트 3초에 160회 이상 |
| AV1 1080p·4K | `V4L2VideoDecoder`, dav1d 스레드 0 |
| AV1 8K(96Mbps, 30fps, 15초) | 7.49초에 영상 7.49초 진행(실시간), 초당 30.0프레임, 끊김 0, 브라우저 CPU 26%(dav1d로 디코딩할 때 렌더러 약 600%) |
| YouTube AV1 8K60(7680×4050, itag 571) | 클럭 패치 전 iris 192~240MHz, 26% 버림(YouTube 통계). 패치 뒤 481MHz, 초당 58.5프레임 디코딩, 22% 버림 |
| YouTube AV1 4K60(3840×2026, itag 401) | iris 192MHz, 초당 60.0프레임, 버림 0.1% |

8K가 패치 없이 안 되던 이유: iris는 4K를 넘는 영상에 bitstream 버퍼 12.75MiB 이상을 요구하고(4K 이하는 6.75MiB, `v4l2-ctl`로 확인), 작은 버퍼는 `iris_vb2_buf_prepare`에서 EINVAL로 거부한다. Chromium은 OUTPUT 형식을 0×0으로 정해 6.75MiB 버퍼를 한 번만 잡으므로 8K 첫 QBUF가 거부되고(`Error while queuing input`) dav1d로 넘어갔다. 패치는 형식을 정할 때 실제 해상도를 넘긴다. 커널 master와 Chromium main도 같은 코드다.

8K60은 하드웨어 한계다. Qualcomm X Elite 제품 사양서의 VPU 디코딩 최대치는 4K120이고, 8K60(7680×4050)은 픽셀 처리량이 그 1.9배다. 최대 클럭에서도 초당 58.5프레임에 그쳐 프레임이 늦게 나오고 버려진다. 1920×1200 화면에서는 4K60을 쓴다.

알려진 문제:

- iris를 처음 켤 때 펌웨어가 `system error of type 0x5000003`을 한 번 내고 바로 복구된다.
- Chromium 빌드 중 node(tsc)가 결과를 다 쓴 뒤 종료 과정에서 멈춘 적이 있다(스레드 셋 모두 futex 대기, 2시간 39분). root로 `gdb -p <pid> -batch -ex 'call (void)_exit(0)'`를 하면 그 단계가 성공으로 처리되고 빌드가 이어진다.

## 확인 명령

```bash
# 장치 트리가 가리키는 펌웨어
for f in $(find /sys/firmware/devicetree/base -name firmware-name); do echo "$f: $(tr '\0' ' ' < $f)"; done
# 펌웨어 파일이 어느 패키지에서 왔는지
readlink -f /run/current-system/firmware/qcom/x1e80100/ASUSTeK/zenbook-a14/*
# DSP 채널과 붙은 드라이버
for d in /sys/bus/rpmsg/devices/*; do echo "$(basename $d) -> $(basename "$(readlink -f $d/driver)")"; done
# DSP 상태
paste /sys/class/remoteproc/remoteproc*/name /sys/class/remoteproc/remoteproc*/state
# 부팅별 DSP 타임아웃 수(최근 10번 부팅)
for b in $(seq -9 0); do k=$(journalctl -b $b -k --no-pager 2>/dev/null) || continue; echo "boot $b: -12=$(grep -c 'failed to create endpoint' <<<"$k") subsys=$(grep -c 'timeout waiting for subsystem event' <<<"$k") apm=$(grep -c 'CMD timeout' <<<"$k")"; done
```
