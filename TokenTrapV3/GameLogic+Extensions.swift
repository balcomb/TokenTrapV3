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

    class RowTimer {
        static var indicatorCount = 4
        var isFull: Bool { value == Self.indicatorCount }
        private var value = 0
        private var timer: Timer?
        private var timeInterval: TimeInterval = 1
        private let callback: (Int) -> Void

        init(callback: @escaping (Int) -> Void) {
            self.callback = callback
        }

        func start() {
            timer?.invalidate()
            value = 0
            timer = .scheduledTimer(
                withTimeInterval: timeInterval,
                repeats: true
            ) { [weak self] _ in
                self?.handleTimer()
            }
        }

        func cancel() {
            timer?.invalidate()
        }

        private func handleTimer() {
            value = value == Self.indicatorCount ? 0 : value + 1
            DispatchQueue.main.async {
                self.callback(self.value)
            }
        }
    }

    struct State {
        var rows: [Row] = []
        var selections: [Selection] = []
        var solvedRows: [SolvedRow?] = []
        var target: Token?
        var level = 1
        var score = 0
        var timerValue = 0
        var gamePhase: GamePhase?
    }

    enum Event {
        case newGame
        case levelTransitionComplete
        case selectedToken(_ token: Token)
    }

    enum GamePhase {
        case levelComplete
        case levelIntro
        case gameActive
        case gameOver
    }

    enum AdjacencyResult {
        case notAdjacent
        case adjacent(isHorizontal: Bool)
    }

    struct Row: GameLogicResource {
        let id = UUID()
        var tokens: [Token]
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
