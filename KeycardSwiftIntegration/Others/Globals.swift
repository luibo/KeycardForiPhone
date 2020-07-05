//
//  Globals.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 18/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import Foundation
import Keycard
import CoreNFC
import UIKit


var pin: String?
var puk: String?
var pp: String?
var dGroup = DispatchGroup()
var kSession: KeycardController?
var applicationInfo: ApplicationInfo?
var cmdSet: KeycardCommandSet?
var currentKeypath = ""
var gapLimit = 10
var appVersion: String = ""
var selectedCoin: WalletCell?


let logo = UIImage(named: "navbarLogo1")
let imageView = UIImageView(image: logo)

let coins: [String] = ["Bitcoin (BTC)",
                       "Ether (ETH)",
                       "Ripple (XRP)",
                       "Litecoin (LTC)",
                       "Bitcoin Cash (BCH)",
                       "Monero (XMR)",
                       "EOS (EOS)",
                       "BitcoinSV (BSV)",
                       "Binance Coin (BNB)",
                       "æternity (AE)",
                       "Lisk (LSK)",
                       "NEO (NEO)"]

let coinIndexes = ["Bitcoin (BTC)": "0",
                   "Ether (ETH)": "60",
                   "Ripple (XRP)": "144",
                   "Litecoin (LTC)": "2",
                   "Bitcoin Cash (BCH)": "145",
                   "Monero (XMR)": "128",
                   "EOS (EOS)": "194",
                   "BitcoinSV (BSV)": "236",
                   "Binance Coin (BNB)": "714",
                   "æternity (AE)": "457",
                   "Lisk (LSK)": "134",
                   "NEO (NEO)": "888"]


func beginCardSession() {
    kSession = KeycardController(onConnect: beginKeycardSession, onFailure: onDisconnection)
    print("Started scanning")
    kSession?.start(alertMessage: "Hold your Keycard near iPhone.")
}


func beginKeycardSession(cardChannel: CardChannel) {
    cmdSet = KeycardCommandSet(cardChannel: cardChannel)
    
    do {
        applicationInfo = try ApplicationInfo(cmdSet!.select().checkOK().data)
    } catch {
        print(error)
        dGroup.leave()
    }
    
    if !performPairing(applicationInfo: applicationInfo!, cmdSet: cmdSet!) {
        dGroup.leave()
        return
    }
    
    if !performAuthentication(cmdSet: cmdSet!) {
        dGroup.leave()
        return
    }

    dGroup.leave()
}

func onDisconnection(error: Error) {
    print("Connection interrupted due to error: \(error)")
    dGroup.leave()
}


func performPairing(applicationInfo: ApplicationInfo, cmdSet: KeycardCommandSet) -> Bool {
    do {
        print("Pairing slots: ", applicationInfo.freePairingSlots)
        
        let pairing = (UserDefaults.standard.object(forKey: applicationInfo.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
            
        if pairing == [] {
            do {
                print("Saving pairing info")
                try cmdSet.autoPair(password: pp!)
            } catch {
                print("Error: \(error)")
            }
        } else {
            print("Found pairing info")
            cmdSet.pairing = Pairing(pairingData: pairing)
        }

        print("opening secure channel")
        try cmdSet.autoOpenSecureChannel()
                    
    } catch {
        print(error)
        kSession?.stop(errorMessage: error.localizedDescription)
        return false
    }
    
    return true
}



func performAuthentication(cmdSet: KeycardCommandSet) -> Bool {
    let userPin = pin!
        print("user pin: \(userPin)")
        
        do {
            print("verifying pin: \(userPin)")
            try cmdSet.verifyPIN(pin: userPin).checkAuthOK()
            print("pin verified")
        } catch {
            print("cannot complete the operation due to error: \(error.localizedDescription)")
            kSession?.stop(errorMessage: error.localizedDescription)
            return false
        }
    return true
}

func nonCon(err:Error){
    print(err)
}



func share(str: String, instance: UIViewController) {
    let textToShare = [ str ]
    let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
    activityViewController.popoverPresentationController?.sourceView = instance.view
    activityViewController.excludedActivityTypes = [UIActivity.ActivityType.postToFacebook]

    // present the view controller
    instance.present(activityViewController, animated: true, completion: nil)

}



extension UIAlertController {

    func show() {
        present(animated: true, completion: nil)
    }

    func present(animated: Bool, completion: (() -> Void)?) {
        if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
            presentFromController(controller: rootVC, animated: animated, completion: completion)
        }
    }

    private func presentFromController(controller: UIViewController, animated: Bool, completion: (() -> Void)?) {
        if let navVC = controller as? UINavigationController,
            let visibleVC = navVC.visibleViewController {
            presentFromController(controller: visibleVC, animated: animated, completion: completion)
        } else
            if let tabVC = controller as? UITabBarController,
                let selectedVC = tabVC.selectedViewController {
                presentFromController(controller: selectedVC, animated: animated, completion: completion)
            } else {
                controller.present(self, animated: animated, completion: completion);
        }
    }
}



extension StringProtocol {
    var hexa: [UInt8] {
        var startIndex = self.startIndex
        return stride(from: 0, to: count, by: 2).compactMap { _ in
            let endIndex = index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }
}
