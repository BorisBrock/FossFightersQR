#!/usr/bin/env bash
# Builds the extension for the desktop host and Android into addons/qr_scanner/bin.
# Needs cmake, ninja or make, Python 3 and the Android NDK.
#
#   native/build.sh [linux] [android]        (default: both)
#
# Android builds arm64-v8a only. For the x86_64 emulator, also build that ABI and
# enable it in the export preset: QR_ANDROID_ABIS="arm64-v8a x86_64" native/build.sh android
set -euo pipefail

native_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_root="${QR_BUILD_DIR:-$native_dir/build}"
jobs="$(nproc)"
targets=("${@:-linux android}")
targets=(${targets[*]})

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
find_ndk() {
	if [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then echo "$ANDROID_NDK_ROOT"; return; fi
	ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1
}

extra_args=()
[[ -n "${QR_ZXING_SOURCE:-}" ]] && extra_args+=("-DFETCHCONTENT_SOURCE_DIR_ZXING=$QR_ZXING_SOURCE")
[[ -n "${QR_GODOT_CPP_SOURCE:-}" ]] && extra_args+=("-DFETCHCONTENT_SOURCE_DIR_GODOT-CPP=$QR_GODOT_CPP_SOURCE")

for target in "${targets[@]}"; do
	case "$target" in
		linux)
			cmake -S "$native_dir" -B "$build_root/linux" -DCMAKE_BUILD_TYPE=Release \
				-DQR_PLATFORM_TAG=linux.x86_64 "${extra_args[@]}"
			cmake --build "$build_root/linux" --target qr_scanner -j"$jobs"
			;;
		android)
			ndk="$(find_ndk)"
			[[ -d "$ndk" ]] || { echo "Android NDK not found; set ANDROID_NDK_ROOT." >&2; exit 1; }
			for abi in ${QR_ANDROID_ABIS:-arm64-v8a}; do
				case "$abi" in
					arm64-v8a) tag=android.arm64 ;;
					x86_64) tag=android.x86_64 ;;
					*) echo "Unsupported ABI: $abi" >&2; exit 1 ;;
				esac
				cmake -S "$native_dir" -B "$build_root/$abi" -DCMAKE_BUILD_TYPE=Release \
					-DCMAKE_TOOLCHAIN_FILE="$ndk/build/cmake/android.toolchain.cmake" \
					-DANDROID_ABI="$abi" -DANDROID_PLATFORM=android-24 -DANDROID_STL=c++_static \
					-DQR_PLATFORM_TAG="$tag" "${extra_args[@]}"
				cmake --build "$build_root/$abi" --target qr_scanner -j"$jobs"
			done
			;;
		*)
			echo "Unknown target: $target" >&2
			exit 1
			;;
	esac
done
