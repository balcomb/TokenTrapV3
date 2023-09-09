//
//  GameLogic+RowGenerator.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 6/18/23.
//

import Foundation

extension GameLogic {

    class RowGenerator {
        private let isExpertMode: Bool
        private let isTrainingMode: Bool

        init(_ settings: Settings?) {
            isExpertMode = settings?.skillLevel == .expert
            isTrainingMode = settings?.isTrainingMode == true
        }

        func getNextRow(for state: GameLogic.State) -> Row? {
            guard let target = state.target else {
                return nil
            }
            let challengeType = getChallengeType(for: state)
            let tokens = getTokens(target, state.level, challengeType)
            return Row(tokens: tokens, challengeType: challengeType)
        }

        private func getTokens(
            _ target: Token,
            _ level: Int,
            _ challengeType: Row.ChallengeType?
        ) -> [Token] {
            if challengeType == .uniform {
                return getUniformRow()
            }
            var keySequence = getKeySequence(for: target, level)
            setTrainingHint(in: &keySequence)
            var tokens = getFullTokens(with: keySequence)
            addWildcards(to: &tokens, for: challengeType)
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

        private func getFullTokens(with keySequence: [Token]) -> [Token] {
            var tokens = (0..<(GameLogic.gridSize - keySequence.count)).map { _ in Token.random }
            let keySequenceIndex = Int.random(in: 0...tokens.endIndex)
            tokens.insert(contentsOf: keySequence, at: keySequenceIndex)
            return tokens
        }

        private func setTrainingHint(in keySequence: inout [Token]) {
            guard isTrainingMode, let index = keySequence.indices.randomElement() else {
                return
            }
            keySequence[index].shouldShowTrainingHint = true
        }

        // MARK: Disguise Logic

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

        // MARK: Challenge Logic

        private func getChallengeType(for state: GameLogic.State) -> Row.ChallengeType? {
            let challengeLogic = ChallengeLogic(state, isExpertMode)
            if challengeLogic.shouldAddUniformRow {
                return .uniform
            }
            if challengeLogic.shouldAddWildcardRow {
                return .wildcardRow
            }
            if challengeLogic.isWildcardSingleEligible {
                return .wildcardSingle
            }
            return nil
        }

        private func getUniformRow() -> [Token] {
            var tokens: [Token] = []
            let attributes = Token.random.attributes
            for _ in (0..<GameLogic.gridSize) {
                tokens.append(Token(attributes.color, attributes.icon))
            }
            return tokens
        }

        private func addWildcards(to tokens: inout [Token], for challengeType: Row.ChallengeType?) {
            let wildcardIndices: [Int]
            switch challengeType {
            case .wildcardRow:
                wildcardIndices = tokens.indices.map { $0 }
            case .wildcardSingle:
                guard let randomIndex = tokens.indices.randomElement() else {
                    fallthrough
                }
                wildcardIndices = [randomIndex]
            default:
                wildcardIndices = []
            }
            wildcardIndices.forEach { index in
                tokens[index].isWildcard = true
            }
        }

        struct ChallengeLogic {
            /**
             * challenge progression:
             * 1: uniform rows
             * 2: one wildcard per row (+ uniform for expert mode)
             * 3: wildcard rows (+ uniform & one wildcard per row for expert mode)
             * rest of game: both challenge rows plus one wildcard per row
             */
            private let canAddChallengeRow: Bool
            private let isWildcardRowEligible: Bool
            private var isUniformEligible: Bool

            var isWildcardSingleEligible: Bool

            var shouldAddUniformRow: Bool {
                canAddChallengeRow && isUniformEligible && Bool.random()
            }

            var shouldAddWildcardRow: Bool {
                canAddChallengeRow && isWildcardRowEligible && Bool.random()
            }

            init(_ state: GameLogic.State, _ isExpertMode: Bool) {
                let level = state.level
                let rows = state.rows
                let startLevel = isExpertMode ? 2 : 5
                let wildcardRowStartLevel = startLevel + 2
                let isAllChallengeEligible = level > wildcardRowStartLevel
                canAddChallengeRow = rows.count > 2 && rows.allSatisfy { $0.challengeType == nil }
                isWildcardRowEligible = level >= wildcardRowStartLevel
                isUniformEligible = isAllChallengeEligible
                isWildcardSingleEligible = isAllChallengeEligible
                guard !isAllChallengeEligible else {
                    return
                }
                if isExpertMode {
                    isUniformEligible = level >= startLevel
                    isWildcardSingleEligible = level > startLevel
                } else {
                    isUniformEligible = level == startLevel
                    isWildcardSingleEligible = level == startLevel + 1
                }
            }
        }
    }
}
