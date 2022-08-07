//
//  GameView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 8/7/22.
//

import SwiftUI

struct GameView: View {
    let settings: GameSettings
    var completion: () -> Void
    var body: some View {
        Button("dismiss") { completion() }
    }
}

struct GameSettings: Equatable {
    var skillLevel = SkillLevel.basic
    var isTrainingMode = false

    enum SkillLevel {
        case basic, expert
    }
}
