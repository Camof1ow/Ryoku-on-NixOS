{ pkgs }:

let
  version = "20250915";

  meta = {
    description = "NCNN Vulkan implementation of waifu2x";
    homepage = "https://github.com/nihui/waifu2x-ncnn-vulkan";
    license = pkgs.lib.licenses.mit;
    mainProgram = "waifu2x-ncnn-vulkan";
  };

  prebuilt = pkgs.stdenv.mkDerivation {
    pname = "waifu2x-ncnn-vulkan";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/nihui/waifu2x-ncnn-vulkan/releases/download/${version}/waifu2x-ncnn-vulkan-${version}-linux.zip";
      hash = "sha256-hI4PulVlfTTakLd1uBOemAbcdUeYsCn5XhBrqIUKcx8=";
    };

    nativeBuildInputs = [
      pkgs.unzip
      pkgs.autoPatchelfHook

      # waifu2x loads the host Vulkan driver at runtime. On NixOS
      # that driver lives under /run/opengl-driver rather than a
      # conventional FHS library directory.
      pkgs.autoAddDriverRunpath
    ];

    buildInputs = [
      pkgs.vulkan-loader
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
      pkgs.libpng
      pkgs.libjpeg_turbo
      pkgs.libwebp
    ];

    # The upstream binary resolves libvulkan.so.1 with dlopen(),
    # so it does not appear in DT_NEEDED and autoPatchelf cannot
    # infer it from the ELF dependency table.
    runtimeDependencies = [
      pkgs.vulkan-loader
    ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack

      mkdir source
      cd source
      unzip -q "$src"

      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      binary="$(
        find . \
          -type f \
          -name waifu2x-ncnn-vulkan \
          -print \
          -quit
      )"

      if [ -z "$binary" ]; then
        echo "waifu2x-ncnn-vulkan executable not found in release archive" >&2
        exit 1
      fi

      install -Dm755 \
        "$binary" \
        "$out/bin/waifu2x-ncnn-vulkan"

      mkdir -p \
        "$out/share/waifu2x-ncnn-vulkan"

      modelCount=0

      while IFS= read -r -d "" modelDir; do
        cp -a \
          "$modelDir" \
          "$out/share/waifu2x-ncnn-vulkan/"

        modelCount=$((modelCount + 1))
      done < <(
        find . \
          -type d \
          -name 'models-*' \
          -print0
      )

      if [ "$modelCount" -eq 0 ]; then
        echo "waifu2x model directories not found in release archive" >&2
        exit 1
      fi

      test -d \
        "$out/share/waifu2x-ncnn-vulkan/models-cunet"

      runHook postInstall
    '';

    meta = meta // {
      platforms = [ "x86_64-linux" ];
    };
  };

  # 공식 릴리스에는 x86_64 리눅스 바이너리만 있다. 다른 아키텍처는 같은 태그를
  # 서브모듈(ncnn, 이미지 코덱)째 받아 소스에서 빌드하고 같은 위치에 설치한다.
  fromSource = pkgs.stdenv.mkDerivation {
    pname = "waifu2x-ncnn-vulkan";
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "nihui";
      repo = "waifu2x-ncnn-vulkan";
      tag = version;
      fetchSubmodules = true;
      hash = "sha256-V1ZeLNjt5VZGVfhkaHMYd1Np9FYs15W4pby2QFgKyv8=";
    };

    sourceRoot = "source/src";

    nativeBuildInputs = [
      pkgs.cmake
      pkgs.autoAddDriverRunpath
    ];

    buildInputs = [
      pkgs.vulkan-headers
      pkgs.vulkan-loader
    ];

    installPhase = ''
      runHook preInstall

      install -Dm755 waifu2x-ncnn-vulkan "$out/bin/waifu2x-ncnn-vulkan"

      mkdir -p "$out/share/waifu2x-ncnn-vulkan"
      cp -a ../../models/models-* "$out/share/waifu2x-ncnn-vulkan/"
      test -d "$out/share/waifu2x-ncnn-vulkan/models-cunet"

      runHook postInstall
    '';

    # 번들 ncnn도 libvulkan을 dlopen()으로 찾는다. 수축된 RPATH 뒤에 로더 경로를 붙인다.
    postFixup = ''
      patchelf --add-rpath ${pkgs.vulkan-loader}/lib "$out/bin/waifu2x-ncnn-vulkan"
    '';

    meta = meta // {
      platforms = [ "aarch64-linux" ];
    };
  };
in
if pkgs.stdenv.hostPlatform.isx86_64 then prebuilt else fromSource
