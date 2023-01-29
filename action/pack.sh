#!/bin/bash
set -e; set -u

DEBUG="${1:-"false"}"
INI_PATH="${2:-"./action/pack.ini"}"
GITHUB_TOKEN="${3:-}"
SECTION_INI_PATH="section.ini"
echo -n "" > "$SECTION_INI_PATH"

#region = debug 
exec 3>&1

debug(){
    ${DEBUG:-false} || return 0
    echo -e "[DEBUG] $*" >&3
}

info(){
    echo "[INFO] $*" >&3
}
#TODO:waring至action
warning(){
    echo "[WARN] $*" >&3
}

error(){
    echo "[ERRO] $*" >&2
    exit 1
}

print_info_head(){
    echo "    --------------------${section:-"[init]"$(warning "unbound variable \$section")}-------------------"
}

print_info_tail(){
    echo "    ============================================"
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
        print_info_"$task" || error "invalid task: $task"
    fi
        print_info_tail
}

update_info(){
    print_info "update"
}
#endregion

#region = download 
get_args_download(){
    [[ -n "$download_file" ]] || error "unbound variable \$download_file"
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
    [[ -n "$ref"         ]] || error "unbound variable \$ref"
    [[ -n "$github_repo" ]] || error "unbound variable \$github_repo"

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
    clone_repo && info "${github_repo} [$ref] cloned"
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
    7z x -bd -o"$tmpdir" "$download_file" -bso0 || error "${github_repo}[$ref] clone failed"
    local tmpdirarray=("$tmpdir"/*/)
    mv "${tmpdirarray[0]::-1}"/* "${github_repo}"/
}

clone_repo_git(){
    local tmppwd=$PWD
    cd "${github_repo}"/..
    git clone -q "$repository" -b "${ref[0]}" --single-branch || error "${github_repo}[$ref] clone failed"
    cd "$tmppwd/${github_repo}"
    git checkout ${ref[1]:-} || error "${github_repo}[$ref] clone failed"
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
    info "lazy ~"
}

set_main_branch_config(){
    find portable_config/ -type f -size 0 -exec sh -c \
        "if ls $github_repo/\$1 > /dev/null; then rm -r \$1; mv -f $github_repo/\$1 \$1; fi;" -- {} \;
    
    mv "./portable_config/"      "$pack_name"
    mv "$github_repo/installer"  "$pack_name"
    mv "$github_repo/LICENSE.MD" "$pack_name"
}

set_customized_config(){
    warning "TODO"
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
    info "initialized"
}
#endregion

#region = public 
get_download_api_from_github_repo(){
    [[ -n "$download_api"   || -n "$download_url" ]] && return
    [[ -n "$github_repo" ]] || error "unbound variable \$github_repo \$download_api \$download_url"
    download_api=https://api.github.com/repos/$github_repo/releases/latest
}

get_download_url_from_download_api(){
    [[ -n "$download_url"  ]] && return
    [[ -n "$download_api"  ]] || error "unbound variable \$download_api"
    [[ -n "$download_file" ]] || error "unbound variable \$download_file"
    [[ -n "$keyword"       ]] || error "unbound variable \$keyword"
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
            error "invalid download_api: $download_api"
            ;;
    esac
}

get_download_file_from_download_url(){
    [[ -n "$download_url"  ]] || error "unbound variable \$download_url"
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
        && info "$2 downloaded"       \
        || error "$2 download failed"
}

print_download_from(){
    local args
    get_header "$1"
    ${DEBUG:-false} && args="-fLH" || args="-sfLH"
    curl "$args" "$header" "$1" || error "$2 print download failed"
}

exec_cmd(){
    # 这块可能有bug，等有缘人.jpg
    if ${DEBUG:-false}; then
        # 使用管道, $? == 0
        ($cmd && info "command executed" || error "command execute failed") | tee debug.log
    else
        $cmd > debug.log && info "command executed" || error "command execute failed"
    fi

    while read -r line; do
        if [[ "$line" == "No files to process" ]]; then
            error "7z: No files to process (没有文件被解压出来，请检查7z命令)"
        fi
    done < debug.log
}
#endregion

#region = run 
run_section(){
    init_args
    # 遇到[init]时啥都没
    echo ""
    info "run=${run:-} && run_${task:-}"
    ${run:-false} \
        && get_args_"${task}" \
        && print_info \
        && run_"$task"
    return 0
}

init_args(){
    clear_ini_args
    source "$SECTION_INI_PATH"
    echo -n "" > "$SECTION_INI_PATH"
}

clear_ini_args(){
    pack_name=${pack_name:-"mpv_lazy"}
    # 遇到[init]时啥都没
    run=${section:+true}
    task=init
    repository=
    github_repo=
    ref=
    download_api=
    download_file=
    download_url=
    cmd=true
}

check_ini_args(){
    case "$*" in
        [a-zA-Z]*)
            echo "$*" >> "$SECTION_INI_PATH"
            ;;
        "")
            ;;
        *)
            warning "invalid ini arg: $*"
            echo "::warning file={$INI_PATH},line={$(sed -n "/$*/=" "$INI_PATH")}::{invalid arg: $*}"
            ;;
    esac
}
#endregion

while read -r line; do
    case "$line" in
        [';#']*)
            ;;
        *'['*']'*)
            run_section
            section="$line" # 供下一节debug使用
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
    print_info
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
