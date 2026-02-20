//
//  TrackTableViewCell.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 1/19/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

class TrackTableViewCell: UITableViewCell {
    
    @IBOutlet weak var artworkImageView: UIImageView!
    @IBOutlet weak var trackName: UILabel!
    @IBOutlet weak var artistName: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        artworkImageView.layer.cornerRadius = 10
        artworkImageView.clipsToBounds = true
        
        if UIDevice.deviceType == .iPhone4_4s || UIDevice.deviceType == .iPhone5_5s_SE {
            trackName.changeToSmallerFont()
            artistName.changeToSmallerFont()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard isEditing else { return }
        
        let horizontalInset: CGFloat = 30
        let layoutDirection = effectiveUserInterfaceLayoutDirection
        
        for subview in subviews {
            let typeName = String(describing: type(of: subview))
            if typeName.contains("EditControl") {
                var frame = subview.frame
                if layoutDirection == .rightToLeft {
                    frame.origin.x = bounds.width - horizontalInset - frame.width
                } else {
                    frame.origin.x = horizontalInset
                }
                subview.frame = frame
            } else if typeName.contains("Reorder") {
                var frame = subview.frame
                if layoutDirection == .rightToLeft {
                    frame.origin.x = horizontalInset
                } else {
                    frame.origin.x = bounds.width - horizontalInset - frame.width
                }
                subview.frame = frame
            }
        }
    }
    
}
