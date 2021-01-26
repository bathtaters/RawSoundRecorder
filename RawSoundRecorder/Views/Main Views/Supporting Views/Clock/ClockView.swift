//
//  ClockView.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI



struct ClockView: View {
    @EnvironmentObject var session: SessionData
    @State var clock = ClockTimer()
    @State var isDimmed = false
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3){
            
            ForEach(clock.description.map{$0}, id: \.self) { digit in
                
                DrawClockDigit(digit: digit,
                               ghostOpacity: self.session.clockOpacity(true),
                               digitColor: self.session.clockColor)
                    
                    .opacity(self.session.clockOpacity(
                        digit == ":" && self.isDimmed
                    ))
            }
        }
        .frame(minWidth: 280.0, maxWidth: .infinity,
               minHeight: 50.0, maxHeight: .infinity)
        .background(Color.black)
            
        .onAppear() { _ = self.clockTimer }
        .onReceive(session.$status) { self.clock.updateFrom($0) }
    }
}



struct ClockView_Previews: PreviewProvider {
    static var previews: some View {
        ClockView()
            .environmentObject(SessionData.test)
    }
}
