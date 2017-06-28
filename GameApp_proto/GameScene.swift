//
//  GameScene.swift
//  GameApp_proto
//
//  Created by konsukeyama on 2017/05/19.
//  Copyright © 2017年 konsukeyama. All rights reserved.
//

import UIKit
import SpriteKit

//移動方向
enum Direction: Int {
    case right = 0	// 右
    case left  = 1	// 左
}

enum NodeName: String {
    case frame_ground = "frame_ground" // 地面あたり
    case frame_floor  = "frame_floor"  // 浮床あたり
    case player       = "player"       // プレイヤー
    case backGround   = "backGround"   // 背景
    case ground       = "ground"       // 地面
    case floor        = "floor"        // 浮床
    case isGround     = "isGround"     // 接地判定用ノード
    
    // 衝突判定カテゴリ
    func category() -> UInt32 {
        switch self {
        case .frame_ground:
            return 0x00000001 << 0 // 地面あたり
        case .frame_floor:
            return 0x00000001 << 1 // 浮床あたり
        case .player:
            return 0x00000001 << 2 // プレイヤーあたり
        case .isGround:
            return 0x00000001 << 3 // 接地判定用ノードあたり
        default:
            return 0x00000000
        }
    }
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // 画面まわりプロパティ
    let baseNode = SKNode()                             // ゲームベースノード
    let backScrNode = SKNode()                          // 背景用ノード
    var allScreenSize = CGSize(width: 0, height: 0)     // 全シーンのサイズ（サイズは後で指定する）
    var oneScreenSize = CGSize(width: 0, height: 0)     // 1画面分のサイズ（サイズは後で指定する）
    
    // プレイヤーまわりプロパティ
    var playerNode: SKSpriteNode!               // プレイヤー用スプライトノード
    var playerDirection: Direction = .right     // 移動方向
    var physicsRadius: CGFloat = 14.0           // 物理半径
    var playerAcceleration: CGFloat = 20.0      // 移動加速値
    var playerMaxVelocity: CGFloat = 250.0      // 移動量の上限
    var playerPt = CGPoint(x: 0, y:0)           // プレイヤーの座標
    var jumpForce: CGFloat = 18.0               // ジャンプ力
    var charXOffset: CGFloat = 0                // X位置のオフセット
    var charYOffset: CGFloat = 0                // Y位置のオフセット
    var moving: Bool = false                    // フラグ：移動中
    var jumping: Bool = false                   // フラグ：ジャンプ中
    var falling: Bool = false                   // フラグ：落下中
    var isGround: Bool = true                   // フラグ：地面接地判定
    
    // デルタタイム
    var delta = TimeInterval(0)
    var lastUpdateTime = TimeInterval(0)
    
    var timeSinceIsGround = TimeInterval(0)        // 強制接地タイマー
    var timeSinceIsGroundLimit = TimeInterval(0.1) // 強制接地タイマーリミット
    var timeSinceIsGroundFlg = false;
    
