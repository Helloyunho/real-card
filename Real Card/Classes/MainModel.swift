//
//  MainModel.swift
//  Real Card
//
//  Created by Helloyunho on 2022/09/14.
//

import Foundation
import SwiftWebSocket

/*
{
  "id": 1,
  "module": "card",
  "function": "insert",
  "params": [0, "E004000000000000"]
}

{
  "id": 1,
  "errors": [],
  "data": []
}
*/

enum PlayerIndex: Int, Identifiable {
    var id: Self { self }
    
    case player1 = 0
    case player2 = 1
}

protocol IntOrString {}
extension String: IntOrString {}
extension Int: IntOrString {}

struct SpiceRequest: Encodable {
    var id: UInt
    var module: String
    var function: String
    var params: [IntOrString]
    
    enum CodingKeys: String, CodingKey {
        case id
        case module
        case function
        case params
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(module, forKey: .module)
        try container.encode(function, forKey: .function)
        var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .params)
        for param in params {
            if let param = param as? Int {
                try unkeyedContainer.encode(param)
            } else if let param = param as? String {
                try unkeyedContainer.encode(param)
            }
        }
    }
}

struct SpiceResponse: Decodable {
    var id: UInt
    var errors: [String]
}

enum ConnectionError: Error {
    case URLNotMatch
    case NoResponse
    case ConnectionUnable
}

struct ResponseError: LocalizedError {
    var errors: [String]
    var errorDescription: String? {
        errors.joined(separator: "\n")
    }
}

extension ConnectionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .URLNotMatch:
            return "URL has incorrect format."
        case .NoResponse:
            return "No Response from the server."
        case .ConnectionUnable:
            return "Unable to connect to the server."
        }
    }
}

@MainActor
class MainModel: ObservableObject {
    @Published var addr = ""
    @Published var port = "1337"
    @Published var password = ""
    @Published var connected = false
    private var _reqID: UInt = 0
    var reqID: UInt {
        get {
            _reqID += 1
            return _reqID
        }
    }

    var websocketStream: WebSocketStream?

    func connect() async throws {
        guard let url = URL(string: "ws://\(addr):\(Int(port)! + 1)") else {
            throw ConnectionError.URLNotMatch
        }
        websocketStream = WebSocketStream(url: url)
        websocketStream?.closed {_,_  in
            DispatchQueue.main.async {
                self.connected = false
            }
        }
        websocketStream?.error {_ in
            DispatchQueue.main.async {
                self.connected = false
            }
        }
        await websocketStream!.ready()
        connected = true
    }
    
    func sendCardID(id: String, index: PlayerIndex) async throws {
        let reqStruct = SpiceRequest(id: reqID, module: "card", function: "insert", params: [index.rawValue, id])
        let encoder = JSONEncoder()
        var reqJson = try encoder.encode(reqStruct) + Data([0])
        if !password.isEmpty {
            var rc4 = RC4()
            rc4.initialize(password.data(using: .utf8)!)
            rc4.encrypt(&reqJson)
        }
        try await websocketStream?.send(reqJson)
        for await rawData in websocketStream! {
            let decoder = JSONDecoder()
            if var data = rawData as? Data {
                if !password.isEmpty {
                    var rc4 = RC4()
                    rc4.initialize(password.data(using: .utf8)!)
                    rc4.encrypt(&data)
                }
                _ = data.removeLast()
                do {
                    let resp = try decoder.decode(SpiceResponse.self, from: data)
                    if !resp.errors.isEmpty {
                        throw ResponseError(errors: resp.errors)
                    }
                } catch {
                    if error is ResponseError {
                        throw error
                    }
                }
                return
            }
        }
    }
    
    func disconnect() async {
        websocketStream?.close(code: .goingAway)
    }
}
