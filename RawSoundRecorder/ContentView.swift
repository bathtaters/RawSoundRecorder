//
//  ContentView.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionData
    
    @State private var filenameIsEditable = false
    @State private var editChannel: Int = -1
    @State private var showInputs = false
    @State private var showSettings = false
    var body: some View {
        HStack {
            VStack {
                
                VStack {
                    
                    // DEBUGGER VIEW
                    //Text("\(session.allFormatsString)").padding().background(Color.black)
                    
                    // Transport
                    TransportView(filenameIsEditable: $filenameIsEditable)
                        .padding(.horizontal, 40)
                        .padding(.top, 30)
                        .padding(.bottom, 0)
                    
                    
                    Spacer()
                    
                    HStack {
                        
                        // Settings Show/Hide Button
                        Button(action: {
                            withAnimation {
                                self.showSettings.toggle() }
                        }) {
                            Image("Settings")
                                .opacity(showSettings ? 0.4 : 1.0)
                        }
                        .disabled(session.status == .disabled)
                        .buttonStyle(PlainButtonStyle())
                        .padding(10)
                        
                        Spacer()
                        
                        // Input Show/Hide Button
                        Button(action: {
                            withAnimation {
                                self.showInputs.toggle()
                            }
                            self.session.enableMeters(self.showInputs)
                        }) {
                            Image("Inputs")
                                .opacity(showInputs ? 0.4 : 1.0)
                        }
                        .disabled(session.status == .disabled)
                        .buttonStyle(PlainButtonStyle())
                        .padding(10)
                        
                    }
                }
                
                if self.showSettings {
                    VStack {
                        Divider()
                    
                        // Settings
                        QuickSettingsView()
                    }
                        .padding(10)
                        .transition(.move(edge: .bottom))
                }
            }
            
            if self.showInputs {
                HStack {
                    Divider().padding(10)
                    // Inputs
                    InputView(editChannel: $editChannel)
                        .padding(0)
                }
                .transition(.move(edge: .trailing))
            }
        }
        // draw background to capture clicks
        .background(Rectangle().opacity(0.01))
        .onTapGesture {
            self.filenameIsEditable = false
            self.editChannel = -1
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        // Publisher listeners
        .onReceive(session.$status) { status in
            if status.disableUI {
                self.editChannel = -1
                self.filenameIsEditable = false
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .onReceive(session.$selectedDevice) { _ in
            self.editChannel = -1
        }
        .onAppear() {
            let _ = self.session.meterUpdater
        }
        
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SessionData.test)
    }
}
