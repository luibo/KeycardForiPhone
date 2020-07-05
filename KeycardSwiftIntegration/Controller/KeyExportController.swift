//
//  KeyExportController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 26/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit
import Keycard
import CryptoSwift

class KeyExportController: UIViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var testButton: UIButton!
    
    var session: KeycardController?
    var onlyCurrentKeypair: Bool?
    var selectedOption: Int?
    var path: String?
    var key: String?
    var exportEthAddress = false


    override func viewDidLoad() {
        super.viewDidLoad()
        
        testButton.isHidden = true
        
        descriptionLabel.text = "It's possible to export any public key as well as the private key of keypaths defined in the EIP-1581 specifications. Those keys, by design, are not to be used for transactions but are instead usable for operations with lower security concerns."
        
         self.tabBarController?.navigationItem.titleView = imageView
    }
    

    @IBAction func exportCurrentKey(_ sender: Any) {
        selectedOption = 0
        createAlert()
        
    }
    
    @IBAction func deriveAndExport(_ sender: Any) {
        
        let alert = UIAlertController(title: "Insert path", message: "", preferredStyle: .alert)
        
        alert.addTextField { (path) in
            path.placeholder = "Path"
        }
        
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { [weak alert]
            (_) in
            
            self.path = alert?.textFields![0].text
            self.selectedOption = 1
            self.createAlert()
            
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.present(alert, animated: true)
        
    }
    
    
    func createAlert() {
        let alert = UIAlertController(title: "", message: "Choose an exporting option.", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Export only current public key", style: .default, handler: { (_) in
            self.onlyCurrentKeypair = true
            self.exportEthAddress = false
            self.beginScanning()
        }))
        
        alert.addAction(UIAlertAction(title: "Export entire keypair (EIP-1581 paths only)", style: .default, handler: { (_) in
            self.onlyCurrentKeypair = false
            self.exportEthAddress = false
            self.beginScanning()
        }))
        
        alert.addAction(UIAlertAction(title: "Export Ethereum address", style: .default, handler: { (_) in
            self.onlyCurrentKeypair = true
            self.exportEthAddress = true
            self.beginScanning()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.present(alert, animated: true)
    }
    
    
    
    func beginScanning() {
        session = KeycardController(onConnect: onCon, onFailure: nonCon)
        session?.start(alertMessage: "Hold your Keycard near iPhone.")
    }
    
    
    func onCon(cc:CardChannel) {
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        var publicKey: BIP32KeyPair?
        
        do{
            let info = try ApplicationInfo(cmdSet.select().checkOK().data)
            
            let pairing = (UserDefaults.standard.object(forKey: info.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
            if pairing == []{
                print("Saving pairing info")
                try cmdSet.autoPair(password: pp!)

            } else {
                print("Found pairing info while creating BIP39. Loading...")
                cmdSet.pairing = Pairing(pairingData: pairing)
            }

            try cmdSet.autoOpenSecureChannel()
            
            print("pin verifying")
            try cmdSet.verifyPIN(pin: pin!).checkAuthOK()
            
            if self.selectedOption == 0 {
                publicKey = try BIP32KeyPair(fromTLV: try cmdSet.exportCurrentKey(publicOnly: onlyCurrentKeypair!).checkOK().data)
            } else if self.selectedOption == 1 {
                publicKey = try BIP32KeyPair(fromTLV: try cmdSet.exportKey(path: self.path!, makeCurrent: false, publicOnly: onlyCurrentKeypair!).checkOK().data)
            }

            try cmdSet.autoUnpair()
     
        } catch let error {
            print("Interrupted: " + error.localizedDescription)
            session?.stop(errorMessage: error.localizedDescription)
            do {
                try cmdSet.autoUnpair()
            } catch {
                print(error)
            }
            return
        }
        session?.stop(alertMessage: "Operation completed")
        
        DispatchQueue.main.async {
            
            if self.exportEthAddress {
                self.key = "0x" + (publicKey?.toEthereumAddress().toHexString() ?? "null")
            } else {
                self.key = publicKey?.publicKey.toHexString()
            }
            
            print(self.key!)
            print("is extended: \(publicKey!.isExtended)")
            
            let alert = UIAlertController(title: "Export complete", message: "\n\(self.key ?? "null")\n", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Export", style: .default, handler: {
                (_) in
                share(str: self.key ?? "null", instance: self)
            }))
            self.present(alert, animated: true)
        }
    }
    

    @IBAction func tryCall() {
        //NetworkManager.shared.beginScanning()
       
        let alertController = UIAlertController(title: "Choose an account to add\n\n\n\n\n\n\n\n", message: nil, preferredStyle: .alert)

        let margin: CGFloat = 10.0
        
        print(alertController.view.frame.width)
        print(alertController.view.bounds.width)
            
        let table = UITableView(frame: CGRect(x: margin, y: margin+40, width: 250, height: 150))
        table.register(UITableViewCell.self, forCellReuseIdentifier: "MyCell")
        table.dataSource = self
        table.delegate = self

        alertController.view.addSubview(table)

        let somethingAction = UIAlertAction(title: "Something", style: .default, handler: {(alert: UIAlertAction!) in print("something")})

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(somethingAction)
        alertController.addAction(cancelAction)

        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion:{})
        }
        
    }

}

extension KeyExportController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyCell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel!.text = "MarioMarioMarioMarioMarioMarioMario"
        return cell
    }
    
}

