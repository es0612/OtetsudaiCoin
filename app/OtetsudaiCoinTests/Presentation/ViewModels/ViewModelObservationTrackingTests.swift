import XCTest
import Observation
@testable import OtetsudaiCoin

/// `BaseViewModel` を継承した ViewModel の「サブクラスで新規宣言した stored property」が
/// Observation で追跡されるか（= SwiftUI View が再描画されるか）を検証する。
///
/// 通常の ViewModel テストはプロパティを直接読むため observation の有無に関わらず PASS してしまい、
/// 壊れた SwiftUI reactivity を検知できない。`withObservationTracking` のみがこれを判別できる。
///
/// 検証対象は **必ずサブクラスで宣言したプロパティ**にする。`isLoading` / `errorMessage` は
/// 基底 `BaseViewModel` の `@Observable` マクロが変換済みで、サブクラス側の `@Observable` 付与有無に
/// 関わらず常に追跡されるため、判別材料にならない（false "動いている" を生む）。
///
/// #145: `@Observable` を継承サブクラスへ再付与する必要があるか（付与しないと新規 stored property が
/// 追跡されないか）を実証し、全継承 VM で付与を統一する根拠とする。
@MainActor
final class ViewModelObservationTrackingTests: XCTestCase {

    /// サブクラスで宣言したプロパティ変更で `onChange` が同期発火することを確認するヘルパ。
    /// `withObservationTracking(_:onChange:)` は apply クロージャで access したプロパティの
    /// 最初の `willSet` で `onChange` を **同期**発火する（非同期待ち不要 = flake しない）。
    private func assertTracksMutation(
        access: () -> Void,
        mutate: () -> Void
    ) -> Bool {
        var fired = false
        withObservationTracking {
            access()
        } onChange: {
            fired = true
        }
        mutate()
        return fired
    }

    // MARK: - ChildManagementViewModel（サブクラスで `children` を宣言）

    /// `ChildManagementViewModel.children` はサブクラス宣言プロパティ。
    /// `@Observable` がサブクラスに付与されていれば追跡され、View が更新される。
    func testChildManagementViewModelChildrenIsObservable() {
        let viewModel = ChildManagementViewModel(childRepository: MockChildRepository())
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")

        let fired = assertTracksMutation(
            access: { _ = viewModel.children },
            mutate: { viewModel.children = [child] }
        )

        XCTAssertTrue(
            fired,
            "ChildManagementViewModel.children の変更が Observation で追跡されていない。"
            + "サブクラスの新規 stored property は @Observable 再付与がないと追跡されず、"
            + "SwiftUI View が再描画されない（#145 の分裂で生じた潜在的 reactivity ギャップ）。"
        )
    }

    // MARK: - RecordViewModel（既に `@Observable` 再付与済み・対照群）

    /// `RecordViewModel` は既にサブクラスへ `@Observable` を再付与している。
    /// サブクラス宣言プロパティ `selectedChild` が追跡されることを対照群として確認する。
    func testRecordViewModelSubclassPropertyIsObservable() {
        let viewModel = RecordViewModel(
            childRepository: MockChildRepository(),
            helpTaskRepository: MockHelpTaskRepository(),
            helpRecordRepository: MockHelpRecordRepository(),
            soundService: MockSoundService()
        )
        let child = Child(id: UUID(), name: "花子", themeColor: "#33FF57")

        let fired = assertTracksMutation(
            access: { _ = viewModel.selectedChild },
            mutate: { viewModel.selectedChild = child }
        )

        XCTAssertTrue(
            fired,
            "RecordViewModel.selectedChild（@Observable 再付与済みサブクラス）が追跡されていない。"
        )
    }

    // MARK: - HomeViewModel（#145 で BaseViewModel 継承へ移行した VM）

    /// 移行後の VM でもサブクラス宣言プロパティ `children` が追跡されることを回帰ガードとして固定する。
    func testHomeViewModelSubclassPropertyIsObservable() {
        let viewModel = HomeViewModel(
            childRepository: MockChildRepository(),
            helpRecordRepository: MockHelpRecordRepository(),
            helpTaskRepository: MockHelpTaskRepository(),
            allowanceCalculator: MockAllowanceCalculator(),
            allowancePaymentRepository: MockAllowancePaymentRepository()
        )
        let child = Child(id: UUID(), name: "次郎", themeColor: "#3357FF")

        let fired = assertTracksMutation(
            access: { _ = viewModel.children },
            mutate: { viewModel.children = [child] }
        )

        XCTAssertTrue(
            fired,
            "HomeViewModel.children（BaseViewModel 継承へ移行後）が追跡されていない。"
        )
    }
}
