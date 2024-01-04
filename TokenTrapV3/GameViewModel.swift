//
//  GameViewModel.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/10/22.
//

import SwiftUI
import Combine

@MainActor
class GameViewModel: ObservableObject {
    @Published var rows: [Row] = []
    @Published var level = 1
    @Published var score = 0
    @Published var targetToken: TokenViewModel?
    @Published var auxiliaryView: AuxiliaryView?
    @Published var rowVisibility = RowVisibility.active
    @Published var closeButtonIsDisabled = true
    @Published var isShowingCloseConfirmation = false

    @Binding private var isShowingGame: Bool

    private(set) lazy var timeProgress = Progress(count: GameLogic.RowTimer.indicatorCount)
    private(set) lazy var levelProgress = Progress(count: GameLogic.requiredRowsCleared)
    private var gameLogic: GameLogic?

    init() {
        _isShowingGame = .constant(true)
    }
}

// MARK: State Handling

extension GameViewModel {

    private func monitor(_ stateSequence: AsyncPublisher<AnyPublisher<GameLogic.State, Never>>) {
        Task { [weak self] in
            guard let self = self else {
                return
            }
            for await state in stateSequence {
                self.handle(state)
            }
        }
    }

    private func handle(_ state: GameLogic.State) {
        updateRows(with: state)
        updateTarget(token: state.target)
        level = state.level
        score = state.score
        timeProgress.status = .active(value: state.timerValue)
        levelProgress.status = .active(value: state.solvedRows.count)
        closeButtonIsDisabled = !(state.gamePhase == .gameOver || state.gamePhase == .gameActive)

        switch state.gamePhase {
        case .levelComplete:
            handleLevelComplete()
        case .levelIntro:
            auxiliaryView = .levelIntro
        case .gameOver:
            handleGameOver(with: state)
        case .gamePaused:
            handleGamePaused()
        case .gameDismissed:
            isShowingGame = false
        case .gameActive, .none:
            handleGameActive()
        }
    }

    private func handleGameActive() {
        isShowingCloseConfirmation = false
        rowVisibility = .active
        auxiliaryView = nil
    }

    private func handleGamePaused() {
        isShowingCloseConfirmation = true
        rowVisibility = .hidden
    }

    private func handleLevelComplete() {
        levelProgress.flash {
            self.rows = []
            self.auxiliaryView = .levelComplete
        }
    }

    private func handleGameOver(with state: GameLogic.State) {
        rowVisibility = .dimmed
        timeProgress.status = .warning
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.clearBoard {
                self.showGameOver(with: state)
            }
        }
    }

    private func clearBoard(_ completion: @escaping () -> Void) {
        guard !rows.isEmpty else {
            completion()
            return
        }
        rows = rows.compactMap { $0 != rows.first ? $0 : nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(20)) {
            self.clearBoard(completion)
        }
    }

    private func showGameOver(with state: GameLogic.State) {
        let settings = gameLogic?.settings ?? GameLogic.Settings()
        let content = GameOverContent(state.stats, settings)
        withAnimation {
            auxiliaryView = .gameOver(content)
        }
    }

    private func updateRows(with state: GameLogic.State) {
        let updatedRows = state.rows.map { stateRow in
            guard let viewModelRow = rows.first(where: { $0.id == stateRow.id }) else {
                return Row(stateRow)
            }
            viewModelRow.update(with: state, stateRow)
            return viewModelRow
        }
        withAnimation {
            rows = updatedRows
        }
    }

    private func updateTarget(token: Token?) {
        guard targetToken?.token != token else {
            return
        }
        var tokenViewModel: TokenViewModel?
        if let token = token {
            tokenViewModel = TokenViewModel(token: token)
            tokenViewModel?.style = .gold
        }
        withAnimation {
            targetToken = tokenViewModel
        }
    }
}

// MARK: Action Handling

extension GameViewModel {

    enum Action {
        case onAppear(_ settings: GameLogic.Settings, _ isShowingGame: Binding<Bool>)
        case selected(token: Token)
        case levelTransition
        case newGame
        case closeSelected
        case closeConfirmed
        case resume
    }

