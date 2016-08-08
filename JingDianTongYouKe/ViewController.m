//
//  ViewController.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/8.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "ViewController.h"
#import "GCDAsyncUdpSocket.h"

#define kDefaultIP @"234.5.6.1"

#define kDefaultPort 8090

@interface ViewController ()

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _player = [[HTPlayer alloc] init];
//    [_player initAudioPlaying];
}

#pragma mark - 开始对讲/结束对讲

-(IBAction)startPlaying:(id)sender{
    [_player startPlaying];
}
-(IBAction)stopPlaying:(id)sender{
    [_player stopPlaying];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
