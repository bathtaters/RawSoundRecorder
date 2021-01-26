//
//  DrawClockDigit.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI



struct DrawClockDigit: View {
    var digit: Character
    var ghostOpacity: Double
    var digitColor: Color
    
    // Layout Params
    static let colon: ViewInfo = .init(
        size: .init(width: 0, height: 6),
        spacing: .init(width: 0, height: 6),
        offset: .init(width: 0, height: 2))
    static let segment: ViewInfo = .init(
        size: .init(width: 15, height: 4.5),
        spacing: .init(width: 11.8, height: -1.3),
        offset: .init(width: -0.2, height: -0.3)) // horizontal only
    var body: some View { Group {
        if digit == ":" {
            // Colon
            VStack(alignment: .center, spacing: Self.colon.spacing.height) {
                Spacer()
                Circle().fill(digitColor).frame(height: Self.colon.spacing.height)
                Circle().fill(digitColor).frame(height: Self.colon.spacing.height)
                Spacer()
            }
            .offset(Self.colon.offset)
        }
        else {
            // Digit
            VStack(alignment: .center, spacing: Self.segment.spacing.height) {
                
                // Horizontal Top
                DigitSegmentPath(color: digitColor)
                    .offset(Self.segment.offset)
                    .opacity(DigitLogic.upper.on(digit) ? 1 : ghostOpacity)
                
                HStack(alignment: .center, spacing: Self.segment.spacing.width) {
                    
                    // Vertical Upper Left
                    DigitSegmentPath(color: digitColor,
                                 vertical: true)
                        .opacity(DigitLogic.upperLeft.on(digit) ? 1 : ghostOpacity)
                    // Vertical Upper Right
                    DigitSegmentPath(color: digitColor,
                                 vertical: true)
                        .opacity(DigitLogic.upperRight.on(digit) ? 1 : ghostOpacity)
                }
                
                // Horizontal Middle
                DigitSegmentPath(color: digitColor)
                    .offset(Self.segment.offset)
                    .opacity(DigitLogic.middle.on(digit) ? 1 : ghostOpacity)
                    
                HStack(alignment: .center, spacing: Self.segment.spacing.width) {
                    
                    // Vertical Lower Left
                    DigitSegmentPath(color: digitColor,
                                 vertical: true)
                        .opacity(DigitLogic.lowerLeft.on(digit) ? 1 : ghostOpacity)
                    
                    // Vertical Lower Right
                    DigitSegmentPath(color: digitColor,
                                 vertical: true)
                        .opacity(DigitLogic.lowerRight.on(digit) ? 1 : ghostOpacity)
                }
                
                // Horizontal Bottom
                DigitSegmentPath(color: digitColor)
                    .offset(Self.segment.offset)
                    .opacity(DigitLogic.lower.on(digit) ? 1 : ghostOpacity)
            }
        }
    }
    .frame(width: 22, height: 40, alignment: .center)
    }
}

struct DigitSegmentPath: View {
    let size: CGSize
    let color: Color
    let indent: CGFloat
    let vertical: Bool
    
    private var horizontalPoints: [CGPoint] { [
        .init(x: size.width * 0.0,
              y: size.height * 0.5),
        .init(x: size.width * indent,
              y: size.height * 1.0),
        .init(x: size.width * (1.0 - indent),
              y: size.height * 1.0),
        .init(x: size.width * 1.0,
              y: size.height * 0.5),
        .init(x: size.width * (1.0 - indent),
              y: size.height * 0.0),
        .init(x: size.width * indent,
              y: size.height * 0.0)
    ] }
    private var verticalPoints: [CGPoint] {
        horizontalPoints.map { $0.flipped }
    }
    private var points: [CGPoint] {
        vertical ? verticalPoints : horizontalPoints
    }
    var body: some View {
        Path { path in
                path.move(to: points.last!)
                path.addLines(points)
            }
            .fill(color)
            .frame(width: vertical ? size.height : size.width,
                   height: vertical ? size.width : size.height,
                   alignment: .center)
    }

    init(color: Color = .accentColor,
         size: CGSize = CGSize(width: 15, height: 4.5),
         vertical: Bool = false,
         indent: CGFloat = 0.15) {
        self.size = size
        self.color = color
        self.indent = indent
        self.vertical = vertical
    }
}







struct DrawClockDigit_Previews: PreviewProvider {
    static var previews: some View {
        DrawClockDigit(digit: Character("1"), ghostOpacity: 0.05, digitColor: .yellow)
    }
}
