//
//  GameLogic+StatsStorage.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 12/24/23.
//

import Foundation

extension GameLogic {

    class StatsStorage {
        private let settings: Settings
        private var lastGameId: UUID?
        private var key: String { "com.tokentrap.stats." + settings.skillLevel.rawValue }

        private var defaultValues: Stats.Values {
            Stats.Values(highScore: 0, averageScore: 0, numberOfGames: 0)
        }

        init(_ settings: Settings) {
            self.settings = settings
        }

        func getUpdatedStats(with state: State) -> Stats {
            let storedValues = getStoredValues()
            guard canUpdateStoredValues(for: state) else {
                return Stats(values: storedValues, isNewHighScore: false, settings: settings)
            }
            lastGameId = state.gameId
            let stats = Stats(
                values: getUpdatedValues(from: storedValues, state.score),
                isNewHighScore: state.score > storedValues.highScore,
                settings: settings
            )
            store(stats.values)
            return stats
        }

        private func canUpdateStoredValues(for state: State) -> Bool {
            !settings.isTrainingMode
            && state.score > 0
            && state.gameId != lastGameId
        }

        private func getUpdatedValues(
            from storedValues: Stats.Values,
            _ score: Int
        ) -> Stats.Values {
            let previousTotalScore = Double(storedValues.numberOfGames) * storedValues.averageScore
            let updatedTotalScore = previousTotalScore + Double(score)
            let updatedNumberOfGames = storedValues.numberOfGames + 1
            let updatedAverageScore = updatedTotalScore / Double(updatedNumberOfGames)
            let updatedHighScore = score > storedValues.highScore ? score : storedValues.highScore
            return Stats.Values(
                highScore: updatedHighScore,
                averageScore: updatedAverageScore,
                numberOfGames: updatedNumberOfGames
            )
        }

        private func getStoredValues() -> Stats.Values {
            guard let data = UserDefaults.standard.data(forKey: key) else {
                return defaultValues
            }
            return (try? JSONDecoder().decode(Stats.Values.self, from: data)) ?? defaultValues
        }

        private func store(_ values: Stats.Values) {
            guard let encoded = try? JSONEncoder().encode(values.self) else {
                return
            }
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
