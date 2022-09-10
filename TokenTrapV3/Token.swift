//
//  Token.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/10/22.
//

import Foundation

class Token: GameViewModelObject {
    let id: UUID = UUID()
    let color: Color
    let icon: Icon
    @Published var selectionStatus = SelectionStatus.none

    init(_ color: Color, _ icon: Icon) {
        self.color = color
        self.icon = icon
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

    enum SelectionStatus {
        case none
        case selected
        case rejected
        case keyMatch
    }
}
