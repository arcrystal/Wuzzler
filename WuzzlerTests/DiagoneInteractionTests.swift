import XCTest
@testable import Wuzzler

@MainActor
final class DiagoneInteractionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearDiagoneDefaults()
    }

    override func tearDown() {
        clearDiagoneDefaults()
        super.tearDown()
    }

    func testTapOnPlacedChipReturnsItToTray() throws {
        let viewModel = try makeStartedViewModel()
        let placement = try placeFirstAvailablePiece(in: viewModel)

        viewModel.handleTap(on: placement.targetId)

        XCTAssertNil(viewModel.engine.state.pieces.first(where: { $0.id == placement.pieceId })?.placedOn)
        XCTAssertNil(viewModel.engine.state.targets.first(where: { $0.id == placement.targetId })?.pieceId)
        XCTAssertFalse(viewModel.fadingPanePieceIds.contains(placement.pieceId))
    }

    func testBoardCellTapReturnsPlacedChipToTray() throws {
        let viewModel = try makeStartedViewModel()
        let placement = try placeFirstAvailablePiece(in: viewModel)
        let target = try XCTUnwrap(viewModel.engine.state.targets.first(where: { $0.id == placement.targetId }))
        let tappedCell = try XCTUnwrap(target.cells.first)

        viewModel.handleTap(at: tappedCell)

        XCTAssertNil(viewModel.engine.state.pieces.first(where: { $0.id == placement.pieceId })?.placedOn)
        XCTAssertNil(viewModel.engine.state.targets.first(where: { $0.id == placement.targetId })?.pieceId)
        XCTAssertFalse(viewModel.fadingPanePieceIds.contains(placement.pieceId))
    }

    func testDraggingPlacedChipIntoTrayReturnsItToTray() throws {
        let viewModel = try makeStartedViewModel()
        let placement = try placeFirstAvailablePiece(in: viewModel)
        viewModel.boardFrameGlobal = CGRect(x: 0, y: 0, width: 360, height: 360)
        viewModel.chipTrayFrameGlobal = CGRect(x: 0, y: 440, width: 360, height: 220)

        viewModel.beginDraggingFromBoard(targetId: placement.targetId, fingerGlobal: CGPoint(x: 24, y: 24))
        viewModel.updateDrag(globalLocation: CGPoint(x: 180, y: 520))
        viewModel.finishDrag()

        XCTAssertNil(viewModel.engine.state.pieces.first(where: { $0.id == placement.pieceId })?.placedOn)
        XCTAssertNil(viewModel.engine.state.targets.first(where: { $0.id == placement.targetId })?.pieceId)
        XCTAssertFalse(viewModel.fadingPanePieceIds.contains(placement.pieceId))
    }

    func testDraggingPlacedChipOutsideTrayRestoresOriginalTarget() throws {
        let viewModel = try makeStartedViewModel()
        let placement = try placeFirstAvailablePiece(in: viewModel)
        viewModel.boardFrameGlobal = CGRect(x: 0, y: 0, width: 360, height: 360)
        viewModel.chipTrayFrameGlobal = CGRect(x: 0, y: 440, width: 360, height: 220)

        viewModel.beginDraggingFromBoard(targetId: placement.targetId, fingerGlobal: CGPoint(x: 24, y: 24))
        viewModel.updateDrag(globalLocation: CGPoint(x: 420, y: 380))
        viewModel.finishDrag()

        XCTAssertEqual(viewModel.engine.state.pieces.first(where: { $0.id == placement.pieceId })?.placedOn, placement.targetId)
        XCTAssertEqual(viewModel.engine.state.targets.first(where: { $0.id == placement.targetId })?.pieceId, placement.pieceId)
        XCTAssertTrue(viewModel.fadingPanePieceIds.contains(placement.pieceId))
    }

    private func makeStartedViewModel() throws -> GameViewModel {
        let launchDate = try XCTUnwrap(PuzzleDay.date(fromStorageKey: "2026-06-01"))
        let viewModel = GameViewModel(puzzleDate: launchDate, countsTowardStats: false)
        viewModel.startGame()
        return viewModel
    }

    private func placeFirstAvailablePiece(in viewModel: GameViewModel) throws -> (pieceId: String, targetId: String) {
        let piece = try XCTUnwrap(viewModel.engine.state.pieces.first)
        let targetId = try XCTUnwrap(viewModel.validTargets(for: piece.id).first)

        XCTAssertTrue(viewModel.handleDrop(pieceId: piece.id, onto: targetId))
        XCTAssertEqual(viewModel.engine.state.pieces.first(where: { $0.id == piece.id })?.placedOn, targetId)
        return (piece.id, targetId)
    }

    private func clearDiagoneDefaults() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("diagone") {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
