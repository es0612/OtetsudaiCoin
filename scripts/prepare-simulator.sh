#!/bin/bash

# シミュレータ事前起動スクリプト
# テスト実行時間短縮のためシミュレータを事前に起動・ウォームアップする

set -e

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
SIMULATOR_NAME="iPhone 16"
SIMULATOR_OS="iOS"
WARMUP_TIMEOUT=30
VERBOSE=false

# ヘルプ表示
show_help() {
    cat << EOF
シミュレータ事前起動スクリプト

使用方法:
  $0 [オプション]

オプション:
  -s, --simulator NAME     シミュレータ名 (デフォルト: iPhone 16)
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

# シミュレータの存在確認
check_simulator_exists() {
    local simulator_name="$1"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "シミュレータ '$simulator_name' の存在を確認中..."
    fi
    
    if xcrun simctl list devices available | grep -q "$simulator_name"; then
        log_success "シミュレータ '$simulator_name' が見つかりました"
        return 0
    else
        log_error "シミュレータ '$simulator_name' が見つかりません"
        log_info "利用可能なシミュレータ一覧:"
        xcrun simctl list devices available | grep "iPhone\|iPad" | head -10
        return 1
    fi
}

# シミュレータの起動状態確認
check_simulator_status() {
    local simulator_name="$1"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "シミュレータ '$simulator_name' の状態を確認中..."
    fi
    
    # 正確なシミュレータ名にマッチするようにパターンを調整
    local device_line=$(xcrun simctl list devices | grep "^ *$simulator_name (" | head -1)
    
    if [[ -z "$device_line" ]]; then
        log_error "シミュレータ '$simulator_name' のデバイス情報を取得できませんでした"
        log_info "利用可能なシミュレータ一覧:"
        xcrun simctl list devices available | grep "iPhone" | head -5
        return 1
    fi
    
    local device_id=$(echo "$device_line" | grep -o "[A-F0-9-]\{36\}")
    local status="Shutdown"
    
    if echo "$device_line" | grep -q "Booted"; then
        status="Booted"
    fi
    
    if [[ -z "$device_id" ]]; then
        log_error "デバイスIDを正しく取得できませんでした"
        log_error "デバイス行: $device_line"
        return 1
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "デバイスID: $device_id"
        log_info "現在の状態: $status"
    fi
    
    echo "$device_id:$status"
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
    
    local elapsed=0
    local interval=2
    
    while [[ $elapsed -lt $timeout ]]; do
        # Simulator.appが利用可能かチェック
        if xcrun simctl spawn "$device_id" launchctl print system 2>/dev/null | grep -q "SpringBoard"; then
            log_success "シミュレータのウォームアップが完了しました (${elapsed}秒)"
            return 0
        fi
        
        verbose_log "ウォームアップ待機中... (${elapsed}/${timeout}秒)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
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
    
    # シミュレータ存在確認
    if ! check_simulator_exists "$SIMULATOR_NAME"; then
        exit 1
    fi
    
    # シミュレータ状態取得
    local status_info
    status_info=$(check_simulator_status "$SIMULATOR_NAME")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    local device_id=$(echo "$status_info" | cut -d: -f1)
    local status=$(echo "$status_info" | cut -d: -f2)
    
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