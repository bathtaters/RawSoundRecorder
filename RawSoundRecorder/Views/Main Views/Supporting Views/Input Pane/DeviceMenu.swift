//
//  DeviceMenu.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/5/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI

struct DeviceMenu: View {
    @EnvironmentObject var session: SessionData
    
    let refreshSize: CGFloat = 22.355 // asset size
    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            Spacer().frame(width: 6, height: refreshSize)
            
            // Refresh Button
            Button(action: session.pressRefresh) {
                Image("Refresh")
            }.buttonStyle(PlainButtonStyle())
             .disabled(session.status.disableUI)
            
            Spacer()
            
            MenuButton(label:
                HStack {
                    Text(session.selectedDevice?.description ?? "")
                        .font(.system(
                            size: 25,
                            weight: .ultraLight,
                            design: .default
                        ))
                        .lineLimit(1)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                
                Spacer()
                Spacer().frame(width: refreshSize, height: refreshSize)
            }) {
                
                // Menu
                ForEach(session.deviceList.indices, id: \.self) { i in
                    Button(action: { self.session.setDeviceIndex(i) }) {
                        DeviceRow(device: self.session.deviceList[i],
                                  selectedDevice: self.$session.selectedDevice)
                    }
                    .frame(height: 35, alignment: .center)
                }
                
                
            }
            .menuButtonStyle(BorderlessPullDownMenuButtonStyle())
            .padding(.vertical, 7)
            .disabled(session.status.disableUI)
            
            Spacer().frame(width: 6, height: refreshSize)
            Spacer()
        }
    }
}

struct DeviceMenu_Previews: PreviewProvider {
    static var previews: some View {
        DeviceMenu()
            .environmentObject(SessionData.test)
    }
}
