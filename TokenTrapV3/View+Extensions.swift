//
//  View+Extensions.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 5/7/23.
//

import SwiftUI

extension View {
    func bigButton() -> some View {
        modifier(BigButton())
    }

    func smallButton() -> some View {
        modifier(SmallButton())
    }

    func buttonText(_ text: String) -> some View {
        Text(text).fontWeight(.heavy)
    }

    func closeIcon(size: CGFloat) -> some View {
        Image(systemName: "xmark.circle")
            .resizable()
            .tint(.white)
            .frame(width: size, height: size)
            .padding()
    }
}

struct BigButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonBorderShape(.roundedRectangle)
            .tint(.buttonBlue)
            .buttonStyle(.borderedProminent)
    }
}

struct SmallButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonBorderShape(.roundedRectangle)
            .controlSize(.small)
            .tint(.logoBlue)
            .buttonStyle(.bordered)
            .foregroundColor(.white)
    }
}
