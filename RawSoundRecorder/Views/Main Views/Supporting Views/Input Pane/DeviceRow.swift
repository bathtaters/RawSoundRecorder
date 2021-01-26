//
//  DeviceRow.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI

struct DeviceRow: View {
    var device: AudioDevice
    @Binding var selectedDevice: AudioDevice?
    
    var channelText: String {
        let channelCount = device.channelCount(.input)
        return "\(channelCount) Channel\(channelCount == 1 ? " " : "s ")"
    }
    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            
            Text(device == selectedDevice ? "•" : " ")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .offset(y: -2)
                .opacity(0.6)
            
            Text(device.description)
                .font(.system(size: 19, weight: .thin, design: .default))
                .frame(minWidth: 20)
            
            Text(device.getTransportType() ?? "")
                .font(.system(size: 12, weight: .regular))
                .opacity(0.5)
            
            Spacer()
            
            Text(channelText)
                .font(.system(size: 15, weight: .regular))
                .opacity(0.6)
            
        }
        .lineLimit(1)
    }
}

struct DeviceRow_Previews: PreviewProvider {
    static var previews: some View {
        DeviceRow(device: testDevice(),
                  selectedDevice: .constant(AudioDevice.defaultInput!))
            .environmentObject(SessionData.test)
    }
}
