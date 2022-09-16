//===--- RC4.swift --------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
struct RC4 {
    var state: Data
    var i: UInt8 = 0
    var j: UInt8 = 0

    init() {
        state = Data(count: 256)
    }

    mutating
    func initialize(_ key: Data) {
        for i in 0..<256 {
            state[i] = UInt8(i)
        }

        var j: UInt8 = 0
        for i in 0..<256 {
            let k: UInt8 = key[i % key.count]
            let s: UInt8 = state[i]
            j = j &+ s &+ k
            swapByIndex(i, y: Int(j))
        }
    }

    mutating
    func swapByIndex(_ x: Int, y: Int) {
        let t1: UInt8 = state[x]
        let t2: UInt8 = state[y]
        state[x] = t2
        state[y] = t1
    }

    mutating
    func next() -> UInt8 {
        i = i &+ 1
        j = j &+ state[Int(i)]
        swapByIndex(Int(i), y: Int(j))
        return state[Int(state[Int(i)] &+ state[Int(j)]) & 0xFF]
    }

    mutating
    func encrypt(_ data: inout Data) {
        let cnt = data.count
        for i in 0..<cnt {
            data[i] = data[i] ^ next()
        }
    }
}
