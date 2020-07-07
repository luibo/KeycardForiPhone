//
//  SelectWalletController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 24/02/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit
import Keycard
import Alamofire

class SelectWalletController: UIViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel! {
        didSet {
            descriptionLabel.text = "Here you can choose which wallet to use, selecting the cryptocoin you want. An account discovery will be performed in order to get the available accounts."
        }
    }
    @IBOutlet weak var coinsTableView: UITableView!
    
    var session: KeycardController?
    var availableAccounts: [(path: String, address: String)] = []
    var accountsFound: [(path: String, address: String)] = []
    var addr: [(path: String, address: String)] = []
    var chosenAddress: (path: String, address: String)?
    var selectedIndex: IndexPath?
    var coin = ""
    var pathToDerive = ""
    var addressIndex = 0
    var okAlertAction: UIAlertAction?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tabBarController?.navigationItem.titleView = imageView
        
    }
    
    
    
    @IBAction func startDiscovery() {
        if coin == "" {
            let alert = UIAlertController(title: "", message: "Please choose a coin.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        self.availableAccounts = []
        self.addressIndex = 0
        
        beginScanning(flag: 0)
    }
    
    
    
    func beginScanning(flag: Int) {
        if flag == 0 {
            session = KeycardController(onConnect: onCon, onFailure: nonCon)
            session?.start(alertMessage: "Searching for \(coin) addresses.\nHold your Keycard near iPhone.")
        } else if flag == 1 {
            session = KeycardController(onConnect: deriveKey, onFailure: nonCon)
            session?.start(alertMessage: "Hold your Keycard near iPhone.")
        }
    }

    
    
    func onCon(cc:CardChannel) {
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        var pathToSearch = ""
        
        do {
            let info = try ApplicationInfo(cmdSet.select().checkOK().data)

            let pairing = (UserDefaults.standard.object(forKey: info.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
            if pairing == [] {
                try cmdSet.autoPair(password: pp!)
            } else {
                print("Found pairing info while creating BIP39. Loading...")
                print(pairing)
                cmdSet.pairing = Pairing(pairingData: pairing)
            }

            print("opening secure channel")
            try cmdSet.autoOpenSecureChannel()

            print("pin verifying")
            try cmdSet.verifyPIN(pin: pin!).checkAuthOK()
            
            if currentKeypath == "m" {
                currentKeypath = "m/44'/0'/0'/0/0"
            }
            
            var pathComponents: (seed: String, purpose: String, coinType: String, account: Int, chain: Int, addressIndex: Int)
            let splits = currentKeypath.components(separatedBy: "/")
            
            pathComponents.seed = splits[0]
            pathComponents.purpose = splits[1]
            pathComponents.coinType = splits[2]
            pathComponents.account = Int(splits[3].replacingOccurrences(of: "\'", with: ""))!
            pathComponents.chain = Int(splits[4])!
            pathComponents.addressIndex = 0
            
            pathToSearch = "m/44'/\(coinIndexes[coin] ?? "0")'/\(pathComponents.account)'/0/"
            
            print("path: \(pathToSearch + String(addressIndex))")

            print("derive and export")
            let publicKey = try BIP32KeyPair(fromTLV: cmdSet.exportKey(path: pathToSearch + String(addressIndex), makeCurrent: false, publicOnly: true).checkOK().data)
              
            accountsFound = []
            addr = []
            accountsFound.append((pathToSearch, "0x" + publicKey.toEthereumAddress().toHexString()))

            addressIndex += 1
            
            for _ in 2...gapLimit {
                //x += String(pathComponents.addressIndex)
                
                print("path: \(pathToSearch + String(addressIndex))")

                print("derive and export")
                let publicKey = try BIP32KeyPair(fromTLV: cmdSet.exportKey(path: "../" + String(addressIndex), makeCurrent: false, publicOnly: true).checkOK().data)
                  
                accountsFound.append((pathToSearch + String(addressIndex), "0x" + publicKey.toEthereumAddress().toHexString()))

                addressIndex += 1
            }
            
            
            try cmdSet.deriveKey(path: currentKeypath).checkOK()
            
            try cmdSet.autoUnpair()
            
        } catch {
            print(error)
            session?.stop(errorMessage: error.localizedDescription)
            //return
        }
        
        session?.stop(alertMessage: "Operation completed")
        
        print("Accounts found:")
        for a in accountsFound {
            print(a.address)
        }

        
        dGroup.enter()
        
        etherscanSearch()

        dGroup.notify(queue: .main) {
            self.checkForOthers()
        }
    }
    
    
    
    func deriveKey(cc: CardChannel) {
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        let pathToDerive: String = self.chosenAddress!.path
                
        
        
        print("path to derive: \(pathToDerive)")
        
        
        do{
            let info = try ApplicationInfo(cmdSet.select().checkOK().data)
            
            let pairing = (UserDefaults.standard.object(forKey: info.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
            if pairing == [] {
                try cmdSet.autoPair(password: pp!)
            } else {
                print("Found pairing info while key derivation")
                print(pairing)
                cmdSet.pairing = Pairing(pairingData: pairing)
            }

            print("opening secure channel")
            try cmdSet.autoOpenSecureChannel()
                
            print("pin verifying")
            try cmdSet.verifyPIN(pin: pin!).checkAuthOK()
            
            print("key derivation")
            try cmdSet.deriveKey(path: pathToDerive).checkOK()

            try cmdSet.autoUnpair()
     
        } catch let error {
            print("Interrupted: "+error.localizedDescription)
            session?.stop(errorMessage: error.localizedDescription)
        }
        session?.stop(alertMessage: "Derivation completed")
        
        currentKeypath = pathToDerive
        
    }
    
    
    
    func etherscanSearch() {
        var alert: UIAlertController?
        
        DispatchQueue.main.async {
            let myGroup = DispatchGroup()
            //self.availableAccounts = []
            alert = self.showLoadingAlert()
            for a in self.accountsFound {
                myGroup.enter()
                guard let url = URL(string: "https://api.etherscan.io/api?module=account&action=txlist&address=\(a.address)&startblock=0&endblock=99999999&sort=asc&apikey=\(etherscanAPIKey)") else {
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
                                    self.addr.append(a)
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
                for acc in self.addr {
                    print(acc.address)
                }
                dGroup.leave()
            }
        }
    }
    
    
    
        func checkForOthers() {
            if addr.count == gapLimit {
                DispatchQueue.main.async {
                    //self.controllerInstance!.dismiss(animated: true, completion: nil)
                    
                    let alert = UIAlertController(title: "Gap limit reached", message: "\(gapLimit) accounts were found. There could be more available addresses, do you want to keep searching?", preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {
                        (_) in
                        self.showList()
                    }))
                    
                    alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: {
                        (_) in
                        self.beginScanning(flag: 0)
                    }))
                    
                    self.present(alert, animated: true
                    )
                    
                }
            } else if addr.count > 0 {
                showList()
            } else {
                let alert = UIAlertController(title: "", message: "No available accounts found.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default))
                self.present(alert, animated: true)
                
            }
            
        }
    

    
    func showList() {
        let alertController = UIAlertController(title: "\(availableAccounts.count) accounts found\n\n\n\n\n\n\n\n", message: nil, preferredStyle: .alert)

         let margin: CGFloat = 10.0
             
         let table = UITableView(frame: CGRect(x: margin, y: margin+40, width: 250, height: 150))
         table.register(UITableViewCell.self, forCellReuseIdentifier: "listCell")
         table.dataSource = self
         table.delegate = self

         alertController.view.addSubview(table)

         let somethingAction = UIAlertAction(title: "Add", style: .default, handler: {(alert: UIAlertAction!)
            in
            self.beginScanning(flag: 1)
         })

         let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

         alertController.addAction(somethingAction)
         alertController.addAction(cancelAction)

        self.okAlertAction = alertController.actions[0]
        okAlertAction?.isEnabled = false

        self.present(alertController, animated: true)
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
         
         self.present(alert, animated: true)
         
         return alert
     }
}


extension SelectWalletController: UITableViewDataSource, UITableViewDelegate {
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if tableView == coinsTableView {
            return coins.count
        } else {
            return availableAccounts.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell?
        
        if tableView == coinsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "walletCell", for: indexPath) as! WalletCell
            
            cell.coinType = coins[indexPath.row]
            cell.pathLabel.text = cell.coinType
            
            if selectedIndex != indexPath {
                cell.check.isHidden = true
            } else {
                cell.check.isHidden = false
            }
            return cell
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "listCell", for: indexPath)
            cell?.textLabel?.text = self.availableAccounts[indexPath.row].address
            cell?.textLabel?.numberOfLines = 0
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == coinsTableView {
            let cell = tableView.cellForRow(at: indexPath) as! WalletCell
            if let sc = selectedCoin {
                sc.deselect()
            }
            cell.select()
            selectedIndex = indexPath
            coin = cell.coinType!
            print(cell.coinType!)
            
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            self.chosenAddress = availableAccounts[indexPath.row]
            print(chosenAddress!)
            self.okAlertAction?.isEnabled = true
        }
    }
    
    
    
}


