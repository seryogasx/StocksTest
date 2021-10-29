//
//  TableViewCell.swift
//  Stocks
//
//  Created by Сергей Петров on 05.09.2021.
//

import UIKit

class StockCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setup(title: String, symbol: String) {
        titleLabel.text = title
        detailLabel.text = symbol
    }
}
