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
        self?.handle(.timerFired(value))
    }

    private lazy var stateSubject = PassthroughSubject<State, Never>()
    var stateSequence: StateSequence { stateSubject.eraseToAnyPublisher().values }

    private var levelIsComplete: Bool {
        state.solvedRows.count == Self.requiredRowsCleared
    }

    init(_ settings: Settings) {
        self.settings = settings
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

    func handle(_ event: Event) {
        defer {
            stateSubject.send(state)
        }
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
        case .timerFired(let value):
            handleTimer(value)
        case .selectionUpdate(let selection):
            executeUpdate(for: selection)
        case .solvedRow(let rowId):
            removeSolvedRow(with: rowId)
        case .emptyBoard:
            startRows()
        case .scoreChangeExpired(let scoreChange):
            removeExpiredScoreChange(scoreChange)
        }
    }

    private func schedule(event: Event, delay: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            self?.handle(event)
        }
    }

    private func handleGameDidAppear() {
        schedule(event: .newGame, delay: 750)
    }

    private func handleSelected(_ token: Token) {
        process(selectedToken: token)
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
        state.gamePhase = nil
        startRows()
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
    }

    private func handleCloseEvent(_ event: Event) {
        if case .closeSelected = event, !gameIsOver {
            timer.cancel()
            state.gamePhase = .gamePaused
        } else {
            state.gamePhase = .gameDismissed
        }
    }

    private func handleResume() {
        timer.resume()
        state.gamePhase = nil
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
        let selection = state.selections[selectionIndex]
        schedule(event: .selectionUpdate(selection), delay: 150)
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

    private func executeUpdate(for selection: Selection) {
        if selection.status != .rejected {
            updatePartialMatch(from: selection)
        }
        state.selections.removeAll { $0 == selection }
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
        schedule(event: .solvedRow(row.id), delay: 666)
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

    private func removeSolvedRow(with id: UUID) {
        guard let index = state.rows.firstIndex(where: { $0.id == id }) else {
            return
        }
        updateScore(for: index)
        state.rows.remove(at: index)
        if levelIsComplete {
            state.gamePhase = .levelComplete
        } else if state.rows.isEmpty {
            schedule(event: .emptyBoard, delay: 333)
        }
    }
}

// MARK: Score Management

extension GameLogic {

    private func updateScore(for rowIndex: Int) {
        let scoreChange = ScoreChange(challengeType: state.rows[rowIndex].challengeType)
        state.scoreChanges.append(scoreChange)
        schedule(event: .scoreChangeExpired(scoreChange), delay: 1000)
        state.score += scoreChange.value
    }

    private func removeExpiredScoreChange(_ scoreChange: ScoreChange) {
        guard state.scoreChanges.contains(scoreChange) else {
            return
        }
        state.scoreChanges.removeAll { $0.id == scoreChange.id }
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
