//
//  QuickSettingsView.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/8/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI
import struct CoreAudioTypes.CoreAudioBaseTypes.AudioStreamBasicDescription

struct QuickSettingsView: View {
    @EnvironmentObject var session: SessionData
    
    @State private var folderTextField = ""
    var body: some View {
        VStack() {
            Text("Settings")
                .font(.system(size: 25))
                .fontWeight(.ultraLight)
                .offset(y: 2)
            
            HStack(spacing: 20) {
                
                // Folder Menu
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save To")
                        .font(.system(size: 18))
                        .fontWeight(.thin)
                    
                    HStack {
                        // Folder - Manual entry
                        TextField(
                            session.currentFolder.path,
                            text: $folderTextField,
                            onCommit: {
                                self.session.setFolder(&self.folderTextField)
                            }
                        )
                        .padding(.horizontal, 2)
                        .offset(x: 4)
                        .disabled(session.status.disableUI) // ERROR!!
                        
                        // Folder - Popup selector
                        Button(action: self.session.pressFolder) {
                            Image("Folder")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .offset(y: -1.0)
                        .disabled(session.status.disableUI)
                        
                    }
                }.onReceive(session.$currentFolder) { folder in
                    self.folderTextField = folder.dirPath
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
                
            }
            
            // Format Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Format")
                    .font(.system(size: 18))
                    .fontWeight(.thin)
                
                Group {
                    // Format - Select multiple options
                    if session.formatList.count > 1 {
                        Picker(selection: $session.formatIndex,
                               label: Spacer()) {
                            ForEach(session.formatList.indices, id: \.self) { i in
                                Text(self.session.formatList[i].description)
                            }
                        }
                        .disabled(session.status.disableUI)
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Spacer()
                            
                            Group {
                            if session.formatList.count == 1 {
                                
                                // Format - Single option
                                Text(session.formatList[0].description)
                                
                            } else {
                                
                                // Format - No options AKA error
                                Text(AudioStreamBasicDescription().description)
                                
                            }
                            }.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            
        }
    }
    
}

struct QuickSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        QuickSettingsView()
            .environmentObject(SessionData.test)
    }
}
