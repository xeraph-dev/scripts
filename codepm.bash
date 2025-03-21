#!/usr/bin/env bash

Green="\e[32m"
Yellow="\e[33m"
Blue="\e[34m"
Magenta="\e[35m"
RESET="\e[0m"

TARGET=
API_URL="https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
VERSION="1.0.0"
BASE_PATH="$HOME/.codepm"
PROFILES_PATH="$BASE_PATH/profiles"
CACHE_PATH="$BASE_PATH/cache"
CONFIG_PATH="$BASE_PATH/settings.json"
CATEGORIES=
DEFAULT_BASE_EXTENSIONS=(
    "teabyii.ayu"
    "aaron-bond.better-comments"
    "usernamehw.errorlens"
    "mkxml.vscode-filesize"
    "miguelsolorio.fluent-icons"
    "christian-kohler.path-intellisense"
    "miguelsolorio.symbols"
    "wayou.vscode-todo-highlight"
)
DEFAULT_PROJECT_EXTENSIONS=(
    "mikestead.dotenv"
    "EditorConfig.EditorConfig"
    "ultram4rine.vscode-choosealicense"
    "donjayamanne.githistory"
    "codezombiech.gitignore"
    "eamodio.gitlens"
    "yzhang.markdown-all-in-one"
    "bierner.markdown-mermaid"
    "DavidAnson.vscode-markdownlint"
    "jock.svg"
    "SimonSiefke.svg-preview"
)

usage() {
    echo -e "\
Visual Studio Code Profile Manager $Yellow$VERSION$RESET

Usage: ${Green}codepm$RESET ${Yellow}[options]$RESET ${Yellow}[command]$RESET ${Yellow}[options]$RESET $Magenta<path>$RESET

${Yellow}Commands:$RESET
  ${Blue}n  new$RESET                 Create a new profile
  ${Blue}r remove$RESET               Remove a profile
  ${Blue}l list$RESET                 List all profiles
  ${Blue}s setup$RESET                Set default configuration and cache base extensions
  ${Blue}c category$RESET             Create, update and delete categories
  ${Blue}cc clear-cache$RESET         Clear ${Green}codepm$RESET cache
  ${Blue}ccf clear-cache-full$RESET   Clear full ${Green}codepm$RESET cache
  ${Blue}i install$RESET              Install ${Green}codepm$RESET
  ${Blue}ui uninstall$RESET           Uninstall ${Green}codepm$RESET
  ${Blue}h help$RESET                 Print usage.

${Yellow}Options:$RESET
  -c --category          Category of the profile
  -n --name              Name of the profile
  -v --version           Print version
  -h --help              Print usage.


$(new_usage)


$(remove_usage)


$(list_usage)


$(category_usage)\
"
}

new_usage() {
    echo -e "\
${Blue}new$RESET Usage: ${Green}codepm$RESET ${Blue}new$RESET ${Yellow}[options]$RESET $Magenta<name>$RESET

${Blue}new$RESET ${Yellow}Options:$RESET
  -c --category          Category of the profile
  -e --extend            Profiles to extend, format <category>:<profile>, sep by comma (ex: language:bash,language:zsh)
  -n --no-default        Don't extend default extensions
  -h --help              Print ${Blue}new$RESET usage\
"
}

remove_usage() {
    echo -e "\
${Blue}remove$RESET Usage: ${Green}codepm$RESET ${Blue}remove$RESET ${Yellow}[options]$RESET $Magenta<name>$RESET

${Blue}remove$RESET ${Yellow}Options:$RESET
  -c --category          Category of the profile
  -h --help              Print ${Blue}remove$RESET usage\
"
}

list_usage() {
    echo -e "\
${Blue}list$RESET Usage: ${Green}codepm$RESET ${Blue}list$RESET ${Yellow}[options]$RESET $Magenta<name>$RESET

${Blue}list$RESET ${Yellow}Options:$RESET
  -c --category          Category of the profile
  -h --help              Print ${Blue}list$RESET usage\
"
}

category_usage() {
    echo -e "\
${Blue}category$RESET Usage: ${Green}codepm$RESET ${Blue}category$RESET ${Yellow}[options]$RESET ${Yellow}[command]$RESET

${Blue}category$RESET ${Yellow}Commands:$RESET
  ${Blue}n new$RESET                  Create a new category
  ${Blue}u update$RESET               Update a category
  ${Blue}r remove$RESET               Remove a category
  ${Blue}l list$RESET                 List all categories

${Blue}category$RESET ${Yellow}Options:$RESET
  -h --help       Print ${Blue}category$RESET usage\
"
}

