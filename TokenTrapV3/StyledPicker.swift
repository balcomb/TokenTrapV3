//
//  StyledPicker.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 7/31/22.
//

import SwiftUI

struct StyledPicker: ViewModifier {
    func body(content: Content) -> some View {
        content.pickerStyle(.segmented)
    }
}

extension Picker {
    func styled(
        backgroundColor: Color = .logoBlue,
        selectedColor: Color = .black.opacity(0.4),
        titleColor: Color = .white
    ) -> some View {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(titleColor),
            .font: UIFontMetrics(
                forTextStyle: .callout
            ).scaledFont(
                for: UIFont.systemFont(ofSize: 15, weight: .heavy)
            )
        ]
        let controlAppearance = UISegmentedControl.appearance()
        controlAppearance.backgroundColor = UIColor(backgroundColor)
        controlAppearance.selectedSegmentTintColor = UIColor(selectedColor)
        controlAppearance.setTitleTextAttributes(attributes, for: .normal)
        return modifier(StyledPicker())
    }
}
