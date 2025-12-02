#!/usr/bin/env bash

# ================================== 路径 & 日志 ==================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 设置对应的日志文件路径

log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
color_echo()     { log "\033[1;32m$1\033[0m"; }
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
warm_echo()      { log "\033[1;33m$1\033[0m"; }
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
err_echo()       { log "\033[1;31m$1\033[0m"; }
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
gray_echo()      { log "\033[0;90m$1\033[0m"; }
bold_echo()      { log "\033[1m$1\033[0m"; }
underline_echo() { log "\033[4m$1\033[0m"; }

init_log() {
  : > "$LOG_FILE"  # 清空旧日志
}

# ================================== 工具函数 ==================================
get_cpu_arch() {
  uname -m
}

inject_shellenv_block() {
  local profile_file="$1"
  local shellenv_cmd="$2"

  [[ -z "$profile_file" || -z "$shellenv_cmd" ]] && return 1

  touch "$profile_file" || return 1

  if grep -Fq "$shellenv_cmd" "$profile_file" 2>/dev/null; then
    info_echo "Homebrew shellenv 已存在于 $profile_file"
    return 0
  fi

  {
    echo ""
    echo "# >>> Homebrew shellenv (added by $SCRIPT_BASENAME) >>>"
    echo "$shellenv_cmd"
    echo "# <<< Homebrew shellenv <<<"
  } >> "$profile_file"

  success_echo "已写入 Homebrew shellenv 到 $profile_file"
}

ensure_command() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" &>/dev/null; then
    error_echo "未检测到命令: $cmd"
    [[ -n "$hint" ]] && note_echo "$hint"
    exit 1
  fi
}

# ================================== Homebrew & fzf ==================================
install_homebrew() {
  local arch="$(get_cpu_arch)"                   # 获取当前架构（arm64 或 x86_64）
  local shell_path="${SHELL##*/}"                # 获取当前 shell 名称（如 zsh、bash）
  local profile_file=""
  local brew_bin=""
  local shellenv_cmd=""

  if ! command -v brew &>/dev/null; then
    warn_echo "🧩 未检测到 Homebrew，正在安装中...（架构：$arch）"

    if [[ "$arch" == "arm64" ]]; then
      # Apple Silicon 原生 Homebrew（/opt/homebrew）
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（arm64）"
        exit 1
      }
      brew_bin="/opt/homebrew/bin/brew"
    else
      # Intel 或在 Apple Silicon 下装一份 Intel 版 Homebrew（需要 Rosetta）
      arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（x86_64）"
        exit 1
      }
      brew_bin="/usr/local/bin/brew"
    fi

    success_echo "✅ Homebrew 安装成功"

    # ==== 注入 shellenv 到对应配置文件（自动生效） ====
    shellenv_cmd="eval \"$(${brew_bin} shellenv)\""
    case "$shell_path" in
      zsh)   profile_file="$HOME/.zprofile" ;;
      bash)  profile_file="$HOME/.bash_profile" ;;
      *)     profile_file="$HOME/.profile" ;;
    esac
    inject_shellenv_block "$profile_file" "$shellenv_cmd"

    # 立刻对当前会话生效（不等重开终端）
    eval "$(${brew_bin} shellenv)"

  else
    info_echo "🔄 Homebrew 已安装。是否执行更新？"
    echo "👉 按 [Enter] 继续：将依次执行  brew update && brew upgrade && brew cleanup && brew doctor && brew -v"
    echo "👉 输入任意字符后回车：跳过更新"
    # 仅当“直接回车”时继续；其他输入一律跳过
    local confirm
    IFS= read -r confirm
    if [[ -z "$confirm" ]]; then
      info_echo "⏳ 正在更新 Homebrew..."
      # 分步执行，任一步失败立即报错退出，方便定位
      brew update       || { error_echo "❌ brew update 失败"; return 1; }
      brew upgrade      || { error_echo "❌ brew upgrade 失败"; return 1; }
      brew cleanup      || { error_echo "❌ brew cleanup 失败"; return 1; }
      brew doctor       || { warn_echo  "⚠️  brew doctor 有警告/错误，请按提示处理"; }
      brew -v           || { warn_echo  "⚠️  打印 brew 版本失败（可忽略）"; }
      success_echo "✅ Homebrew 已更新"
    else
      note_echo "⏭️ 已选择跳过 Homebrew 更新"
    fi
  fi
}

