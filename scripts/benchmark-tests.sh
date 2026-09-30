#!/bin/bash

# テスト実行時間ベンチマークスクリプト
# シミュレータ事前起動の効果を測定

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# 設定 (パスはスクリプトの位置から解決するので、どの cwd から実行してもよい)
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
PROJECT_PATH="$SCRIPT_DIR/../app/OtetsudaiCoin.xcodeproj"
SCHEME="OtetsudaiCoin"
TEST_TARGET="OtetsudaiCoinTests/AllowanceCalculatorTests"
BENCHMARK_ITERATIONS="${BENCHMARK_ITERATIONS:-3}"
UDID=""  # main で 1 台に決める (Issue #224)

# カラー出力関数。ログは stderr に出す: measure_test_time は stdout で平均値を返し、
# main が $(...) で受け取るため、ログが stdout に混ざると bc が Parse error になる (Issue #229)。
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1" >&2
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1" >&2
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1" >&2
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

# 計測対象のシミュレータだけをシャットダウンする。`shutdown all` は並行して動く
# 別セッションのシミュレータまで落とすので使わない (Issue #224)。
shutdown_simulator() {
    log_info "シミュレータ ($UDID) をシャットダウン中..."
    xcrun simctl shutdown "$UDID" 2>/dev/null || true
    sleep 3
}

# テスト実行時間を測定
measure_test_time() {
    local description="$1"
    local warm_start="$2"
    
    log_info "=== $description ==="
    
    local total_time=0
    local times=()
    
    for i in $(seq 1 $BENCHMARK_ITERATIONS); do
        log_info "実行 $i/$BENCHMARK_ITERATIONS..."
        
        # クリーンスレート: シミュレータをシャットダウン
        if [ "$warm_start" = "false" ]; then
            shutdown_simulator
        fi
        
        # シミュレータ事前起動（warm start の場合）
        if [ "$warm_start" = "true" ]; then
            "$SCRIPT_DIR/prepare-simulator.sh" -d "$UDID" >/dev/null 2>&1 || true
        fi
        
        # テスト実行時間を測定
        local start_time=$(date +%s.%N)
        
        xcodebuild test \
            -project "$PROJECT_PATH" \
            -scheme "$SCHEME" \
            -destination "id=$UDID" \
            -only-testing:"$TEST_TARGET" \
            >/dev/null 2>&1
        
        local end_time=$(date +%s.%N)
        local execution_time=$(echo "$end_time - $start_time" | bc)
        
        times+=("$execution_time")
        total_time=$(echo "$total_time + $execution_time" | bc)
        
        log_info "実行時間: ${execution_time}秒"
    done
    
    # 平均時間を計算
    local average_time=$(echo "scale=2; $total_time / $BENCHMARK_ITERATIONS" | bc)
    
    log_success "$description の平均実行時間: ${average_time}秒"
    
    # 個別実行時間を表示
    log_info "個別実行時間:"
    for i in "${!times[@]}"; do
        log_info "  実行 $((i+1)): ${times[i]}秒"
    done
    
    echo "$average_time"
}

# メイン実行
main() {
    log_info "=== テスト実行時間ベンチマーク開始 ==="
    JQ="$(resolve_jq)" || { log_error "動作する jq が見つかりません (brew install jq)"; exit 1; }
    UDID="$(resolve_udid "$SIMULATOR_NAME")"
    [[ -n "$UDID" ]] || { log_error "シミュレータ '$SIMULATOR_NAME' が見つかりません"; exit 1; }
    log_info "シミュレータ: $SIMULATOR_NAME ($UDID)"
    log_info "テストターゲット: $TEST_TARGET"
    log_info "ベンチマーク反復回数: $BENCHMARK_ITERATIONS"
    echo
    
    # 事前準備
    log_info "事前準備: 計測対象のシミュレータをシャットダウン"
    shutdown_simulator
    
    # コールドスタート測定
    local cold_time=$(measure_test_time "コールドスタート（シミュレータ事前起動なし）" "false")
    echo
    
    # ウォームスタート測定
    local warm_time=$(measure_test_time "ウォームスタート（シミュレータ事前起動あり）" "true")
    echo
    
    # 結果比較
    log_info "=== ベンチマーク結果比較 ==="
    log_info "コールドスタート平均時間: ${cold_time}秒"
    log_info "ウォームスタート平均時間: ${warm_time}秒"
    
    # 平均値が数値でなければ比較できない。黙って「改善効果なし」にせず失敗させる (Issue #229)
    local t
    for t in "$cold_time" "$warm_time"; do
        if ! [[ "$t" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            log_error "平均時間が数値ではありません: '$t'"
            exit 1
        fi
    done

    # 改善効果を計算
    local improvement=$(echo "scale=2; $cold_time - $warm_time" | bc)
    local improvement_percent=$(echo "scale=1; $improvement * 100 / $cold_time" | bc)
    
    if (( $(echo "$improvement > 0" | bc -l) )); then
        log_success "改善効果: ${improvement}秒短縮 (${improvement_percent}%改善)"
    else
        log_warning "改善効果なし: ${improvement}秒 (${improvement_percent}%)"
    fi
    
    log_success "ベンチマーク完了"
}

# エラーハンドリング
trap 'log_error "ベンチマークが中断されました"; exit 1' ERR

# メイン実行
main