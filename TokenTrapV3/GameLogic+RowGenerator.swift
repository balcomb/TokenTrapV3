//
//  GameLogic+RowGenerator.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 6/18/23.
//

import Foundation

extension GameLogic {

    class RowGenerator {

        private var isExpertMode: Bool { GameLogic.settings.skillLevel == .expert }

        func getNextRow(for target: Token, _ level: Int) -> Row {
            Row(tokens: getTokens(target, level))
        }

        private func getTokens(_ target: Token, _ level: Int) -> [Token] {
            let keySequence = getKeySequence(for: target, level)
            var tokens = (0..<(GameLogic.gridSize - keySequence.count)).map { _ in Token.random }
            let keySequenceIndex = Int.random(in: 0...tokens.endIndex)
            tokens.insert(contentsOf: keySequence, at: keySequenceIndex)
            return tokens
        }

        private func getKeySequence(for target: Token, _ level: Int) -> [Token] {
            let initialPair = TokenPair(partialMatchTarget: target)
            guard let disguiseValues = getDisguiseValues(for: level),
                  disguiseValues.count == 2
            else {
                return initialPair.tokens
            }
            return getDisguisedSequence(for: initialPair, disguiseValues)
        }

        private func getDisguisedSequence(
            for initialPair: TokenPair,
            _ disguiseValues: [Bool]
        ) -> [Token] {
            var sequence: [Token] = []
            for (index, token) in initialPair.tokens.enumerated() {
                let willDisguise = disguiseValues[index]
                let subsequence = getSubsequence(for: token, willDisguise)
                sequence.append(contentsOf: subsequence)
            }
            return sequence
        }

        private func getSubsequence(for token: Token, _ willDisguise: Bool) -> [Token] {
            guard willDisguise else {
                return [token]
            }
            return TokenPair(partialMatchTarget: token).tokens
        }

        private func getDisguiseValues(for level: Int) -> [Bool]? {
            guard let disguiseType = getDisguiseType(for: level) else {
                return nil
            }
            switch disguiseType {
            case .single:
                return [true, false].shuffled()
            case .double:
                return [true, true]
            }
        }

        private func getDisguiseType(for level: Int) -> DisguiseType? {
            var disguiseType: DisguiseType?
            if isExpertMode || level > 2 {
                disguiseType = DisguiseType.allCases.randomElement()
            } else if level == 2 {
                disguiseType = .single
            }
            return disguiseType
        }

        private enum DisguiseType: CaseIterable {
            case single, double
        }
    }
}
