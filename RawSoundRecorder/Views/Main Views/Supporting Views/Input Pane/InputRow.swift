//
//  InputRow.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/5/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI

extension AudioChannel {
    func toggle() {
        enabled.toggle()
        callAlert(.prerelease, "Channel \(number) turned \(enabled ? "on" : "off")")
    }
}

struct InputRow: View {
    @Environment(\.colorScheme) var colorScheme // For light/dark mode fix
    
    @ObservedObject var channel: AudioChannel
    @Binding var editChannel: Int
    @State private var channelLabel = ""
    @Binding var isDisabled: Bool
    
    var showChannelEditor: Bool {
        UserSettings.editChannelNames && (!isDisabled && channel.canRename && editChannel == channel.number)
    }
    
    let ledOnSize: CGFloat = 119.0
    let ledOffOffset = CGSize(width: -0.25, height: -0.75)
    var body: some View {
        ZStack {
            
            Image("InputBgd")
                // Light/dark mode fix
                .offset(y: (colorScheme == .dark ? 1 : 0))
            
            HStack {
                
                // Input LED
                Button(action: channel.toggle) {
                    Image(channel.enabled ? "LEDon" : "LEDoff")
                        .offset( channel.enabled ? CGSize() : ledOffOffset)
                }
                .buttonStyle(PlainButtonStyle())
                // Alignment bounds
                .frame(width: ledOnSize, height: ledOnSize, alignment: .center)
                // Actual bounds
                .frame(width: 20, height: 20)
                .offset(x: 1.5, y: 0.5)
                .disabled(isDisabled)
                
                // Input Knob here
                
                
                ZStack {
                    
                    // Input Meter
                    HStack {
                        Spacer()
                        DrawMeter(meterValue: $channel.meterValue)
                            .frame(width: 80.0, height: 18.0)
                            .opacity(channel.enabled ? 0.8 : 0.5)
                        
                        Spacer()
                            .frame(width: 5.0)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                
                                // Channel Label
                                Text("\(channel.number)  ")
                                    .fontWeight(.bold)

                                if showChannelEditor {
                                    TextField(
                                        AudioChannel.defaultDescription,
                                        text: self.$channelLabel,
                                        onCommit: { self.editChannel = -1 }
                                    )
                                    .textFieldStyle(ChannelTextFieldStyle())
                                    .fixedSize(horizontal: true, vertical: false)
                                    .multilineTextAlignment(.leading)
                                    .onDisappear() {
                                        self.channel.name = self.channelLabel
                                    }
                                    .onAppear() {
                                        self.channelLabel = self.channel.name
                                    }
                                    
                                }
                                else { Text(channel.description) }
                            }
                            .frame(height: 16)
                            .onTapGesture(count: 2, perform: {
                                if !self.isDisabled {
                                    self.editChannel = self.channel.number
                                }
                            })
                            
                            // Device Subtitle
                            Text(channel.deviceName)
                                .font(.caption)
                                .opacity(0.65)
                            
                        }
                        .lineLimit(1)
                     Spacer()
                    }
                }
                
            }
            .padding(.horizontal, 25)
        }
        .frame(height: 50)
    }
}
struct ChannelTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(0)
            .padding(.leading, -3.0)
    }
}


struct InputRow_Previews: PreviewProvider {
    static var previews: some View {
        InputRow(channel: testChannel(5), editChannel: .constant(2), isDisabled: .constant(false))
    }
}
