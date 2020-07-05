//
//  Transaction.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 26/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import Foundation

class Transaction {
    var sender: String
    var receiver: String
    var value: UInt8
    var hash: String
    
    init(from: String, to: String, value: UInt8, hash: String) {
        self.sender = from
        self.receiver = to
        self.value = value
        self.hash = hash
    }
}



