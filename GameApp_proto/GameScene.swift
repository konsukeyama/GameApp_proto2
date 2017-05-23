//
//  GameScene.swift
//  GameApp_proto
//
//  Created by konsukeyama on 2017/05/19.
//  Copyright © 2017年 konsukeyama. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit // <-とりあえず必要ないかも...

//移動方向
enum Direction: Int {
    case right = 0	// 右
    case left  = 1	// 左
}

enum NodeName: String {                          // <--これらは初期値""でもOK?
    case frame_ground = "frame_ground" // 地面あたり
    case frame_floor  = "frame_floor"  // 浮床あたり
    case player       = "player"       // プレイヤー
    case backGround   = "backGround"   // 背景
    case ground       = "ground"       // 地面
    case floor        = "floor"        // 浮床
    
    // 衝突判定カテゴリ
    func category() -> UInt32 {
        switch self {
        case .frame_ground:
            return 0x00000001 << 0 // 地面あたり
        case .frame_floor:
            return 0x00000001 << 1 // 浮床あたり
        case .player:
            return 0x00000001 << 2 // プレイヤーあたり
        default:
            return 0x00000000
        }
    }
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // 画面まわりプロパティ
    let baseNode = SKNode()                     // ゲームベースノード
    let backScrNode = SKNode()                  // 背景用ノード
    // var baseNode: SKNode!                    // ゲームベースノード　※上記と同じ？（後で検証する）
    // var backScrNode: SKNode!                 // 背景用ノード　　　　※上記と同じ？（後で検証する）
    var allScreenSize = CGSize(width: 0, height: 0)     // 全シーンのサイズ（ここでは初期化のみ）
    let oneScreenSize = CGSize(width: 375, height: 667) // 1画面分のサイズ
    
    // プレイヤーまわりプロパティ
    var playerNode: SKSpriteNode!               // プレイヤー用スプライトノード
    var playerDirection: Direction = .right     // 移動方向
    var physicsRadius: CGFloat = 14.0           // 物理半径
    var playerAcceleration: CGFloat = 50.0      // 移動加速値
    var playerMaxVelocity: CGFloat = 200.0      // MAX移動値
    var jumpForce: CGFloat = 16.0               // ジャンプ力
    var charXOffset: CGFloat = 0                // X位置のオフセット
    var charYOffset: CGFloat = 0                // Y位置のオフセット
    var moving: Bool = false                    // フラグ：移動中
    var jumping: Bool = false                   // フラグ：ジャンプ中
    var falling: Bool = false                   // フラグ：落下中
    
    var tapPoint: CGPoint = CGPoint.zero        // タップ座標
    var screenSpeed: CGFloat = 12.0             // スクリーンノードのスピード
    var screenSpeedScale: CGFloat = 1.0         // ？？？