    var tapPoint: CGPoint = CGPoint.zero        // タップ座標
    var screenSpeed: CGFloat = 12.0             // スクリーンノードのスピード（どこで使う？）
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
        
        
        // シーンファイル読み込み
        if let scene = SKScene(fileNamed: "GameSceneTile.sks") {
            // シーンファイルの取得成功した場合

            // シーンのサイズを設定
            self.oneScreenSize = CGSize(width: self.size.width, height: self.size.height)  // 1画面のサイズ
            self.allScreenSize = CGSize(width: scene.size.width, height: self.size.height) // 全画面のサイズ

            // 重力を設定
            physicsWorld.gravity = scene.physicsWorld.gravity
            
            // 背景色を設定
            backgroundColor = Util.RGBA(red: 107, green: 140, blue: 255, alpha: 1)

            //--------------------------------------------------
            // タイルマップ
            //--------------------------------------------------
            // シーンファイルの子ノード（タイルマップ）を探して処理を実行
            scene.enumerateChildNodes(withName: "Tile Map Node", using: { (node, stop) -> Void in
                let tileMap = node as! SKTileMapNode

                let tileSize = tileMap.tileSize // タイル1個のサイズ
                
                for col in 0..<tileMap.numberOfColumns {
                    for row in 0..<tileMap.numberOfRows {
                        if tileMap.tileDefinition(atColumn: col, row: row) != nil { // 指定位置のタイル定義が有無判定
                            // 物理判定用ノード作成
                            let x = CGFloat(col) * tileSize.width                                         // タイルの左辺
                            let y = CGFloat(row) * tileSize.height                                        // タイルの下辺
                            let tileRect = CGRect(x: 0, y: 0, width: tileSize.width, height: tileSize.height) // タイル1個分の矩形作成
                            let tileNode = SKShapeNode(rect: tileRect)                                        // ノード作成
                            tileNode.lineWidth = 0                   // 矩形の罫線の太さ
                            tileNode.position = CGPoint(x: x, y: y)  // タイルの表示位置
                            tileNode.name = NodeName.ground.rawValue // ノード名を設定

                            // 物理設定
                            // tileNode.physicsBody = SKPhysicsBody(edgeLoopFrom: tileRect) // 矩形（エッジベース）
                            tileNode.physicsBody = SKPhysicsBody(rectangleOf: tileSize, center: CGPoint(x: tileSize.width / 2.0, y: tileSize.height / 2.0)) // 矩形（ボリュームベース）

                            tileNode.physicsBody!.friction = 0.2			                         // 摩擦（0〜1.0、デフォ: 0.2）
                            tileNode.physicsBody!.isDynamic = false			                         // 摩擦（0〜1.0、デフォ: 0.2）
                            tileNode.physicsBody!.restitution = 0.0                                  // 反射係数（跳ね返り。0〜1.0、デフォ: 0.2）
                            tileNode.physicsBody!.categoryBitMask = NodeName.frame_ground.category() // 衝突判定カテゴリ（地面）
                            
                            // タイルマップに物理ノードを追加
                            tileMap.addChild(tileNode)
                        }
                    }
                }
                tileMap.removeFromParent()      // シーンから子ノードを削除
                self.baseNode.addChild(tileMap) // ゲームベースノード（baseNode）にノードを追加
            })

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

            /*
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
            */
            
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
                let playerPath = UIBezierPath(roundedRect: CGRect(x: -self.physicsRadius * 1.7 / 2, y: 0, width: self.physicsRadius * 1.7, height: self.physicsRadius * 1.7), cornerRadius: 5)
                self.playerNode.physicsBody = SKPhysicsBody(polygonFrom: playerPath.cgPath) // 物理体（角丸矩形）を作成
                // self.playerNode.physicsBody = SKPhysicsBody(circleOfRadius: self.physicsRadius, center: CGPoint(x: 0, y: self.physicsRadius)) // 物理体（円）を作成
                // self.playerNode.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: self.physicsRadius * 1.5, height: self.physicsRadius * 1.5), center: CGPoint(x: 0, y: self.physicsRadius * 1.5 / 2)) // 物理体（矩形）を作成

                /*
                // let playerNodePhysicsBody_0 = SKPhysicsBody(rectangleOf: CGSize(width: self.physicsRadius * 1.5, height: self.physicsRadius * 1.5), center: CGPoint(x: 0, y: self.physicsRadius * 1.5 / 2)) // 物理体を作成
                // let playerNodePhysicsBody_1 = SKPhysicsBody(circleOfRadius: 1, center: CGPoint(x: 0, y: 0.5)) // 物理体を作成
                // let playerNodePhysicsBody_1 = SKPhysicsBody(circleOfRadius: self.physicsRadius, center: CGPoint(x: 0, y: self.physicsRadius / 2)) // 物理体を作成
                let playerNodePhysicsBody_1 = SKPhysicsBody(circleOfRadius: 2, center: CGPoint(x: -(self.physicsRadius * 1.5 / 2), y: +(self.physicsRadius * 1.5 / 2) + self.physicsRadius * 1.5 / 2)) // 物理体を作成
                let playerNodePhysicsBody_2 = SKPhysicsBody(circleOfRadius: 2, center: CGPoint(x: +(self.physicsRadius * 1.5 / 2), y: +(self.physicsRadius * 1.5 / 2) + self.physicsRadius * 1.5 / 2)) // 物理体を作成
                let playerNodePhysicsBody_3 = SKPhysicsBody(circleOfRadius: 2, center: CGPoint(x: +(self.physicsRadius * 1.5 / 2), y: -(self.physicsRadius * 1.5 / 2) + self.physicsRadius * 1.5 / 2)) // 物理体を作成
                let playerNodePhysicsBody_4 = SKPhysicsBody(circleOfRadius: 2, center: CGPoint(x: -(self.physicsRadius * 1.5 / 2), y: -(self.physicsRadius * 1.5 / 2) + self.physicsRadius * 1.5 / 2)) // 物理体を作成
                self.playerNode.physicsBody = SKPhysicsBody(bodies:[playerNodePhysicsBody_0, playerNodePhysicsBody_1, playerNodePhysicsBody_2, playerNodePhysicsBody_3, playerNodePhysicsBody_4])
                */

                self.playerNode.physicsBody!.mass = 0.027                                                                // 質量
                self.playerNode.physicsBody!.friction = 0.2			                                                                  // 摩擦（0〜1.0、デフォ: 0.2）
                self.playerNode.physicsBody!.allowsRotation = false	                                                                  // 回転（false: 回転禁止）
                self.playerNode.physicsBody!.restitution = 0.0                                                                        // 反射係数（跳ね返り。0〜1.0、デフォ: 0.2）
                self.playerNode.physicsBody!.categoryBitMask = NodeName.player.category()                                             // 衝突判定カテゴリ（プレイヤー）
                self.playerNode.physicsBody!.collisionBitMask = NodeName.frame_ground.category()                                      // 衝突させる相手（地面）
                self.playerNode.physicsBody!.contactTestBitMask = 0/*NodeName.frame_ground.category()*/                                                                   // 衝突時に通知を受ける相手（なし）
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
            wallFrameNode.physicsBody!.usesPreciseCollisionDetection = false              // 判定精度（false: 低い）
            wallFrameNode.physicsBody!.restitution = 0.0                                  // 反射係数（跳ね返り。0〜1.0、デフォ: 0.2）
        }

    }

    /// プレイヤーアクション
    // 右移動
    func moveToRight() {
        self.moving = true					                               // 移動: ON
        self.playerDirection = .right                                      // 移動方向（右: 0）
        if self.isGround == true {
            // 接地中の場合
            let names = ["m_right2", "m_right3", "m_right4"]           // 移動画像を配列セット
            self.startTextureAnimation(self.playerNode, names: names)      // テクスチャアニメ実行
        } else
            if self.falling == false {
            // ジャンプ中の場合
            self.playerNode.texture = SKTexture(imageNamed: "m_right_jump1") // テクスチャ（ジャンプ中）をセット
        }
    }

    // 左移動
    func moveToLeft() {
        self.moving = true
        self.playerDirection = .left
        if self.isGround == true {
            // 接地中の場合
            let names = ["m_left2", "m_left3", "m_left4"]
            self.startTextureAnimation(self.playerNode, names: names)
        } else
            if self.falling == false {
            // ジャンプ中の場合
            self.playerNode.texture = SKTexture(imageNamed: "m_left_jump1")
        }
    }
    
    // 停止
    func moveStop() {
        self.moving = false // 移動: OFF
        if self.isGround == true {
            // 接地中の場合
            var name: String!
            if self.playerDirection == .right {
                // 移動方向が「右」の場合
                name = "m_right1"
            } else {
                // 移動方向が「左」の場合
                name = "m_left1"
            }
            self.stopTextureAnimation(self.playerNode, name: name) // プレイヤーのアニメを停止
        }
    }

    // ジャンプ
    func jumpingAction() {
        if self.isGround == true {
            // 接地中の場合
            self.moving = false   // 移動    : OFF
            self.jumping = true   // ジャンプ: ON
            self.isGround = false // 接地    : OFF
            
            // 衝突判定変更（ジャンプ中は浮床と衝突させない）
            self.playerNode.physicsBody!.collisionBitMask = NodeName.frame_ground.category()                                     // 衝突相手（地面）
            self.playerNode.physicsBody!.contactTestBitMask = NodeName.frame_floor.category() | NodeName.frame_ground.category() // 衝突通知（地面＆浮床）
            
            if self.playerDirection == .left {
                // 移動方向が「左」の場合
                self.stopTextureAnimation(self.playerNode, name: "m_left_jump1")                   // プレイヤーのアニメを停止
                self.playerNode.physicsBody!.applyImpulse(CGVector(dx: 0.0, dy: self.jumpForce)) // プレイヤーに上方向の力を与える
            } else {
                // 移動方向が「右」の場合
                self.stopTextureAnimation(self.playerNode, name: "m_right_jump1")                  // プレイヤーのアニメを停止
                self.playerNode.physicsBody!.applyImpulse(CGVector(dx: 0.0, dy: self.jumpForce)) // プレイヤーに上方向の力を与える
            }
        }
    }

    // 落下
    func fallingAction() {
        self.jumping = false  // ジャンプ: OFF
        self.falling = true   // 落下    : ON
        self.isGround = false // 接地    : OFF
        if self.playerDirection == .left {
            // プレイヤーが左方向の場合
            // self.stopTextureAnimation(self.playerNode, name: "m_left_falling1")  // テクスチャアニメを停止し落下中画像にする
            self.stopTextureAnimation(self.playerNode, name: "m_left_jump1")  // テクスチャアニメを停止し落下中画像にする
        } else {
            // プレイヤーが右方向の場合
            // self.stopTextureAnimation(self.playerNode, name: "m_right_falling1") // テクスチャアニメを停止し落下中画像にする
            self.stopTextureAnimation(self.playerNode, name: "m_right_jump1") // テクスチャアニメを停止し落下中画像にする
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
            // 右方向へのスワイプの場合
            if self.moving == false || self.playerDirection != .right {
                // 移動中でなく、右向きでない場合
                self.moveToRight() // プレイヤーを右移動
            }
        } else {
            // 左方向へのスワイプの場合
            if self.moving == false || self.playerDirection != .left {
                // 移動中でなく、左向きでない場合
                self.moveToLeft() // プレイヤーを左移動
            }
        }
    }
 
    // タッチエンド時に呼ばれる関数
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.moveStop() // プレイヤー停止
    }

    // 強制着地
    func isGroundUpdate() {
        self.timeSinceIsGround += self.delta
        if self.timeSinceIsGround >= timeSinceIsGroundLimit {
            print("強制接地タイマー：エンド")
            // 実行する処理
            self.timeSinceIsGroundFlg = false
            self.jumping = false // ジャンプ: OFF
            self.falling = false // 落下    : OFF
            self.isGround = true // 接地    : ON
            if self.moving == true {
                if self.playerDirection == .right {
                    // 移動方向が「右」の場合
                    moveToRight()
                } else {
                    // 移動方向が「左」の場合
                    moveToLeft()
                }
            } else {
                self.moveStop() // プレイヤー停止
            }
        }
    }
    
    /// シーンのフレームの更新時に呼ばれる
    override func update(_ currentTime: TimeInterval) {

        // デルタタイム
        if self.lastUpdateTime == 0.0 {
            self.delta = 0
        } else {
            self.delta = currentTime - self.lastUpdateTime
        }
        self.lastUpdateTime = currentTime

        // タイマーで実行させたい処理
        if self.timeSinceIsGroundFlg == true {
            self.isGroundUpdate() // 強制接地
        }

    }

    /// シーンの物理シミュレーション処理後に呼ばれる
    override func didSimulatePhysics() {

        let isGroundPt = CGPoint(x: self.playerNode.position.x, y: self.playerNode.position.y - self.physicsRadius)
        let isGroundPtRelative = self.convert(isGroundPt, from: self.baseNode)

        // isGroundTimer
        if self.timeSinceIsGroundFlg == false
            && (self.jumping == true || self.falling == true)                                                            // ジャンプor落下中かつ
            && abs(self.playerNode.physicsBody!.velocity.dy) < 9.8                                                       // Y変動が極小かつ
            && (self.atPoint(isGroundPtRelative).name == "ground" || self.atPoint(isGroundPtRelative).name == "floor") { // 真下が地面or床の場合
            
            print("強制接地タイマー：スタート")
            self.timeSinceIsGroundFlg = true
            self.timeSinceIsGround = 0.0
        }

        // 横移動時の不意な衝突を抑える
        if self.isGround == true && self.moving == true && (self.atPoint(isGroundPtRelative).name == "ground" || self.atPoint(isGroundPtRelative).name == "floor") {
            self.playerNode.physicsBody!.velocity.dy = 0
        }
        
        // プレイヤー落下処理
        if self.playerNode.physicsBody!.velocity.dy < -9.8 && self.falling == false {
            // プレイヤーの下方向の移動量が-9.8以下で落下中でない場合
            print("落下")
            self.fallingAction()
        }

        // Ray判定
        let playerRayPt = CGPoint(x: self.playerNode.position.x, y: self.playerNode.position.y)
        let playerRayPtRelative = self.convert(playerRayPt, from: self.baseNode)
        let rayStart = CGPoint(x: playerRayPtRelative.x, y: playerRayPtRelative.y + physicsRadius)
        let rayEnd = CGPoint(x: playerRayPtRelative.x, y: playerRayPtRelative.y - physicsRadius)
        
        physicsWorld.enumerateBodies(alongRayStart: rayStart, end: rayEnd) { body, point, normal, stop in
            if body.node?.name == "floor" {
                var floorTopPosition : CGFloat = 0
                floorTopPosition = (body.node?.position.y)! + 10.5
                if self.falling == true && self.playerNode.position.y > floorTopPosition && self.playerNode.position.y < (floorTopPosition + self.physicsRadius) {
                    print("Ray判定：浮床の上を検知")
                    self.playerNode.physicsBody!.collisionBitMask = NodeName.frame_ground.category() | NodeName.frame_floor.category()   // 衝突相手（地面、浮床）
                    self.playerNode.physicsBody!.contactTestBitMask = NodeName.frame_ground.category() | NodeName.frame_floor.category() // 衝突通知（地面）
                }
            }

            if body.node?.name == "ground" {
                var groundTopPosition : CGFloat = 0
                groundTopPosition = (body.node?.position.y)! + 120
                if self.falling == true && self.playerNode.position.y > groundTopPosition && self.playerNode.position.y < (groundTopPosition + self.physicsRadius) {
                    print("Ray判定：地面の上を検知")
                    self.playerNode.physicsBody!.collisionBitMask = NodeName.frame_ground.category() | NodeName.frame_floor.category()   // 衝突相手（地面、浮床）
                    self.playerNode.physicsBody!.contactTestBitMask = NodeName.frame_ground.category() | NodeName.frame_floor.category() // 衝突通知（地面）
                }
            }
        }

        // 移動速度の上限制御
        if self.playerNode.physicsBody!.velocity.dx > self.playerMaxVelocity {
            // 右方向の移動量の上限制御
            self.playerNode.physicsBody!.velocity.dx = self.playerMaxVelocity
        } else if self.playerNode.physicsBody!.velocity.dx < -(self.playerMaxVelocity) {
            // 左方向の移動量の上限制御
            self.playerNode.physicsBody!.velocity.dx = -(self.playerMaxVelocity)
        }

        if self.playerNode.physicsBody!.velocity.dy < -(self.playerMaxVelocity * 2.5) {
            // 下方向の移動量の上限制御
            self.playerNode.physicsBody!.velocity.dy = -(self.playerMaxVelocity * 1)
        }

        // ゆっくり停止
        if self.isGround == true && self.moving == false {
            if self.playerNode.physicsBody!.velocity.dx != 0 {
                self.playerNode.physicsBody!.velocity.dx = self.playerNode.physicsBody!.velocity.dx * 0.85
            }
        }

        // プレイヤー移動処理
        if self.moving == true {
            var dx: CGFloat = 0
            var dy: CGFloat = 0
            
            // 加える加速度をセット
            if self.playerDirection == .right {
                // プレイヤーが右向きの場合
                dx = self.playerAcceleration    // 右方向(+)の移動加速度をセット
                dy = 0
            } else if self.playerDirection == .left {
                // プレイヤーが左向きの場合
                dx = -(self.playerAcceleration) // 左方向(-)の移動加速度をセット
                dy = 0
            }
            // プレイヤーに継続的な力を加える
            self.playerNode.physicsBody!.applyForce(CGVector(dx: dx, dy: dy))

            // 移動モーション（高速／低速）切り替え
            if abs(self.playerNode.physicsBody!.velocity.dx) >= 200 {
                self.playerNode.speed = 3
            } else {
                self.playerNode.speed = 1
            }
        }
        
        // 画面スクロール処理
        // プレイヤーの座標をbaseNodeからの相対座標に変換
        self.playerPt = self.convert(self.playerNode.position, from: self.baseNode)
        
        var	x = self.baseNode.position.x - self.playerPt.x + self.charXOffset
        var	y = self.baseNode.position.y - self.playerPt.y + self.charYOffset

        // 全画面の右端より右は表示しない
        if x <= -(self.allScreenSize.width - self.size.width) {
            x = -(self.allScreenSize.width - self.size.width)
        }
        // 全画面の左端より左は表示しない
        if x > 0 {
            x = 0
        }
        // 全画面の上端より上は表示しない
        if y <= -(self.allScreenSize.height - self.size.height) {
            y = -(self.allScreenSize.height - self.size.height)
        }
        // 全画面の下端より下は表示しない
        if y > 0 {
            y = 0
        }
        self.baseNode.position = CGPoint(x: x, y: y)
        self.backScrNode.position = CGPoint(x: x / 2, y: y)

    }

    /// 衝突したときに呼ばれる
    func didBegin(_ contact: SKPhysicsContact) {
        print("デバッグ：衝突！")
        /*
        print("contactPoint: \(contact.contactPoint.y)")
        let myBox2 = SKSpriteNode(color: SKColor.yellow, size:CGSize(width: 3, height: 3))
        myBox2.position = CGPoint(x: self.playerNode.position.x, y: contact.contactPoint.y)
        myBox2.zPosition = 10
        self.baseNode.addChild(myBox2)
        print("===")
        */
        
        let isGroundPt = CGPoint(x: self.playerNode.position.x, y: contact.contactPoint.y - 10)
        let isGroundPtRelative = self.convert(isGroundPt, from: self.baseNode)
        
        if self.atPoint(isGroundPtRelative).name == "ground" {
            // 真下が「地面」の場合
            print("atPoint判定：下は地面")
            self.playerNode.physicsBody!.contactTestBitMask = 0 // 衝突通知（なし）
            
            self.jumping = false // ジャンプ: OFF
            self.falling = false // 落下    : OFF
            self.isGround = true // 接地    : ON
            
            if self.moving == true {
                if self.playerDirection == .right {
                    // 移動方向が「右」の場合
                    moveToRight()
                } else {
                    // 移動方向が「左」の場合
                    moveToLeft()
                }
            } else {
                self.moveStop() // プレイヤー停止
            }
        }

        if self.atPoint(isGroundPtRelative).name == "floor" {
            // 真下が「浮床」の場合
            print("atPoint判定：下は浮床")
            self.playerNode.physicsBody!.contactTestBitMask = 0 // 衝突通知（なし）
            
            self.jumping = false // ジャンプ: OFF
            self.falling = false // 落下    : OFF
            self.isGround = true // 接地    : ON
            
            if self.moving == true {
                if self.playerDirection == .right {
                    // 移動方向が「右」の場合
                    moveToRight()
                } else {
                    // 移動方向が「左」の場合
                    moveToLeft()
                }
            } else {
                self.moveStop() // プレイヤー停止
            }
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
        let action = SKAction.animate(with: ary, timePerFrame: 0.2, resize: true, restore: false)
        // アクション実行（＆キー名作成）
        node.run(SKAction.repeatForever(action), withKey: "textureAnimation")
    }

    // アニメ停止（node: アニメ停止させるノード, names: 表示する画像）
    func stopTextureAnimation(_ node: SKSpriteNode, name: String) {
        node.removeAction(forKey: "textureAnimation") // 指定キーのアクションを削除
        node.texture = SKTexture(imageNamed: name)    // 指定ノードのテクスチャをセット
    }

}
