//
//  GameLogic.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 11/13/22.
//

import Foundation
import Combine

class GameLogic {

    typealias StateSequence = AsyncPublisher<AnyPublisher<State, Never>>

    private let settings: Settings
    private lazy var state = State()
    private lazy var rowGenerator = RowGenerator(settings)
    private lazy var statsStorage = StatsStorage(settings)

    private var gameIsOver: Bool {
        state.gamePhase == .gameOver
    }

    private lazy var timer = RowTimer { [weak self] value in
        self?.handleTimer(value)
    }

    private lazy var stateSubject = PassthroughSubject<State, Never>()
    var stateSequence: StateSequence { stateSubject.eraseToAnyPublisher().values }

    private var levelIsComplete: Bool {
        state.solvedRows.count == Self.requiredRowsCleared
    }

    private func sendState() {
        stateSubject.send(state)
    }

    init(_ settings: Settings) {
        self.settings = settings
    }

    private func startLevel() {
        if state.score > 0 {
            state.level += 1
            state.rows = []
            state.solvedRows = []
            state.selections = []
        }
        state.target = getTargetToken()
        state.gamePhase = .levelIntro
        timer.setTimeInterval(with: state.level, settings)
        sendState()
    }

    private func getTargetToken() -> Token {
        var randomToken = Token.random
        while randomToken.attributes == state.target?.attributes {
            randomToken = Token.random
        }
        return randomToken
    }
}


// MARK: Constants

extension GameLogic {
    static var gridSize: Int { 8 }
    static var requiredRowsCleared: Int { 10 }
}

// MARK: Event Handling

extension GameLogic {

    func handle(_ event: GameViewModel.Event) {
        switch event {
        case .gameAppeared:
            handleGameDidAppear()
        case .tokenSelected(let token):
            handleSelected(token)
        case .newGame:
            handleNewGame()
        case .levelTransition:
            handleLevelTransitionComplete()
        case .closeSelected, .closeConfirmed:
            handleCloseEvent(event)
        case .gameResumed:
            handleResume()
        }
    }

    private func handleGameDidAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750)) {
            self.handleNewGame()
        }
    }

    private func handleSelected(_ token: Token) {
        process(selectedToken: token)
        sendState()
    }

    private func handleNewGame() {
        state = State()
        startLevel()
    }

    private func handleLevelTransitionComplete() {
        guard case .levelIntro = state.gamePhase  else {
            startLevel()
            return
        }
        state.gamePhase = .gameActive
        startRows()
        sendState()
    }

    private func handleCloseEvent(_ event: GameViewModel.Event) {
        if case .closeSelected = event, !gameIsOver {
            timer.cancel()
            state.gamePhase = .gamePaused
        } else {
            state.gamePhase = .gameDismissed
        }
        sendState()
    }

    private func handleResume() {
        timer.resume()
        state.gamePhase = .gameActive
        sendState()
    }
}

// MARK: Selection Processing

extension GameLogic {

    private func canSelect(_ token: Token) -> Bool {
        guard !(levelIsComplete || gameIsOver) else {
            return false
        }
        let tokenIsInSolvedRow = isSolved(row: state.rows.first { $0.tokens.contains(token) })
        guard let selection = state.selections.first(where: { $0.tokens.contains(token) }),
              let selectedPair = selection.tokenPair
        else {
            return !tokenIsInSolvedRow
        }
        let tokenIsInSelectedPair = selectedPair.contains(token) && selection.status != .rejected
        return !(tokenIsInSelectedPair || tokenIsInSolvedRow)
    }

    private func process(selectedToken: Token) {
        guard canSelect(selectedToken) else {
            return
        }
        guard let selection = state.selections.last, selection.tokenPair == nil else {
            state.selections.append(Selection(selectedToken))
            return
        }
        process(selectedPair: TokenPair(token1: selection.token1, token2: selectedToken))
    }

    private func process(selectedPair: TokenPair) {
        guard let selectionIndex = state.selections.firstIndex(
            where: { $0.token1 == selectedPair.token1 }
        ) else {
            return
        }
        state.selections[selectionIndex].tokenPair = selectedPair
        let selectionStatus = getStatus(for: selectedPair)
        state.selections[selectionIndex].status = selectionStatus
        updateSolvedRows(with: selectionStatus, selectedPair)
        scheduleUpdate(for: state.selections[selectionIndex])
    }

    private func updateSolvedRows(with selectionStatus: Selection.Status, _ tokenPair: TokenPair) {
        guard selectionStatus == .targetMatch,
              let solvedRow = getRow(for: [tokenPair.token1])
        else {
            return
        }
        state.solvedRows.append(SolvedRow(row: solvedRow, targetPair: tokenPair))
    }

    private func getStatus(for tokenPair: TokenPair) -> Selection.Status {
        guard tokenPair.isPartialMatch,
              case .adjacent(let isHorizontal) = getAdjacencyResult(for: tokenPair)
        else {
            return .rejected
        }
        if isHorizontal && tokenPair.canConvert(to: state.target) {
            return .targetMatch
        }
        return .partialMatch
    }

