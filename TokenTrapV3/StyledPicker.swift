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
        selectedColor: Color = .buttonBlue,
        titleColor: Color = .white
    ) -> some View {
        let controlAppearance = UISegmentedControl.appearance()
        controlAppearance.backgroundColor = UIColor(backgroundColor)
        controlAppearance.selectedSegmentTintColor = UIColor(selectedColor)
        controlAppearance.setTitleTextAttributes(
            [.foregroundColor: UIColor(titleColor)],
            for: .normal
        )
        return modifier(StyledPicker())
    }
}
