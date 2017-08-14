#!/bin/bash

# This script will compile and install a static ffmpeg build with support for
# nvenc on ubuntu. See the prefix path and compile options if edits are needed
# to suit your needs.

#Authors:
#   Linux GameCast ( http://linuxgamecast.com/ )
#   Mathieu Comandon <strider@strycore.com>

set -e

ShowUsage() {
    echo "Usage: ./build.sh [--dest /path/to/ffmpeg] [--obs] [--help]"
    echo "Options:"
    echo "  -d/--dest: Where to build ffmpeg (Optional, defaults to ./ffmpeg-nvenc)"
    echo "  -h/--help: This help screen"
    exit 0
}

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

params=$(getopt -n $0 -o d:oh --long dest:,obs,help -- "$@")
eval set -- $params
while true ; do
    case "$1" in
        -h|--help) ShowUsage ;;
        -o|--obs) build_obs=1; shift ;;
        -d|--dest) build_dir=$2; shift 2;;
        *) shift; break ;;
    esac
done

cpus=$(getconf _NPROCESSORS_ONLN)
source_dir="${root_dir}/source"
mkdir -p $source_dir
build_dir="${build_dir:-"${root_dir}/ffmpeg-nvenc"}"
mkdir -p $build_dir
bin_dir="${build_dir}/bin"
mkdir -p $bin_dir
inc_dir="${build_dir}/include"
mkdir -p $inc_dir

echo "Building FFmpeg in ${build_dir}"

export PATH=$bin_dir:$PATH

InstallDependencies() {
    echo "Installing dependencies"
    sudo apt-get -y --force-yes install autoconf automake build-essential libass-dev libfreetype6-dev \
          libsdl2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev \
          libxcb-xfixes0-dev pkg-config texinfo wget zlib1g-dev
}

BuildNasm() {
    echo "Compiling nasm"
    cd $source_dir
    nasm_version="2.13.01"
    nasm_basename="nasm-${nasm_version}"
    wget -4 -N http://www.nasm.us/pub/nasm/releasebuilds/${nasm_version}/nasm-${nasm_version}.tar.gz
    tar xzf "${nasm_basename}.tar.gz"
    cd $nasm_basename
    ./configure --prefix="${build_dir}" --bindir="${bin_dir}"
    make -j${cpus}
    make install
}

BuildYasm() {
    echo "Compiling yasm"
    cd $source_dir
    yasm_version="1.3.0"
    yasm_basename="yasm-${yasm_version}"
    wget -4 -N http://www.tortall.net/projects/yasm/releases/${yasm_basename}.tar.gz
    tar xzf "${yasm_basename}.tar.gz"
    cd $yasm_basename
    ./configure --prefix="${build_dir}" --bindir="${bin_dir}"
    make -j${cpus}
    make install
}

BuildX264() {
    echo "Compiling libx264"
    cd $source_dir
    wget -4 -N http://download.videolan.org/pub/x264/snapshots/last_x264.tar.bz2
    tar xjf last_x264.tar.bz2
    cd x264-snapshot*
    ./configure --prefix="$build_dir" --bindir="$bin_dir" --enable-pic --enable-shared
    make -j${cpus}
    make install
}

BuildX265() {
    echo "Compiling libx265"
    cd $source_dir
    x265_version="2.5"
    x265_basename="x265_${x265_version}"
    x265_dlname="${x265_basename}.tar.gz"
    wget -4 -N https://bitbucket.org/multicoreware/x265/downloads/${x265_dlname}
    tar xzf "${x265_dlname}"
    cd ${x265_basename}/build/linux
    cmake -G "Ninja" -DCMAKE_INSTALL_PREFIX="$build_dir" -DENABLE_SHARED:bool=on ../../source    
    ninja
    ninja install
}

BuildFdkAac() {
    echo "Compiling libfdk-aac"
    cd $source_dir
    wget -4 -O fdk-aac.zip https://github.com/mstorsjo/fdk-aac/zipball/master
    unzip fdk-aac.zip
    cd mstorsjo-fdk-aac*
    autoreconf -fiv
    ./configure --prefix="$build_dir" # --disable-shared
    make -j${cpus}
    make install
}

BuildLame() {
    echo "Compiling libmp3lame"
    cd $source_dir
    lame_version="3.99.5"
    lame_basename="lame-${lame_version}"
    wget -4 -N "http://downloads.sourceforge.net/project/lame/lame/3.99/${lame_basename}.tar.gz"
    tar xzf "${lame_basename}.tar.gz"
    cd $lame_basename
    ./configure --prefix="$build_dir" --enable-nasm # --disable-shared
    make -j${cpus}
    make install
}

BuildOpus() {
    echo "Compiling libopus"
    cd $source_dir
    opus_version="1.1"
    opus_basename="opus-${opus_version}"
    wget -4 -N "http://downloads.xiph.org/releases/opus/${opus_basename}.tar.gz"
    tar xzf "${opus_basename}.tar.gz"
    cd $opus_basename
    ./configure --prefix="$build_dir" # --disable-shared
    make -j${cpus}
    make install
}

BuildVpx() {
    echo "Compiling libvpx"
    cd $source_dir
    vpx_version="1.5.0"
    vpx_basename="libvpx-${vpx_version}"
    vpx_url="http://storage.googleapis.com/downloads.webmproject.org/releases/webm/${vpx_basename}.tar.bz2"
    wget -4 -N $vpx_url
    tar xjf "${vpx_basename}.tar.bz2"
    cd $vpx_basename
    ./configure --prefix="$build_dir" --disable-examples --enable-shared --disable-static
    make -j${cpus}
    make install
}

BuildFFmpeg() {
    echo "Compiling ffmpeg"
    cd $source_dir
    ffmpeg_version="3.3"
    wget -4 -N http://ffmpeg.org/releases/ffmpeg-${ffmpeg_version}.tar.bz2
    tar xjf ffmpeg-${ffmpeg_version}.tar.bz2
    cd ffmpeg-${ffmpeg_version}
    PKG_CONFIG_PATH="${build_dir}/lib/pkgconfig" ./configure \
        --prefix="$build_dir" \
        --pkg-config-flags="--static" \
        --extra-cflags="-fPIC -m64 -I${inc_dir}" \
        --extra-ldflags="-L${build_dir}/lib" \
        --bindir="$bin_dir" \
        --enable-gpl \
        --enable-libass \
        --enable-libfdk-aac \
        --enable-libfreetype \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libtheora \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-nonfree \
        --enable-nvenc \
        --disable-static \
        --enable-shared
    make -j${cpus}
    make install
}

CleanAll() {
    rm -rf $source_dir
}

MakeScripts() {
    cd $build_dir
    mkdir -p scripts
    cd scripts
    cat <<EOF > ffmpeg.sh
#!/bin/bash
export LD_LIBRARY_PATH="${build_dir}/lib":\$LD_LIBRARY_PATH
cd "${build_dir}/bin"
./ffmpeg "\$@"
EOF
    chmod +x ffmpeg.sh
}

if [ $1 ]; then
    $1
else
    InstallDependencies
    BuildNasm
    BuildYasm
    BuildX264
    BuildX265
    BuildFdkAac
    BuildLame
    BuildOpus
    BuildVpx
    BuildFFmpeg

    MakeScripts
fi
