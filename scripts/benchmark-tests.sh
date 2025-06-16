#!/bin/bash

# テスト実行時間ベンチマークスクリプト
# シミュレータ事前起動の効果測定用

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

# テスト実行関数
run_test_benchmark() {
    local test_name="$1"
    local test_target="$2"
    
    log_info "テスト実行: $test_name"
    
    local start_time=$(date +%s.%N)
    
    if xcodebuild test \
        -project app/OtetsudaiCoin.xcodeproj \
        -scheme OtetsudaiCoin \
        -destination 'platform=iOS Simulator,name=iPhone 16' \
        -only-testing:"$test_target" \
        > /dev/null 2>&1; then
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        
        log_success "テスト完了: ${duration}秒"
        echo "$duration"
    else
        log_error "テスト失敗: $test_name"
        echo "ERROR"
    fi
}

# メイン処理
main() {
    log_info "=== テスト実行時間ベンチマーク開始 ==="
    
    # テスト対象
    local test_target="OtetsudaiCoinTests/CoinAnimationViewTests/testCoinAnimationViewDisplaysCoin"
    
    # シミュレータをシャットダウン
    log_info "シミュレータをシャットダウン中..."
    xcrun simctl shutdown all > /dev/null 2>&1 || true
    
    # ベースライン測定（シミュレータ停止状態から）
    log_info "=== ベースライン測定（シミュレータ停止状態） ==="
    local baseline_time
    baseline_time=$(run_test_benchmark "ベースライン" "$test_target")
    
    if [[ "$baseline_time" == "ERROR" ]]; then
        log_error "ベースライン測定に失敗しました"
        exit 1
    fi
    
    # シミュレータを事前起動
    log_info "=== シミュレータ事前起動 ==="
    /Users/shinya/workspace/claude/OtetsudaiCoin/scripts/prepare-simulator.sh -s "iPhone 16" > /dev/null 2>&1
    
    # ウォームアップ後の測定
    log_info "=== ウォームアップ後測定（シミュレータ起動済み） ==="
    local warmup_time
    warmup_time=$(run_test_benchmark "ウォームアップ後" "$test_target")
    
    if [[ "$warmup_time" == "ERROR" ]]; then
        log_error "ウォームアップ後測定に失敗しました"
        exit 1
    fi
    
    # 結果比較
    log_info "=== 結果比較 ==="
    log_info "ベースライン（シミュレータ停止状態）: ${baseline_time}秒"
    log_info "ウォームアップ後（シミュレータ起動済み）: ${warmup_time}秒"
    
    local improvement=$(echo "$baseline_time - $warmup_time" | bc)
    local improvement_percent=$(echo "scale=1; ($improvement / $baseline_time) * 100" | bc)
    
    if (( $(echo "$improvement > 0" | bc -l) )); then
        log_success "改善効果: ${improvement}秒短縮 (${improvement_percent}%向上)"
    else
        log_warning "改善効果は確認されませんでした"
    fi
    
    log_success "=== ベンチマーク完了 ==="
}

# スクリプト実行
main "$@"