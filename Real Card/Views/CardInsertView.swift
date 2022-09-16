//
//  CardInsertView.swift
//  Real Card
//
//  Created by Helloyunho on 2022/09/15.
//

import SwiftUI
import CoreNFC

struct CardInsertView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var mainModel: MainModel
    @StateObject var nfcReader = NFCReader()
    @State var playerIndex: PlayerIndex = .player1
    @State var showAlert = false
    @State var error: Error? = nil
    @State var showRepeatAlert = false
    
    var body: some View {
        VStack {
            Form {
                Toggle("Auto Read", isOn: $nfcReader.repeat)
                    .onChange(of: nfcReader.repeat) { value in
                        showRepeatAlert = value
                    }
                Picker("Player", selection: $playerIndex) {
                    Text("Player 1")
                        .tag(PlayerIndex.player1)
                    Text("Player 2")
                        .tag(PlayerIndex.player2)
                }
                .pickerStyle(.segmented)
                Button(action: {
                    nfcReader.initialize()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                        Text("Read")
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 40)
            }
            .alert("Auto Read", isPresented: $showRepeatAlert) {
                Button ("OK") {}
            } message: {
                Text("Auto Read is a feature that keep tries to detect a card. It may drain your battery very quickly. Press the read button to start.")
            }
            .alert("Error", isPresented: $nfcReader.showErrorAlert) {
                Button ("OK") {
                    nfcReader.error = nil
                }
            } message: {
                Text(nfcReader.error?.localizedDescription ?? "Unknown error.")
            }
            .alert("Error", isPresented: $showAlert) {
                Button ("OK") {
                    error = nil
                }
            } message: {
                Text(error?.localizedDescription ?? "Unknown error.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .nfcCardRead)) { nfcTag in
                guard let nfcTag = nfcTag.object as? NFCFeliCaTag else {
                    return
                }
                
                let tagID = nfcTag.currentIDm.map { String(format: "%02hhX", $0) }.joined()
                var task: Task<(), Never>? = nil
                let timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
                    task?.cancel()
                    DispatchQueue.main.async {
                        self.error = ConnectionError.NoResponse
                        self.showAlert = true
                    }
                }
                task = Task {
                    do {
                        try await mainModel.sendCardID(id: tagID, index: playerIndex)
                        timer.invalidate()
                    } catch {
                        self.error = error
                        self.showAlert = true
                    }
                }
            }
            .onChange(of: mainModel.connected) { connected in
                if !connected {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    Task {
                        await mainModel.disconnect()
                    }
                }) {
                    Image(systemName: "chevron.backward")
                }
            }
        }
    }
}

struct CardInsertView_Previews: PreviewProvider {
    static var previews: some View {
        CardInsertView()
    }
}