    /// シーンが表示されたときに呼ばれる
    override func didMove(to view: SKView) {
        // Get label node from scene and store it for use later

        // 背景色をリセット
        self.backgroundColor = SKColor.clear
        
        // 衝突判定デリゲート
        self.physicsWorld.contactDelegate = self

        //--------------------------------------------------
        // 背景作成
        //--------------------------------------------------

        // シーンに各ノードを追加
        self.addChild(self.baseNode)    // 地面、キャラ
        self.addChild(self.backScrNode) // 背景
        
        // 全シーンのサイズを設定
        let wCount = 4 // 横の画面数
        self.allScreenSize = CGSize(width: self.oneScreenSize.width * CGFloat(wCount), height: self.size.height)
        
        // シーンファイル読み込み
        if let scene = SKScene(fileNamed: "GameScene.sks") {
            // シーンファイルの取得成功した場合

            //--------------------------------------------------
            // 背景
            //--------------------------------------------------
            // シーンファイルの子ノード（背景スプライト: back_wall）を探して処理を実行
            scene.enumerateChildNodes(withName: "back_wall", using: { (node, stop) -> Void in
                let back_wall = node as! SKSpriteNode         // 子ノードをスプライトノードとして使用
                back_wall.name = NodeName.backGround.rawValue // スプライトノード名をセット（＝列挙体「backGround」の値）
                back_wall.removeFromParent()                  // シーンから子ノードを削除
                self.backScrNode.addChild(back_wall)          // 背景用ノード（backScrNode）にスプライトノードを追加
            })

            //--------------------------------------------------
            // 地面
            //--------------------------------------------------
            // シーンファイルの子ノード（地面スプライト: ground）を探して処理を実行
            scene.enumerateChildNodes(withName: "ground", using: { (node, stop) -> Void in
                let ground = node as! SKSpriteNode
                ground.name = NodeName.ground.rawValue
                ground.removeFromParent()
                self.baseNode.addChild(ground)                // ゲームベースノード（baseNode）にスプライトノードを追加
            })
            
            //--------------------------------------------------
            // 浮床
            //--------------------------------------------------
            // シーンファイルの子ノード（浮床スプライト: floor）を探して処理を実行
            scene.enumerateChildNodes(withName: "floor", using: { (node, stop) -> Void in
                let floor = node as! SKSpriteNode
                floor.name = NodeName.floor.rawValue
                floor.removeFromParent()
                self.baseNode.addChild(floor)                 // ゲームベースノード（baseNode）にスプライトノードを追加
            })

            //--------------------------------------------------
            // プレイヤー
            //--------------------------------------------------
            self.playerDirection = .right // 移動方向（右: 0）
            self.charXOffset = self.oneScreenSize.width * 0.5
            self.charYOffset = self.oneScreenSize.height * 0.5
            
            // シーンファイルの子ノード（プレイヤースプライト: player）を探して処理を実行
            scene.enumerateChildNodes(withName: "player", using: { (node, stop) -> Void in
                let player = node as! SKSpriteNode      // 子ノードをスプライトノードとして使用
                self.playerNode = player                // プレイヤー用スプライトノード（playerNode）にセット
                player.removeFromParent()               // シーンから子ノードを削除
                self.baseNode.addChild(self.playerNode) // ゲームベースノード（baseNode）にスプライトノードを追加

                // 物理設定
                self.playerNode.physicsBody = SKPhysicsBody(circleOfRadius: self.physicsRadius, center: CGPoint(x: 0, y: self.physicsRadius)) // 物理体を作成
                self.playerNode.physicsBody!.friction = 1.0			                                                               // 摩擦（0〜1.0、デフォ: 0.2）
                self.playerNode.physicsBody!.allowsRotation = false	                                                               // 回転（false: 回転禁止）
                self.playerNode.physicsBody!.restitution = 0.0                                                                     // 弾力性（跳ね返り。0〜1.0、デフォ: 0.2）
                self.playerNode.physicsBody!.categoryBitMask = NodeName.player.category()                                          // 衝突判定カテゴリ（プレイヤー）
                self.playerNode.physicsBody!.collisionBitMask = NodeName.frame_ground.category() | NodeName.frame_floor.category() // 衝突させる相手（地面、浮床）
                self.playerNode.physicsBody!.contactTestBitMask = 0                                                                // 衝突時に通知を受ける相手（なし）
                self.playerNode.physicsBody!.usesPreciseCollisionDetection = true // 判定精度（true: 高い）※小さく＆早いものはtrueがベスト
            })
            
            //--------------------------------------------------
            // 外壁
            //--------------------------------------------------
            let wallFrameNode = SKNode()                                                  // 外壁用ノード
            self.baseNode.addChild(wallFrameNode)                                         // ゲームベースノードに追加
            // 読み込んだシーンのサイズから外壁の物理体を作成する。※外壁は衝突時に動かない（isDynamic: false）になる。
            wallFrameNode.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 0, width: scene.size.width, height: scene.size.height))
            wallFrameNode.physicsBody!.categoryBitMask = NodeName.frame_ground.category() // 衝突判定カテゴリ
            wallFrameNode.physicsBody!.usesPreciseCollisionDetection = true               // 判定精度（true: 高い）
        }

    }

    /// プレイヤーアクション
    // 右移動
    func moveToRight() {
        self.moving = true					                               // 移動中フラグON
        self.playerDirection = .right                                      // 移動方向（右: 0）
        if self.jumping == false && self.falling == false {
            // ジャンプ中でも落下中でもない場合
            let names = ["right2", "right1", "right3", "right1"]           // 移動画像を配列セット
            self.startTextureAnimation(self.playerNode, names: names)      // テクスチャアニメ実行
        } else {
            // ジャンプ
            self.playerNode.texture = SKTexture(imageNamed: "right_jump1") // テクスチャ（ジャンプ中）をセット
        }
    }

    // 左移動
    func moveToLeft() {
        self.moving = true
        self.playerDirection = .left
        if self.jumping == false && self.falling == false {
            let names = ["left2", "left1", "left3", "left1"]
            self.startTextureAnimation(self.playerNode, names: names)
        } else {
            self.playerNode.texture = SKTexture(imageNamed: "left_jump1")
        }
    }
    
    // 停止
    func moveStop() {
        self.moving = false                                               // 移動中フラグOFF
        if self.jumping == false && self.falling == false {
            // ジャンプ中でも落下中でもない場合
            var name: String!
            if self.playerDirection == .right {
                // 移動方向が「右」の場合
                name = "right1"
            } else {
                // 移動方向が「左」の場合
                name = "left1"
            }
            self.stopTextureAnimation(self.playerNode, name: name)         // プレイヤーのアニメを停止
            self.playerNode.physicsBody!.velocity = CGVector(dx: 0, dy: 0) // プレイヤーの動きをゼロにする
        }
    }
    
    // ジャンプ
    func jumpingAction() {
        if self.jumping == false && self.falling == false {
            // ジャンプ中でも落下中でもない場合
            self.moving = false // 移動中フラグOFF
            self.jumping = true // ジャンプ中フラグON
            
            // 衝突判定変更（ジャンプ中は浮床と衝突させない）
            self.playerNode.physicsBody!.collisionBitMask = NodeName.frame_ground.category()     // 衝突させる相手（地面）
            self.playerNode.physicsBody!.contactTestBitMask = 0                                  // 衝突時に通知を受ける相手（なし）
            
            if self.playerDirection == .left {
                // 移動方向が「左」の場合
                self.stopTextureAnimation(self.playerNode, name: "left_jump1")                   // プレイヤーのアニメを停止
                self.playerNode.physicsBody!.applyImpulse(CGVector(dx: 0.0, dy: self.jumpForce)) // プレイヤーに上方向の衝撃を与える
            } else {
                // 移動方向が「右」の場合
                self.stopTextureAnimation(self.playerNode, name: "right_jump1")                  // プレイヤーのアニメを停止
                self.playerNode.physicsBody!.applyImpulse(CGVector(dx: 0.0, dy: self.jumpForce)) // プレイヤーに上方向の衝撃を与える
            }
        }
    }

