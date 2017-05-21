//
//  GmaeView.swift
//  GameApp_proto
//
//  Created by konsukeyama on 2017/05/21.
//  Copyright © 2017年 konsukeyama. All rights reserved.
//

import UIKit
import SpriteKit

class GameView: SKView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
    }
    
    // SKView継承時に必須となるイニシャライザ
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
