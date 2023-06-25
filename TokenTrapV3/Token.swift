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

        var partialMatches: [Attributes] {
            var possibleAttributes: [Token.Attributes] = []
            Token.Color.allCases.forEach { color in
                Token.Icon.allCases.forEach { icon in
                    let attributes = Token.Attributes(color: color, icon: icon)
                    guard isPartialMatch(for: attributes) else {
                        return
                    }
                    possibleAttributes.append(attributes)
                }
            }
            return possibleAttributes
        }

        func isPartialMatch(for attributes: Attributes) -> Bool {
            self != attributes && (color == attributes.color || icon == attributes.icon)
        }
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
        token1.attributes.isPartialMatch(for: token2.attributes)
    }

    init(token1: Token, token2: Token) {
        self.token1 = token1
        self.token2 = token2
    }

    init(partialMatchTarget: Token) {
        let possibleAttributes = partialMatchTarget.attributes.partialMatches
        let attributes1 = possibleAttributes.randomElement()!
        let attributes2 = possibleAttributes.first { $0.isPartialMatch(for: attributes1) }!
        token1 = Token(attributes1.color, attributes1.icon)
        token2 = Token(attributes2.color, attributes2.icon)
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
