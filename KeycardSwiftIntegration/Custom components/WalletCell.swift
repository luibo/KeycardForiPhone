//
//  WalletCell.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 24/02/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit

class WalletCell: UITableViewCell {
    
    @IBOutlet weak var pathLabel: UILabel!
    @IBOutlet weak var check: UIImageView! {
        didSet {
            check.isHidden = true
        }
    }
    
    var cellSelected = false
    var coinType: String?

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
    
    func select() {
        cellSelected = true
        check.isHidden = false
        selectedCoin = self
    }
    
    func deselect() {
        cellSelected = false
        check.isHidden = true
    }
    
    
}
