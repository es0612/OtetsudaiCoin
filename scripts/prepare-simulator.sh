#!/bin/bash

# シミュレータ事前起動スクリプト
# テスト実行時間短縮のためシミュレータを事前に起動・ウォームアップする

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# カラー出力用の定数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# デフォルト設定
SIMULATOR_NAME="iPhone 17"
SIMULATOR_UDID=""
WARMUP_TIMEOUT=30
VERBOSE=false

# ヘルプ表示
show_help() {
    cat << EOF
シミュレータ事前起動スクリプト

使用方法:
  $0 [オプション]

オプション:
  -s, --simulator NAME     シミュレータ名 (デフォルト: iPhone 17)。同名が複数あれば起動済みを優先して 1 台に決める
  -d, --udid UDID          起動する端末を UDID で直接指定 (-s より優先)
  -t, --timeout SECONDS   ウォームアップタイムアウト (デフォルト: 30秒)
  -v, --verbose           詳細ログ出力
  -h, --help              このヘルプを表示

例:
  $0                              # デフォルト設定で実行
  $0 -s "iPhone 15"               # iPhone 15シミュレータを起動
  $0 -t 60 -v                     # 60秒タイムアウト、詳細ログ出力
EOF
}

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--simulator)
            SIMULATOR_NAME="$2"
            shift 2
            ;;
        -d|--udid)
            SIMULATOR_UDID="$2"
            shift 2
            ;;
        -t|--timeout)
            WARMUP_TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# 詳細ログ関数
verbose_log() {
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "$1"
    fi
}

# 対象端末の UDID を決める。同名の端末が複数あるため name 一致の grep ではなく
# resolve_udid (lib/common.sh) で 1 台に決める (Issue #224)。
resolve_target_udid() {
    if [[ -n "$SIMULATOR_UDID" ]]; then
        printf '%s\n' "$SIMULATOR_UDID"
        return 0
    fi
    resolve_udid "$SIMULATOR_NAME"
}

# 端末の状態 (Booted / Shutdown / ...) を返す。見つからなければ空。
# ログは stderr へ出す (stdout は呼び出し側の $(...) が値として受け取る)。
simulator_state() {
    local udid="$1"
    xcrun simctl list devices -j \
        | "$JQ" -r --arg u "$udid" '[.devices[][] | select(.udid == $u)][0].state // empty'
}

# シミュレータ起動
boot_simulator() {
    local device_id="$1"
    local simulator_name="$2"
    
    log_info "シミュレータ '$simulator_name' を起動中..."
    
    if xcrun simctl boot "$device_id" 2>/dev/null; then
        log_success "シミュレータの起動を開始しました"
        return 0
    else
        log_warning "シミュレータは既に起動済みまたは起動中です"
        return 0
    fi
}

# シミュレータウォームアップ
warmup_simulator() {
    local device_id="$1"
    local simulator_name="$2"
    local timeout="$3"
    
    log_info "シミュレータのウォームアップ中... (最大${timeout}秒)"

    # 起動完了は `simctl bootstatus -b` で待つ。以前の「launchctl print system に
    # SpringBoard が出るか」判定は iOS 26 ランタイムでは出てこず、常にタイムアウトしていた
    # (Issue #224)。bootstatus にはタイムアウト指定が無いので、裏で動かして -t 秒で打ち切る。
    xcrun simctl bootstatus "$device_id" -b >/dev/null 2>&1 &
    local waiter=$!
    local elapsed=0
    local interval=2

    while [[ $elapsed -lt $timeout ]]; do
        if ! kill -0 "$waiter" 2>/dev/null; then
            if wait "$waiter"; then
                log_success "シミュレータのウォームアップが完了しました (${elapsed}秒)"
                return 0
            fi
            log_warning "bootstatus が失敗しました"
            return 1
        fi
        verbose_log "ウォームアップ待機中... (${elapsed}/${timeout}秒)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    kill "$waiter" 2>/dev/null || true
    log_warning "ウォームアップがタイムアウトしました (${timeout}秒)"
    return 1
}

# ランタイム情報表示
show_runtime_info() {
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "=== ランタイム情報 ==="
        log_info "Xcode: $(xcodebuild -version | head -1)"
        log_info "iOS SDK: $(xcrun --show-sdk-version --sdk iphoneos)"
        log_info "シミュレータSDK: $(xcrun --show-sdk-version --sdk iphonesimulator)"
        log_info "利用可能メモリ: $(free -h 2>/dev/null | grep 'Mem:' | awk '{print $7}' || echo 'N/A')"
        log_info "===================="
    fi
}

# メイン処理
main() {
    log_info "=== シミュレータ事前起動スクリプト開始 ==="
    
    # ランタイム情報表示
    show_runtime_info
    
    JQ="$(resolve_jq)" || {
        log_error "動作する jq が見つかりません。brew install jq でインストールしてください"
        exit 1
    }

    local device_id
    device_id="$(resolve_target_udid)"
    local status=""
    [[ -n "$device_id" ]] && status="$(simulator_state "$device_id")"
    if [[ -z "$status" ]]; then
        log_error "シミュレータが見つかりません (名前: '$SIMULATOR_NAME', UDID: '${SIMULATOR_UDID:-未指定}')"
        log_info "利用可能なシミュレータ一覧:"
        xcrun simctl list devices available | grep "iPhone\|iPad" | head -10
        exit 1
    fi
    log_success "対象シミュレータ: $SIMULATOR_NAME ($device_id, $status)"

    # 状態に応じた処理
    case "$status" in
        "Booted")
            log_success "シミュレータは既に起動済みです"
            ;;
        "Shutdown")
            # シミュレータ起動
            if boot_simulator "$device_id" "$SIMULATOR_NAME"; then
                # ウォームアップ
                warmup_simulator "$device_id" "$SIMULATOR_NAME" "$WARMUP_TIMEOUT"
            fi
            ;;
        *)
            log_warning "不明なシミュレータ状態: $status"
            # シミュレータを起動してみる
            if boot_simulator "$device_id" "$SIMULATOR_NAME"; then
                warmup_simulator "$device_id" "$SIMULATOR_NAME" "$WARMUP_TIMEOUT"
            fi
            ;;
    esac
    
    log_success "=== シミュレータ準備完了 ==="
}

# スクリプト実行
main "$@"