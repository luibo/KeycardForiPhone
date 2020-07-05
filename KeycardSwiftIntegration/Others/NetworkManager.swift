//
//  NetworkManager.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 05/02/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import Foundation
import UIKit
import Keycard
import CryptoSwift
import CommonCrypto
import Alamofire

let etherscanAPIKey = "TETQPY5CFTZI18A23T1U98E438TEJCT8AG"
let addr = "0x25686723B928C66db78f7C71C37982CdC36A20A2"
let mock = "https://api.etherscan.io/api?module=account&action=txlist&address=0x03c63ea973e34b99a370aa519c32e87674f71cfe&startblock=0&endblock=99999999&sort=asc&apikey=TETQPY5CFTZI18A23T1U98E438TEJCT8AG"


//controllare svuotamento array indirizzi
class NetworkManager {
    
    static let shared = NetworkManager()
    var session: KeycardController?
    var availableAccounts: [String] = []
    var addressesFound: [String] = []
    var addressIndex = 0
    
    
    func beginScanning() {
        session = KeycardController(onConnect: onCon, onFailure: nonCon)
        session?.start(alertMessage: "Hold your Keycard near iPhone. This could take some minutes.")
    }
    
    
    func onCon(cc: CardChannel) {
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        
        do{
            let info = try ApplicationInfo(cmdSet.select().checkOK().data)

            let pairing = (UserDefaults.standard.object(forKey: info.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
            if pairing == [] {
                try cmdSet.autoPair(password: "000000")
            } else {
                print("Found pairing info while creating BIP39. Loading...")
                print(pairing)
                cmdSet.pairing = Pairing(pairingData: pairing)
            }

            print("opening secure channel")
            try cmdSet.autoOpenSecureChannel()

            print("pin verifying")
            try cmdSet.verifyPIN(pin: "000000").checkAuthOK()
            
            var pathComponents: (seed: String, purpose: String, coinType: String, account: Int, chain: Int, addressIndex: Int)
            let splits = currentKeypath.components(separatedBy: "/")
            
            print(currentKeypath)
            print(splits)
            
            pathComponents.seed = splits[0]
            pathComponents.purpose = splits[1]
            pathComponents.coinType = splits[2]
            pathComponents.account = Int(splits[3].replacingOccurrences(of: "\'", with: ""))!
//            pathComponents.account = 0
            pathComponents.chain = Int(splits[4])!
//            pathComponents.addressIndex = Int(splits[5])!
            pathComponents.addressIndex = self.addressIndex
            
            var p = pathComponents.seed + "/"
            p += pathComponents.purpose + "/"
            p += pathComponents.coinType + "/"
            

            var x = p
            
            x += String(pathComponents.account) + "'/"
            x += String(pathComponents.chain) + "/"
            
            addressesFound = []
                
            //address gap limit = 10
            for _ in 1...gapLimit {
                //x += String(pathComponents.addressIndex)
                
                print("path: \(x + String(self.addressIndex))")

                
                print("derive and export")
                let publicKey = try BIP32KeyPair(fromTLV: cmdSet.exportKey(path: "../" + String(self.addressIndex), makeCurrent: false, publicOnly: true).checkOK().data)
                  
                addressesFound.append("0x" + publicKey.toEthereumAddress().toHexString())

                    self.addressIndex += 1
            }
                
            try cmdSet.autoUnpair()
            
        } catch let error {
            print("Interrupted: " + error.localizedDescription)
            session?.stop(errorMessage: error.localizedDescription)
            
            for a in addressesFound {
                print(a)
            }
            
            return
        }
        
        session?.stop(alertMessage: "Operation completed")
        
        print("Addresses found:")
        for addr in addressesFound {
            print(addr)
        }
        
        
        addressesFound = ["0x07B42c0036906029eB375ccb6C6a01ce944680cF",
        "0x62835145352c0359c7e37103559061808b23ea22",
        "0x794f604a9d8b1dccf62865ef60cb00dae048ea04",
        "0x4ed1fd8e13db7e08c6fb8f46ffb3752eb3343a2a",
        "0x8d5e099a355a048b5926add4a022e9b2ab4434d5",
        "0x2f54110df99e55c9624a69b103749b93fdb93f1a",
        "0xae38ca6305847d286881109f4d592b985b7fd0dd",
        "0xdccba7454da27074442c077d3f7c48aecdd2858c",
        "0xbcf3b011d70e4f3595a1767763082db6597f6d21",
        "0x830676d6774c76adfb827967434b6847f49fb0f4"]
        
        
        //availableAccounts = []
        dGroup.enter()
        
        etherscanSearch()

        dGroup.notify(queue: .main) {
            self.checkForOthers()
        }
    }
    
    
    
    func etherscanSearch() {
        var alert: UIAlertController?
        
        DispatchQueue.main.async {
            let myGroup = DispatchGroup()
            //self.availableAccounts = []
            alert = showLoadingAlert()
            for a in self.addressesFound {
                //var transactionsFound: Bool = false
                myGroup.enter()
                guard let url = URL(string: "https://api.etherscan.io/api?module=account&action=txlist&address=\(a)&startblock=0&endblock=99999999&sort=asc&apikey=\(etherscanAPIKey)") else {
                    print("Error: cannot create URL")
                    return
                }
                
                AF.request(url).responseJSON {
                    response in
                    print(response)
                    
                    switch response.result {
                        case .success(let value):
                            if let json = value as? [String:Any] {
                                let status = json["status"] as! String
                                if status == "1" {
                                    //transactionsFound = true
                                    self.availableAccounts.append(a)
                                }
                        }
                        case .failure(let error):
                            print(error)
                            break
                    }
                    myGroup.leave()
                }
            }
            
            myGroup.notify(queue: .main) {
                print("Finished all requests.")
                alert!.dismiss(animated: true, completion: nil)
                
                print("Available addresses:")
                for acc in self.availableAccounts {
                    print(acc)
                }
                dGroup.leave()
            }
        }
    }
    
    
    func checkForOthers() {
        if availableAccounts.count != gapLimit {
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: "Gap limit reached", message: "\(gapLimit) accounts were found. There could be more available addresses, do you want to keep searching?", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: {
                    (_) in
                    self.beginScanning()
                }))
                
                //alert2.show()
                UIApplication.shared.keyWindow?.rootViewController!.present(alert, animated: true)
            }
        }
    }
    
    
    

}


func showLoadingAlert() -> UIAlertController {
    let alert = UIAlertController(title: "Discovering...", message: nil, preferredStyle: .alert)

    let indicator = UIActivityIndicatorView()
    indicator.translatesAutoresizingMaskIntoConstraints = false
    alert.view.addSubview(indicator)

    let views = ["pending" : alert.view, "indicator" : indicator]
    var constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[indicator]-(-50)-|", metrics: nil, views: views as [String : Any])
    constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|[indicator]|", metrics: nil, views: views as [String : Any])
    alert.view.addConstraints(constraints)

    indicator.isUserInteractionEnabled = false
    indicator.startAnimating()

    //pending.show()
    UIApplication.shared.keyWindow?.rootViewController!.present(alert, animated: true)
    
    return alert
}






