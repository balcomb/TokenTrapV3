//
//  GameViewModel.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/10/22.
//

import SwiftUI

class GameViewModel: ObservableObject {
    @Published var rows: [Row] = []
    @Published var gameStatus = GameStatus.active
    @Published var level = 1
    @Published var score = 0
    @Published var keyToken: Token?
    @Published var levelCountdown = ""
    static var gridSize: Int { 8 }
    var settings: Settings?
    private(set) lazy var timeProgress = Progress(count: 4)
    private(set) lazy var levelProgress = Progress(count: 10)
    private var selectedToken: Token?
    private var timer: Timer?
    private var timeInterval: TimeInterval = 1

    private var canAddRows: Bool {
        rows.count < Self.gridSize
    }

    func startNewGame() {
        if gameStatus != .active {
            resetGame()
        }
        startLevel(level)
    }

    private func resetGame() {
        rows = []
        level = 1
        gameStatus = .active
        timeProgress.reset()
    }

    private func startLevel(_ level: Int? = nil) {
        self.level = level ?? self.level + 1
        levelProgress.reset()
        showTarget()
        showLevelStart { [weak self] in
            self?.addRow()
            self?.startTimer()
        }
    }

    private func showTarget() {
        withAnimation {
            let keyToken = Token(.allCases.randomElement()!, .allCases.randomElement()!)
            keyToken.selectionStatus = .keyMatch
            self.keyToken = keyToken
        }
    }

    private func showLevelStart(completion: @escaping (() -> Void)) {
        levelCountdown = " "
        var sequence = [
            SequencedAnimation(duration: 1) {
                self.gameStatus = .levelBegin
            },
            SequencedAnimation(duration: 0.5) {
                self.gameStatus = .active
            }
        ]
        let messages = ["Ready", "Set", "GO!"]
        let countdownSubsequence: [SequencedAnimation] = messages.map { message in
            SequencedAnimation(duration: 0.5, delay: message == messages.last ? 0.75 : 0.5) {
                self.levelCountdown = message
            }
        }
        sequence.insert(contentsOf: countdownSubsequence, at: 1)
        SequencedAnimation.start(sequence, completion: completion)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = .scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
            self?.handleTimer()
        }
    }

    private func handleTimer() {
        timeProgress.updateValue()
        guard timeProgress.isComplete else {
            return
        }
        guard canAddRows else {
            handleGameOver()
            return
        }
        addRow()
    }

    private func addRow() {
        guard let keyToken = keyToken else { return }
        withAnimation {
            rows.insert(Row(keyToken: keyToken), at: 0)
        }
    }

    private func handleGameOver() {
        timer?.invalidate()
        gameStatus = .inactive
        timeProgress.activateWarning()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            withAnimation {
                self.gameStatus = .gameOver
            }
        }
    }

    func handleTap(token: Token, in row: Row) {
        guard gameStatus == .active, row.isActive else {
            return
        }
        guard let selectedToken = selectedToken else {
            token.selectionStatus = .selected
            selectedToken = token
            return
        }
        let tokens = [token, selectedToken]
        let selectionResult = getSelctionResult(token, selectedToken)
        switch selectionResult {
        case .none:
            updateSelectionStatus(tokens: tokens, status: .rejected)
        case .partialMatch, .partialMatchKey:
            handlePartialMatch(tokens: tokens, selectionResult: selectionResult)
        }
        self.selectedToken = nil
    }

    private func updateSelectionStatus(tokens: [Token], status: Token.SelectionStatus) {
        tokens.forEach { $0.selectionStatus = status }
        guard status != .keyMatch else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
            tokens.forEach { $0.selectionStatus = .none }
        }
    }

    private func handlePartialMatch(tokens: [Token], selectionResult: SelectionResult) {
        guard let token1 = tokens.first,
              let token2 = tokens.last,
              let convertedToken = getConvertedToken(token1, token2)
        else {
            return
        }
        var newTokens: [Token] = []
        var rowToClear: Row?
        tokens.forEach { token in
            guard let row = rows.first(where: { $0.tokens.contains(token) }),
                  let tokenIndex = row.tokens.firstIndex(of: token)
            else {
                return
            }
            let newToken = Token(convertedToken.color, convertedToken.icon)
            row.tokens[tokenIndex] = newToken
            newTokens.append(newToken)
            rowToClear = row
        }
        updateSelectionStatus(
            tokens: newTokens,
            status: selectionResult == .partialMatch ? .selected : .keyMatch
        )
        if let row = rowToClear, selectionResult == .partialMatchKey {
            timer?.invalidate()
            row.isActive = false
            flashKeyPair(tokens: newTokens, in: row)
            updateScore(clearedRow: row)
        }
    }

    private func updateScore(clearedRow: Row) {
        let rowValue = 5 // TODO: calculate bonus points
        withAnimation {
            score += rowValue
        }
    }

    private func flashKeyPair(tokens: [Token], in row: Row, count: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
            tokens.forEach {
                $0.selectionStatus = $0.selectionStatus == .none ? .keyMatch : .none
            }
            if count < 5 {
                self.flashKeyPair(tokens: tokens, in: row, count: count + 1)
            } else {
                self.clear(row)
            }
        }
    }

    private func clear(_ row: Row) {
        levelProgress.updateValue()
        withAnimation {
            rows = rows.filter { $0 != row }
        }
        if levelProgress.isComplete {
            gameStatus = .inactive
            timeProgress.reset()
            flashLevelProgress()
            return
        }
        if rows.isEmpty {
            timeProgress.reset()
            addRow()
        }
        startTimer()
    }

    private func flashLevelProgress(count: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
            let levelProgress = self.levelProgress
            levelProgress.isComplete ? levelProgress.reset() : levelProgress.setComplete()
            guard count < 5 else {
                self.showLevelComplete()
                return
            }
            self.flashLevelProgress(count: count + 1)
        }
    }

    private func showLevelComplete() {
        SequencedAnimation.start([
            SequencedAnimation {
                self.gameStatus = .levelComplete
            },
            SequencedAnimation(duration: 0.5, delay: 1) {
                self.keyToken = nil
                self.rows = []
            },
            SequencedAnimation {
                self.gameStatus = .inactive
            }
        ]) {
            self.startLevel()
        }
    }
}

