//
//  TransportView.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI

struct TransportView: View {
    @EnvironmentObject var session: SessionData
    @Binding var filenameIsEditable: Bool
    
    var body: some View {
        VStack {
                Spacer()
                FilenameView(isEditable: $filenameIsEditable)
                
                Spacer()
                ClockView()
                    .frame(width: 270, height: 70)
                    .cornerRadius(5.0)
                    .padding(.vertical, 30.0)
                    .shadow(radius: 5.0)
                
                Spacer()
                HStack(alignment: .center, spacing: 75.0) {
                    
                    // Record Button
                    Button(action: session.pressRecord) {
                        Image(session.recordButtonImage)
                            .resizable()
                            .frame(width: 100, height: 100)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(session.status == .disabled)
                    .offset(y: 1)
                    
                    // Stop Button
                    Button(action: session.pressStop) {
                        Image(session.stopButtonImage)
                            .resizable()
                            .frame(width: 100, height: 100)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(session.status == .disabled)
                    
                }
                
                Spacer()
            }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32.0)
                .padding(.vertical, 32.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(session.status.isRecording ? Color.red : Color.accentColor, lineWidth: 1)
                )
    }
}

struct TransportView_Previews: PreviewProvider {
    static var previews: some View {
        TransportView(filenameIsEditable: .constant(false))
            .environmentObject(SessionData.test)
    }
}
