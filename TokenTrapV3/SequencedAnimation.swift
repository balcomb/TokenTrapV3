//
//  SequencedAnimation.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/18/22.
//

import SwiftUI

struct SequencedAnimation {
    var duration: TimeInterval = 0.3
    var delay: TimeInterval = 0
    let body: () -> Void

    private var waitTime: TimeInterval {
        duration + delay
    }

    fileprivate static func animate(
        _ sequence: [SequencedAnimation],
        after delay: TimeInterval,
        with control: Control,
        finallyCalling completion: (() -> Void)?
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delay * 1000))) {
            guard control.canContinue else {
                return
            }
            guard let animation = sequence.first else {
                completion?()
                return
            }
            withAnimation(.easeInOut(duration: animation.duration), animation.body)
            animate(
                Array(sequence.dropFirst()),
                after: animation.waitTime,
                with: control,
                finallyCalling: completion
            )
        }
    }
}

extension SequencedAnimation {

    class Control {
        fileprivate var canContinue = true

        func cancel() {
            canContinue = false
        }
    }
}

extension Array where Element == SequencedAnimation {

    @discardableResult func start(
        delay: TimeInterval = 0,
        completion: (() -> Void)? = nil
    ) -> SequencedAnimation.Control {
        let control = SequencedAnimation.Control()
        SequencedAnimation.animate(self, after: delay, with: control, finallyCalling: completion)
        return control
    }
}
