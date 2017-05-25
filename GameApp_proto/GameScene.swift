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
    var allScreenSize = CGSize(width: 0, height: 0)     // 全シーンのサイズ（ここでは初期化のみ）
    let oneScreenSize = CGSize(width: 375, height: 667) // 1画面分のサイズ
    
    // プレイヤーまわりプロパティ
    var playerNode: SKSpriteNode!               // プレイヤー用スプライトノード
    var playerDirection: Direction = .right     // 移動方向
    var physicsRadius: CGFloat = 14.0           // 物理半径
    var playerAcceleration: CGFloat = 50.0      // 移動加速値
    var playerMaxVelocity: CGFloat = 200.0      // 移動量の上限
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
print("停止")
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

    /// タッチ処理
    // タッチダウン時に呼ばれる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        var location: CGPoint!
        for touch in touches {
            location = touch.location(in: self) // タッチ座標を取得
        }
        self.tapPoint = location
        self.playerNode.physicsBody!.linearDamping = 0.0 // 空気の摩擦ゼロ
    }

    // タッチムーブ時に呼ばれる
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var location: CGPoint!
        for touch in touches {
            location = touch.location(in: self) // ムーブ時の座標を取得
        }
        // タッチダウン時の座標を基に移動角度を計算
        let	radian = (atan2(location.y - self.tapPoint.y, location.x - self.tapPoint.x))
        let angle = radian * 180 / CGFloat(Double.pi)
        if angle > -90 && angle < 90 {
            // 右方向へのタッチムーブの場合
            if self.moving == false || self.playerDirection != .right {
                // 移動中かつ右向きの場合
                self.moveToRight() // プレイヤーを右に移動
            }
        } else {
            // 左方向へのタッチムーブの場合
            if self.moving == false || self.playerDirection != .left {
                // 移動中かつ左向きの場合
                self.moveToLeft() // プレイヤーを左に移動
            }
        }
    }
    
    // タッチエンド時に呼ばれる関数
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.moveStop() // プレイヤー停止
    }

    
    /// シーンのフレームの更新時に呼ばれる
    override func update(_ currentTime: TimeInterval) {
        // プレイヤー移動処理
        if self.moving == true {
            // プレイヤーが移動中の場合
            var dx: CGFloat = 0
            var dy: CGFloat = 0

            // 加える加速度をセット
            if self.playerDirection == .right {
                // プレイヤーが右向きの場合
                dx = self.playerAcceleration    // 右方向(+)の移動加速度をセット
                dy = 0.0
            } else if self.playerDirection == .left {
                // プレイヤーが左向きの場合
                dx = -(self.playerAcceleration) // 左方向(-)の移動加速度をセット
                dy = 0.0
            }
            // プレイヤーに継続的な力を加える
            self.playerNode.physicsBody!.applyForce(CGVector(dx: dx, dy: dy))

            if self.jumping == false && self.falling == false {
                // ジャンプ中でも落下中でもない場合（地面の移動）
                if self.playerNode.physicsBody!.velocity.dx > self.playerMaxVelocity {
                    // 右方向の移動量の上限制御
                    self.playerNode.physicsBody!.velocity.dx = self.playerMaxVelocity
                } else if self.playerNode.physicsBody!.velocity.dx < -(self.playerMaxVelocity) {
                    // 左方向の移動量の上限制御
                    self.playerNode.physicsBody!.velocity.dx = -(self.playerMaxVelocity)
                }
            } else {
                // 空中の移動の場合、地上の1/2の移動量を上限とする
                if self.playerNode.physicsBody!.velocity.dx > self.playerMaxVelocity / 2 {
                    // 右方向の移動量の上限制御
                    self.playerNode.physicsBody!.velocity.dx = self.playerMaxVelocity / 2
                } else if self.playerNode.physicsBody!.velocity.dx < -(self.playerMaxVelocity / 2) {
                    // 左方向の移動量の上限制御
                    self.playerNode.physicsBody!.velocity.dx = -(self.playerMaxVelocity / 2)
                }
            }
        }

////////////// ここから
        // 画面スクロール処理
        // シーン上でのプレイヤーの座標をbaseNodeからの位置に変換
        let PlayerPt = self.convert(self.playerNode.position, from: self.baseNode)
// print("PlayerPt: \(PlayerPt)")
        // シーン上でプレイヤー位置を基準にしてbaseNodeの位置を変更する
        var	x = self.baseNode.position.x - PlayerPt.x + self.charXOffset
        var	y = self.baseNode.position.y - PlayerPt.y + self.charYOffset
        // スクロール制限
// print("self.size.width: \(self.size.width)")
        if x <= -(self.allScreenSize.width - self.size.width) {
            x = -(self.allScreenSize.width - self.size.width)
        }
        if x > 0 {
            x = 0
        }
        if y <= -(self.allScreenSize.height - self.size.height) {
            y = -(self.allScreenSize.height - self.size.height)
        }
        if y > 0 {
            y = 0
        }
        self.baseNode.position = CGPoint(x: x, y: y)
        self.backScrNode.position = CGPoint(x: x / 4, y: y)
////////////// ここまでは後で検証する

        // プレイヤー落下処理
        if ((self.playerNode.physicsBody?.velocity.dy)! < CGFloat(-9.8)) && (self.falling == false) {
            // プレイヤーの下方向の移動量が一定数以下で落下中でない場合
            self.jumping = false // ジャンプ中フラグOFF
            self.falling = true  // 落下中フラグON
            self.playerNode.physicsBody!.collisionBitMask = NodeName.frame_ground.category() | NodeName.frame_floor.category()   // 衝突相手（地面＆浮床）
            self.playerNode.physicsBody!.contactTestBitMask = NodeName.frame_floor.category() | NodeName.frame_ground.category() // 衝突通知（地面＆浮床）
            if self.playerDirection == .left {
                // プレイヤーが左方向の場合
                self.stopTextureAnimation(self.playerNode, name: "left_falling1")  // テクスチャアニメを停止し落下中画像にする
            } else {
                // プレイヤーが右方向の場合
                self.stopTextureAnimation(self.playerNode, name: "right_falling1") // テクスチャアニメを停止し落下中画像にする
            }
        }
    }

    /// シーンの物理シミュレーション処理後に呼ばれる
    override func didSimulatePhysics() {
    }

    /// 衝突したときに呼ばれる
    // プレイヤーの衝突通知は「地面」「浮床」のみのため、このメソッドが呼ばれた場合は着地時となる
    func didBegin(_ contact: SKPhysicsContact) {
print("衝突！")
        // 当たり判定のリセット
        self.playerNode.physicsBody!.collisionBitMask = NodeName.frame_ground.category() | NodeName.frame_floor.category() // 衝突相手（地面＆浮床）
        self.playerNode.physicsBody!.contactTestBitMask = 0                                                                // 衝突通知（なし）
        // self.playerNode.physicsBody!.velocity = CGVector(dx: self.playerNode.physicsBody!.velocity.dx, dy: 0)
        
        self.jumping = false // ジャンプ中フラグOFF
        self.falling = false // 落下中フラグOFF
        
        if self.moving {
            // プレイヤーが移動中の場合
            if self.playerDirection == .right {
                // 右向きの場合
                self.moveToRight() // 右移動
            } else if self.playerDirection == .left {
                // 左向きの場合
                self.moveToLeft() // 左移動
            }
        } else {
            // プレイヤーが移動していない場合
            self.moveStop() // プレイヤー停止
        }
    }
    
    /// 衝突の終了時に呼ばれる
    func didEnd(_ contact: SKPhysicsContact) {
    }
    
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
    
    // アニメ停止（node: アニメ停止させるノード, names: 表示する画像）
    func stopTextureAnimation(_ node: SKSpriteNode, name: String) {
        node.removeAction(forKey: "textureAnimation") // 指定キーのアクションを削除
        node.texture = SKTexture(imageNamed: name)    // 指定ノードのテクスチャをセット
    }
    

}
