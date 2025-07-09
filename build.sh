#!/bin/bash
set -e

# Light Color definitions
readonly COLOR_LIGHT_RED='\033[1;31m'
readonly COLOR_LIGHT_GREEN='\033[1;32m'
readonly COLOR_LIGHT_YELLOW='\033[1;33m'
readonly COLOR_LIGHT_BLUE='\033[1;34m'
readonly COLOR_LIGHT_MAGENTA='\033[1;35m'
readonly COLOR_LIGHT_CYAN='\033[1;36m'
readonly COLOR_LIGHT_GRAY='\033[0;37m'
readonly COLOR_DARK_GRAY='\033[1;30m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_LIGHT_ORANGE='\033[1;91m'
readonly COLOR_RESET='\033[0m'

# Default values
readonly DEFAULT_SOURCE_DIR="$(pwd)"
readonly DEFAULT_RESULT_DIR="${DEFAULT_SOURCE_DIR}/build"
readonly DEFAULT_BUILD_CONFIG="${DEFAULT_SOURCE_DIR}/build.config.sh"
readonly DEFAULT_BUILDMODE="default"
readonly DEFAULT_CROSS_COMPILER_DIR="$(dirname $(mktemp -u))/go-cross-compiler"
readonly DEFAULT_CGO_FLAGS="-O2 -g0 -pipe"
readonly DEFAULT_CGO_LDFLAGS="-s"
readonly DEFAULT_LDFLAGS="-s -w -linkmode auto"
readonly DEFAULT_EXT_LDFLAGS=""
readonly DEFAULT_CGO_DEPS_VERSION="v0.5.12"
readonly DEFAULT_TTY_WIDTH="40"
readonly DEFAULT_NDK_VERSION="r27"

# Go environment variables
readonly GOHOSTOS="$(go env GOHOSTOS)"
readonly GOHOSTARCH="$(go env GOHOSTARCH)"
readonly GOHOSTPLATFORM="${GOHOSTOS}/${GOHOSTARCH}"
readonly GOVERSION="$(go env GOVERSION | sed 's/^go//')" # e.g 1.23.1
readonly GODISTLIST="$(go tool dist list)"
readonly DEFAULT_CGO_ENABLED="$(go env CGO_ENABLED)"
readonly DEFAULT_CC="$(go env CC)"
readonly DEFAULT_CXX="$(go env CXX)"

# Prints help information about build configuration.
function printBuildConfigHelp() {
    echo -e "${COLOR_LIGHT_ORANGE}You can customize the build configuration using the following functions (defined in ${DEFAULT_BUILD_CONFIG}):${COLOR_RESET}"
    echo -e "  ${COLOR_LIGHT_GREEN}initDep${COLOR_RESET}          - Initialize dependencies"
    echo -e "  ${COLOR_LIGHT_GREEN}initDepTargets${COLOR_RESET}   - Initialize dependency targets"
    echo -e "  ${COLOR_LIGHT_GREEN}parseDepArgs${COLOR_RESET}     - Parse dependency arguments"
    echo -e "  ${COLOR_LIGHT_GREEN}printDepEnvHelp${COLOR_RESET}  - Print dependency environment variable help"
    echo -e "  ${COLOR_LIGHT_GREEN}printDepHelp${COLOR_RESET}     - Print dependency help information"
}

# Prints help information about environment variables.
function printEnvHelp() {
    echo -e "${COLOR_LIGHT_YELLOW}Environment Variables:${COLOR_RESET}"
    echo -e "  ${COLOR_LIGHT_CYAN}BIN_NAME${COLOR_RESET}           - Set the binary name (default: source directory basename)"
    echo -e "  ${COLOR_LIGHT_CYAN}BIN_NAME_NO_SUFFIX${COLOR_RESET} - Do not append the architecture suffix to the binary name"
    echo -e "  ${COLOR_LIGHT_CYAN}BUILD_CONFIG${COLOR_RESET}       - Set the build configuration file (default: ${DEFAULT_BUILD_CONFIG})"
    echo -e "  ${COLOR_LIGHT_CYAN}BUILDMODE${COLOR_RESET}          - Set the build mode (default: ${DEFAULT_BUILDMODE})"
    echo -e "  ${COLOR_LIGHT_CYAN}CGO_ENABLED${COLOR_RESET}        - Enable or disable CGO (default: ${DEFAULT_CGO_ENABLED})"
    echo -e "  ${COLOR_LIGHT_CYAN}CGO_FLAGS${COLOR_RESET}          - Set CGO flags (default: ${DEFAULT_CGO_FLAGS})"
    echo -e "  ${COLOR_LIGHT_CYAN}CGO_LDFLAGS${COLOR_RESET}        - Set CGO linker flags (default: ${DEFAULT_CGO_LDFLAGS})"
    echo -e "  ${COLOR_LIGHT_CYAN}CROSS_COMPILER_DIR${COLOR_RESET} - Set the cross compiler directory (default: ${DEFAULT_CROSS_COMPILER_DIR})"
    echo -e "  ${COLOR_LIGHT_CYAN}ENABLE_MICRO${COLOR_RESET}       - Enable building micro variants"
    echo -e "  ${COLOR_LIGHT_CYAN}GH_PROXY${COLOR_RESET}           - Set the GitHub proxy mirror (e.g., https://mirror.ghproxy.com/)"
    echo -e "  ${COLOR_LIGHT_CYAN}CC${COLOR_RESET}                 - Force set the use of a specific C compiler"
    echo -e "  ${COLOR_LIGHT_CYAN}CXX${COLOR_RESET}                - Force set the use of a specific C++ compiler"
    echo -e "  ${COLOR_LIGHT_CYAN}NDK_VERSION${COLOR_RESET}        - Set the Android NDK version (default: ${DEFAULT_NDK_VERSION})"
    echo -e "  ${COLOR_LIGHT_CYAN}PLATFORM${COLOR_RESET}           - Set the target target(s) (default: host target, supports: all, linux, linux/arm*, ...)"
    echo -e "  ${COLOR_LIGHT_CYAN}RESULT_DIR${COLOR_RESET}         - Set the build result directory (default: ${DEFAULT_RESULT_DIR})"
    echo -e "  ${COLOR_LIGHT_CYAN}SOURCE_DIR${COLOR_RESET}         - Set the source directory (default: ${DEFAULT_SOURCE_DIR})"

    if declare -f printDepEnvHelp >/dev/null; then
        echo -e "${COLOR_LIGHT_GRAY}$(printSeparator)${COLOR_RESET}"
        echo -e "${COLOR_LIGHT_ORANGE}Dependency Environment Variables:${COLOR_RESET}"
        printDepEnvHelp
    fi
}

# Prints help information about command-line arguments.
function printHelp() {
    echo -e "${COLOR_LIGHT_GREEN}Usage:${COLOR_RESET}"
    echo -e "  $(basename "$0") [options]"
    echo -e ""
    echo -e "${COLOR_LIGHT_RED}Options:${COLOR_RESET}"
    echo -e "  ${COLOR_LIGHT_BLUE}--bin-name=<name>${COLOR_RESET}                 - Specify the binary name (default: source directory basename)"
    echo -e "  ${COLOR_LIGHT_BLUE}--bin-name-no-suffix${COLOR_RESET}              - Do not append the architecture suffix to the binary name"
    echo -e "  ${COLOR_LIGHT_BLUE}--buildmode=<mode>${COLOR_RESET}                - Set the build mode (default: ${DEFAULT_BUILDMODE})"
    echo -e "  ${COLOR_LIGHT_BLUE}--cross-compiler-dir=<dir>${COLOR_RESET}        - Specify the cross compiler directory (default: ${DEFAULT_CROSS_COMPILER_DIR})"
    echo -e "  ${COLOR_LIGHT_BLUE}--cgo-enabled${COLOR_RESET}                     - Enable CGO (default: ${DEFAULT_CGO_ENABLED})"
    echo -e "  ${COLOR_LIGHT_BLUE}--cgo-enabled=<value>${COLOR_RESET}             - Set CGO enabled value (default: ${DEFAULT_CGO_ENABLED})"
    echo -e "  ${COLOR_LIGHT_BLUE}-eh, --env-help${COLOR_RESET}                   - Display help information about environment variables"
    echo -e "  ${COLOR_LIGHT_BLUE}--enable-micro${COLOR_RESET}                    - Enable building micro architecture variants"
    echo -e "  ${COLOR_LIGHT_BLUE}--ext-ldflags='<flags>'${COLOR_RESET}           - Set external linker flags (default: \"${DEFAULT_EXT_LDFLAGS}\")"
    echo -e "  ${COLOR_LIGHT_BLUE}--cc=<path>${COLOR_RESET}                       - Force set the use of a specific C compiler"
    echo -e "  ${COLOR_LIGHT_BLUE}--cxx=<path>${COLOR_RESET}                      - Force set the use of a specific C++ compiler"
    echo -e "  ${COLOR_LIGHT_BLUE}--use-default-cc-cxx${COLOR_RESET}              - Use the default C and C++ compilers (${DEFAULT_CC} and ${DEFAULT_CXX})"
    echo -e "  ${COLOR_LIGHT_BLUE}--github-proxy-mirror=<url>${COLOR_RESET}       - Use a GitHub proxy mirror (e.g., https://mirror.ghproxy.com/)"
    echo -e "  ${COLOR_LIGHT_BLUE}-h, --help${COLOR_RESET}                        - Display this help message"
    echo -e "  ${COLOR_LIGHT_BLUE}--ldflags='<flags>'${COLOR_RESET}               - Set linker flags (default: \"${DEFAULT_LDFLAGS}\")"
    echo -e "  ${COLOR_LIGHT_BLUE}--add-go-build-args='<args>'${COLOR_RESET}      - Pass additional arguments to the 'go build' command"
    echo -e "  ${COLOR_LIGHT_BLUE}-race${COLOR_RESET}                             - Enable race detection"
    echo -e "  ${COLOR_LIGHT_BLUE}-a${COLOR_RESET}                                - Force rebuilding of packages that are already up-to-date"
    echo -e "  ${COLOR_LIGHT_BLUE}-n${COLOR_RESET}                                - Print the commands but do not run them"
    echo -e "  ${COLOR_LIGHT_BLUE}-x${COLOR_RESET}                                - Print the commands"
    echo -e "  ${COLOR_LIGHT_BLUE}-v${COLOR_RESET}                                - Print the names of packages as they are compiled"
    echo -e "  ${COLOR_LIGHT_BLUE}-work${COLOR_RESET}                             - Print the name of the temporary work directory and do not delete it when exiting"
    echo -e "  ${COLOR_LIGHT_BLUE}--ndk-version=<version>${COLOR_RESET}           - Specify the Android NDK version (default: ${DEFAULT_NDK_VERSION})"
    echo -e "  ${COLOR_LIGHT_BLUE}-t=<targets>, --targets=<targets>${COLOR_RESET} - Specify target target(s) (default: host target, supports: all, linux, linux/arm*, ...)"
    echo -e "  ${COLOR_LIGHT_BLUE}--result-dir=<dir>${COLOR_RESET}                - Specify the build result directory (default: ${DEFAULT_RESULT_DIR})"
    echo -e "  ${COLOR_LIGHT_BLUE}--show-all-targets${COLOR_RESET}                - Display all supported target targets"
    echo -e "  ${COLOR_LIGHT_BLUE}--tags='<tags>'${COLOR_RESET}                   - Set build tags"

    if declare -f printDepHelp >/dev/null; then
        echo -e "${COLOR_LIGHT_MAGENTA}$(printSeparator)${COLOR_RESET}"
        echo -e "${COLOR_LIGHT_MAGENTA}Dependency Options:${COLOR_RESET}"
        printDepHelp
    fi

    echo -e "${COLOR_DARK_GRAY}$(printSeparator)${COLOR_RESET}"
    printBuildConfigHelp
}

# Sets a variable to a default value if it's not already set.
# Arguments:
#   $1: Variable name.
#   $2: Default value.
function setDefault() {
    local var_name="$1"
    local default_value="$2"
    [[ -z "${!var_name}" ]] && eval "${var_name}=\"${default_value}\"" || true
}

# Appends tags to the TAGS variable.
# Arguments:
#   $1: Tags to append.
function addTags() {
    TAGS="$(echo "$TAGS $@" | sed 's/ //g' | sed 's/"//g' | sed 's/\n//g')"
}

# Appends linker flags to the LDFLAGS variable.
# Arguments:
#   $1: Linker flags to append.
function addLDFLAGS() {
    [[ -n "${1}" ]] && LDFLAGS="${LDFLAGS} ${1}" || true
}

function addExtLDFLAGS() {
    [[ -n "${1}" ]] && EXT_LDFLAGS="${EXT_LDFLAGS} ${1}" || true
}

# Appends build arguments to the BUILD_ARGS variable.
# Arguments:
#   $1: Build arguments to append.
function addBuildArgs() {
    [[ -n "${1}" ]] && BUILD_ARGS="${BUILD_ARGS} ${1}" || true
}

# Fixes and validates command-line arguments and sets default values.
function fixArgs() {
    setDefault "RESULT_DIR" "${SOURCE_DIR}/build"
    echo -e "${COLOR_LIGHT_BLUE}Result directory: ${COLOR_LIGHT_GREEN}${RESULT_DIR}${COLOR_RESET}"

    setDefault "BIN_NAME" "$(basename "${SOURCE_DIR}")"
    echo -e "${COLOR_LIGHT_BLUE}Binary name: ${COLOR_LIGHT_GREEN}${BIN_NAME}${COLOR_RESET}"

    setDefault "CGO_ENABLED" "${DEFAULT_CGO_ENABLED}"
    setDefault "CROSS_COMPILER_DIR" "$DEFAULT_CROSS_COMPILER_DIR"
    setDefault "PLATFORMS" "${GOHOSTPLATFORM}"
    setDefault "BUILDMODE" "${DEFAULT_BUILDMODE}"
    setDefault "LDFLAGS" "${DEFAULT_LDFLAGS}"
    setDefault "EXT_LDFLAGS" "${DEFAULT_EXT_LDFLAGS}"
    setDefault "CGO_DEPS_VERSION" "${DEFAULT_CGO_DEPS_VERSION}"
    setDefault "CGO_FLAGS" "${DEFAULT_CGO_FLAGS}"
    setDefault "CGO_LDFLAGS" "${DEFAULT_CGO_LDFLAGS}"
    setDefault "NDK_VERSION" "${DEFAULT_NDK_VERSION}"
}

# Checks if CGO is enabled.
# Returns:
#   0: CGO is enabled.
#   1: CGO is disabled.
function isCGOEnabled() {
    [[ "${CGO_ENABLED}" == "1" ]]
}

# Downloads a file from a URL and extracts it.
# Arguments:
#   $1: URL of the file to download.
#   $2: Directory to extract the file to.
#   $3: Optional. File type (e.g., "tgz", "zip"). If not provided, it's extracted from the URL.
function downloadAndUnzip() {
    local url="$1"
    local file="$2"
    local type="${3:-$(echo "${url}" | sed 's/.*\.//g')}"

    mkdir -p "${file}" || return $?
    file="$(cd "${file}" && pwd)" || return $?
    if [ "$(ls -A "${file}")" ]; then
        rm -rf "${file}"/* || return $?
    fi
    echo -e "${COLOR_LIGHT_BLUE}Downloading ${COLOR_LIGHT_CYAN}\"${url}\"${COLOR_LIGHT_BLUE} to ${COLOR_LIGHT_CYAN}\"${file}\"${COLOR_RESET}"

    local start_time=$(date +%s)

    case "${type}" in
    "tgz" | "gz")
        curl -sL "${url}" | tar -xf - -C "${file}" --strip-components 1 -z || return $?
        ;;
    "bz2")
        curl -sL "${url}" | tar -xf - -C "${file}" --strip-components 1 -j || return $?
        ;;
    "xz")
        curl -sL "${url}" | tar -xf - -C "${file}" --strip-components 1 -J || return $?
        ;;
    "lzma")
        curl -sL "${url}" | tar -xf - -C "${file}" --strip-components 1 --lzma || return $?
        ;;
    "zip")
        curl -sL "${url}" -o "${file}/tmp.zip" || return $?
        unzip -q -o "${file}/tmp.zip" -d "${file}" || return $?
        rm -f "${file}/tmp.zip" || return $?
        ;;
    *)
        echo -e "${COLOR_LIGHT_RED}Unsupported compression type: ${type}${COLOR_RESET}"
        return 2
        ;;
    esac

    local end_time=$(date +%s)
    echo -e "${COLOR_LIGHT_GREEN}Download and extraction successful (took $((end_time - start_time))s)${COLOR_RESET}"
}

# Removes duplicate targets from a comma-separated list.
# Arguments:
#   $1: Comma-separated list of targets.
# Returns:
#   Comma-separated list of targets with duplicates removed.
function removeDuplicateTargets() {
    local all_targets="$1"
    all_targets="$(echo "${all_targets}" | tr ', ' '\n' | sort | uniq | paste -s -d ',' -)"
    all_targets="${all_targets#,}"
    all_targets="${all_targets%,}"
    echo "${all_targets}"
}

# Adds targets to the allowed targets list.
# Arguments:
#   $1: Comma-separated list of targets to add.
function addAllowedTargets() {
    ALLOWED_PLATFORMS=$(removeDuplicateTargets "$ALLOWED_PLATFORMS,$1")
}

# Removes targets from the allowed targets list.
# Arguments:
#   $1: Comma-separated list of targets to remove.
function deleteAllowedTargets() {
    ALLOWED_PLATFORMS=$(echo "${ALLOWED_PLATFORMS}" | sed "s|${1}$||g" | sed "s|${1},||g")
}

# Clears the allowed targets list.
function clearAllowedTargets() {
    ALLOWED_PLATFORMS=""
}

# Initializes the targets based on environment variables and allowed targets.
# go tool dist list
function initTargets() {
    addAllowedTargets "$GODISTLIST"
}

# Checks if a target is allowed.
# Arguments:
#   $1: Target target to check.
#   $2: Optional. List of allowed targets. If not provided, ALLOWED_PLATFORMS is used.
# Returns:
#   0: Target is allowed.
#   1: Target is not allowed.
function checkTarget() {
    local target_target="$1"

    if [[ "${ALLOWED_PLATFORMS}" =~ (^|,)${target_target}($|,) ]]; then
        return 0
    else
        return 1
    fi
}

# Checks if a list of targets are allowed.
# Arguments:
#   $1: Comma-separated list of targets to check.
# Returns:
#   0: All targets are allowed.
#   1: At least one target is not allowed.
#   3: Error checking targets.
function checkTargets() {
    for target in ${1//,/ }; do
        case $(
            checkTarget "${target}"
            echo $?
        ) in
        0)
            continue
            ;;
        1)
            echo -e "${COLOR_LIGHT_RED}Target not supported: ${target}${COLOR_RESET}"
            return 1
            ;;
        *)
            echo -e "${COLOR_LIGHT_RED}Error checking target: ${target}${COLOR_RESET}"
            return 3
            ;;
        esac
    done
    return 0
}

function resetCGO() {
    _CC=""
    _CXX=""
    MORE_CGO_CFLAGS=""
    MORE_CGO_CXXFLAGS=""
    MORE_CGO_LDFLAGS=""

    EXTRA_PATH=""
}

# Initializes CGO dependencies based on the target operating system and architecture.
# Arguments:
#   $1: Target operating system (GOOS).
#   $2: Target architecture (GOARCH).
#   $3: Optional. Micro architecture variant.
# Returns:
#   0: CGO dependencies initialized successfully.
#   1: CGO disabled.
#   2: Error initializing CGO dependencies.
function initCGODeps() {
    resetCGO
    local goos="$1"
    local goarch="$2"
    local micro="$3"

    local cc_var="CC_FOR_${goos}_${goarch}"
    local cxx_var="CXX_FOR_${goos}_${goarch}"
    local _CC=${CC_FOR_TARGET}
    local _CXX=${CXX_FOR_TARGET}

    if [[ -n "${_CC}" ]] && [[ -n "${_CXX}" ]]; then
        _CC=${CC_FOR_TARGET}
        _CXX=${CXX_FOR_TARGET}
    fi

    if [[ -n "${_CC}" ]] && [[ -n "${_CXX}" ]]; then
        _CC="${_CC}"
        _CXX="${_CXX}"
        absCCCXX || return $?
        return 0
    fi

    if [[ -n "${CC}" ]] && [[ -n "${CXX}" ]]; then
        _CC="${CC}"
        _CXX="${CXX}"
        absCCCXX || return $?
        return 0
    elif [[ -n "${CC}" ]] || [[ -n "${CXX}" ]]; then
        echo -e "${COLOR_LIGHT_RED}Both CC and CXX must be set at the same time.${COLOR_RESET}"
        return 2
    fi

    initDefaultCGODeps "$@" || return $?

    PATH=${EXTRA_PATH:+$EXTRA_PATH:}$PATH absCCCXX || return $?

    return 0
}

function absCCCXX() {
    local cc_command cc_options
    read -r cc_command cc_options <<<"${_CC}"
    _CC="$(command -v "${cc_command}")" || return 2
    [[ -n "${cc_options}" ]] && _CC="${_CC} ${cc_options}"

    local cxx_command cxx_options
    read -r cxx_command cxx_options <<<"${_CXX}"
    _CXX="$(command -v "${cxx_command}")" || return 2
    [[ -n "${cxx_options}" ]] && _CXX="${_CXX} ${cxx_options}"

    return 0
}

# Initializes CGO dependencies for the host target.
function initHostCGODeps() {
    _CC="${HOST_CC}"
    _CXX="${HOST_CXX}"
}

# Initializes default CGO dependencies based on the target operating system, architecture, and micro architecture.
# Arguments:
#   $1: Target operating system (GOOS).
#   $2: Target architecture (GOARCH).
#   $3: Optional. Micro architecture variant.
function initDefaultCGODeps() {
    local goos="$1"
    local goarch="$2"
    local micro="$3"
    local unamespacer="${GOHOSTOS}-${GOHOSTARCH}"
    [[ "${GOHOSTARCH}" == "arm" ]] && unamespacer="${GOHOSTOS}-arm32v7"

    case "${goos}" in
    "linux")
        case "${GOHOSTOS}" in
        "linux" | "darwin") ;;
        *)
            if [[ "${goos}" == "${GOHOSTOS}" ]] && [[ "${goarch}" == "${GOHOSTARCH}" ]]; then
                initHostCGODeps "$@"
                return 0
            else
                echo -e "${COLOR_LIGHT_YELLOW}CGO is disabled for ${goos}/${goarch}${micro:+"/$micro"}.${COLOR_RESET}"
                return 1
            fi
            ;;
        esac

        case "${GOHOSTARCH}" in
        "amd64" | "arm64" | "arm" | "ppc64le" | "riscv64" | "s390x") ;;
        *)
            if [[ "${goos}" == "${GOHOSTOS}" ]] && [[ "${goarch}" == "${GOHOSTARCH}" ]]; then
                initHostCGODeps "$@"
                return 0
            else
                echo -e "${COLOR_LIGHT_YELLOW}CGO is disabled for ${goos}/${goarch}${micro:+"/$micro"}.${COLOR_RESET}"
                return 1
            fi
            ;;
        esac

        case "${micro}" in
        "hardfloat")
            micro="hf"
            ;;
        "softfloat")
            micro="sf"
            ;;
        esac
        case "${goarch}" in
        "386")
            initLinuxCGO "i686" "" || return $?
            ;;
        "amd64")
            initLinuxCGO "x86_64" "" || return $?
            ;;
        "arm")
            if [[ -z "${micro}" ]]; then
                initLinuxCGO "armv6" "eabihf" || return $?
            elif [[ "${micro}" =~ ^5 ]]; then
                initLinuxCGO "armv${micro%,*}" "eabi" || return $?
            else
                if [[ "${micro}" =~ ,softfloat$ ]]; then
                    initLinuxCGO "armv${micro%,*}" "eabi" || return $?
                else
                    initLinuxCGO "armv${micro%,*}" "eabihf" || return $?
                fi
            fi
            ;;
        "arm64")
            initLinuxCGO "aarch64" "" || return $?
            ;;
        "mips")
            [[ "${micro}" == "hf" ]] && micro="" || micro="sf"
            initLinuxCGO "mips" "" "${micro}" || return $?
            ;;
        "mipsle")
            [[ "${micro}" == "hf" ]] && micro="" || micro="sf"
            initLinuxCGO "mipsel" "" "${micro}" || return $?
            ;;
        "mips64")
            [[ "${micro}" == "hf" ]] && micro="" || micro="sf"
            initLinuxCGO "mips64" "" "${micro}" || return $?
            ;;
        "mips64le")
            [[ "${micro}" == "hf" ]] && micro="" || micro="sf"
            initLinuxCGO "mips64el" "" "${micro}" || return $?
            ;;
        "ppc64")
            # initLinuxCGO "powerpc64" ""
            echo -e "${COLOR_LIGHT_YELLOW}CGO is disabled for ${goos}/${goarch}${micro:+"/$micro"}.${COLOR_RESET}"
            return 1
            ;;
        "ppc64le")
            initLinuxCGO "powerpc64le" "" || return $?
            ;;
        "riscv64")
            initLinuxCGO "riscv64" "" || return $?
            ;;
        "s390x")
            initLinuxCGO "s390x" "" || return $?
            ;;
        "loong64")
            initLinuxCGO "loongarch64" "" || return $?
            ;;
        *)
            if [[ "${goos}" == "${GOHOSTOS}" ]] && [[ "${goarch}" == "${GOHOSTARCH}" ]]; then
                initHostCGODeps "$@" || return $?
            else
                echo -e "${COLOR_LIGHT_YELLOW}CGO is disabled for ${goos}/${goarch}${micro:+"/$micro"}.${COLOR_RESET}"
                return 1
            fi
            ;;
        esac
        ;;
    "windows")
        case "${GOHOSTOS}" in
        "linux" | "darwin") ;;
        *)
            if [[ "${goos}" == "${GOHOSTOS}" ]] && [[ "${goarch}" == "${GOHOSTARCH}" ]]; then
                initHostCGODeps "$@" || return $?
                return 0
            else
                echo -e "${COLOR_LIGHT_YELLOW}CGO is disabled for ${goos}/${goarch}${micro:+"/$micro"}.${COLOR_RESET}"
                return 1
            fi
            ;;
        esac

        case "${GOHOSTARCH}" in
        "amd64" | "arm64" | "arm" | "ppc64le" | "riscv64" | "s390x") ;;
        *)
            if [[ "${goos}" == "${GOHOSTOS}" ]] && [[ "${goarch}" == "${GOHOSTARCH}" ]]; then
                initHostCGODeps "$@" || return $?
                return 0
            else
                echo -e "${COLOR_LIGHT_YELLOW}CGO is disabled for ${goos}/${goarch}${micro:+"/$micro"}.${COLOR_RESET}"
                return 1
            fi
            ;;
        esac

        case "${goarch}" in
        "386")
            initWindowsCGO "i686" || return $?
            ;;
        "amd64")
            initWindowsCGO "x86_64" || return $?
            ;;
        *)
            if [[ "${goos}" == "${GOHOSTOS}" ]] && [[ "${goarch}" == "${GOHOSTARCH}" ]]; then
                initHostCGODeps "$@" || return $?
            else
                echo -e "${COLOR_LIGHT_YELLOW}CGO is disabled for ${goos}/${goarch}${micro:+"/$micro"}.${COLOR_RESET}"
                return 1
            fi
            ;;
        esac
        ;;
    "android")
        case "${GOHOSTOS}" in
        "windows" | "linux")
            [[ "${GOHOSTARCH}" != "amd64" ]] && echo -e "${COLOR_LIGHT_RED}CGO is disabled for android/${goarch}${micro:+"/$micro"}.${COLOR_RESET}" && return 1
            ;;
        "darwin") ;;
        *)
            echo -e "${COLOR_LIGHT_RED}CGO is disabled for android/${goarch}${micro:+"/$micro"}.${COLOR_RESET}" && return 1
            ;;
        esac
        initAndroidNDK "${goarch}" "${micro}" || return $?
        ;;
    "darwin")
        initOsxCGO "${goarch}" "${micro}" || return $?
        ;;
    "ios")
        initIosCGO "${goarch}" "${micro}" || return $?
        ;;
    *)
        if [[ "${goos}" == "${GOHOSTOS}" ]] && [[ "${goarch}" == "${GOHOSTARCH}" ]]; then
            initHostCGODeps "$@" || return $?
        else
            echo -e "${COLOR_LIGHT_YELLOW}CGO is disabled for ${goos}/${goarch}${micro:+"/$micro"}.${COLOR_RESET}"
            return 1
        fi
        ;;
    esac
}

function initIosCGO() {
    local goarch="$1"
    case "${GOHOSTOS}" in
    "darwin")
        case "${goarch}" in
        "amd64")
            if [[ "${APPLE_SIMULATOR}" == "true" ]]; then
                local sdk_path
                sdk_path=$(xcrun -sdk iphonesimulator --show-sdk-path)
                [ $? -ne 0 ] && echo -e "${COLOR_LIGHT_RED}Failed to get iOS simulator SDK path.${COLOR_RESET}" && return 1
                _CC="clang -arch x86_64 -miphonesimulator-version-min=4.2 -isysroot ${sdk_path}"
                _CXX="clang++ -arch x86_64 -miphonesimulator-version-min=4.2 -isysroot ${sdk_path}"
            else
                local sdk_path
                sdk_path=$(xcrun -sdk iphoneos --show-sdk-path)
                [ $? -ne 0 ] && echo -e "${COLOR_LIGHT_RED}Failed to get iOS SDK path.${COLOR_RESET}" && return 1
                _CC="clang -arch x86_64 -miphoneos-version-min=4.2 -isysroot ${sdk_path}"
                _CXX="clang++ -arch x86_64 -miphoneos-version-min=4.2 -isysroot ${sdk_path}"
            fi
            ;;
        "arm64")
            local sdk_path
            if [[ "${APPLE_SIMULATOR}" == "true" ]]; then
                sdk_path=$(xcrun -sdk iphonesimulator --show-sdk-path)
                [ $? -ne 0 ] && echo -e "${COLOR_LIGHT_RED}Failed to get iOS simulator SDK path.${COLOR_RESET}" && return 1
                _CC="clang -arch arm64 -miphonesimulator-version-min=4.2 -isysroot ${sdk_path}"
                _CXX="clang++ -arch arm64 -miphonesimulator-version-min=4.2 -isysroot ${sdk_path}"
            else
                sdk_path=$(xcrun -sdk iphoneos --show-sdk-path)
                [ $? -ne 0 ] && echo -e "${COLOR_LIGHT_RED}Failed to get iOS SDK path.${COLOR_RESET}" && return 1
                _CC="clang -arch arm64 -miphoneos-version-min=4.2 -isysroot ${sdk_path}"
                _CXX="clang++ -arch arm64 -miphoneos-version-min=4.2 -isysroot ${sdk_path}"
            fi
            ;;
        *)
            echo -e "${COLOR_LIGHT_YELLOW}Unknown ios architecture: ${goarch}${COLOR_RESET}"
            return 2
            ;;
        esac
        ;;
    "linux")
        if [[ "${goarch}" != "arm64" ]]; then
            echo -e "${COLOR_LIGHT_YELLOW}Cross compiler not supported for ios/${goarch}.${COLOR_RESET}"
            return 2
        fi
        case "${GOHOSTARCH}" in
        "amd64")
            if [[ "${APPLE_SIMULATOR}" == "true" ]]; then
                if command -v arm64-apple-darwin11-clang >/dev/null 2>&1 && command -v arm64-apple-darwin11-clang++ >/dev/null 2>&1; then
                    _CC="arm64-apple-darwin11-clang"
                    c_CXXxx="arm64-apple-darwin11-clang++"
                elif [[ -x "${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin/arm64-apple-darwin11-clang" ]] && [[ -x "${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin/arm64-apple-darwin11-clang++" ]]; then
                    _CC="${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin/arm64-apple-darwin11-clang"
                    _CXX="${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin/arm64-apple-darwin11-clang++"
                    EXTRA_PATH="${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin"
                    patchelf --set-rpath "${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/lib" \
                        ${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin/arm64-apple-darwin*-ld || return 2
                else
                    local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
                    if [[ "$ubuntu_version" != *"."* ]]; then
                        ubuntu_version="20.04"
                    fi
                    downloadAndUnzip "${GH_PROXY}https://github.com/zijiren233/cctools-port/releases/download/v0.1.4/ioscross-iPhoneSimulator18-5-arm64-linux-x86_64-gnu-ubuntu-${ubuntu_version}.tar.gz" \
                        "${CROSS_COMPILER_DIR}/ioscross-simulator-amd64" || return 2
                    _CC="${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin/arm64-apple-darwin11-clang"
                    _CXX="${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin/arm64-apple-darwin11-clang++"
                    EXTRA_PATH="${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin"
                    patchelf --set-rpath "${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/lib" \
                        ${CROSS_COMPILER_DIR}/ioscross-simulator-amd64/bin/arm64-apple-darwin*-ld || return 2
                fi
            else
                if command -v arm64-apple-darwin11-clang >/dev/null 2>&1 && command -v arm64-apple-darwin11-clang++ >/dev/null 2>&1; then
                    _CC="arm64-apple-darwin11-clang"
                    _CXX="arm64-apple-darwin11-clang++"
                elif [[ -x "${CROSS_COMPILER_DIR}/ioscross-amd64/bin/arm64-apple-darwin11-clang" ]] && [[ -x "${CROSS_COMPILER_DIR}/ioscross-amd64/bin/arm64-apple-darwin11-clang++" ]]; then
                    _CC="${CROSS_COMPILER_DIR}/ioscross-amd64/bin/arm64-apple-darwin11-clang"
                    _CXX="${CROSS_COMPILER_DIR}/ioscross-amd64/bin/arm64-apple-darwin11-clang++"
                    EXTRA_PATH="${CROSS_COMPILER_DIR}/ioscross-amd64/bin"
                    patchelf --set-rpath "${CROSS_COMPILER_DIR}/ioscross-amd64/lib" \
                        ${CROSS_COMPILER_DIR}/ioscross-amd64/bin/arm64-apple-darwin*-ld || return 2
                else
                    local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
                    if [[ "$ubuntu_version" != *"."* ]]; then
                        ubuntu_version="20.04"
                    fi
                    downloadAndUnzip "${GH_PROXY}https://github.com/zijiren233/cctools-port/releases/download/v0.1.4/ioscross-iPhoneOS18-5-arm64-linux-x86_64-gnu-ubuntu-${ubuntu_version}.tar.gz" \
                        "${CROSS_COMPILER_DIR}/ioscross-amd64" || return 2
                    _CC="${CROSS_COMPILER_DIR}/ioscross-amd64/bin/arm64-apple-darwin11-clang"
                    _CXX="${CROSS_COMPILER_DIR}/ioscross-amd64/bin/arm64-apple-darwin11-clang++"
                    EXTRA_PATH="${CROSS_COMPILER_DIR}/ioscross-amd64/bin"
                    patchelf --set-rpath "${CROSS_COMPILER_DIR}/ioscross-amd64/lib" \
                        ${CROSS_COMPILER_DIR}/ioscross-amd64/bin/arm64-apple-darwin*-ld || return 2
                fi
            fi
            ;;
        "arm64")
            if [[ "${APPLE_SIMULATOR}" == "true" ]]; then
                if command -v arm64-apple-darwin11-clang >/dev/null 2>&1 && command -v arm64-apple-darwin11-clang++ >/dev/null 2>&1; then
                    _CC="arm64-apple-darwin11-clang"
                    _CXX="arm64-apple-darwin11-clang++"
                elif [[ -x "${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin/arm64-apple-darwin11-clang" ]] && [[ -x "${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin/arm64-apple-darwin11-clang++" ]]; then
                    _CC="${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin/arm64-apple-darwin11-clang"
                    _CXX="${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin/arm64-apple-darwin11-clang++"
                    EXTRA_PATH="${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin"
                    patchelf --set-rpath "${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/lib" \
                        ${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin/arm64-apple-darwin*-ld || return 2
                else
                    local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
                    if [[ "$ubuntu_version" != *"."* ]]; then
                        ubuntu_version="20.04"
                    fi
                    downloadAndUnzip "${GH_PROXY}https://github.com/zijiren233/cctools-port/releases/download/v0.1.4/ioscross-iPhoneSimulator18-5-arm64-linux-aarch64-gnu-ubuntu-${ubuntu_version}.tar.gz" \
                        "${CROSS_COMPILER_DIR}/ioscross-simulator-arm64" || return 2
                    _CC="${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin/arm64-apple-darwin11-clang"
                    _CXX="${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin/arm64-apple-darwin11-clang++"
                    EXTRA_PATH="${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin"
                    patchelf --set-rpath "${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/lib" \
                        ${CROSS_COMPILER_DIR}/ioscross-simulator-arm64/bin/arm64-apple-darwin*-ld || return 2
                fi
            else
                if command -v arm64-apple-darwin11-clang >/dev/null 2>&1 && command -v arm64-apple-darwin11-clang++ >/dev/null 2>&1; then
                    _CC="arm64-apple-darwin11-clang"
                    _CXX="arm64-apple-darwin11-clang++"
                elif [[ -x "${CROSS_COMPILER_DIR}/ioscross-arm64/bin/arm64-apple-darwin11-clang" ]] && [[ -x "${CROSS_COMPILER_DIR}/ioscross-arm64/bin/arm64-apple-darwin11-clang++" ]]; then
                    _CC="${CROSS_COMPILER_DIR}/ioscross-arm64/bin/arm64-apple-darwin11-clang"
                    _CXX="${CROSS_COMPILER_DIR}/ioscross-arm64/bin/arm64-apple-darwin11-clang++"
                    EXTRA_PATH="${CROSS_COMPILER_DIR}/ioscross-arm64/bin"
                    patchelf --set-rpath "${CROSS_COMPILER_DIR}/ioscross-arm64/lib" \
                        ${CROSS_COMPILER_DIR}/ioscross-arm64/bin/arm64-apple-darwin*-ld || return 2
                else
                    local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
                    if [[ "$ubuntu_version" != *"."* ]]; then
                        ubuntu_version="20.04"
                    fi
                    downloadAndUnzip "${GH_PROXY}https://github.com/zijiren233/cctools-port/releases/download/v0.1.4/ioscross-iPhoneOS18-5-arm64-linux-aarch64-gnu-ubuntu-${ubuntu_version}.tar.gz" \
                        "${CROSS_COMPILER_DIR}/ioscross-arm64" || return 2
                    _CC="${CROSS_COMPILER_DIR}/ioscross-arm64/bin/arm64-apple-darwin11-clang"
                    _CXX="${CROSS_COMPILER_DIR}/ioscross-arm64/bin/arm64-apple-darwin11-clang++"
                    EXTRA_PATH="${CROSS_COMPILER_DIR}/ioscross-arm64/bin"
                    patchelf --set-rpath "${CROSS_COMPILER_DIR}/ioscross-arm64/lib" \
                        ${CROSS_COMPILER_DIR}/ioscross-arm64/bin/arm64-apple-darwin*-ld || return 2
                fi
            fi
            ;;
        *)
            echo -e "${COLOR_LIGHT_YELLOW}Cross compiler not supported for ${GOHOSTOS}/${GOHOSTARCH}.${COLOR_RESET}"
            return 2
            ;;
        esac
        ;;
    *)
        echo -e "${COLOR_LIGHT_YELLOW}Cross compiler not supported for ${GOHOSTOS}/${GOHOSTARCH}.${COLOR_RESET}"
        return 2
        ;;
    esac
}

function initOsxCGO() {
    local goarch="$1"
    case "${GOHOSTOS}" in
    "darwin")
        case "${goarch}" in
        "amd64")
            local sdk_path
            sdk_path=$(xcrun -sdk macosx --show-sdk-path)
            [ $? -ne 0 ] && echo -e "${COLOR_LIGHT_RED}Failed to get macOS SDK path.${COLOR_RESET}" && return 1
            _CC="clang -arch x86_64 -mmacosx-version-min=10.11 -isysroot ${sdk_path}"
            _CXX="clang++ -arch x86_64 -mmacosx-version-min=10.11 -isysroot ${sdk_path}"
            ;;
        "arm64")
            local sdk_path
            sdk_path=$(xcrun -sdk macosx --show-sdk-path)
            [ $? -ne 0 ] && echo -e "${COLOR_LIGHT_RED}Failed to get macOS SDK path.${COLOR_RESET}" && return 1
            _CC="clang -arch arm64 -mmacosx-version-min=10.11 -isysroot ${sdk_path}"
            _CXX="clang++ -arch arm64 -mmacosx-version-min=10.11 -isysroot ${sdk_path}"
            ;;
        *)
            echo -e "${COLOR_LIGHT_YELLOW}Unknown darwin architecture: ${goarch}${COLOR_RESET}"
            return 2
            ;;
        esac
        ;;
    "linux")
        case "${GOHOSTARCH}" in
        "amd64")
            if command -v o64-clang >/dev/null 2>&1 && command -v o64-clang++ >/dev/null 2>&1; then
                _CC="o64-clang"
                _CXX="o64-clang++"
            elif [[ -x "${CROSS_COMPILER_DIR}/osxcross-amd64/bin/o64-clang" ]] && [[ -x "${CROSS_COMPILER_DIR}/osxcross-amd64/bin/o64-clang++" ]]; then
                _CC="${CROSS_COMPILER_DIR}/osxcross-amd64/bin/o64-clang"
                _CXX="${CROSS_COMPILER_DIR}/osxcross-amd64/bin/o64-clang++"
                EXTRA_PATH="${CROSS_COMPILER_DIR}/osxcross-amd64/bin"
                patchelf --set-rpath "${CROSS_COMPILER_DIR}/osxcross-amd64/lib" \
                    ${CROSS_COMPILER_DIR}/osxcross-amd64/bin/x86_64-apple-darwin*-ld || return 2
            else
                local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
                if [[ "$ubuntu_version" != *"."* ]]; then
                    ubuntu_version="20.04"
                fi
                # need install clang to fix:
                # osxcross: warning: cannot find clang intrinsic headers; please report this issue to the OSXCross project
                downloadAndUnzip "${GH_PROXY}https://github.com/zijiren233/osxcross/releases/download/v0.2.0/osxcross-14-5-linux-x86_64-gnu-ubuntu-${ubuntu_version}.tar.gz" \
                    "${CROSS_COMPILER_DIR}/osxcross-amd64" || return 2
                _CC="${CROSS_COMPILER_DIR}/osxcross-amd64/bin/o64-clang"
                _CXX="${CROSS_COMPILER_DIR}/osxcross-amd64/bin/o64-clang++"
                EXTRA_PATH="${CROSS_COMPILER_DIR}/osxcross-amd64/bin"
                patchelf --set-rpath "${CROSS_COMPILER_DIR}/osxcross-amd64/lib" \
                    ${CROSS_COMPILER_DIR}/osxcross-amd64/bin/x86_64-apple-darwin*-ld || return 2
            fi
            ;;
        "arm64")
            if command -v o64-clang >/dev/null 2>&1 && command -v o64-clang++ >/dev/null 2>&1; then
                _CC="o64-clang"
                _CXX="o64-clang++"
            elif [[ -x "${CROSS_COMPILER_DIR}/osxcross-arm64/bin/o64-clang" ]] && [[ -x "${CROSS_COMPILER_DIR}/osxcross-arm64/bin/o64-clang++" ]]; then
                _CC="${CROSS_COMPILER_DIR}/osxcross-arm64/bin/o64-clang"
                _CXX="${CROSS_COMPILER_DIR}/osxcross-arm64/bin/o64-clang++"
                EXTRA_PATH="${CROSS_COMPILER_DIR}/osxcross-arm64/bin"
                patchelf --set-rpath "${CROSS_COMPILER_DIR}/osxcross-arm64/lib" \
                    ${CROSS_COMPILER_DIR}/osxcross-arm64/bin/x86_64-apple-darwin*-ld || return 2
            else
                local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
                if [[ "$ubuntu_version" != *"."* ]]; then
                    ubuntu_version="20.04"
                fi
                # need install clang to fix:
                # osxcross: warning: cannot find clang intrinsic headers; please report this issue to the OSXCross project
                downloadAndUnzip "${GH_PROXY}https://github.com/zijiren233/osxcross/releases/download/v0.2.0/osxcross-14-5-linux-aarch64-gnu-ubuntu-${ubuntu_version}.tar.gz" \
                    "${CROSS_COMPILER_DIR}/osxcross-arm64" || return 2
                _CC="${CROSS_COMPILER_DIR}/osxcross-arm64/bin/o64-clang"
                _CXX="${CROSS_COMPILER_DIR}/osxcross-arm64/bin/o64-clang++"
                EXTRA_PATH="${CROSS_COMPILER_DIR}/osxcross-arm64/bin"
                patchelf --set-rpath "${CROSS_COMPILER_DIR}/osxcross-arm64/lib" \
                    ${CROSS_COMPILER_DIR}/osxcross-arm64/bin/x86_64-apple-darwin*-ld || return 2
            fi
            ;;
        *)
            echo -e "${COLOR_LIGHT_YELLOW}Cross compiler not supported for ${GOHOSTOS}/${GOHOSTARCH}.${COLOR_RESET}"
            return 2
            ;;
        esac
        ;;
    *)
        echo -e "${COLOR_LIGHT_YELLOW}Cross compiler not supported for ${GOHOSTOS}/${GOHOSTARCH}.${COLOR_RESET}"
        return 2
        ;;
    esac
}

# Initializes CGO dependencies for Linux.
# Arguments:
#   $1: Architecture prefix (e.g., "i686", "x86_64").
#   $2: Optional. ABI (e.g., "eabi", "eabihf").
#   $3: Optional. Micro architecture variant.
function initLinuxCGO() {
    local arch_prefix="$1"
    local abi="$2"
    local micro="$3"
    local cross_compiler_name="${arch_prefix}-linux-musl${abi}${micro}-cross"
    if command -v "${arch_prefix}-linux-musl${abi}${micro}-gcc" >/dev/null 2>&1 &&
        command -v "${arch_prefix}-linux-musl${abi}${micro}-g++" >/dev/null 2>&1; then
        _CC="${arch_prefix}-linux-musl${abi}${micro}-gcc -static --static"
        _CXX="${arch_prefix}-linux-musl${abi}${micro}-g++ -static --static"
    elif [[ -x "${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-linux-musl${abi}${micro}-gcc" ]] &&
        [[ -x "${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-linux-musl${abi}${micro}-g++" ]]; then
        _CC="${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-linux-musl${abi}${micro}-gcc -static --static"
        _CXX="${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-linux-musl${abi}${micro}-g++ -static --static"
    else
        downloadAndUnzip "${GH_PROXY}https://github.com/zijiren233/musl-cross-make/releases/download/${CGO_DEPS_VERSION}/${cross_compiler_name}-${unamespacer}.tgz" \
            "${CROSS_COMPILER_DIR}/${cross_compiler_name}" || return 2
        _CC="${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-linux-musl${abi}${micro}-gcc -static --static"
        _CXX="${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-linux-musl${abi}${micro}-g++ -static --static"
    fi
}

# Initializes CGO dependencies for Windows.
# Arguments:
#   $1: Architecture prefix (e.g., "i686", "x86_64").
function initWindowsCGO() {
    local arch_prefix="$1"
    local cross_compiler_name="${arch_prefix}-w64-mingw32-cross"
    if command -v "${arch_prefix}-w64-mingw32-gcc" >/dev/null 2>&1 &&
        command -v "${arch_prefix}-w64-mingw32-g++" >/dev/null 2>&1; then
        _CC="${arch_prefix}-w64-mingw32-gcc -static --static"
        _CXX="${arch_prefix}-w64-mingw32-g++ -static --static"
    elif [[ -x "${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-w64-mingw32-gcc" ]] &&
        [[ -x "${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-w64-mingw32-g++" ]]; then
        _CC="${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-w64-mingw32-gcc -static --static"
        _CXX="${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-w64-mingw32-g++ -static --static"
    else
        downloadAndUnzip "${GH_PROXY}https://github.com/zijiren233/musl-cross-make/releases/download/${CGO_DEPS_VERSION}/${cross_compiler_name}-${unamespacer}.tgz" \
            "${CROSS_COMPILER_DIR}/${cross_compiler_name}" || return 2
        _CC="${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-w64-mingw32-gcc -static --static"
        _CXX="${CROSS_COMPILER_DIR}/${cross_compiler_name}/bin/${arch_prefix}-w64-mingw32-g++ -static --static"
    fi
}

# Initializes CGO dependencies for Android NDK.
# Arguments:
#   $1: Target architecture (GOARCH).
function initAndroidNDK() {
    local goarch="$1"

    local ndk_dir="${CROSS_COMPILER_DIR}/android-ndk-${GOHOSTOS}-${NDK_VERSION}"
    local clang_base_dir="${ndk_dir}/toolchains/llvm/prebuilt/${GOHOSTOS}-x86_64/bin"
    local clang_prefix="$(getAndroidClang "${goarch}")"
    local _CC="${clang_base_dir}/${clang_prefix}-clang"
    local _CXX="${clang_base_dir}/${clang_prefix}-clang++"

    if [[ ! -d "${ndk_dir}" ]]; then
        local ndk_url="https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-${GOHOSTOS}.zip"
        downloadAndUnzip "${ndk_url}" "${ndk_dir}" "zip" || return 2
        mv "$ndk_dir/android-ndk-${NDK_VERSION}/"* "$ndk_dir"
        rmdir "$ndk_dir/android-ndk-${NDK_VERSION}" || return 2
    fi

    if [[ ! -x "${_CC}" ]] || [[ ! -x "${_CXX}" ]]; then
        echo -e "${COLOR_LIGHT_RED}Android NDK not found or invalid. Please check the NDK_VERSION environment variable.${COLOR_RESET}"
        return 2
    fi
}

# Gets the Clang host prefix for Android NDK.
# Arguments:
#   $1: Target architecture (GOARCH).
# Returns:
#   The Clang host prefix.
function getAndroidClang() {
    local API="${API:-24}"
    case ${1} in
    arm)
        echo "armv7a-linux-androideabi${API}"
        ;;
    arm64)
        echo "aarch64-linux-android${API}"
        ;;
    386)
        echo "i686-linux-android${API}"
        ;;
    amd64)
        echo "x86_64-linux-android${API}"
        ;;
    esac
}

# Gets a separator line based on the terminal width.
# Returns:
#   A string of "-" characters with the length of the terminal width.
function printSeparator() {
    local width=$(tput cols 2>/dev/null || echo $DEFAULT_TTY_WIDTH)
    printf '%*s\n' "$width" '' | tr ' ' -
}

function compareVersions() {
    if [[ $1 == $2 ]]; then
        return 0
    fi

    local IFS=.
    local i ver1=($1) ver2=($2)

    # Fill empty fields in ver1 with zeros
    for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
        ver1[i]=0
    done

    # Fill empty fields in ver2 with zeros
    for ((i = ${#ver2[@]}; i < ${#ver1[@]}; i++)); do
        ver2[i]=0
    done

    for ((i = 0; i < ${#ver1[@]}; i++)); do
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done

    return 0
}

function versionGreaterThan() {
    if [[ $(compareVersions "${GOVERSION}" "$1") -eq 1 ]]; then
        return 0
    fi
    return 1
}

function versionLessThan() {
    if [[ $(compareVersions "${GOVERSION}" "$1") -eq 2 ]]; then
        return 0
    fi
    return 1
}

function versionEqual() {
    if [[ $(compareVersions "${GOVERSION}" "$1") -eq 0 ]]; then
        return 0
    fi
    return 1
}

function microDisabled() {
    local micro="$(echo "$1" | tr '[:lower:]' '[:upper:]')"
    local var="MICRO_${micro}_DISABLED"
    if [[ -n "${micro}" ]] && [[ -n "${!var}" ]]; then
        return 0
    fi
    return 1
}

function submicroDisabled() {
    local micro="$(echo "$1" | tr '[:lower:]' '[:upper:]')"
    local var="SUBMICRO_${micro}_DISABLED"
    if [[ -n "${micro}" ]] && [[ -n "${!var}" ]]; then
        return 0
    fi
    return 1
}

# Builds a target for a specific target and micro architecture variant.
# Arguments:
#   $1: Target target (e.g., "linux/amd64").
#   $2: Target name (e.g., binary name).
# Ref:
# https://go.dev/wiki/MinimumRequirements#microarchitecture-support
# https://go.dev/doc/install/source#environment
function buildTarget() {
    local target="$1"

    local goos="${target%/*}"
    local goarch="${target#*/}"

    echo -e "${COLOR_LIGHT_GRAY}$(printSeparator)${COLOR_RESET}"

    cleanBuildCache

    buildTargetWithMicro "${goos}" "${goarch}" ""

    if [ -z "${ENABLE_MICRO}" ]; then
        return 0
    fi
    if microDisabled "${goarch}"; then
        return 0
    fi

    # Build micro architecture variants based on the target architecture.
    case "${goarch%%-*}" in
    "386")
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "sse2"
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "softfloat"
        ;;
    "arm")
        for v in {5..7}; do
            echo
            buildTargetWithMicro "${goos}" "${goarch}" "$v"
            if submicroDisabled "arm"; then
                continue
            fi
            if versionLessThan "${GOVERSION}" "1.22"; then
                continue
            fi
            echo
            buildTargetWithMicro "${goos}" "${goarch}" "$v,softfloat"
            echo
            buildTargetWithMicro "${goos}" "${goarch}" "$v,hardfloat"
        done
        ;;
    "arm64")
        if versionLessThan "${GOVERSION}" "1.23"; then
            return 0
        fi
        for major in 8 9; do
            for minor in $(seq 0 $((major == 8 ? 9 : 5))); do
                echo
                buildTargetWithMicro "${goos}" "${goarch}" "v${major}.${minor}"
                if submicroDisabled "arm64"; then
                    continue
                fi
                echo
                buildTargetWithMicro "${goos}" "${goarch}" "v${major}.${minor},lse"
                echo
                buildTargetWithMicro "${goos}" "${goarch}" "v${major}.${minor},crypto"
            done
        done
        ;;
    "amd64")
        if versionLessThan "${GOVERSION}" "1.18"; then
            return 0
        fi
        for v in {1..4}; do
            echo
            buildTargetWithMicro "${goos}" "${goarch}" "v$v"
        done
        ;;
    "mips" | "mipsle")
        if versionLessThan "${GOVERSION}" "1.10"; then
            return 0
        fi
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "hardfloat"
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "softfloat"
        ;;
    "mips64" | "mips64le")
        if versionLessThan "${GOVERSION}" "1.11"; then
            return 0
        fi
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "hardfloat"
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "softfloat"
        ;;
    "ppc64" | "ppc64le")
        for version in 8 9 10; do
            echo
            buildTargetWithMicro "${goos}" "${goarch}" "power${version}"
        done
        ;;
    "wasm")
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "satconv"
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "signext"
        ;;
    "riscv64")
        if versionLessThan "${GOVERSION}" "1.23"; then
            return 0
        fi
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "rva20u64"
        echo
        buildTargetWithMicro "${goos}" "${goarch}" "rva22u64"
        ;;
    esac
}

