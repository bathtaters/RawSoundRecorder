//
//  InputView.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/5/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import SwiftUI


struct InputView: View {
    @EnvironmentObject var session: SessionData
    @Binding var editChannel: Int
    
    var body: some View {
        VStack {
            
            DeviceMenu()
            
            // Input Channel list
            
            List(session.channelList.indices, id: \.self) { index in
                InputRow(
                    channel: self.session.channelList[index],
                    editChannel: self.$editChannel,
                    isDisabled: self.$session.status.disableUI
                )
            }
            
            /*ScrollView(showsIndicators: true) {
                ForEach(session.channelList.indices, id: \.self) { index in
                    InputRow(
                        channel: self.session.channelList[index],
                        editChannel: self.$editChannel,
                        isDisabled: self.$session.status.disableUI
                    )
                }
            } // */
        }
    }
    
}

struct InputView_Previews: PreviewProvider {
    static var previews: some View {
        InputView(editChannel: .constant(2))
            .environmentObject(SessionData.test)
    }
}
