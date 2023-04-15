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
        guard let selection = selection else {
            return !tokenIsInSolvedRow
        }
        let tokenIsInSelectedPair = (
            selection.tokens.contains(token)
            && selection.tokens.count == 2
            && selection.token1.status == .selected
        )
        return !(tokenIsInSelectedPair || tokenIsInSolvedRow)
    }

    private func process(selectedToken: Token) {
        guard canSelect(selectedToken) else {
            return
        }
        if let selection = selection, selection.token2 == nil {
            selection.token2 = selectedToken
            selection.tokens.set(status: getStatus(for: selection))
            scheduleUpdate(for: selection)
        } else {
            selection?.tokens.set(status: nil)
            selection = Selection(token1: selectedToken)
            selectedToken.status = .selected
        }
    }

    private func getStatus(for selection: Selection) -> Token.Status {
        let token1 = selection.token1
        guard let token2 = selection.token2 else {
            return .selected
        }

        switch getAdjacencyResult(token1, token2) {
        case .notAdjacent:
            return .rejected
        case .adjacent(let isHorizontal):
            guard isPartialMatch(token1, token2) else {
                return .rejected
            }
            if isHorizontal, let rowIndex = getSolvedRowIndex(token1, token2) {
                state.rows[rowIndex].isSolved = true
                return .targetMatch
            }
            return .selected
        }
    }

    private func getSolvedRowIndex(_ token1: Token, _ token2: Token) -> Int? {
        guard areTargetMatch([token1, token2]) else {
            return nil
        }
        return state.rows.firstIndex(where: { $0.tokens.contains(token1) })
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
            selection.tokens.set(status: nil)
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

    private func convertPartialMatch() -> (token1: Token, token2: Token)? {
        guard let token1 = selection?.token1,
              let token2 = selection?.token2,
              let newToken1 = getFullMatchToken(token1, token2),
              let newToken2 = getFullMatchToken(token1, token2)
        else {
            return nil
        }
        replace(token1, with: newToken1)
        replace(token2, with: newToken2)
        return (newToken1, newToken2)
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

    private func getAdjacencyResult(_ token1: Token, _ token2: Token) -> AdjacencyResult {
        if let token1Coordinates = getCoordinates(for: token1),
           let token2Coordinates = getCoordinates(for: token2) {
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

    private func isPartialMatch(_ token1: Token, _ token2: Token) -> Bool {
        token1.attributes != token2.attributes
        && (
            token1.attributes.color == token2.attributes.color
            || token1.attributes.icon == token2.attributes.icon
        )
    }

    private func getFullMatchToken(_ token1: Token, _ token2: Token) -> Token? {
        guard isPartialMatch(token1, token2) else { return nil }
        let color: Token.Color?
        let icon: Token.Icon?
        if token1.attributes.color == token2.attributes.color {
            color = token1.attributes.color
            icon = Token.Icon.allCases.first {
                ![token1.attributes.icon, token2.attributes.icon].contains($0)
            }
        } else {
            icon = token1.attributes.icon
            color = Token.Color.allCases.first {
                ![token1.attributes.color, token2.attributes.color].contains($0)
            }
        }
        guard let color = color, let icon = icon else { return nil }
        return Token(color, icon)
    }

    private func areTargetMatch(_ tokens: [Token]) -> Bool {
        guard tokens.count == 2,
              let token1 = tokens.first,
              let token2 = tokens.last,
              let convertedToken = getFullMatchToken(token1, token2)
        else {
            return false
        }
        return convertedToken.attributes == state.target?.attributes
    }
}
