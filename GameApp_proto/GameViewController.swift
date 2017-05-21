//
//  GameViewController.swift
//  GameApp_proto
//
//  Created by konsukeyama on 2017/05/21.
//  Copyright © 2017年 konsukeyama. All rights reserved.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    var gameView: GameView!   // これがSKViewになる
    var gameScene: GameScene! // これがSKSceneになる

    // GameViewController（ジャンプボタンがある部品）を作成する　※クラスメソッド
    class func gameViewController() -> GameViewController {
        // xibで作成した部品を読み込む
        let gameView = GameViewController(nibName: "GameViewController", bundle: nil)
        // 画面サイズを取得
        let frame = UIScreen.main.bounds
        // ビューのframeサイズ指定
        gameView.view.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)

        return gameView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        //--------------------------------------------------
        // SKView初期化
        //--------------------------------------------------
        let frame = UIScreen.main.bounds
        self.gameView = GameView(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)) // SKViewを作成
        self.gameView.allowsTransparency = true      // 透過ノードの使用（true: 使用する）
        self.gameView.ignoresSiblingOrder = true     // 同じz座標のノードの振る舞い（true: 順序を保証しないがパフォーマンス向上）
        self.view.addSubview(self.gameView)          // SKViewをサブビューに追加する
        self.view.sendSubview(toBack: self.gameView) // SKViewを再背面にする

        // デバッグ表示
        self.gameView.showsFPS = true       // フレームレート
        self.gameView.showsNodeCount = true // ノードの数
        self.gameView.showsPhysics = true   // ノードの物理関係
        
        //--------------------------------------------------
        // SKScene初期化
        //--------------------------------------------------
        // ？？？
        self.gameScene = GameScene(size: CGSize(width: frame.size.width, height: frame.size.height)) // SKSceneを作成
        self.gameScene.scaleMode = .aspectFill
        
        self.gameScene.size = CGSize(width: frame.size.width, height: frame.size.height) // SKSceneをSKViewと同じく画面いっぱいに
        // SKScene（gameScene）を表示
        self.gameView.presentScene(self.gameScene)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // ジャンプボタン
    @IBOutlet weak var jumpButton: UIButton!
    @IBAction func jumpButtonAction(_ sender: Any) {
        self.gameScene.jumpingAction()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
