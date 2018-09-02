//
//  ReaderMoreViewController.swift
//  Tangem
//
//  Created by Gennady Berezovsky on 02.09.18.
//  Copyright © 2018 dns user. All rights reserved.
//

import Foundation

class ReaderMoreViewController: ModalActionViewController {
    
    @IBOutlet weak var contentLabel: UILabel!
    
    var contentText = ""
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let paragraphStyle = paragraphStyleWith(lineSpacingChange: 10.0)
        let attributedText = NSAttributedString(string: contentText, attributes: [NSAttributedStringKey.paragraphStyle : paragraphStyle,
                                                                                  NSAttributedStringKey.kern : 1.12])
        
        contentLabel.attributedText = attributedText
    }
    
    private func paragraphStyleWith(lineSpacingChange: CGFloat, alignment: NSTextAlignment = .center) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing += lineSpacingChange
        paragraphStyle.alignment = alignment
        
        return paragraphStyle
    }
    
}