extension GameViewModel {

    private func isMatch(_ token1: Token, _ token2: Token) -> Bool {
        token1.color == token2.color && token1.icon == token2.icon
    }

    private func isPartialMatch(_ token1: Token, _ token2: Token) -> Bool {
        !isMatch(token1, token2) && (token1.color == token2.color || token1.icon == token2.icon)
    }

    private func getConvertedToken(_ token1: Token, _ token2: Token) -> Token? {
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

    private func getSelctionResult(_ token1: Token, _ token2: Token) -> SelectionResult {
        switch getAdjacencyResult(token1, token2) {
        case .notAdjacent:
            return .none
        case .adjacentVertical:
            return isPartialMatch(token1, token2) ? .partialMatch : .none
        case .adjacentHorizontal:
            return isPartialMatch(token1, token2) ? getPartialMatchType(token1, token2) : .none
        }
    }

    private func getPartialMatchType(_ token1: Token, _ token2: Token) -> SelectionResult {
        guard let convertedToken = getConvertedToken(token1, token2),
              let keyToken = keyToken
        else {
            return .none
        }
        return isMatch(convertedToken, keyToken) ? .partialMatchKey : .partialMatch
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
        guard let rowIndex = rows.firstIndex(where: { $0.tokens.contains(token) }),
              let tokenIndex = rows[rowIndex].tokens.firstIndex(of: token)
        else {
            return nil
        }
        return (tokenIndex, rowIndex)
    }
}

extension GameViewModel {

    enum GameStatus {
        case active
        case inactive
        case levelBegin
        case levelComplete
        case gameOver
    }

    struct Settings: Equatable {
        var skillLevel = SkillLevel.basic
        var isTrainingMode = false

        enum SkillLevel {
            case basic, expert
        }
    }

    class Row: GameViewModelObject {
        let id = UUID()
        var isActive = true

        @Published var tokens: [Token]

        init(keyToken: Token) {
            tokens = Self.getTokens(keyToken: keyToken)
        }

        static func getTokens(keyToken: Token) -> [Token] {
            (0..<GameViewModel.gridSize).map { index in
                if index < 2 {
                    return Token(Token.Color.allCases.filter({ $0 != keyToken.color })[index], keyToken.icon)
                }
                return Token(
                    Token.Color.allCases.randomElement()!,
                    Token.Icon.allCases.randomElement()!
                )
            }
        }
    }

    enum AdjacencyResult {
        case notAdjacent
        case adjacentVertical
        case adjacentHorizontal
    }

    enum SelectionResult {
        case none
        case partialMatch
        case partialMatchKey
    }

    class Progress {
        let indicators: [Indicator]
        fileprivate var currentValue = 0

        var isComplete: Bool {
            currentValue == indicators.count
        }

        init(count: Int) {
            indicators = (0..<count).map { _ in Indicator() }
        }

        func updateValue() {
            currentValue = currentValue < indicators.count ? currentValue + 1 : 0
            for (index, indicator) in indicators.enumerated() {
                indicator.isOn = index < currentValue
            }
        }

        func reset() {
            currentValue = 0
            indicators.forEach {
                $0.isOn = false
                $0.isWarningOn = false
            }
        }

        func activateWarning() {
            indicators.forEach {
                $0.isWarningOn = true
            }
        }

        func setComplete() {
            currentValue = indicators.count
            indicators.forEach {
                $0.isOn = true
            }
        }

        class Indicator: GameViewModelObject {
            @Published var isOn = false
            @Published var isWarningOn = false
        }
    }
}

protocol GameViewModelObject: Hashable, Identifiable, ObservableObject {}
extension GameViewModelObject {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