code() {
    local CATEGORY="$1"
    local PROFILE="$2"
    local TARGET_PATH="$3"
    local PPATH="$PROFILES_PATH/$CATEGORY/$PROFILE"
    local PPATH_DATA="$PPATH/data"
    local PPATH_EXTS="$PPATH/exts"
    local PPATH_CONFIG="$PPATH_DATA/User/settings.json"
    local DISABLE=()
    local CONFIG=
    CONFIG="$(cat "$PPATH_CONFIG")"
    echo "$CONFIG"

    if [[ -f "$TARGET_PATH" ]]; then
        for ext in $(project_extensions_names "$CATEGORY" "$PROFILE"); do
            DISABLE+=("--disable-extension" "$ext")
        done

        jq ' setpath(["breadcrumbs.enabled"]; false)
       | setpath(["editor.minimap.enabled"]; false)
       | setpath(["workbench.statusBar.visible"]; false)
       | setpath(["workbench.activityBar.visible"]; false)
       | setpath(["workbench.layoutControl.enabled"]; false)
       | setpath(["workbench.editor.showTabs"]; false)' \
            <<<"$CONFIG" >"$PPATH_CONFIG"
    else
        jq ' setpath(["breadcrumbs.enabled"]; true)
       | setpath(["editor.minimap.enabled"]; true)
       | setpath(["workbench.statusBar.visible"]; true)
       | setpath(["workbench.activityBar.visible"]; true)
       | setpath(["workbench.layoutControl.enabled"]; true)
       | setpath(["workbench.editor.showTabs"]; true)' \
            <<<"$CONFIG" >"$PPATH_CONFIG"
    fi

    /usr/bin/env code --reuse-window --max-memory 2048 --locale en-US --sync off --extensions-dir "$PPATH_EXTS" --user-data-dir "$PPATH_DATA" "${DISABLE[@]}" "$TARGET_PATH"
}

cache_extensions() {
    local TO_CACHE=()
    local EXTENSIONS=()

    for ext in "$@"; do
        if [[ ! -f "$CACHE_PATH/$ext/version" ]] || [[ ! -f "$CACHE_PATH/$ext/$ext.$(cat "$CACHE_PATH/$ext/version").vsix" ]]; then
            TO_CACHE+=("$ext")
        fi
    done

    if [[ -z "${TO_CACHE[*]}" ]]; then return; fi

    echo "Caching extensions"
    eval "$(curl -sfL "$API_URL" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json;api-version=3.0-preview.1' \
        -d "$(jq --arg exts "${TO_CACHE[@]}" --arg flags $((0x0 | 0x2 | 0x200)) \
            ' setpath(["filters", 0, "criteria"]; $exts | split(" ") | map({ filterType: 7, "value": . }) + [{"filterType": 8, "value": "Microsoft.VisualStudio.Code"}])
      | setpath(["assetTypes"]; ["Microsoft.VisualStudio.Services.VSIXPackage"])
      | setpath(["flags"]; $flags|tonumber)' \
            <<<'{}')" |
        jq -r '@sh "EXTENSIONS=(\(.results[0].extensions | map({
        "name": (.publisher.publisherName + "." + .extensionName),
        "version": .versions[0].version,
        "url": .versions[0].files[0].source
      } | tostring)))"')"

    for ext in "${EXTENSIONS[@]}"; do
        local path=
        local name=
        local version=
        local url=
        eval "$(jq -r '@sh "name=\(.name)"' <<<"$ext")"
        eval "$(jq -r '@sh "version=\(.version)"' <<<"$ext")"
        eval "$(jq -r '@sh "url=\(.url)"' <<<"$ext")"
        path="$CACHE_PATH/$name"

        if [[ ! -d "$path" ]]; then mkdir -p "$path"; fi
        echo -e "Downloading $Blue$name$RESET $Yellow$version$RESET"
        curl -# -C - -L "$url" -o "$path/$name.$version.vsix"
        echo "$version" >"$path/version"
    done
}