    private func scheduleUpdate(for selection: Selection?) {
        guard let selection = selection else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) {
            self.executeUpdate(for: selection)
        }
    }

    private func executeUpdate(for selection: Selection) {
        if selection.status != .rejected {
            updatePartialMatch(from: selection)
        }
        state.selections.removeAll { $0 == selection }
        sendState()
    }

    private func updatePartialMatch(from selection: Selection) {
        guard let selectedPair = selection.tokenPair,
              let convertedTokens = convertPartialMatch(for: selectedPair)
        else {
            return
        }
        replace(selectedPair.token1, with: convertedTokens.token1)
        replace(selectedPair.token2, with: convertedTokens.token2)
        guard let row = getRow(for: [convertedTokens.token1, convertedTokens.token2]),
              isSolved(row: row)
        else {
            return
        }
        scheduleRemoval(rowId: row.id)
        guard levelIsComplete || state.rows.count == 1 else {
            return
        }
        timer.cancel()
        state.timerValue = 0
    }

    private func convertPartialMatch(for tokenPair: TokenPair) -> TokenPair? {
        guard let newToken1 = Token(partialMatch: tokenPair),
              let newToken2 = Token(partialMatch: tokenPair)
        else {
            return nil
        }
        return TokenPair(token1: newToken1, token2: newToken2)
    }

    private func replace(_ token: Token, with newToken: Token) {
        guard let coordinates = getCoordinates(for: token) else {
            return
        }
        state.rows[coordinates.row].tokens[coordinates.column] = newToken
    }
}

// MARK: Row Management

extension GameLogic {

    private var canAddRows: Bool {
        state.rows.filter { !isSolved(row: $0) }.count < Self.gridSize
    }

    private func startRows() {
        addRow()
        timer.start()
    }

    private func isSolved(row: Row?) -> Bool {
        guard let rowId = row?.id else {
            return false
        }
        return state.solvedRows.contains { $0?.id == rowId }
    }

    private func handleTimer(_ value: Int) {
        if timer.isFull {
            addRowOrEndGame()
        }
        state.timerValue = value
        sendState()
    }

    private func addRowOrEndGame() {
        guard canAddRows else {
            endGame()
            return
        }
        addRow()
    }

    private func addRow() {
        guard let row = rowGenerator.getNextRow(for: state) else {
            return
        }
        state.rows.insert(row, at: 0)
        updateTrainingHintStatus(with: row)
    }

    private func updateTrainingHintStatus(with row: Row) {
        guard settings.isTrainingMode else {
            return
        }
        state.nextTrainingHintToken = row.tokens.first { $0.shouldShowTrainingHint }
    }

    private func endGame() {
        state.gamePhase = .gameOver
        state.stats = statsStorage.getUpdatedStats(with: state)
        timer.cancel()
    }

    private func getRow(for tokens: [Token]) -> Row? {
        state.rows.first { row in
            tokens.allSatisfy { token in
                row.tokens.contains(token)
            }
        }
    }

    private func scheduleRemoval(rowId: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(666)) {
            self.removeRow(with: rowId)
        }
    }

    private func removeRow(with id: UUID) {
        guard let index = state.rows.firstIndex(where: { $0.id == id }) else {
            return
        }
        state.score += getScoreForRow(at: index)
        state.rows.remove(at: index)
        if levelIsComplete {
            state.gamePhase = .levelComplete
        } else if state.rows.isEmpty {
            startRows()
        }
        sendState()
    }

    private func getScoreForRow(at index: Int) -> Int {
        switch state.rows[index].challengeType {
        case .uniform: return 10
        case .wildcardRow: return 20
        default: return 5
        }
    }
}

// MARK: Token Helpers

extension GameLogic {

    private func getAdjacencyResult(for tokenPair: TokenPair) -> AdjacencyResult? {
        if let token1Coordinates = getCoordinates(for: tokenPair.token1),
           let token2Coordinates = getCoordinates(for: tokenPair.token2) {
            if valuesFitAdjacency(
                matchingValues: (token1Coordinates.row, token2Coordinates.row),
                adjacentValues: (token1Coordinates.column, token2Coordinates.column)
            ) {
                return .adjacent(isHorizontal: true)
            }
            if valuesFitAdjacency(
                matchingValues: (token1Coordinates.column, token2Coordinates.column),
                adjacentValues: (token1Coordinates.row, token2Coordinates.row)
            ) {
                return .adjacent(isHorizontal: false)
            }
        }
        return .notAdjacent
    }

    private func valuesFitAdjacency(
        matchingValues: (Int, Int),
        adjacentValues: (Int, Int)
    ) -> Bool {
        matchingValues.0 == matchingValues.1 && abs(adjacentValues.0 - adjacentValues.1) == 1
    }

    private func getCoordinates(for token: Token) -> (column: Int, row: Int)? {
        let rows = state.rows
        guard let row = rows.firstIndex(where: { $0.tokens.contains(token) }),
              let column = rows[row].tokens.firstIndex(where: { $0 == token })
        else {
            return nil
        }
        return (column, row)
    }
}
