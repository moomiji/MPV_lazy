#!/bin/bash
set -e; set -u
# Usage:
#   cd portable_config/..
#   chmod +x ./action/pack.sh
#   ./action/pack.sh "action/pack.ini" [is_debug] [GITHUB_TOKEN]

INI_PATH="${1:-"action/pack.ini"}" # 不能带$PWD，因为Warning()会输出该文件的github网页链接
DEBUG="${2:-"false"}"
GITHUB_TOKEN="${3:-}"
DEBUG_LOG="$PWD/debug.log"
SECTION_INI_PATH="$PWD/section.ini"
echo -n "" > "$SECTION_INI_PATH"

#region = debug 
exec 3>&1

Debug(){
    ${DEBUG:-false} || return 0
    echo -e "[DEBUG] ${FUNCNAME[1]}: $*" >&3
}

Info(){
    echo "[INFO] ${FUNCNAME[1]}: $*" >&3
}

Warning(){
    echo "[WARN] ${FUNCNAME[*]}: $*" >&3
    case $1 in 
        "invalid ini arg:")
            echo "::warning title=$*::$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/blob/$GITHUB_REF_NAME/$INI_PATH#L$(sed -n "/$2/=" "$INI_PATH")" >&3
            ;;
        *)
            echo "::warning title=${FUNCNAME[*]}::$*" >&3
            ;;
    esac
}

Error(){
    cat "$DEBUG_LOG" >&3
    echo "[ERRO] ${FUNCNAME[*]}: $*" >&2
    echo "::error title=${FUNCNAME[*]}::$*" >&3
    exit 1
}

print_info_head(){
    echo "--------------------${section:-"[init]"$(Warning "unbound variable \$section")}-------------------"
}

print_info_tail(){
    echo "============================================"
}

print_info_update(){
    echo "                args updated"
}

print_info(){
    if [[ -z "${*:-}" ]]; then
        print_info_head
    else
        print_info_update
    fi
    if $run; then
        print_info_"$task" || Error "invalid task: $task"
    fi
        print_info_tail
}

update_info(){
    print_info "update"
}
#endregion

#region = download 
get_args_download(){
    [[ -n "$download_file" ]] || Error "unbound variable \$download_file"
    local keyword="download_url"

    get_download_api_from_github_repo
    get_download_url_from_download_api
    get_download_file_from_download_url
}
print_info_download(){
    echo "    github_repo=$github_repo
    download_api=$download_api
    download_url=$download_url
    download_file=$download_file
    cmd=$cmd"
}
run_download(){
    download_from "$download_url" "$download_file"
    exec_cmd
}
#endregion

#region = clone 
get_args_clone(){
    [[ -n "$ref"         ]] || Error "unbound variable \$ref"
    [[ -n "$github_repo" ]] || Error "unbound variable \$github_repo"

    if [[ "$ref" == "latest_release" ]]; then
        local keyword="zipball_url"
        download_file="$keyword"
        get_download_api_from_github_repo
        get_download_url_from_download_api
    else
        download_url="https://github.com/$github_repo/archive/$ref.zip"
    fi
}
print_info_clone(){
    echo "    repository=$repository
    github_repo=$github_repo
    ref=$ref
    cmd=$cmd
    download_api=$download_api
    download_url=$download_url"
}
run_clone(){
    clone_repo && Info "${github_repo} [$ref] cloned"
    exec_cmd
}

clone_repo(){
    mkdir -p "${github_repo}"
    if [[ -n "$repository" ]]; then
        clone_repo_git
    else
        clone_repo_7z
    fi
}

