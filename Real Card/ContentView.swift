//
//  ContentView.swift
//  Real Card
//
//  Created by Helloyunho on 2022/09/14.
//

import SwiftUI

struct ContentView: View {
    @StateObject var mainModel = MainModel()
    @State var showAlert = false
    @State var error: Error? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: CardInsertView().environmentObject(mainModel), isActive: $mainModel.connected) { EmptyView() }
                Form {
                    Section(header: Text("Connection Info")) {
                        HStack {
                            Text("Address")
                            TextField("IP Address or Domain", text: $mainModel.addr)
                                .disableAutocorrection(true)
                        }
                        HStack {
                            Text("Port")
                            TextField("Port in number", text: $mainModel.port)
                                .disableAutocorrection(true)
                                .keyboardType(.numberPad)
                        }
                        HStack {
                            Text("Password")
                            SecureField("(optional)", text: $mainModel.password)
                                .disableAutocorrection(true)
                        }
                        HStack {
                            Spacer()
                            Button ("Connect") {
                                var task: Task<(), Never>? = nil
                                let timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
                                    task?.cancel()
                                    DispatchQueue.main.async {
                                        self.error = ConnectionError.ConnectionUnable
                                        self.showAlert = true
                                    }
                                }
                                task = Task {
                                    do {
                                        try await mainModel.connect()
                                        timer.invalidate()
                                    } catch {
                                        self.error = error
                                        self.showAlert = true
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(Text("Real Card"))
            .alert("Error", isPresented: $showAlert) {
                Button("OK") {
                    self.error = nil
                }
            } message: {
                Text(error?.localizedDescription ?? "Unknown Error.")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
