# Zenbook A14 (UX3407RA, X1E80100) 펌웨어·모듈 맵

2026-11-24 기준 Zenbook A14 UX3407RA 한 대(NixOS, 커널 7.2.8 + iris IRQ 패치)에서 실측한 기록이다. 5절은 그 기기의 `/etc/nixos`에서 시험한 로컬 설정이고, 이 저장소의 Zenbook 모듈에는 `cluster_cl5` 완화만 들어 있다. 확인 명령은 맨 아래에 있다.

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

## 5. 이 기기에서 바꾼 것 (`/etc/nixos`)

| 파일 | 내용 | 되돌리기 |
|---|---|---|
| `configuration.nix` | `boot.initrd.extraFirmwarePaths`에 GPU 펌웨어 2개 추가 | 백업 `configuration.nix.bak-errfix` |
| `modules/iris-test.nix` | 장치 트리에서 iris 켜기, `qcvss8380.mbn` 지정 | imports에서 줄 삭제 |
| `modules/iris-irq-fix.nix` + `patches/iris-irq-sync/` | `qcom_iris` 종료 데드락 수정(Qualcomm v3 시리즈를 7.2.8에 맞춰 옮김), 커널 직접 빌드 | imports에서 줄 삭제 후 `nixos-rebuild boot`(배포판 커널로 돌아감) |
| `modules/iris-encoder.nix` | 부팅 때 `qcom_iris` 로드, `power/control=on`, 펌웨어 미리 깨우기 | 백업 `configuration.nix.bak-irisenc` |
| `modules/x1e-cluster-idle.nix` | `cluster_cl5` 유휴 상태 제거(강제 리셋 완화) | imports에서 줄 삭제 |
| `modules/dsp-early.nix` | initrd에서 `qcom_pd_mapper`·`qrtr_smd`를 DSP보다 먼저 로드 | 백업 `configuration.nix.bak-dspearly` |

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