clone_repo_7z(){
    download_file=$(mktemp "./XXXXXXXX.zip")
    download_from "$download_url" "$download_file"
    local tmpdir="./${download_file::-4}"
    7z x -bd -y -o"$tmpdir" "$download_file" -bso0 || Error "${github_repo}[$ref] clone failed"
    local tmpdirarray=("$tmpdir"/*/)
    mv "${tmpdirarray[0]::-1}"/* "${github_repo}"/
}

clone_repo_git(){
    local tmppwd=$PWD
    cd "${github_repo}"/..
    git clone -q "$repository" -b "${ref[0]}" --single-branch || Error "${github_repo}[$ref] clone failed"
    cd "$tmppwd/${github_repo}"
    git checkout ${ref[1]:-} || Error "${github_repo}[$ref] clone failed"
    cd "$tmppwd"
}

#endregion

#region = lazy 
get_args_lazy(){
    github_repo=${github_repo:-"hooke007/MPV_lazy"}
    get_args_clone
}
print_info_lazy(){
    print_info_clone
}
run_lazy(){
    run_clone
    set_main_branch_config
    set_customized_config
    Info "lazy ~"
}

set_main_branch_config(){
    clear "$DEBUG_LOG"
    # find的路径是运行workflow的分支的portable_config/**，不然得裁一下字符串，太麻烦了
    find portable_config/ -type f -size 0 -exec sh -c \
        "if ls $github_repo/\$1 1>/dev/null 2>>$DEBUG_LOG; then rm -r \$1; mv -f $github_repo/\$1 \$1; fi;" -- {} \;
    parse_debug_log

    mv "./portable_config/"      "$pack_name"
    mv "$github_repo/installer"  "$pack_name"
    mv "$github_repo/LICENSE.MD" "$pack_name"
}

set_customized_config(){
    # TODO: 原本是想整个action/input.conf啥的，复制到portable_config/input_uosc.conf的末尾，
    #       但因为git自带diff，显得没啥卵用……(等个有缘人.jpg)(佬可自行修改)
    # Example:
    #   cat action/input.conf >> portable_config/input_uosc.conf
    #   cat action/mpv.conf >> portable_config/mpv.conf
    Debug "TODO: set_customized_config"
}
#endregion

#region = init 
get_args_init(){
    echo "artifact_name=$pack_name" >> "$GITHUB_ENV"
    echo "pack_dir=$PWD/$pack_name" >> "$GITHUB_ENV"
}
print_info_init(){
    echo "    pack_name=$pack_name
    cmd=$cmd"
}
run_init(){
    mkdir -p "$pack_name"
    exec_cmd
    Info "initialized"
}
#endregion

#region = public 
get_download_api_from_github_repo(){
    [[ -n "$download_api"   || -n "$download_url" ]] && return 0
    [[ -n "$github_repo" ]] || Error "unbound variable \$github_repo \$download_api \$download_url"
    download_api=https://api.github.com/repos/$github_repo/releases/latest
}

get_download_url_from_download_api(){
    [[ -n "$download_url"  ]] && return 0
    [[ -n "$download_api"  ]] || Error "unbound variable \$download_api"
    [[ -n "$download_file" ]] || Error "unbound variable \$download_file"
    [[ -n "$keyword"       ]] || Error "unbound variable \$keyword"
    # 通配符替换为正则，给grep awk sed三剑客用
    download_file="${download_file/'*'/'.*'}"

    # 从api解析出url
    case "$download_api" in
        *api.github.com*)
            download_url="$(print_download_from "$download_api" | grep -i "$download_file" | awk "/$keyword/{print \$4;exit}" FS='"')"
            ;;
        *api.git.where*)  
            download_url= # 预留
            ;;
        *)
            Error "invalid download_api: $download_api"
            ;;
    esac
}

get_download_file_from_download_url(){
    [[ "$download_file" == *"*"* ]] || return 0
    [[ -n "$download_url"  ]] || Error "unbound variable \$download_url"
    download_file="${download_url##*/}"
}

get_header(){
    header=""
    case "$1" in
        *github.com*)
            if [[ -n "$GITHUB_TOKEN" ]]; then
                header="authorization: Bearer $GITHUB_TOKEN"
            fi
            ;;
    esac
}

download_from(){
    local args
    get_header "$1"
    ${DEBUG:-false} && args="-fLH" || args="-sfLH"
    curl "$args" "$header" "$1" -o "$2" \
        && Info "$2 downloaded"       \
        || Error "$2 download failed"
}

print_download_from(){
    local args
    get_header "$1"
    ${DEBUG:-false} && args="-fLH" || args="-sfLH"
    curl "$args" "$header" "$1" || Error "$2 print download failed"
}

exec_cmd(){
    [[ -n "$cmd" ]] || return 0
    clear "$DEBUG_LOG"
    eval "$cmd" &>"$DEBUG_LOG" && Info "command executed" || Error "command execute failed"
    ${DEBUG:-false} && cat "$DEBUG_LOG"
    parse_debug_log
}

parse_debug_log(){
    local line
    while read -r line; do
        if [[ "$line" == "No files to process" ]]; then
            Error "7z: No files to process (没有文件被解压出来，请检查7z命令)"
        fi
        if [[ "$line" == "ls:"* ]]; then
            Warning "$line"
        fi
    done < "$DEBUG_LOG"
}

clear(){
    echo "" > "$1"
}
#endregion

#region = run 
run_section(){
    init_args
    # 遇到[init]时啥都没
    echo ""
    Info "run=${run:-} && run_${task:-}"
    ${run:-false} \
        && get_args_"${task}" \
        && print_info \
        && run_"$task"
    return 0
}

init_args(){
    clear_ini_args
    source "$SECTION_INI_PATH"
    clear "$SECTION_INI_PATH"
}

clear_ini_args(){
    pack_name=${pack_name:-"mpv-lazy"}
    # 遇到[init]时啥都没
    run=${section:+true}
    task=init
    repository=
    github_repo=
    ref=
    download_api=
    download_file=
    download_url=
    cmd=
}

check_ini_args(){
    case "$*" in
        "") ;;
        pack_name=*     | \
        run=true        | run=false | \
        task=init       | task=download | task=clone | task=lazy | \
        repository=*    | \
        github_repo=*   | \
        ref=*           | \
        download_api=*  | \
        download_file=* | \
        download_url=*  | \
        cmd=*           )
            echo "$*" >> "$SECTION_INI_PATH"
            ;;
        *)
            Warning "invalid ini arg:" "$*"
            ;;
    esac
}
#endregion

while read -r line; do
    case "$line" in
        [';#']*)
            ;;
        *'['*']'*)
            next_section=$line
            run_section
            section=$next_section
            ;;
        *)
            check_ini_args "$line"
            ;;
    esac
done < "$INI_PATH"
run_section



#region = example
get_args_example(){
    # 检查必须的参数
    # 添加没在ini中列出的参数
    example=$PWD
}
print_info_example(){
    grep -v "^$" "$SECTION_INI_PATH"
    # 或者
    echo "example=$example"
    # 或者
    echo -e "${example:+"\bexample=$example\n"}"
}
run_example(){
    echo
}
#endregion
