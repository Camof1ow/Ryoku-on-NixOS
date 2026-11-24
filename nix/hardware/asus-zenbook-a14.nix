# ASUS Zenbook A14 UX3407RA (Snapdragon X Elite X1E-78-100).
# kuruczgy/x1e-nixos-config의 modules/x1e80100.nix를 이 기기에 맞춰 옮겼다.
# 라이브 ISO와 설치된 시스템이 함께 쓴다.
{ lib, pkgs, ... }:

{
  imports = [ ./asus-zenbook-a14-iris.nix ];

  hardware.deviceTree = {
    enable = true;
    name = "qcom/x1e80100-asus-zenbook-a14.dtb";
    # X1(Hamoa)은 CPU 클러스터가 가장 깊은 유휴 상태(cluster_cl5)에 들어간 뒤
    # DC ZVA가 꺼진 캐시를 건드리면 패닉 기록 없이 SoC가 리셋된다. 업스트림 RFC
    # "arm64: dts: qcom: hamoa: Drop cluster_cl5 idle state from CPU clusters"와
    # 같게 cl5를 뺀다. 이 기기에서 x1e-crash 재현기가 cl5가 있을 때 리셋되고,
    # 뺀 뒤에는 10분 넘게 리셋되지 않았다. 대가는 유휴 전력이 조금 느는 것이다.
    overlays = [
      {
        name = "x1e-drop-cluster-cl5";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / {
            compatible = "qcom,x1e80100";
            fragment@0 {
              target-path = "/psci/power-domain-cpu-cluster0";
              __overlay__ { domain-idle-states = <&cluster_cl4>; };
            };
            fragment@1 {
              target-path = "/psci/power-domain-cpu-cluster1";
              __overlay__ { domain-idle-states = <&cluster_cl4>; };
            };
            fragment@2 {
              target-path = "/psci/power-domain-cpu-cluster2";
              __overlay__ { domain-idle-states = <&cluster_cl4>; };
            };
          };
        '';
      }
    ];
  };

  # 장치 트리와 X1E 드라이버가 온전히 들어 있는 최신 커널을 쓴다.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "pd_ignore_unused"
    "clk_ignore_unused"
  ];

  # 기본 initrd 모듈 목록은 x86 PC 기준이다. 이 기기의 부팅에 필요한 것만 넣는다.
  boot.initrd.includeDefaultModules = false;
  boot.initrd.availableKernelModules = [
    # USB-A·USB-C 부팅
    "usb_storage"
    "uas"
    "phy_qcom_qmp_combo"
    "phy_qcom_qmp_usb"
    "phy_snps_eusb2"
    "phy_qcom_eusb2_repeater"
    "phy_nxp_ptn3222"
    "tcsrcc_x1e80100"
    "ps883x"
    "pmic_glink_altmode"
    "qrtr"

    # 키보드·터치패드
    "i2c_hid_of"
    "i2c_qcom_geni"

    # 내장 OLED 화면. msm은 모든 DP 출력의 브리지가 준비돼야 화면을 켠다.
    "dispcc-x1e80100"
    "gpucc-x1e80100"
    "phy_qcom_edp"
    "panel_edp"
    "panel_samsung_atna33xc20"
    "msm"
    "simple_bridge"
    "display_connector"

    # NVMe
    "nvme"
    "phy_qcom_qmp_pcie"
  ];

  # 커널 충돌이 잦아 x1e-nixos-config도 끈다.
  boot.blacklistedKernelModules = [ "qcom_iris" ];

  # TPM 드라이버가 없어 systemd가 TPM을 기다리느라 부팅이 1분 넘게 멈춘다.
  systemd.tpm2.enable = false;
  boot.initrd.systemd.tpm2.enable = false;

  # Wi-Fi(ath12k)와 GPU 공용 펌웨어는 linux-firmware에 있다.
  hardware.enableRedistributableFirmware = true;

  # systemd-boot는 기본 부팅 경로(EFI/BOOT/BOOTAA64.EFI)로만 설치한다. 이 기기의 INSYDE 펌웨어는
  # 그 경로를 "EFI Hard Drive" 부팅 항목으로 스스로 등록한다. UEFI 변수 쓰기(uefisecapp)도 되지만
  # 펌웨어에 맡기고 쓰지 않는다(2026-11-24 실기기: efibootmgr 항목이 재부팅 뒤에도 남음).
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
}
