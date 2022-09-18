//
//  SequencedAnimation.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/18/22.
//

import SwiftUI

struct SequencedAnimation {
    var duration: Double = 0.3
    let body: () -> Void

    private var delay: Int {
        Int(duration * 1000)
    }

    static func start(_ sequence: [SequencedAnimation]) {
        animate(sequence)
    }

    private static func animate(
        _ sequence: [SequencedAnimation],
        previousAnimation: SequencedAnimation? = nil
    ) {
        
        guard !sequence.isEmpty else {
            return
        }
        var sequence = sequence
        let currentAnimation = sequence.removeFirst()

        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(previousAnimation?.delay ?? 0)
        ) {
            withAnimation(.easeInOut(duration: currentAnimation.duration), currentAnimation.body)
            animate(sequence, previousAnimation: currentAnimation)
        }
    }
}
