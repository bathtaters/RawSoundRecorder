//
//  FilenameView.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI


struct FilenameView: View {
    @EnvironmentObject var session: SessionData
    
    @State private var filenameText = ""
    @Binding var isEditable: Bool
    
    var body: some View {
        Group {
            if isEditable && session.status == .stop {
                GeometryReader { geometry in
                    HStack(alignment: .center, spacing: 0.0) {
                    Spacer()
                    
                    // Editable Filename
                    TextField(
                        "Filename",
                        text: self.$filenameText,
                        onCommit: {
                            self.session.setFilename(self.filenameText)
                            self.isEditable = false
                        }
                    )
                        .fixedSize(horizontal: true, vertical: false)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 30)
                        .onAppear() {
                            self.filenameText = self.session.currentFilename
                        }
                        .onDisappear() {
                            self.session.setFilename(self.filenameText)
                            self.isEditable = false
                        }
                        
                    // Editable FileType
                    MenuButton(label:
                        Text(".\(self.session.selectedFileType.defaultExt)")
                    ) {
                        ForEach(
                            self.session.fileTypeList.indices,
                            id: \.self
                        ) { i in
                            Button(action: {
                                self.session.setFileType(i)
                            }) {
                                Text(self.session.fileTypeList[i].defaultExt)
                            }
                            
                            .frame(height: 35, alignment: .center)
                        }
                        
                    }
                    .menuButtonStyle(BorderlessPullDownMenuButtonStyle())
                    .padding(.vertical, 7)
                    .fixedSize()
                    //.frame(width: 78)
                    
                    Spacer()
                        //.frame(width: geometry.size.width * 0.4 - 70)
                    
                }
                }
            } else {
                // Uneditable Filename + Ext
                Text("\(session.currentFilename ).\(session.selectedFileType.defaultExt)")
                    .onTapGesture(count: 2, perform: {
                        self.isEditable = (self.session.status == .stop)
                    })
            }
        }
            .font(.system(
                size: 35,
                weight: .ultraLight,
                design: .rounded
            ))
            .foregroundColor(self.session.status.isRecording ? .red : .primary)
            .lineLimit(1)
            .clipped()
            .frame(height: 60, alignment: .center)
            .frame(maxWidth: .infinity)
    }
}

struct FilenameView_Previews: PreviewProvider {
    static var previews: some View {
        FilenameView(isEditable: .constant(true))
            .environmentObject(SessionData.test)
    }
}
