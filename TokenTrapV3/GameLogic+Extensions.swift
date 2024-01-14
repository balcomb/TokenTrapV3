//
//  GameLogic+Extensions.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 2/20/23.
//

import Foundation

protocol GameLogicResource: Identifiable, Equatable {}
extension GameLogicResource {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension GameLogic {

    struct Settings {
        var skillLevel = SkillLevel.basic
        var isTrainingMode = false

        enum SkillLevel: String {
            case basic, expert
        }
    }

    class RowTimer {
        static var indicatorCount = 4
        var isFull: Bool { value == Self.indicatorCount }
        private var value = 0
        private var timer: Timer?
        private var timeInterval: TimeInterval?
        private let callback: (Int) -> Void

        init(callback: @escaping (Int) -> Void) {
            self.callback = callback
        }

        func setTimeInterval(with level: Int, _ settings: Settings) {
            let defaultInterval = 1.2
            let lastDefaultIntervalLevel = settings.skillLevel == .expert ? 4 : 8
            guard !settings.isTrainingMode && level > lastDefaultIntervalLevel else {
                timeInterval = defaultInterval
                return
            }
            let exponent = Double(level - lastDefaultIntervalLevel)
            let factor = pow(0.9, exponent)
            timeInterval = defaultInterval * factor
        }

        func start() {
            value = 0
            setTimer()
        }

        func cancel() {
            timer?.invalidate()
        }

        func resume() {
            setTimer()
        }

        private func setTimer() {
            guard let timeInterval = timeInterval else {
                return
            }
            timer?.invalidate()
            timer = .scheduledTimer(
                withTimeInterval: timeInterval,
                repeats: true
            ) { [weak self] _ in
                self?.handleTimer()
            }
        }

        private func handleTimer() {
            value = isFull ? 0 : value + 1
            DispatchQueue.main.async {
                self.callback(self.value)
            }
        }
    }

    struct State {
        let gameId = UUID()
        var rows: [Row] = []
        var selections: [Selection] = []
        var solvedRows: [SolvedRow?] = []
        var nextTrainingHintToken: Token?
        var target: Token?
        var level = 1
        var score = 0
        var scoreChanges: [ScoreChange] = []
        var timerValue = 0
        var gamePhase: GamePhase?
        var stats: Stats?
    }

    struct ScoreChange: Equatable, Identifiable {
        let id = UUID()
        let value: Int

        init(challengeType: Row.ChallengeType?) {
            switch challengeType {
            case .uniform: value = 10
            case .wildcardRow: value = 20
            default: value = 5
            }
        }
    }

    struct Stats {
        let values: Values
        let isNewHighScore: Bool
        let settings: GameLogic.Settings

        struct Values: Codable {
            let highScore: Int
            let averageScore: Double
            let numberOfGames: Int
        }
    }

    enum GamePhase {
        case levelComplete
        case levelIntro
        case gameActive
        case gameOver
        case gamePaused
        case gameDismissed
    }

    enum AdjacencyResult {
        case notAdjacent
        case adjacent(isHorizontal: Bool)
    }

    struct Row: GameLogicResource {
        let id = UUID()
        var tokens: [Token]
        var challengeType: ChallengeType?

        enum ChallengeType {
            case uniform, wildcardRow, wildcardSingle
        }
    }

    struct SolvedRow {
        let id: UUID
        let targetPairRange: NSRange

        init?(row: Row, targetPair: TokenPair) {
            guard let index1 = row.tokens.firstIndex(of: targetPair.token1),
                  let index2 = row.tokens.firstIndex(of: targetPair.token2)
            else {
                return nil
            }
            id = row.id
            targetPairRange = NSRange(location: min(index1, index2), length: 2)
        }
    }

    struct Selection: GameLogicResource {
        let id = UUID()
        var token1: Token
        var tokenPair: TokenPair?
        var status = Status.selected

        var tokens: [Token] {
            guard let tokenPair = tokenPair else {
                return [token1]
            }
            return [tokenPair.token1, tokenPair.token2]
        }

        init(_ token: Token) {
            token1 = token
        }

        enum Status {
            case selected
            case rejected
            case partialMatch
            case targetMatch
        }
    }
}

extension Array where Element == GameLogic.SolvedRow? {

    func has(_ index: Int, in row: GameLogic.Row) -> Bool {
        guard let solvedRow = first(where: { $0?.id == row.id }),
              let targetPairRange = solvedRow?.targetPairRange
        else {
            return false
        }
        return targetPairRange.contains(index)
    }
}