    func handle(_ action: Action) {
        switch action {
        case .onAppear(let settings, let isShowingGame):
            handleOnAppear(settings, isShowingGame)
        case .selected(let token):
            gameLogic?.handle(event: .selectedToken(token))
        case .levelTransition:
            gameLogic?.handle(event: .levelTransitionComplete)
        case .newGame:
            gameLogic?.handle(event: .newGame)
        case .closeSelected:
            gameLogic?.handle(event: .closeSelected)
        case .closeConfirmed:
            gameLogic?.handle(event: .closeConfirmed)
        case .resume:
            gameLogic?.handle(event: .resume)
        }
    }

    private func handleOnAppear(_ settings: GameLogic.Settings, _ isShowingGame: Binding<Bool>) {
        let gameLogic = GameLogic(settings)
        self.gameLogic = gameLogic
        monitor(gameLogic.stateSequence)
        gameLogic.handle(event: .gameDidAppear)
        _isShowingGame = isShowingGame
    }
}

// MARK: Objects

extension GameViewModel {

    enum RowVisibility {
        case active
        case dimmed
        case hidden

        var opacity: CGFloat {
            switch self {
            case .active: return 1
            case .dimmed: return 0.7
            case .hidden: return 0
            }
        }
    }

    enum AuxiliaryView {
        case levelComplete
        case levelIntro
        case gameOver(_ content: GameOverContent)
    }

    struct GameOverContent {
        let headline: String
        let detailTextItems: [String]

        init(_ stats: GameLogic.Stats?, _ settings: GameLogic.Settings) {
            guard !settings.isTrainingMode,
                  let values = stats?.values,
                  let isNewHighScore = stats?.isNewHighScore,
                  let statsContent = StatsContent(values, settings.skillLevel)
            else {
                headline = Self.getHeadline()
                detailTextItems = [Self.getNoStatsDetailText(for: settings.isTrainingMode)]
                return
            }
            headline = Self.getHeadline(isNewHighScore)
            detailTextItems = statsContent.textItems
        }

        private static func getHeadline(_ isNewHighScore: Bool = false) -> String {
            isNewHighScore ? "New High Score" : "Game Over"
        }

        private static func getNoStatsDetailText(for isTrainingMode: Bool) -> String {
            let components: [String]
            if isTrainingMode {
                components = [
                    "Ready for an official game?",
                    "",
                    "Go back to the main menu",
                    "to get out of training mode."
                ]
            } else {
                components = [
                    "Need Practice?",
                    "",
                    "Get in-game hints by tapping",
                    "“\(MenuView.trainingModeText)”",
                    "on the main menu."
                ]
            }
            return components.joined(separator: "\n")
        }

        struct StatsContent {
            private let subhead: String
            private let averageScoreText: String
            private let highScoreText: String

            var textItems: [String] { [subhead, averageScoreText, highScoreText] }

            init?(_ values: GameLogic.Stats.Values, _ skillLevel: GameLogic.Settings.SkillLevel) {
                let shouldDisplayStats = values.numberOfGames > 1
                guard shouldDisplayStats else {
                    return nil
                }
                subhead = "\(skillLevel.rawValue) Level Stats".uppercased()
                let formattedAverageScore = String(format: "%.1f", values.averageScore)
                averageScoreText = "Average Score: \(formattedAverageScore)"
                highScoreText = "High Score: \(values.highScore)"
            }
        }
    }

    class Row: GameViewModelObject {
        let id: UUID
        @Published var tokens: [TokenViewModel]

        init(_ stateRow: GameLogic.Row) {
            id = stateRow.id
            tokens = stateRow.tokens.map { TokenViewModel(token: $0) }
        }

        fileprivate func update(with state: GameLogic.State, _ stateRow: GameLogic.Row) {
            guard stateRow.id == id else {
                return
            }
            for (index, token) in stateRow.tokens.enumerated() {
                let tokenViewModel = tokens[index]
                guard tokenViewModel.token != token else {
                    continue
                }
                tokens[index] = TokenViewModel(token: token)
            }
            for (index, tokenViewModel) in tokens.enumerated() {
                tokenViewModel.update(with: state, stateRow, index)
            }
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

        func flash(count: Int = 0, with completion: @escaping () -> Void) {
            guard count < 10 else {
                completion()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) {
                self.status = .active(value: count % 2 == 0 ? 0 : GameLogic.requiredRowsCleared)
                self.flash(count: count + 1, with: completion)
            }
        }

        enum Status {
            case active(value: Int)
            case warning
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
