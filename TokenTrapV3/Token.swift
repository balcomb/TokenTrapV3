//
//  Token.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/10/22.
//

import Foundation

struct Token: GameLogicResource {
    let id = UUID()
    var attributes: Attributes

    static var random: Token {
        Token(Color.allCases.randomElement()!, Icon.allCases.randomElement()!)
    }

    init(_ color: Color, _ icon: Icon) {
        attributes = Attributes(color: color, icon: icon)
    }

    init?(partialMatch pair: TokenPair) {
        guard pair.isPartialMatch else {
            return nil
        }
        let attributes1 = pair.token1.attributes
        let attributes2 = pair.token2.attributes
        let color: Token.Color?
        let icon: Token.Icon?
        if attributes1.color == attributes2.color {
            color = attributes1.color
            icon = Token.Icon.allCases.first { icon in
                icon != attributes1.icon && icon != attributes2.icon
            }
        } else {
            icon = attributes1.icon
            color = Token.Color.allCases.first { color in
                color != attributes1.color && color != attributes2.color
            }
        }
        guard let color = color, let icon = icon else {
            return nil
        }
        self.init(color, icon)
    }

    struct Attributes: Equatable {
        let color: Color
        let icon: Icon
    }

    enum Icon: String, CaseIterable, Identifiable {
        case die = "IconDie"
        case face = "IconFace"
        case star = "IconStar"

        var id: String { self.rawValue }
    }

    enum Color: String, CaseIterable {
        case blue = "TokenBlue"
        case gray = "TokenGray"
        case red = "TokenRed"
    }
}

struct TokenPair {
    var token1: Token
    var token2: Token

    var isPartialMatch: Bool {
        guard token1.attributes != token2.attributes else {
            return false
        }
        return token1.attributes.color == token2.attributes.color
            || token1.attributes.icon == token2.attributes.icon
    }

    func canConvert(to token: Token?) -> Bool {
        guard let token = token else {
            return false
        }
        return [
            self,
            TokenPair(token1: token, token2: token1),
            TokenPair(token1: token, token2: token2)
        ].allSatisfy {
            $0.isPartialMatch
        }
    }

    func contains(_ token: Token) -> Bool {
        token == token1 || token == token2
    }
}

class TokenViewModel: GameViewModelObject {
    let token: Token
    @Published var style: Style?
    @Published var isDimmed = false

    init(token: Token, style: Style? = nil) {
        self.token = token
        self.style = style
    }

    func update(with state: GameLogic.State, _ stateRow: GameLogic.Row, _ index: Int) {
        setStyle(
            isTargetMatch: state.solvedRows.has(index, in: stateRow),
            selection: state.selections.last
        )
        guard style == nil else {
            return
        }
        isDimmed = state.solvedRows.contains { $0?.id == stateRow.id }
    }

    private func setStyle(isTargetMatch: Bool, selection: GameLogic.Selection?) {
        if isTargetMatch {
            style = .gold
            return
        }
        guard let selection = selection, selection.tokens.contains(token) else {
            style = nil
            return
        }
        style = Style(selection.status)
    }

    enum Style {
        case gray
        case green
        case red
        case gold

        init(_ selectionStatus: GameLogic.Selection.Status) {
            switch selectionStatus {
            case .selected:
                self = .gray
            case .rejected:
                self = .red
            case .partialMatch:
                self = .green
            case .targetMatch:
                self = .gold
            }
        }
    }
}