install_extensions() {
    local PPATH="$PROFILES_PATH/$1/$2"
    local PPATH_DATA="$PPATH/data"
    local PPATH_EXTS="$PPATH/exts"
    local EXTS=()
    shift 2

    if [[ -n "$*" ]]; then
        for e in "$@"; do
            if [[ -f "$CACHE_PATH/$e/version" ]] || [[ -f "$CACHE_PATH/$e/$e.$(cat "$CACHE_PATH/$e/version").vsix" ]]; then
                EXTS+=("--install-extension" "$CACHE_PATH/$e/$e.$(cat "$CACHE_PATH/$e/version").vsix")
            fi
        done

        /usr/bin/env code --extensions-dir "$PPATH_EXTS" --user-data-dir "$PPATH_DATA" "${EXTS[@]}"
    fi
}

profile_extensions() {
    local CATEGORY="$1"
    local NAME="$2"
    local EXTS=()

    echo "${EXTS[@]}"
}

select_category() {
    PS3='Select category: '
    select opt in "${CATEGORIES[@]}"; do
        case $opt in
        *)
            if [[ -n "$opt" ]]; then
                echo "$opt"
                return
            fi
            ;;
        esac
    done
    PS3=
}

select_profile() {
    PS3='Select profile: '
    local options=()
    for p in "$PROFILES_PATH/$1"/*; do
        options+=("$(basename "$p")")
    done

    select opt in "${options[@]}"; do
        case $opt in
        *)
            if [[ -n "$opt" ]]; then
                echo "$opt"
                return
            fi
            ;;
        esac
    done
    PS3=
}

read_name() {
    local NAME=
    read -p "Enter name: " -r NAME
    echo "$NAME"
}

read_category() {
    local NAME=
    read -p "Enter category: " -r NAME
    echo "$NAME"
}

extensions_with_versions() {
    local EXTS=()

    for ext in "$@"; do
        if [[ -f "$CACHE_PATH/$ext/version" ]]; then
            EXTS+=("$ext@$(cat "$CACHE_PATH/$ext/version")")
        fi
    done

    echo "${EXTS[@]}"
}

extension_name() {
    local arr=()
    IFS='@'
    read -r -a arr <<<"$1"
    unset IFS
    echo "${arr[0]}"
}

extends_extensions_names() {
    local EXTS=()
    local EXTS_VER=()

    for req in "$@"; do
        if [[ "$req" == "default" ]]; then
            eval "$(jq -r '@sh "EXTS_VER+=(\(.extensions.base + .extensions.project))"' <"$CONFIG_PATH")"
        else
            local CATEGORY=
            local PROFILE=
            local arr=()
            IFS=':'
            read -r -a arr <<<"$1"
            unset IFS
            CATEGORY="${arr[0]}"
            PROFILE="${arr[1]}"
            local PROFILE_CONFIG_PATH="$PROFILES_PATH/$CATEGORY/$PROFILE/settings.json"
            if [[ -f "$PROFILE_CONFIG_PATH" ]]; then
                eval "$(jq -r '@sh "EXTS_VER+=(\(.extensions.base + .extensions.project))"' <"$PROFILE_CONFIG_PATH")"
            fi
        fi
    done

    for ext in "${EXTS_VER[@]}"; do
        EXTS+=("$(extension_name "$ext")")
    done

    echo "${EXTS[@]}"
}

project_extensions_names() {
    local CATEGORY="$1"
    local PROFILE="$2"
    local PPATH="$PROFILES_PATH/$CATEGORY/$PROFILE"
    local PPATH_CONFIG="$PPATH/settings.json"
    local PPATH_DATA="$PPATH/data"
    local PPATH_EXTS="$PPATH/exts"

    local EXTENDS=()
    local EXTS_VER=()
    local EXTS=()

    eval "$(jq -r '@sh "EXTENDS=(\(.extends // [])); EXTS_VER=(\(.extensions.project // []))"' <"$PPATH_CONFIG")"

    for req in "${EXTENDS[@]}"; do
        if [[ "$req" == "default" ]]; then
            eval "$(jq -r '@sh "EXTS_VER+=(\(.extensions.project))"' <"$CONFIG_PATH")"
        else
            local CATEGORY=
            local PROFILE=
            local arr=()
            IFS=':'
            read -r -a arr <<<"$1"
            unset IFS
            CATEGORY="${arr[0]}"
            PROFILE="${arr[1]}"
            local PROFILE_CONFIG_PATH="$PROFILES_PATH/$CATEGORY/$PROFILE/settings.json"
            if [[ -f "$PROFILE_CONFIG_PATH" ]]; then
                eval "$(jq -r '@sh "EXTS_VER+=(\(.extensions.project))"' <"$PROFILE_CONFIG_PATH")"
            fi
        fi
    done

    for ext in "${EXTS_VER[@]}"; do
        EXTS+=("$(extension_name "$ext")")
    done

    echo "${EXTS[@]}"
}

print_category_profiles() {
    echo -e "$Blue$1$RESET profiles":
    local values=("$PROFILES_PATH/$1"/*)
    for p in "${values[@]}"; do
        echo -n -e "$Yellow"
        if [[ "$p" == "${values[-1]}" ]]; then
            printf ' └ '
        elif [[ "$p" == "${values[0]}" ]]; then
            printf ' ┌ '
        else
            printf ' ├ '
        fi
        echo -n -e "$RESET"
        basename "$p"
    done
}

new() {
    local CATEGORY=
    local NAME=
    local NO_DEFAULT=false
    local EXTENDS=()

    while true; do
        if [[ -z "$1" ]]; then
            break
        fi

        case "$1" in
        -h | --help)
            echo -e "Visual Studio Code Profile Manager ${Yellow}$VERSION$RESET"
            echo
            new_usage
            return
            ;;
        -c | --category)
            if [[ "$2" == -* ]]; then
                shift
            else
                if [[ "${CATEGORIES[*]}" =~ $2 ]]; then
                    CATEGORY="$2"
                fi
                shift 2
            fi
            ;;
        -e | --extend)
            if [[ "$2" == -* ]]; then
                shift
            else
                IFS=','
                read -r -a EXTENDS <<<"$2"
                unset IFS
                shift 2
            fi
            ;;
        -n | --no-default)
            if [[ "$2" == -* ]]; then
                shift
            else
                NO_DEFAULT=true
                shift
            fi
            ;;
        *)
            if [[ "$1" != -* ]] && [[ -z "$NAME" ]]; then
                NAME="$1"
                shift
            else
                shift
                if [[ "$1" != -* ]] && [[ -n "$NAME" ]]; then
                    shift
                fi
            fi
            ;;
        esac
    done

    if [[ -z "$CATEGORY" ]]; then
        CATEGORY=$(select_category)
    fi

    if [[ -z "$NAME" ]]; then
        NAME=$(read_name)
    fi

    echo -e "Creating profile $Blue$NAME$RESET in category $Yellow$CATEGORY$RESET"

    local PPATH="$PROFILES_PATH/$CATEGORY/$NAME"
    local PPATH_DATA="$PPATH/data"
    local PPATH_EXTS="$PPATH/exts"
    local PPATH_CONFIG="$PPATH_DATA/User/settings.json"

    mkdir -p "$PPATH"
    mkdir -p "$PPATH_DATA"
    mkdir -p "$PPATH_EXTS"

    if [[ "$NO_DEFAULT" == false ]]; then
        EXTENDS+=("default" "${EXTENDS[@]}")
    fi

    local EXTENSIONS=()
    for ext in $(extends_extensions_names "${EXTENDS[@]}"); do
        EXTENSIONS+=("$ext")
    done

    cache_extensions "${EXTENSIONS[@]}"

    jq --arg EXTENDS "${EXTENDS[@]}" \
        ' setpath(["extensions"]; {"base": [], "project": []})
       | setpath(["extends"]; $EXTENDS | split(" "))' \
        <<<'{}' >"$PPATH/settings.json"

    install_extensions "$CATEGORY" "$NAME" "${EXTENSIONS[@]}"

    echo '{
      "editor.accessibilitySupport": "off",
      "update.mode": "none",
      "workbench.colorTheme": "Ayu Dark",
      "workbench.iconTheme": "symbols",
      "workbench.productIconTheme": "fluent-icons",
      "window.title": "language - bash | ${activeEditorShort}${separator}${rootName}",
      "symbols.hidesExplorerArrows": false,
      "telemetry.telemetryLevel": "off",
      "terminal.integrated.defaultProfile.linux": "zsh",
      "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"
  }' >"$PPATH_CONFIG"

    echo -e "Profile $Blue$NAME$RESET created in category $Yellow$CATEGORY$RESET"
}

remove() {
    local CATEGORY=
    local NAME=

    while true; do
        if [[ -z "$1" ]]; then
            break
        fi

        case "$1" in
        -h | --help)
            echo -e "Visual Studio Code Profile Manager $Yellow$VERSION$RESET"
            echo
            remove_usage
            return
            ;;
        -c | --category)
            if [[ "$2" == -* ]]; then
                shift
            else
                if [[ "${CATEGORIES[*]}" =~ $2 ]]; then
                    CATEGORY="$2"
                fi
                shift 2
            fi
            ;;
        *)
            if [[ "$1" != -* ]] && [[ -z "$NAME" ]]; then
                NAME="$1"
                shift
            else
                shift
                if [[ "$1" != -* ]] && [[ -n "$NAME" ]]; then
                    shift
                fi
            fi
            ;;
        esac
    done

    if [[ -z "$CATEGORY" ]]; then
        CATEGORY=$(select_category)
    fi

    if [[ -z "$NAME" ]]; then
        NAME=$(select_profile "$CATEGORY")
    fi

    local PPATH="$PROFILES_PATH/$CATEGORY/$NAME"
    rm -rf "$PPATH"
}

list() {
    local CATEGORY=

    while true; do
        if [[ -z "$1" ]]; then
            break
        fi

        case "$1" in
        -h | --help)
            echo -e "Visual Studio Code Profile Manager ${Yellow}$VERSION$RESET"
            echo
            list_usage
            return
            ;;
        -c | --category)
            if [[ "$2" == -* ]]; then
                shift
            else
                if [[ "${CATEGORIES[*]}" =~ $2 ]]; then
                    CATEGORY="$2"
                fi
                shift 2
            fi
            ;;
        *) shift ;;
        esac
    done

    if [[ -n "$CATEGORY" ]]; then
        if [[ ! -d "$PROFILES_PATH/$CATEGORY" ]] || [[ ! "$(ls -A "$PROFILES_PATH/$CATEGORY")" ]]; then return; fi
        print_category_profiles "$CATEGORY"
    else
        local values=("$PROFILES_PATH"/*)
        if [[ -z "$(ls -A "$PROFILES_PATH")" ]]; then return; fi
        for c in "${values[@]}"; do
            if [[ ! -d "$PROFILES_PATH/$(basename "$c")" ]] || [[ ! "$(ls -A "$PROFILES_PATH/$(basename "$c")")" ]]; then continue; fi
            print_category_profiles "$(basename "$c")"
            if [[ "$c" != "${values[-1]}" ]]; then
                echo
            fi
        done
    fi
}

main() {
    local TARGET_PATH=
    local CATEGORY=
    local NAME=

    while true; do
        if [[ -z "$1" ]]; then
            break
        fi

        case "$1" in
        -h | --help)
            usage
            return
            ;;
        -v | --version)
            echo "$VERSION"
            return
            ;;
        -c | --category)
            if [[ "${CATEGORIES[*]}" =~ $2 ]]; then
                CATEGORY="$2"
            fi
            shift 2
            ;;
        -n | --name)
            NAME="$2"
            shift 2
            ;;
        *)
            if [[ "$1" != -* ]] && [[ -z "$TARGET_PATH" ]]; then
                TARGET_PATH="$1"
                shift
            else
                shift
                if [[ "$1" != -* ]] && [[ -n "$TARGET_PATH" ]]; then
                    shift
                fi
            fi
            ;;
        esac
    done

    if [[ -z "$CATEGORY" ]]; then
        CATEGORY=$(select_category)
    fi

    if [[ -z "$NAME" ]]; then
        NAME=$(select_profile "$CATEGORY")
    fi

    if [[ ! -d "$PROFILES_PATH/$CATEGORY/$NAME" ]]; then
        echo -e "Profile $Magenta$NAME$RESET does not exist in category $Magenta$CATEGORY$RESET"
        exit 1
    fi

    code "$CATEGORY" "$NAME" "$TARGET_PATH"
}

setup() {
    EXTS=()
    which jq >/dev/null || EXTS+=("jq")
    if [[ -n "${EXTS[*]}" ]]; then
        case "$TARGET" in
        darwin) brew install "${EXTS[*]}" ;;
        debian) apt install "${EXTS[*]}" ;;
        archlinux) pacman -S "${EXTS[*]}" ;;
        *) echo -e "Please install ${Green}jq$RESET manually" ;;
        esac
    fi

    cache_extensions "${DEFAULT_BASE_EXTENSIONS[@]}" "${DEFAULT_PROJECT_EXTENSIONS[@]}"

    jq --arg BASE_EXTENSIONS "$(extensions_with_versions "${DEFAULT_BASE_EXTENSIONS[@]}")" --arg PROJECT_EXTENSIONS "$(extensions_with_versions "${DEFAULT_PROJECT_EXTENSIONS[@]}")" \
        'setpath(["extensions"]; {
              "base": $BASE_EXTENSIONS | split(" "),
              "project": $PROJECT_EXTENSIONS | split(" "),
            })' \
        <<<"{}" >"$CONFIG_PATH"
}

category() {
    CATEGORY=$2
    NAME=$3
    case "$1" in
    n | new)
        if [[ -z "$CATEGORY" ]]; then
            CATEGORY=$(read_category)
        fi
        mkdir -p "$PROFILES_PATH/$CATEGORY"
        ;;
    u | update)
        if [[ -z "$CATEGORY" ]]; then
            CATEGORY=$(select_category)
        fi
        if [[ -z "$NAME" ]]; then
            NAME=$(read_category)
        fi
        mv "$PROFILES_PATH/$CATEGORY" "$PROFILES_PATH/$NAME"
        ;;
    r | remove)
        if [[ -z "$CATEGORY" ]]; then
            CATEGORY=$(select_category)
        fi
        rm -rf "$PROFILES_PATH/${CATEGORY:?}"
        ;;
    l | list)
        echo "${CATEGORIES[*]}"
        ;;
    -h | --help)
        echo -e "Visual Studio Code Profile Manager ${Yellow}$VERSION$RESET"
        echo
        category_usage
        ;;
    *)
        echo -e "Visual Studio Code Profile Manager ${Yellow}$VERSION$RESET"
        echo
        category_usage
        ;;
    esac
}

clear_cache() {
    FULL=${1-false}

    if [[ $FULL ]]; then
        rm -rf "$CACHE_PATH"
        mkdir -p "$CACHE_PATH"
    else
        echo "Unimplemented, FULL=$FULL"
    fi
}

install() {
    case "$TARGET" in
    darwin) sh -c "sudo install -o root -g wheel $0 /usr/local/bin/codepm" ;;
    *) echo "Please copy this script to any location in PATH" ;;
    esac
}

uninstall() {
    while true; do
        read -r -p "Do you wish to uninstall this program? (y/n) " yn
        case $yn in
        [Yy]*)
            if [[ -d "$BASE_PATH" ]]; then
                rm -rf "$BASE_PATH"
            fi
            if [[ -f "/usr/local/bin/codepm" ]]; then
                sh -c "sudo rm /usr/local/bin/codepm"
            fi
            echo "${Green}codepm$RESET was uninstalled"
            break
            ;;
        [Nn]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
}

if [[ ! -d "$BASE_PATH" ]]; then mkdir -p "$BASE_PATH"; fi
if [[ ! -d "$PROFILES_PATH" ]]; then mkdir -p "$PROFILES_PATH"; fi
if [[ ! -d "$CACHE_PATH" ]]; then mkdir -p "$CACHE_PATH"; fi
if [[ ! -f "$CONFIG_PATH" ]]; then echo "{}" >"$CONFIG_PATH"; fi

# Ensure all dependencies are installed
if [[ "$1" != 's' ]] && [[ "$1" != 'setup' ]]; then
    which code >/dev/null || {
        echo -e "Please install ${Green}code$RESET manually or try with ${Green}codepm$RESET ${Blue}setup$RESET"
        exit 1
    }
    which jq >/dev/null || {
        echo -e "Please install ${Green}jq$RESET manually or try with ${Green}codepm$RESET ${Blue}setup$RESET"
        exit 1
    }
fi

read -ra CATEGORIES <<<"$(find "$PROFILES_PATH" -type d -depth 1 | xargs basename -a | xargs)"

case $(uname) in
'Darwin') TARGET=darwin ;;
'Linux')
    which apt && TARGET=debian
    which pacman && TARGET=archlinux
    ;;
esac

if [[ -z "$1" ]]; then
    usage
    exit 0
fi

case "$1" in
h | help)
    usage
    ;;
n | new)
    shift
    new "$@"
    ;;
r | remove)
    shift
    remove "$@"
    ;;
l | list)
    shift
    list "$@"
    ;;
s | setup) setup ;;
c | category)
    shift
    category "$@"
    ;;
cc | clear-cache) clear_cache ;;
ccf | clear-cache-full) clear_cache true ;;
i | install) install ;;
ui | uninstall) uninstall ;;
*) main "$@" ;;
esac
