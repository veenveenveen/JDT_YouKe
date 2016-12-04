//
//  ViewController.h
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/8.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HTPlayer.h"

@interface ViewController : UIViewController

@property (nonatomic, strong) HTPlayer *player;

- (IBAction)playOrPause:(id)sender;

@end

