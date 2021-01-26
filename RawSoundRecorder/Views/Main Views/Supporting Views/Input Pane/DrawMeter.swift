//
//  DrawMeter.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI

struct DrawMeter: View {
    @EnvironmentObject var session: SessionData
    
    @Binding var meterValue: Float
    var scaledMeterValue: CGFloat { CGFloat( meterValue.percentToScale(session.meterSettings.minimumDB )) }
    var body: some View {
        GeometryReader { meterSize in
        ZStack(alignment: .trailing) {
            Group {
            HStack(spacing: 0) {
            Rectangle()
                .fill(Color.red)
                .frame(
                    width: self.session.meterSettings.redFactor * meterSize.size.width,
                    height: meterSize.size.height)
            Rectangle()
                .fill(Color.yellow)
                .frame(
                    width: self.session.meterSettings.yellowFactor * meterSize.size.width,
                    height: meterSize.size.height)
            Rectangle()
                .fill(Color.green)
                .frame(
                    width: self.session.meterSettings.greenFactor * meterSize.size.width,
                    height: meterSize.size.height)
            }
            .frame(
                width: CGFloat(self.scaledMeterValue) * meterSize.size.width,
                height: meterSize.size.height,
                alignment: .trailing
            )
            .clipped()
            .cornerRadius(1)
            }
            .frame(
                width: meterSize.size.width,
                height: meterSize.size.height,
                alignment: .trailing
            )
            .mask(
                HStack(spacing: 0) {
                    ForEach((0..<Int(
                        meterSize.size.width / self.session.meterSettings.barCountFactor
                        ))) { i in
                        Rectangle()
                            .cornerRadius(1)
                            .padding(
                                .trailing,
                                self.session.meterSettings.barSpacing
                        )
                    }
                }
            )
            .transition(.move(edge: .trailing))
            
            
            if self.session.meterSettings.displayNumber {
                Text(String(
                    format: " %.1f dB ",
                    self.meterValue.percentToDB(-1000)
                ))
                    .opacity(0.8)
                    .foregroundColor(.black)
            }
        }
        }
    }
}

struct DrawMeter_Previews: PreviewProvider {
    static var previews: some View {
        DrawMeter(meterValue: .constant(0.01))
            .frame(width: 150, height: 20)
            .environmentObject(SessionData.test)
    }
}