install_fzf() {
  if ! command -v fzf &>/dev/null; then
    note_echo "📦 未检测到 fzf，正在通过 Homebrew 安装..."
    brew install fzf || { error_echo "❌ fzf 安装失败"; exit 1; }
    success_echo "✅ fzf 安装成功"
  else
    info_echo "🔄 fzf 已安装。是否执行升级？"
    echo "👉 按 [Enter] 继续：将依次执行  brew upgrade fzf && brew cleanup"
    echo "👉 输入任意字符后回车：跳过升级"

    local confirm
    IFS= read -r confirm
    if [[ -z "$confirm" ]]; then
      info_echo "⏳ 正在升级 fzf..."
      brew upgrade fzf       || { error_echo "❌ fzf 升级失败"; return 1; }
      brew cleanup           || { warn_echo  "⚠️  brew cleanup 执行时有警告"; }
      success_echo "✅ fzf 已升级到最新版本"
    else
      note_echo "⏭️ 已选择跳过 fzf 升级"
    fi
  fi
}

# ================================== Podspec 选择 & 解析 ==================================
PODSPEC_PATH=""
PODSPEC_BASENAME=""
POD_NAME=""
POD_VERSION=""

select_podspec_in_script_dir() {
  local search_dir="$SCRIPT_DIR"
  local podspec_files=("$search_dir"/*.podspec)

  if [[ ! -e "${podspec_files[0]}" ]]; then
    warn_echo "在脚本目录($search_dir)下未找到任何 *.podspec 文件。"
    ask_podspec_from_user
    return
  fi

  if [[ ${#podspec_files[@]} -eq 1 ]]; then
    PODSPEC_PATH="${podspec_files[0]}"
    PODSPEC_BASENAME="$(basename "$PODSPEC_PATH")"
    success_echo "自动选中 podspec: $PODSPEC_BASENAME"
    return
  fi

  # 多个 podspec，用 fzf 选择
  ensure_command fzf "请先安装 fzf（brew install fzf）"
  note_echo "检测到多个 podspec，请选择要发布的那个："

  local selected_basename
  selected_basename=$(printf '%s\n' "${podspec_files[@]##"$search_dir"/}" | \
    fzf --prompt="选择 podspec: " --height=40%) || {
    error_echo "未选择任何 podspec，发布流程中断。"
    exit 1
  }

  PODSPEC_PATH="$search_dir/$selected_basename"
  PODSPEC_BASENAME="$selected_basename"
  success_echo "已选择 podspec: $PODSPEC_BASENAME"
}

ask_podspec_from_user() {
  while :; do
    warm_echo "请手动输入要发布的 .podspec 文件路径（可直接将文件拖入终端后回车）："
    printf "> "
    local input
    IFS= read -r input

    # 处理拖入路径时自动加的引号
    input="${input%\"}"; input="${input#\"}"
    input="${input%\'}"; input="${input#\'}"

    # 处理 ~
    input=${input/#~/$HOME}

    if [[ -f "$input" ]]; then
      PODSPEC_PATH="$input"
      PODSPEC_BASENAME="$(basename "$PODSPEC_PATH")"
      success_echo "已选择 podspec: $PODSPEC_BASENAME"
      break
    else
      error_echo "路径无效或文件不存在: $input"
    fi
  done
}

read_podspec_metadata() {
  ensure_command ruby "CocoaPods 依赖 Ruby，请先安装 Ruby 环境。"

  local spec_file="$PODSPEC_PATH"
  if [[ ! -f "$spec_file" ]]; then
    error_echo "podspec 文件不存在: $spec_file"
    exit 1
  fi

  local ruby_script
  ruby_script=$(cat << 'RUBY'
require 'cocoapods'
spec_path = ARGV[0]
spec = Pod::Specification.from_file(spec_path)
puts spec.name
puts spec.version
RUBY
  )

  local output
  if ! output=$(ruby -e "$ruby_script" "$spec_file" 2>/tmp/podspec_parse_error.log); then
    error_echo "使用 Ruby 解析 podspec 失败，详情见 /tmp/podspec_parse_error.log"
    exit 1
  fi

  POD_NAME=$(echo "$output" | sed -n '1p')
  POD_VERSION=$(echo "$output" | sed -n '2p')

  if [[ -z "$POD_NAME" || -z "$POD_VERSION" ]]; then
    error_echo "未能从 podspec 中解析出 name/version，请检查文件。"
    exit 1
  fi

  info_echo "📦 Pod 名称: $POD_NAME"
  info_echo "🏷 版本号: $POD_VERSION"
}

# ================================== CocoaPods 操作 ==================================
ensure_cocoapods() {
  ensure_command pod "请先安装 CocoaPods，例如: sudo gem install cocoapods"
}

run_pod_lib_lint() {
  info_echo "开始执行 pod lib lint --allow-warnings $PODSPEC_BASENAME"
  # 这里实际用的是你选择的 podspec 路径；通常文件名和 s.name 一致
  if pod lib lint --allow-warnings "$PODSPEC_PATH"; then
    success_echo "✅ pod lib lint 校验通过"
  else
    error_echo "❌ pod lib lint 校验失败，发布流程终止。"
    exit 1
  fi
}

maybe_trunk_register() {
  warm_echo "pod trunk register 一般只在首次使用该邮箱时需要执行。"
  echo "是否现在执行 pod trunk register? [y/N]"
  printf "> "
  local ans
  IFS= read -r ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    note_echo "跳过 pod trunk register。"
    return
  fi

  local email
  while :; do
    warm_echo "请输入用于 CocoaPods trunk 的注册邮箱："
    printf "> "
    IFS= read -r email
    if [[ -n "$email" ]]; then
      break
    fi
    warn_echo "邮箱不能为空。"
  done

  info_echo "执行: pod trunk register $email 'Jobs' --description='$PODSPEC_BASENAME'"
  if pod trunk register "$email" 'Jobs' --description="$PODSPEC_BASENAME"; then
    success_echo "已发起 trunk 注册请求。"
    note_echo "请前往邮箱查收 CocoaPods 发来的确认邮件并完成验证后再继续发布。"
  else
    error_echo "pod trunk register 执行失败，你可以手动检查原因或稍后重试。"
  fi
}

push_to_trunk() {
  info_echo "准备执行 pod trunk push $PODSPEC_BASENAME --allow-warnings"
  warm_echo "确保该 Pod 已完成 trunk 邮箱验证，并且本地 'pod trunk me' 状态正常。"
  echo "按 [Enter] 继续推送，或 Ctrl+C 取消。"
  IFS= read -r _

  if pod trunk push "$PODSPEC_PATH" --allow-warnings; then
    success_echo "✅ pod trunk push 成功 ($POD_NAME $POD_VERSION)"
  else
    error_echo "❌ pod trunk push 失败，请检查错误信息。"
    exit 1
  fi
}

show_trunk_info() {
  info_echo "查询 trunk 上的 Pod 信息: $POD_NAME"
  if pod trunk info "$POD_NAME"; then
    success_echo "已展示 pod trunk info $POD_NAME"
  else
    warn_echo "pod trunk info 查询失败，请确认该 Pod 是否已成功发布。"
  fi
}

# ================================== main ==================================
main() {
  init_log
  bold_echo "========== CocoaPods 发布辅助脚本 (${SCRIPT_BASENAME}) =========="
  gray_echo "脚本路径: $SCRIPT_PATH"

  # 1. 自检 / 安装 Homebrew + fzf
  install_homebrew
  install_fzf
  ensure_cocoapods

  # 2. 选择 podspec & 解析 name/version
  select_podspec_in_script_dir
  read_podspec_metadata

  # 3. lint 通过再继续
  run_pod_lib_lint

  # 4. trunk register（可选，通常只需要一次）
  maybe_trunk_register

  # 5. push & 查看 info
  push_to_trunk
  show_trunk_info

  success_echo "🎉 发布流程结束。"
}

main "$@"