////////////////////////////// ここから
    /// タッチ処理
    // タッチダウンされたときに呼ばれる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        var location: CGPoint!
        for touch in touches {
            location = touch.location(in: self)
        }
        self.tapPoint = location
        self.playerNode.physicsBody!.linearDamping = 0.0
    }
    //タッチ移動
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        var location: CGPoint!
        for touch in touches {
            location = touch.location(in: self)
        }
        //移動角度
        let	radian = (atan2(location.y-self.tapPoint.y, location.x-self.tapPoint.x))
        let angle = radian * 180 / CGFloat(Double.pi)
        if angle > -90 && angle < 90 {
            if self.moving == false || self.playerDirection != .right {
                self.moveToRight()	//右
            }
        }
        else {
            if self.moving == false || self.playerDirection != .left{
                self.moveToLeft()	//左
            }
        }
    }
    //タッチアップされたときに呼ばれる関数
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.moveStop()
    }

    
    // 中略
    
    
    /// テクスチャアニメーション
    // アニメ開始（node: アニメさせるノード, names: アニメさせる画像（配列））
    func startTextureAnimation(_ node: SKSpriteNode, names: [String]) {
        node.removeAction(forKey: "textureAnimation") // 指定キーのアクションを削除
        // スプライトを配列に格納
        var ary: [SKTexture] = []
        for name in names {
            ary.append(SKTexture(imageNamed: name))
        }
        // アクションを作成（timePerFrame: アクション間隔, resize: テクスチャに合わせてサイズ変更する, restore: アクション完了後に最初のテクスチャに戻す）
        let action = SKAction.animate(with: ary, timePerFrame: 0.1, resize: true, restore: false)
        // アクション実行（＆キー名作成）
        node.run(SKAction.repeatForever(action), withKey: "textureAnimation")
    }
    
    // アニメ停止（node: 停止させるノード, names: 表示する画像）
    func stopTextureAnimation(_ node: SKSpriteNode, name: String) {
        node.removeAction(forKey: "textureAnimation") // 指定キーのアクションを削除
        node.texture = SKTexture(imageNamed: name)    // 指定ノードのテクスチャをセット
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
