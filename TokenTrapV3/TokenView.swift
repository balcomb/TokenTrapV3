//
//  TokenView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 8/13/22.
//

import SwiftUI

struct TokenView: View {
    @State var token: Token
    var size: CGFloat
    private var iconSize: CGFloat { size * 0.6 }

    var body: some View {
        ZStack {
            Circle().foregroundColor(.white)
            Image(
                token.icon.rawValue
            )
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundColor(Color(token.color.rawValue))
            .frame(width: iconSize, height: iconSize)
        }
        .frame(width: size, height: size)
    }
}

struct Token: Identifiable {
    var id: String = UUID().uuidString

    let color: Color
    let icon: Icon

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
}
