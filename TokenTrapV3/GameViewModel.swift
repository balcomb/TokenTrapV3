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
    @Published var level = 1
    @Published var score = 0
    @Published var targetToken: TokenViewModel?
    @Published var auxiliaryView: AuxiliaryView?
    @Published var rowOpacity: CGFloat = 1
    private(set) lazy var timeProgress = Progress(count: GameLogic.RowTimer.indicatorCount)
    private(set) lazy var levelProgress = Progress(count: GameLogic.requiredRowsCleared)
    private lazy var gameLogic = GameLogic()

    init() {
        monitorState()
    }
}

// MARK: State Handling

extension GameViewModel {

    private func monitorState() {
        Task { [weak self] in
            guard let self = self else {
                return
            }
            for await state in self.gameLogic.stateSequence {
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

        switch state.gamePhase {
        case .levelComplete:
            handleLevelComplete()
        case .levelIntro:
            auxiliaryView = .levelIntro
        case .gameOver:
            handleGameOver()
        case .gameActive, .none:
            rowOpacity = 1
            auxiliaryView = nil
        }
    }

    private func handleLevelComplete() {
        levelProgress.flash {
            self.rows = []
            self.auxiliaryView = .levelComplete
        }
    }

    private func handleGameOver() {
        rowOpacity = 0.7
        timeProgress.status = .warning
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.clearBoard {
                self.showGameOver()
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

    private func showGameOver() {
        withAnimation {
            auxiliaryView = .gameOver
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
        case onAppear
        case selected(token: Token)
        case levelTransition
        case newGame
        case pause
    }

    func handle(_ action: Action) {
        switch action {
        case .onAppear:
            handleOnAppear()
        case .selected(let token):
            gameLogic.handle(event: .selectedToken(token))
        case .levelTransition:
            gameLogic.handle(event: .levelTransitionComplete)
        case .newGame:
            startNewGame()
        case .pause:
            gameLogic.handle(event: .pause)
        }
    }

    private func handleOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750)) {
            self.startNewGame()
        }
    }

    private func startNewGame() {
        gameLogic.handle(event: .newGame)
    }
}

// MARK: Objects

extension GameViewModel {

    enum AuxiliaryView {
        case levelComplete
        case levelIntro
        case gameOver
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
