//
//  GameLogic.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 11/13/22.
//

import Foundation
import Combine

class GameLogic {

    private lazy var state = State()
    private var selection: Selection?

    private lazy var timer = RowTimer { [weak self] value in
        self?.handleTimer(value)
    }

    private lazy var stateSubject = PassthroughSubject<State, Never>()
    var stateSequence: AsyncPublisher<AnyPublisher<State, Never>> {
        AsyncPublisher(stateSubject.eraseToAnyPublisher())
    }

    private var levelIsComplete: Bool {
        state.rowsCleared + solvedRowCount == Self.requiredRowsCleared
    }

    private var solvedRowCount: Int {
        state.rows.filter { $0.isSolved }.count
    }

    private func sendState() {
        stateSubject.send(state)
    }

    private func startLevel() {
        if state.score > 0 {
            state.level += 1
            state.rows = []
            state.rowsCleared = 0
            selection = nil
        }
        state.target = getKeyToken()
        state.gamePhase = .levelIntro
        sendState()
    }

    private func getKeyToken() -> Token {
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

// MARK: View Event Handling

extension GameLogic {

    func handle(event: Event) {
        switch event {
        case .selectedToken(let token):
            handleSelected(token)
        case .newGame:
            handleNewGame()
        case .levelTransitionComplete:
            handleLevelTransitionComplete()
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
        guard state.gamePhase == .levelIntro else {
            startLevel()
            return
        }
        state.gamePhase = .gameActive
        startRows()
        sendState()
    }
}

// MARK: Selection Processing

extension GameLogic {

    private func canSelect(_ token: Token) -> Bool {
        guard !(levelIsComplete || state.gamePhase == .gameOver) else {
            return false
        }
        let tokenIsInSolvedRow = state.rows.first { $0.tokens.contains(token) }?.isSolved == true
        guard let selectedPair = selection?.tokenPair else {
            return !tokenIsInSolvedRow
        }
        let tokenIsInSelectedPair = selectedPair.contains(token) && token.status == .selected
        return !(tokenIsInSelectedPair || tokenIsInSolvedRow)
    }

    private func process(selectedToken: Token) {
        guard canSelect(selectedToken) else {
            return
        }
        guard let selection = selection, selection.tokenPair == nil else {
            setSelection(with: selectedToken)
            return
        }
        let tokenPair = TokenPair(token1: selection.token1, token2: selectedToken)
        tokenPair.set(status: getStatus(for: tokenPair))
        selection.tokenPair = tokenPair
        scheduleUpdate(for: selection)
    }

    private func setSelection(with token: Token) {
        selection?.tokenPair?.set(status: nil)
        selection = Selection(token1: token)
    }

    private func getStatus(for tokenPair: TokenPair) -> Token.Status {
        guard tokenPair.isPartialMatch,
              case .adjacent(let isHorizontal) = getAdjacencyResult(for: tokenPair)
        else {
            return .rejected
        }
        if isHorizontal && tokenPair.canConvert(to: state.target) {
            return .targetMatch
        }
        return .selected
    }

    private func scheduleUpdate(for selection: Selection) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) {
            self.executeUpdate(for: selection)
        }
    }

    private func executeUpdate(for selection: Selection) {
        guard self.selection === selection else {
            return
        }
        if selection.token1.status != .rejected {
            updatePartialMatch(from: selection)
        } else {
            selection.tokenPair?.set(status: nil)
        }
        sendState()
        self.selection = nil
    }

    private func updatePartialMatch(from selection: Selection) {
        guard let convertedTokens = convertPartialMatch(),
              let row = getRow(for: [convertedTokens.token1, convertedTokens.token2]),
              row.isSolved
        else {
            return
        }
        [convertedTokens.token1, convertedTokens.token2].set(status: .targetMatch)
        scheduleRemoval(rowId: row.id)
        guard levelIsComplete || state.rows.count == 1 else {
            return
        }
        timer.cancel()
        state.timerValue = 0
    }

    private func convertPartialMatch() -> TokenPair? {
        let isTargetMatch = selection?.token1.status == .targetMatch
        guard let tokenPair = selection?.tokenPair,
              let newToken1 = Token(partialMatch: tokenPair),
              let newToken2 = Token(partialMatch: tokenPair)
        else {
            return nil
        }
        replace(tokenPair.token1, with: newToken1)
        replace(tokenPair.token2, with: newToken2)
        let newTokenPair = TokenPair(token1: newToken1, token2: newToken2)
        if isTargetMatch {
            newTokenPair.set(status: .targetMatch)
        }
        return newTokenPair
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
        state.rows.count - solvedRowCount < Self.gridSize
    }

    private func startRows() {
        addRow()
        timer.start()
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
        state.rows.insert(makeRow(), at: 0)
    }

    private func endGame() {
        state.gamePhase = .gameOver
        timer.cancel()
    }

    private func getRow(for tokens: [Token]) -> Row? {
        state.rows.first { row in
            tokens.allSatisfy { token in
                row.tokens.contains(token)
            }
        }
    }

    private func makeRow() -> Row {
        guard let keyToken = state.target else {
            return Row(tokens: [])
        }
        let tokens = (0..<Self.gridSize).map { index in
            if index < 2 {
                return Token(Token.Color.allCases.filter({ $0 != keyToken.attributes.color })[index], keyToken.attributes.icon)
            }
            return Token.random
        }
        let row = Row(tokens: tokens)
        return row
    }

    private func scheduleRemoval(rowId: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(666)) {
            self.removeRow(with: rowId)
        }
    }

    private func removeRow(with id: UUID) {
        state.rows.removeAll { $0.id == id }
        state.rowsCleared += 1
        state.score += 5
        if levelIsComplete {
            state.gamePhase = .levelComplete
        } else if state.rows.isEmpty {
            startRows()
        }
        sendState()
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
              let column = rows[row].tokens.firstIndex(where: { $0 === token })
        else {
            return nil
        }
        return (column, row)
    }
}
