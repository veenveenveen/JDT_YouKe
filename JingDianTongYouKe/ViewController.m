//
//  ViewController.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/8.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UILabel *promptLable;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _player = [[HTPlayer alloc] init];
}

#pragma mark - 开始对讲/结束对讲
- (IBAction)playOrPause:(id)sender {
    if (_player.isplaying) {
        [self.playButton setImage:[UIImage imageNamed:@"record_false"] forState:UIControlStateNormal];
        self.promptLable.hidden = YES;
        [_player stopPlaying];
        _player.isplaying = NO;
    }
    else if (!_player.isplaying) {
        [self.playButton setImage:[UIImage imageNamed:@"record_true"] forState:UIControlStateNormal];
        self.promptLable.hidden = NO;
        [_player startPlaying];
        _player.isplaying = YES;
    }
}

//-(IBAction)startPlaying:(id)sender{
//    [_player startPlaying];
//}
//-(IBAction)stopPlaying:(id)sender{
//    [_player stopPlaying];
//}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
