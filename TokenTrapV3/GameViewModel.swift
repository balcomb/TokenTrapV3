//
//  GameViewModel.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/10/22.
//

import SwiftUI

@MainActor
class GameViewModel: ObservableObject {
    @Published var rows: [Row] = []
    @Published var gameStatus = GameStatus.active
    @Published var level = 1
    @Published var score = 0
    @Published var keyToken: Token?
    @Published var levelCountdown = ""
    var settings: Settings?
    private(set) lazy var timeProgress = Progress(count: 4)
    private(set) lazy var levelProgress = Progress(count: 10)
    private var timer: Timer?
    private var timeInterval: TimeInterval = 1
    private lazy var gameLogic = GameLogic()

    init() {
        monitorScore()
    }

    private func monitorScore() {
        Task {
            for await value in gameLogic.scoreStream {
                score = value
            }
        }
    }

    func startNewGame() {
        if gameStatus != .active {
            resetGame()
        }
        startLevel(level)
    }

    private func resetGame() {
        gameLogic.reset()
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
            let keyToken = gameLogic.getKeyToken()
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
            guard let self = self else {
                return
            }
            DispatchQueue.main.async {
                self.handleTimer()
            }
        }
    }

    private func handleTimer() {
        timeProgress.updateValue()
        guard timeProgress.isComplete else {
            return
        }
        guard gameLogic.canAddRows else {
            handleGameOver()
            return
        }
        addRow()
    }

    private func addRow() {
        withAnimation {
            rows.insert(Row(tokens: gameLogic.getRowTokens()), at: 0)
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
        let selectionResult = gameLogic.getSelectionResult(token: token)
        switch selectionResult {
        case .firstSelection:
            token.selectionStatus = .selected
        case .none(let tokens):
            updateSelectionStatus(tokens: tokens, status: .rejected)
        case .partialMatch(let tokens):
            handlePartialMatch(tokens: tokens)
        case .partialMatchKey(let tokens):
            handlePartialMatch(tokens: tokens, rowToClear: row)
        }
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

    private func handlePartialMatch(tokens: [Token], rowToClear: Row? = nil) {
        guard let newTokens = gameLogic.getConvertedTokens(keyMatchTokens: tokens) else {
            return
        }
        for (index, row) in rows.enumerated() {
            row.tokens = gameLogic.rows[index]
        }
        updateSelectionStatus(tokens: newTokens, status: rowToClear == nil ? .selected : .keyMatch)
        guard let rowToClear = rowToClear else {
            return
        }
        timer?.invalidate()
        rowToClear.isActive = false
        flashKeyPair(tokens: newTokens, in: rowToClear)
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
        gameLogic.clearRow(tokens: row.tokens)
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

        init(tokens: [Token]) {
            self.tokens = tokens
        }
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