# Gets the extension based on the build mode and operating system.
# Arguments:
#   $1: Operating system (e.g., "linux", "windows", "darwin", "ios").
#   $2: Build mode (e.g., "archive", "shared", "default").
# Returns:
#   The extension string.
function extension() {
    local goos="$1"
    local buildmode="$2"
    if [ "$buildmode" == "archive" ] || [ "$buildmode" == "c-archive" ]; then
        if [ "$goos" == "windows" ]; then
            echo ".lib"
        else
            echo ".a"
        fi
    elif [ "$buildmode" == "shared" ] || [ "$buildmode" == "c-shared" ]; then
        if [ "$goos" == "windows" ]; then
            echo ".dll"
        elif [ "$goos" == "darwin" ] || [ "$goos" == "ios" ]; then
            echo ".dylib"
        else
            echo ".so"
        fi
    else
        if [ "$goos" == "windows" ]; then
            echo ".exe"
        fi
    fi
}

function cleanBuildCache() {
    go clean -cache
}

# Builds a target for a specific target, micro architecture variant, and build environment.
# Arguments:
#   $1: GOOS
#   $2: GOARCH
#   $3: Micro architecture variant (e.g., "sse2", "softfloat"). Ref: https://go.dev/wiki/MinimumRequirements#microarchitecture-support
#   $4: CGO enabled (0 or 1)
function buildTargetWithMicro() {
    local goos="$1"
    local goarch="$2"
    local micro="$3"

    local build_env=(
        "GOOS=${goos}"
        "GOARCH=${goarch}"
    )
    local buildmode=$BUILDMODE
    local ext=$(extension "${goos}" "${buildmode}")
    local target_file="${RESULT_DIR}/${BIN_NAME}"
    [ -z "$BIN_NAME_NO_SUFFIX" ] && target_file="${target_file}-${goos}-${goarch}${micro:+"-${micro//[.,]/-}"}" || true
    target_file="${target_file}${ext}"

    # Set micro architecture specific environment variables.
    case "${goarch}" in
    "386")
        build_env+=("GO386=${micro}")
        [ -z "$micro" ] && micro="sse2"
        ;;
    "arm")
        build_env+=("GOARM=${micro}")
        [ -z "$micro" ] && micro="6"
        ;;
    "arm64")
        build_env+=("GOARM64=${micro}")
        [ -z "$micro" ] && micro="v8.0"
        ;;
    "amd64")
        build_env+=("GOAMD64=${micro}")
        ;;
    "mips" | "mipsle")
        build_env+=("GOMIPS=${micro}")
        [ -z "$micro" ] && micro="hardfloat"
        ;;
    "mips64" | "mips64le")
        build_env+=("GOMIPS64=${micro}")
        [ -z "$micro" ] && micro="hardfloat"
        ;;
    "ppc64" | "ppc64le")
        build_env+=("GOPPC64=${micro}")
        ;;
    "wasm")
        build_env+=("GOWASM=${micro}")
        ;;
    "riscv64")
        build_env+=("GORISCV64=${micro}")
        [ -z "$micro" ] && micro="rva20u64"
        ;;
    esac

    echo -e "${COLOR_LIGHT_MAGENTA}Building ${goos}/${goarch}${micro:+/${micro}}...${COLOR_RESET}"

    if isCGOEnabled; then
        if initCGODeps "${goos}" "${goarch}" "${micro}"; then
            code=0
        else
            code=$?
        fi

        build_env+=("PATH=${EXTRA_PATH:+$EXTRA_PATH:}$PATH")

        case "$code" in
        0)
            build_env+=("CGO_ENABLED=1")
            build_env+=("CC=${_CC}")
            build_env+=("CXX=${_CXX}")
            build_env+=("CGO_CFLAGS=${CGO_FLAGS}${MORE_CGO_CFLAGS:+ ${MORE_CGO_CFLAGS}}")
            build_env+=("CGO_CXXFLAGS=${CGO_FLAGS}${MORE_CGO_CXXFLAGS:+ ${MORE_CGO_CXXFLAGS}}")
            build_env+=("CGO_LDFLAGS=${CGO_LDFLAGS}${MORE_CGO_LDFLAGS:+ ${MORE_CGO_LDFLAGS}}")
            ;;
        *)
            echo -e "${COLOR_LIGHT_RED}Error initializing CGO dependencies.${COLOR_RESET}"
            return 1
            ;;
        esac
    else
        build_env+=("CGO_ENABLED=0")
    fi

    local full_ldflags="${LDFLAGS}${EXT_LDFLAGS:+ -extldflags '$EXT_LDFLAGS'}"

    echo -e "${COLOR_LIGHT_BLUE}Run command:${COLOR_RESET}\n$(for var in "${build_env[@]}"; do
        key=$(echo "${var}" | cut -d= -f1)
        value=$(echo "${var}" | cut -d= -f2-)
        echo -e "${COLOR_LIGHT_GREEN}export${COLOR_RESET} ${COLOR_WHITE}${key}='${value}'${COLOR_RESET}"
    done)\n${COLOR_LIGHT_CYAN}go build -buildmode=$buildmode -trimpath ${BUILD_ARGS} -tags \"${TAGS}\" -ldflags \"${full_ldflags}\" -o \"${target_file}\" \"${SOURCE_DIR}\"${COLOR_RESET}"
    local start_time=$(date +%s)

    # reset CC_FOR_TARGET and CC_FOR_${goos}_${goarch}, because it will be set by initCGODeps to CC and CXX environment variables
    build_env+=("CC_FOR_TARGET=")
    build_env+=("CXX_FOR_TARGET=")
    build_env+=("CC_FOR_${goos}_${goarch}=")
    build_env+=("CXX_FOR_${goos}_${goarch}=")

    env "${build_env[@]}" go build -buildmode=$buildmode -trimpath ${BUILD_ARGS} -tags "${TAGS}" -ldflags "${full_ldflags}" -o "${target_file}" "${SOURCE_DIR}"
    local end_time=$(date +%s)
    echo -e "${COLOR_LIGHT_GREEN}Build successful: ${goos}/${goarch}${micro:+ ${micro}} (took $((end_time - start_time))s, size: $(du -sh "${target_file}" | cut -f1))${COLOR_RESET}"
}

