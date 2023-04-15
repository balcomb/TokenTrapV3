//
//  GameLogic+Extensions.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 2/20/23.
//

import Foundation

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
        var rowsCleared = 0
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

    struct Row {
        let id = UUID()
        var tokens: [Token]
        var isSolved = false

        mutating func replace(_ token: Token, with newToken: Token) {
            guard let tokenIndex = tokens.firstIndex(where: { $0 === token }) else {
                return
            }
            tokens[tokenIndex] = newToken
        }
    }

    class Selection {
        let token1: Token
        var token2: Token?

        init(token1: Token, token2: Token? = nil) {
            self.token1 = token1
            self.token2 = token2
        }

        var tokens: [Token] {
            [token1, token2].compactMap { $0 }
        }
    }
}
