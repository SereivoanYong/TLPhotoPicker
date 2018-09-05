//
//  SVCollectionTableViewCell.swift
//  TLPhotosPicker
//
//  Created by wade.hawk on 2017. 5. 3..
//  Copyright © 2017년 wade.hawk. All rights reserved.
//

import UIKit

final class SVCollectionTableViewCell: UITableViewCell {
  
  let thumbnailImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.backgroundColor = .white
    imageView.clipsToBounds = true
    imageView.contentMode = .scaleAspectFill
    return imageView
  }()
  let titleLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .white
    label.font = .systemFont(ofSize: 14, weight: .semibold)
    label.numberOfLines = 1
    label.textAlignment = .left
    label.textColor = .black
    return label
  }()
  let subtitleLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .white
    label.font = .systemFont(ofSize: 12, weight: .regular)
    label.numberOfLines = 1
    label.textAlignment = .left
    label.textColor = UIColor(white: 110/255, alpha: 1)
    return label
  }()
  
  override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    contentView.addSubview(thumbnailImageView)
    contentView.addSubview(titleLabel)
    contentView.addSubview(subtitleLabel)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let layoutMargins = contentView.layoutMargins
    thumbnailImageView.frame = CGRect(x: layoutMargins.left, y: 12, width: 50, height: 50)
    let titleHeight = ceil(titleLabel.font.lineHeight)
    let subtitleHeight = ceil(subtitleLabel.font.lineHeight)
    titleLabel.frame = CGRect(x: thumbnailImageView.frame.maxX + 20, y: ceil((contentView.bounds.height - titleHeight - 2 - subtitleHeight) / 2), width: contentView.bounds.width - layoutMargins.left - layoutMargins.right, height: titleHeight)
    subtitleLabel.frame = CGRect(x: thumbnailImageView.frame.maxX + 20, y: titleLabel.frame.maxY + 2, width: contentView.bounds.width - layoutMargins.left - layoutMargins.right, height: titleHeight)
  }
}
