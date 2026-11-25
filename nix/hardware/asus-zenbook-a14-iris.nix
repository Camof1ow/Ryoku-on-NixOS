# iris(하드웨어 영상 코덱)를 켜는 옵션. 기본은 꺼져 있다(qcom_iris는 asus-zenbook-a14.nix에서 블랙리스트).
# 켜면 커널과 Chromium을 소스에서 빌드한다. 이 기기에서 커널 29분, Chromium 5시간 11분이 걸렸고
# nixpkgs를 올릴 때마다 다시 빌드한다. 펌웨어 qcvss8380.mbn(ASUS BSP V1.312.8100.0, Windows 드라이버와 같음)은
# 호스트가 /etc/nixos/firmware/qcom/x1e80100/ASUSTeK/zenbook-a14/에 둬야 한다.
# 실측과 근거는 docs/zenbook-a14-firmware.md 7절.
{ config, lib, pkgs, ... }:
let
  cfg = config.hardware.asus-zenbook-a14.iris;
  kernelPatch = name: { inherit name; patch = ../patches/iris-irq-sync + "/${name}.patch"; };
in
{
  options.hardware.asus-zenbook-a14.iris.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      iris 영상 코덱을 켠다: 장치 트리 노드, 종료 데드락 커널 패치, 부팅 때 인코더 준비,
      Chromium의 V4L2 디코딩(H.264·HEVC·VP9·AV1, 8K까지). 커널과 Chromium을 소스에서 빌드한다.
    '';
  };

  config = lib.mkIf cfg.enable {
    hardware.deviceTree.overlays = [
      {
        name = "zenbook-a14-iris";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / {
            compatible = "qcom,x1e80100";
            fragment@0 {
              target-path = "/soc@0/video-codec@aa00000";
              __overlay__ {
                firmware-name = "qcom/x1e80100/ASUSTeK/zenbook-a14/qcvss8380.mbn";
                status = "okay";
              };
            };
          };
        '';
      }
    ];

    # 7.2.8의 iris_vpu_power_off()는 core->lock을 쥔 채 disable_irq()로 스레드 IRQ를 기다리고, 그 IRQ는
    # core->lock을 기다려 종료가 멈춘다. Qualcomm "media: qcom: iris: Fix IRQ synchronization during power-off"
    # v3(2026-11-20)를 7.2.8 문맥에 맞춰 옮겼다. 커널이 이 시리즈를 포함하면 뺀다.
    # iris-8k-max-clock: iris는 입력 버퍼가 들어오는 속도로 fps를 추정해 클럭을 정하므로, 디코딩이 밀리면 클럭도
    # 같이 내려간다(8K60 AV1 재생 중 192~240MHz). 4K를 넘으면 최대 OPP(481MHz)를 쓴다. 그래도 8K60은 초당 58.5프레임만
    # 디코딩해 22%를 버린다(X Elite 디코딩 사양은 4K120까지). 4K60은 이 패치와 상관없이 192MHz에서 버림 0.1%다.
    boot.kernelPatches = map kernelPatch [
      "0001-Revert-media-qcom-iris-use-disable_irq-during-power-"
      "0002-media-qcom-iris-Fix-IRQ-disable-depth-imbalance-on-w"
      "0003-media-qcom-iris-Skip-register-access-in-IRQ-handler-"
    ] ++ [ { name = "iris-8k-max-clock"; patch = ../patches/iris-8k-max-clock.patch; } ];

    # 런타임 PM auto에서는 다시 켤 때 펌웨어가 0x5000003으로 죽어 압축 세션 시작이 13/20만 성공했고,
    # on에서는 44/44 성공했다. 유휴 전력 차이는 측정되지 않았다.
    services.udev.extraRules = ''
      ACTION=="bind", SUBSYSTEM=="platform", DRIVER=="qcom-iris", ATTR{power/control}="on"
    '';

    # systemd-modules-load는 블랙리스트를 지키므로 이름을 지정한 modprobe로 올린다. 전원을 처음 켤 때의
    # 실패를 부팅 직후 소진한다. 실패한 세션은 SIGINT를 무시하므로 SIGKILL로 끊는다.
    systemd.services.iris-encoder-warmup = {
      description = "Load and wake the Iris video encoder";
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.coreutils pkgs.kmod pkgs.ffmpeg-headless ];
      serviceConfig.Type = "simple";
      script = ''
        modprobe qcom_iris
        for _ in $(seq 10); do
          grep -qs encoder /sys/class/video4linux/video*/name && break
          sleep 1
        done
        for try in $(seq 6); do
          if timeout -s KILL 10 ffmpeg -v error -y -f lavfi -i testsrc2=size=1280x736:rate=30 -frames:v 15 \
              -pix_fmt nv12 -c:v h264_v4l2m2m -f null -; then
            echo "iris encoder ready after $try attempt(s)"
            exit 0
          fi
          sleep 1
        done
        echo "iris encoder did not start; the recorder retries or falls back to the CPU"
      '';
    };

    # nixpkgs aarch64 Chromium은 V4L2 빌드인데 use_av1_hw_decoder가 VA-API 빌드에서만 기본으로 켜져 AV1이 빠진다
    # (nixpkgs#537726). iris는 4K를 넘는 영상에 12.75MiB 이상 bitstream 버퍼를 요구하는데 Chromium은 형식을 0×0으로
    # 정해 6.75MiB로 잡으므로, 해상도를 넘기는 패치를 더한다. 실행 플래그는 Omarchy PR #15697과 같다.
    nixpkgs.overlays = [
      (final: prev: {
        chromium =
          let
            old = prev.chromium.browser;
            browser = (old.override (args: {
              mkChromiumDerivation = buildFun:
                args.mkChromiumDerivation (base: buildFun base // { gnFlags = { use_av1_hw_decoder = true; }; });
            })).overrideAttrs (o: {
              patches = (o.patches or [ ]) ++ [ ../patches/chromium-v4l2-coded-size.patch ];
            });
          in
          (prev.chromium.override {
            commandLineArgs = "--use-angle=gles-egl --enable-features=WaylandWindowDecorations,AcceleratedVideoDecoder";
          }).overrideAttrs (o: {
            # nixpkgs 래퍼에는 안쪽 browser를 바꾸는 인자가 없어 경로만 새 빌드로 바꾼다.
            buildCommand = builtins.replaceStrings
              [ "${old}" "${old.sandbox}" ]
              [ "${browser}" "${browser.sandbox}" ]
              o.buildCommand;
          });
      })
    ];
  };
}
