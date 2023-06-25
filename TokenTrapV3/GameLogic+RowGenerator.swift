//
//  GameLogic+RowGenerator.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 6/18/23.
//

import Foundation

extension GameLogic {

    class RowGenerator {

        func getNextRow(for target: Token, _ level: Int) -> Row {
            Row(tokens: getTokens(target, level))
        }

        private func getTokens(_ target: Token, _ level: Int) -> [Token] {
            var tokens = getRandomTokens()
            let keyPairIndex = getRandomTargetIndex()
            addKeyPair(to: &tokens, for: target, at: keyPairIndex)
            return tokens
        }

        private func addKeyPair(to tokens: inout [Token], for target: Token, at index: Int) {
            let keyPair = TokenPair(partialMatchTarget: target)
            tokens[index] = keyPair.token1
            tokens[index + 1] = keyPair.token2
        }

        private func getRandomTokens() -> [Token] {
            (0..<GameLogic.gridSize).map { _ in Token.random }
        }

        private func getRandomTargetIndex() -> Int {
            Int.random(in: 0..<(GameLogic.gridSize - 1))
        }
    }
}
