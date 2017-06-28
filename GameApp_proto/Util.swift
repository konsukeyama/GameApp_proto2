//
//  Util.swift
//  GameApp_proto
//
//  Created by konsukeyama on 2017/06/25.
//  Copyright © 2017年 konsukeyama. All rights reserved.
//

import UIKit

class Util {
    
    // UIColorをRGBA指定する
    class func RGBA(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> UIColor {
        let r = red / 255.0
        let g = green / 255.0
        let b = blue / 255.0
        let rgba = UIColor(red: r, green: g, blue: b, alpha: alpha)
        return rgba
    }
    
}