# Expands target patterns (e.g., "linux/*") to a list of supported targets.
# Arguments:
#   $1: Comma-separated list of targets, potentially containing patterns.
# Returns:
#   Comma-separated list of expanded targets.
function expandTargets() {
    local targets="$1"
    IFS=, read -r -a targets <<<"${targets}"
    local expanded_targets=""
    for target in "${targets[@]}"; do
        if [[ "${target}" == "all" ]] || [[ "${target}" == '*' ]]; then

            echo "${ALLOWED_PLATFORMS}"
            return 0
        elif [[ "${target}" == *\** ]]; then
            for tmp_var in ${ALLOWED_PLATFORMS//,/ }; do
                [[ "${tmp_var}" == ${target} ]] && expanded_targets="${expanded_targets},${tmp_var}"
            done
        elif [[ "${target}" != */* ]]; then
            expanded_targets="${expanded_targets},$(expandTargets "${target}/*")"
        else
            expanded_targets="${expanded_targets},${target}"
        fi
    done
    removeDuplicateTargets "${expanded_targets}"
}

# Performs the automatic build process for the specified targets.
# Arguments:
#   $1: Comma-separated list of targets to build for.
function autoBuild() {
    local targets=$(expandTargets "$1")
    checkTargets "${targets}" || return 1
    [ -z "${targets}" ] &&
        echo -e "${COLOR_LIGHT_RED}No targets specified.${COLOR_RESET}" &&
        echo -e "${COLOR_LIGHT_RED}Supported targets:${COLOR_RESET} ${COLOR_LIGHT_CYAN}${ALLOWED_PLATFORMS}${COLOR_RESET}" &&
        return 1
    local start_time=$(date +%s)
    if declare -f initDep >/dev/null; then
        initDep
    fi
    local build_num=0
    for target in ${targets//,/ }; do
        buildTarget "${target}" # Ensure the full target with suffix is passed
        build_num=$((build_num + 1))
    done
    local end_time=$(date +%s)
    if [[ "${build_num}" -gt 1 ]]; then
        echo -e "${COLOR_LIGHT_YELLOW}Total took $((end_time - start_time))s${COLOR_RESET}"
    fi
}

# Loads the build configuration file if it exists.
function loadBuildConfig() {
    if [[ -f "${BUILD_CONFIG}" ]]; then
        source "${BUILD_CONFIG}" && return 0
        echo -e "${COLOR_LIGHT_RED}Failed to load build configuration from ${BUILD_CONFIG}${COLOR_RESET}" 1>&2
        exit 1
    else
        echo -e "${COLOR_LIGHT_YELLOW}Skipping config (file not found): ${COLOR_LIGHT_GREEN}${BUILD_CONFIG}${COLOR_RESET}" 1>&2
    fi
}

function printVar() {
    echo -e "${COLOR_LIGHT_BLUE}Working directory: ${COLOR_LIGHT_GREEN}$(pwd)${COLOR_RESET}" 1>&2
    echo -e "${COLOR_LIGHT_BLUE}Source directory: ${COLOR_LIGHT_GREEN}${SOURCE_DIR}${COLOR_RESET}" 1>&2
    echo -e "${COLOR_LIGHT_BLUE}Config file: ${COLOR_LIGHT_GREEN}${BUILD_CONFIG}${COLOR_RESET}" 1>&2
    local allowed_targets="$(echo "${ALLOWED_PLATFORMS}" | sed 's/,/ /g')"
    echo -e "${COLOR_LIGHT_BLUE}Allowed targets: ${COLOR_LIGHT_GREEN}${allowed_targets}${COLOR_RESET}" 1>&2
}

setDefault "SOURCE_DIR" "${DEFAULT_SOURCE_DIR}"
SOURCE_DIR="$(cd "${SOURCE_DIR}" && pwd)"
setDefault "BUILD_CONFIG" "${SOURCE_DIR}/build.config.sh"

initTargets
printVar
loadBuildConfig

# Parse command-line arguments.
while [[ $# -gt 0 ]]; do
    case "${1}" in
    -h | --help)
        printHelp
        exit 0
        ;;
    -eh | --env-help)
        printEnvHelp
        exit 0
        ;;
    --buildmode=*)
        BUILDMODE="${1#*=}"
        ;;
    --bin-name=*)
        BIN_NAME="${1#*=}"
        ;;
    --bin-name-no-suffix)
        BIN_NAME_NO_SUFFIX="true"
        ;;
    --add-go-build-args=*)
        addBuildArgs "${1#*=}"
        ;;
    -race | -a | -v | -x | -n | -work)
        addBuildArgs "-${1#-}"
        ;;
    --enable-micro)
        ENABLE_MICRO="true"
        ;;
    --ldflags=*)
        addLDFLAGS "${1#*=}"
        ;;
    --ext-ldflags=*)
        addExtLDFLAGS "${1#*=}"
        ;;
    -t=* | --targets=*)
        PLATFORMS="${1#*=}"
        ;;
    --cgo-enabled)
        CGO_ENABLED="1"
        ;;
    --cgo-enabled=*)
        value="${1#*=}"
        if [[ "${value}" == "true" ]]; then
            CGO_ENABLED="1"
        elif [[ "${value}" == "false" ]]; then
            CGO_ENABLED="0"
        else
            CGO_ENABLED="${value}"
        fi
        ;;
    --apple-simulator)
        APPLE_SIMULATOR="true"
        ;;
    --result-dir=*)
        RESULT_DIR="${1#*=}"
        ;;
    --tags=*)
        addTags "${1#*=}"
        ;;
    --show-all-targets)
        echo "${ALLOWED_PLATFORMS}"
        exit 0
        ;;
    --show-all-targets=*)
        echo "$(expandTargets "${1#*=}")"
        exit 0
        ;;
    --github-proxy-mirror=*)
        GH_PROXY="${1#*=}"
        ;;
    --cross-compiler-dir=*)
        CROSS_COMPILER_DIR="${1#*=}"
        ;;
    --cc=*)
        CC="${1#*=}"
        ;;
    --cxx=*)
        CXX="${1#*=}"
        ;;
    --use-default-cc-cxx)
        CC="${DEFAULT_CC}"
        CXX="${DEFAULT_CXX}"
        ;;
    --ndk-version=*)
        NDK_VERSION="${1#*=}"
        ;;
    *)
        if declare -f parseDepArgs >/dev/null && parseDepArgs "$1"; then
            shift
            continue
        fi
        echo -e "${COLOR_LIGHT_RED}Invalid option: $1${COLOR_RESET}"
        exit 1
        ;;
    esac
    shift
done

fixArgs
autoBuild "${PLATFORMS}"
