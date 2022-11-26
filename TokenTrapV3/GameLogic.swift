//
//  GameLogic.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 11/13/22.
//

import Foundation

class GameLogic {

    enum AdjacencyResult {
        case notAdjacent
        case adjacentVertical
        case adjacentHorizontal
    }

    enum SelectionResult {
        case firstSelection
        case none(_ tokens: [Token])
        case partialMatch(_ tokens: [Token])
        case partialMatchKey(_ tokens: [Token])
    }

    private(set) lazy var rows: [[Token]] = []
    private var rowsCleared = 0
    private var keyToken: Token?
    private var selectedToken: Token?
    private var score = 0

    private var randomToken: Token {
        Token(.allCases.randomElement()!, .allCases.randomElement()!)
    }

    static var gridSize: Int { 8 }
    static var requiredRowsCleared: Int { 10 }

    var canAddRows: Bool {
        rows.count < Self.gridSize
    }

    var levelIsComplete: Bool {
        rowsCleared == Self.requiredRowsCleared
    }

    var rowsClearedStream: AsyncStream<Int> {
        AsyncStream {
            self.rowsCleared
        }
    }

    var scoreStream: AsyncStream<Int> {
        AsyncStream {
            self.score
        }
    }

    func incrementLevel() {
        rowsCleared = 0
    }

    func reset() {
        rows = []
        rowsCleared = 0
        score = 0
        selectedToken = nil
    }

    func getKeyToken() -> Token {
        var newToken = randomToken
        while newToken == keyToken {
            newToken = randomToken
        }
        keyToken = newToken
        return newToken
    }

    func getConvertedTokens(keyMatchTokens: [Token]) -> [Token]? {
        guard let token1 = keyMatchTokens.first,
              let token2 = keyMatchTokens.last,
              let fullMatchToken = getFullMatchToken(token1, token2)
        else {
            return nil
        }
        var newTokens: [Token] = []
        keyMatchTokens.forEach { token in
            guard let rowIndex = rows.firstIndex(where: { $0.contains(token) }),
                  let tokenIndex = rows[rowIndex].firstIndex(of: token)
            else {
                return
            }
            let newToken = Token(fullMatchToken.color, fullMatchToken.icon)
            rows[rowIndex][tokenIndex] = newToken
            newTokens.append(newToken)
        }
        return newTokens
    }

    func getSelectionResult(token: Token) -> SelectionResult {
        guard let selectedToken = selectedToken else {
            selectedToken = token
            return .firstSelection
        }
        let tokens = [token, selectedToken]
        var result = SelectionResult.none(tokens)
        self.selectedToken = nil
        switch getAdjacencyResult(token, selectedToken) {
        case .notAdjacent:
            break
        case .adjacentVertical:
            if isPartialMatch(token, selectedToken) {
                result = .partialMatch(tokens)
            }
        case .adjacentHorizontal:
            if isPartialMatch(token, selectedToken) {
                result = getPartialMatchType(token, selectedToken)
                updateScore(for: result)
            }
        }
        return result
    }

    func clearRow(tokens: [Token]) {
        rows.removeAll {
            $0 == tokens
        }
        rowsCleared += 1
    }

    func getRowTokens() -> [Token] {
        guard let keyToken = keyToken else {
            return []
        }
        let tokens = (0..<Self.gridSize).map { index in
            if index < 2 {
                return Token(Token.Color.allCases.filter({ $0 != keyToken.color })[index], keyToken.icon)
            }
            return randomToken
        }
        rows.insert(tokens, at: 0)
        return tokens
    }

    private func updateScore(for selectionResult: SelectionResult) {
        guard case .partialMatchKey(let tokens) = selectionResult else {
            return
        }
        var rowValue = 5
        if let row = rows.first(where: { $0.contains(tokens.first!) }) {
            // TODO: calculate bonus
        }
        score += rowValue
    }

    private func getFullMatchToken(_ token1: Token, _ token2: Token) -> Token? {
        guard isPartialMatch(token1, token2) else { return nil }
        let color: Token.Color?
        let icon: Token.Icon?
        if token1.color == token2.color {
            color = token1.color
            icon = Token.Icon.allCases.first { ![token1.icon, token2.icon].contains($0) }
        } else {
            icon = token1.icon
            color = Token.Color.allCases.first { ![token1.color, token2.color].contains($0) }
        }
        guard let color = color, let icon = icon else { return nil }
        return Token(color, icon)
    }

    private func isMatch(_ token1: Token, _ token2: Token) -> Bool {
        token1.color == token2.color && token1.icon == token2.icon
    }

    private func isPartialMatch(_ token1: Token, _ token2: Token) -> Bool {
        !isMatch(token1, token2) && (token1.color == token2.color || token1.icon == token2.icon)
    }

    private func getPartialMatchType(_ token1: Token, _ token2: Token) -> SelectionResult {
        let tokens = [token1, token2]
        guard let convertedToken = getFullMatchToken(token1, token2),
              let keyToken = keyToken
        else {
            return .none(tokens)
        }
        return isMatch(convertedToken, keyToken) ? .partialMatchKey(tokens) : .partialMatch(tokens)
    }

    private func getAdjacencyResult(_ token1: Token, _ token2: Token) -> AdjacencyResult {
        if let token1Coordinates = getCoordinates(for: token1),
           let token2Coordinates = getCoordinates(for: token2) {
            if valuesFitAdjacency(
                matchingValues: (token1Coordinates.row, token2Coordinates.row),
                adjacentValues: (token1Coordinates.column, token2Coordinates.column)
            ) {
                return .adjacentHorizontal
            }
            if valuesFitAdjacency(
                matchingValues: (token1Coordinates.column, token2Coordinates.column),
                adjacentValues: (token1Coordinates.row, token2Coordinates.row)
            ) {
                return .adjacentVertical
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
        guard let rowIndex = rows.firstIndex(where: { $0.contains(token) }),
              let tokenIndex = rows[rowIndex].firstIndex(of: token)
        else {
            return nil
        }
        return (tokenIndex, rowIndex)
    }
}
