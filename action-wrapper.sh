#!/bin/bash
set -e

# Action wrapper script for go-build-action
# This script translates GitHub Actions inputs (via environment variables)
# into command-line arguments for cross.sh

# Build command arguments from environment variables
ARGS=()

# Set CGO_ENABLED based on input
if [ "$CGO_ENABLED" = "true" ]; then
	export CGO_ENABLED=1
elif [ "$CGO_ENABLED" = "false" ]; then
	export CGO_ENABLED=0
fi

# Directory and config options
[ -n "$INPUT_RESULT_DIR" ] && ARGS+=("--result-dir=$INPUT_RESULT_DIR")
[ -n "$INPUT_BUILD_CONFIG" ] && ARGS+=("--build-config=$INPUT_BUILD_CONFIG")

# Build mode and binary options
[ -n "$INPUT_BUILDMODE" ] && ARGS+=("--buildmode=$INPUT_BUILDMODE")
[ -n "$INPUT_BIN_NAME" ] && ARGS+=("--bin-name=$INPUT_BIN_NAME")
[ "$INPUT_BIN_NAME_NO_SUFFIX" = "true" ] && ARGS+=("--bin-name-no-suffix")

# Additional Go build arguments
[ -n "$INPUT_ADD_GO_BUILD_ARGS" ] && ARGS+=("--add-go-build-args=$INPUT_ADD_GO_BUILD_ARGS")

# Target platforms
[ -n "$INPUT_TARGETS" ] && ARGS+=("--targets=$INPUT_TARGETS")

# Compiler options
[ "$INPUT_USE_DEFAULT_CC_CXX" = "true" ] && ARGS+=("--use-default-cc-cxx")
[ -n "$INPUT_CC" ] && ARGS+=("--cc=$INPUT_CC")
[ -n "$INPUT_CXX" ] && ARGS+=("--cxx=$INPUT_CXX")

# CGO flags
[ -n "$INPUT_CGO_FLAGS" ] && ARGS+=("--cgo-flags=$INPUT_CGO_FLAGS")
[ -n "$INPUT_CGO_LDFLAGS" ] && ARGS+=("--cgo-ldflags=$INPUT_CGO_LDFLAGS")

# Linker flags
[ -n "$INPUT_LDFLAGS" ] && ARGS+=("--ldflags=$INPUT_LDFLAGS")
[ -n "$INPUT_EXT_LDFLAGS" ] && ARGS+=("--ext-ldflags=$INPUT_EXT_LDFLAGS")

# Build tags
[ -n "$INPUT_TAGS" ] && ARGS+=("--tags=$INPUT_TAGS")

# Cross-compilation options
[ -n "$INPUT_GITHUB_PROXY_MIRROR" ] && ARGS+=("--github-proxy-mirror=$INPUT_GITHUB_PROXY_MIRROR")
[ -n "$INPUT_CROSS_COMPILER_DIR" ] && ARGS+=("--cross-compiler-dir=$INPUT_CROSS_COMPILER_DIR")
[ -n "$INPUT_NDK_VERSION" ] && ARGS+=("--ndk-version=$INPUT_NDK_VERSION")

# Enable micro architecture variants
[ "$INPUT_ENABLE_MICRO" = "true" ] && ARGS+=("--enable-micro")

# Go build flags
[ "$INPUT_RACE" = "true" ] && ARGS+=("-race")
[ "$INPUT_A" = "true" ] && ARGS+=("-a")
[ "$INPUT_N" = "true" ] && ARGS+=("-n")
[ "$INPUT_X" = "true" ] && ARGS+=("-x")
[ "$INPUT_V" = "true" ] && ARGS+=("-v")
[ "$INPUT_WORK" = "true" ] && ARGS+=("-work")

# Additional config arguments (should be at the end)
[ -n "$INPUT_CONFIG_ARGS" ] && ARGS+=($INPUT_CONFIG_ARGS)

# Execute command
"$ACTION_PATH/cross.sh" "${ARGS[@]}"
