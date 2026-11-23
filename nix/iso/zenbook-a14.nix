# Zenbook A14용 라이브 ISO 설정. 장치 설정은 nix/hardware/asus-zenbook-a14.nix에 있다.
{ lib, ... }:

{
  # 라이브 환경에서 ADSP가 올라오면 USB 부팅이 끊긴다(x1e-nixos-config iso.nix).
  boot.blacklistedKernelModules = [ "qcom_q6v5_pas" ];

  # x86 위주의 전체 하드웨어 모듈 대신 기기 모듈만 initrd에 넣는다.
  hardware.enableAllHardware = lib.mkForce false;

  boot.supportedFilesystems = {
    zfs = lib.mkForce false;
    cifs = lib.mkForce false;
    # 설치기가 Windows 파티션에서 기기 펌웨어를 복사한다.
    ntfs = true;
  };

  # 미리 빌드한 설치 시스템을 통째로 넣어 크다. 압축 시간을 줄인다.
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
}
