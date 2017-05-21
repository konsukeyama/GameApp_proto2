//
//  ViewController.swift
//  GameApp_proto
//
//  Created by konsukeyama on 2017/05/21.
//  Copyright © 2017年 konsukeyama. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        // 操作ボタンのビューコントローラーを生成　※クラス・メソッド
        let gameView = GameViewController.gameViewController()

        // 操作ボタンのビューコントローラーを現在のビューコントローラーの子に追加
        self.addChildViewController(gameView)
        
        // 操作ボタンのビューを現在のビューに追加
        self.view.addSubview(gameView.view)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
