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
    var settings: Settings?
    private(set) lazy var timeProgress = Progress(count: 4)
    private(set) lazy var levelProgress = Progress(count: GameLogic.requiredRowsCleared)
    private var timer: Timer?
    private var timeInterval: TimeInterval = 1
    private lazy var gameLogic = GameLogic()

    init() {
        monitorLevel()
        monitorScore()
        monitorRowsCleared()
    }

    private func monitorLevel() {
        Task {
            for await value in gameLogic.levelStream {
                level = value
            }
        }
    }

    private func monitorScore() {
        Task {
            for await value in gameLogic.scoreStream {
                score = value
            }
        }
    }

    private func monitorRowsCleared() {
        Task {
            for await rowsCleared in gameLogic.rowsClearedStream {
                levelProgress.status = .active(value: rowsCleared)
            }
        }
    }

    func startNewGame() {
        if case .gameOver = gameStatus {
            resetGame()
        }
        gameStatus = .newGame
    }

    func handleLevelTransition(event: GameView.LevelTransitionView.Event) {
        switch event {
        case .countdownStart:
            startLevel()
        case .countdownComplete:
            handleLevelCountdownComplete()
        }
    }

    private func handleLevelCountdownComplete() {
        if keyToken == nil {
            startLevel()
        }
        withAnimation {
            gameStatus = .active
        }
        addRow()
        startTimer()
    }

    private func resetGame() {
        gameLogic.reset()
        rows = []
        gameStatus = .active
        timeProgress.reset()
    }

    private func startLevel() {
        if !gameStatus.isNewGame {
            gameLogic.incrementLevel()
        }
        showTarget()
    }

    private func showTarget() {
        withAnimation {
            let keyToken = gameLogic.getKeyToken()
            keyToken.selectionStatus = .keyMatch
            self.keyToken = keyToken
        }
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
        timeProgress.updateProgress()
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
        timeProgress.status = .warning
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            withAnimation {
                self.gameStatus = .gameOver
            }
        }
    }

    func handleTap(token: Token, in row: Row) {
        guard case .active = gameStatus, row.isActive else {
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
        withAnimation {
            rows = rows.filter { $0 != row }
        }
        if gameLogic.levelIsComplete {
            handleLevelComplete()
            return
        }
        if rows.isEmpty {
            timeProgress.reset()
            addRow()
        }
        startTimer()
    }

    private func handleLevelComplete() {
        gameStatus = .inactive
        timeProgress.reset()
        levelProgress.status = .flash { [weak self] in
            self?.handleLevelProgressFlashComplete()
        }
    }

    private func handleLevelProgressFlashComplete() {
        hideCompletedLevel()
        levelProgress.updateProgress(complete: true)
        gameStatus = .levelTransition(LevelTransitionInfo(completed: level, next: level + 1))
    }

    private func hideCompletedLevel() {
        withAnimation {
            keyToken = nil
            rows = []
        }
    }
}

extension GameViewModel {

    enum GameStatus {
        case active
        case inactive
        case levelTransition(_ info: LevelTransitionInfo)
        case gameOver

        fileprivate var isNewGame: Bool {
            switch self {
            case .levelTransition(let levelInfo):
                return levelInfo.next == 1
            default:
                return false
            }
        }

        fileprivate static var newGame: Self {
            .levelTransition(LevelTransitionInfo(completed: nil, next: 1))
        }
    }

    struct LevelTransitionInfo {
        let completed: Int?
        let next: Int
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

    class Progress: GameViewModelObject {
        @Published var status: Status = .active(value: 0)
        let count: Int

        var isComplete: Bool {
            guard case .active(let value) = status else {
                return false
            }
            return value == count
        }

        init(count: Int) {
            self.count = count
        }

        func updateProgress(complete: Bool = false) {
            if complete {
                status = .active(value: count)
                return
            }
            var newValue = 0
            if case .active(let value) = status {
                newValue = isComplete ? 0 : value + 1
            }
            status = .active(value: newValue)
        }

        func reset() {
            status = .active(value: 0)
        }

        enum Status {
            case active(value: Int)
            case warning
            case flash(completion: () -> Void)
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
