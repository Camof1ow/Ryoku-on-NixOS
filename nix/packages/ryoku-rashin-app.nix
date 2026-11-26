{ pkgs, src }:

# Rashin 대시보드(127.0.0.1:3600)를 띄우는 GTK3 + WebKitGTK 창(rashin-app).
# 업스트림 deploy.sh의 compile_app ryoku/rashin/app 단계와 같은 CMake 빌드다.
pkgs.stdenv.mkDerivation {
  pname = "ryoku-rashin-app";
  version = "1.0.0";

  src = src + "/ryoku/rashin/app";

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.wrapGAppsHook3
  ];

  buildInputs = [
    pkgs.gtk3
    pkgs.webkitgtk_4_1
    pkgs.libsoup_3
  ];

  postInstall = ''
    install -Dm644 "$src/rashin-app.desktop" "$out/share/applications/rashin-app.desktop"
    install -Dm644 "$src/logo.svg" "$out/share/icons/hicolor/scalable/apps/rashin-app.svg"
  '';

  meta = {
    description = "Rashin console window for the Ryoku desktop";
    mainProgram = "rashin-app";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
