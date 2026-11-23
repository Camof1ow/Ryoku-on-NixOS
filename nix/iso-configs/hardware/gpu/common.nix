# Shared graphics stack for every Ryoku installation.
{ pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    # 32비트 그래픽 라이브러리는 x86_64에만 있다.
    enable32Bit = pkgs.stdenv.hostPlatform.isx86_64;
  };
}
