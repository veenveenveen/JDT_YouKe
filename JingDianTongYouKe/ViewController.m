//
//  ViewController.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/8.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "HTShowStatusView.h"
#import "HTWebViewController.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIButton *webButton;

@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UILabel *promptLable;

@property (nonatomic, assign) BOOL hasInterruptedWhenPlaying;
@property (nonatomic, assign) BOOL hasHeadset;

@property (nonatomic, strong) HTShowStatusView *statusView;
@property (nonatomic, strong) HTWebViewController *webViewController;

@end

@implementation ViewController

- (instancetype)init {
    if (self = [super init]) {
        
        self.statusView = [[HTShowStatusView alloc] initWithFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height-60-120-50, [UIScreen mainScreen].bounds.size.width, 60)];
        [self.view addSubview:self.statusView];
        
        self.player = [[HTPlayer alloc] init];
        
        self.hasInterruptedWhenPlaying = NO;
        self.hasHeadset = NO;
        
        self.webViewController = [[HTWebViewController alloc] initWithNibName:@"WebView" bundle:nil];
        
        [self setupAudioSession];
        
        [self addListener];
        
        [self setupWebButton];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)setupWebButton {
    self.webButton.backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.2];
    self.webButton.layer.cornerRadius = 5;
    self.webButton.layer.masksToBounds = YES;
}

#pragma mark - 点击进入网址

- (IBAction)clickToWeb:(id)sender {
    [self.webViewController reloadView];
    [self presentViewController:self.webViewController animated:YES completion:nil];
}

#pragma mark - 开始对讲/结束对讲

- (IBAction)playOrPause:(id)sender {
    if (self.player.isplaying) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playButton setImage:[UIImage imageNamed:@"mic0"] forState:UIControlStateNormal];
            self.promptLable.hidden = YES;
        });
        
        [self.player stopPlaying];
    }
    else if (!self.player.isplaying) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playButton setImage:[UIImage imageNamed:@"mic1"] forState:UIControlStateNormal];
            self.promptLable.hidden = NO;
        });
        
        [self.player startPlaying];
    }
}

#pragma mark - setup audio session

- (void)setupAudioSession {
    //音频会话
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    NSError *error = nil;
    //设置会话类型(后台播放)
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error) {
        NSLog(@"error: %@",error.description);
    }
    
    //激活会话
    [session setActive:YES error:nil];
}


#pragma mark - add listener

- (void)addListener {
    //被打断监听
    AudioSessionInitialize(NULL, NULL, interruptionListener, (__bridge void *)(self));
    //route改变监听
    AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange,audioRouteChangeListenerCallback, (__bridge void *)(self));
}

//interrupt callback
void interruptionListener(void *inClientData, UInt32 inInterruptionState) {
    ViewController *appVC = (__bridge ViewController *)(inClientData);
    if (appVC) {
        if (kAudioSessionBeginInterruption == inInterruptionState) {
            NSLog(@"interruptionListenner state ================ %u", (unsigned int)inInterruptionState);
            if (appVC.player.isplaying) {
                [appVC playOrPause:nil];
                NSLog(@"stop play");
                appVC.hasInterruptedWhenPlaying = YES;
            }
        }
        else {
            NSLog(@"interruptionListenner state >>>>>>>>>>>>>>>> %u", (unsigned int)inInterruptionState);
            if (!appVC.player.isplaying && appVC.hasInterruptedWhenPlaying) {
                [appVC playOrPause:nil];
                NSLog(@"resume play");
                appVC.hasInterruptedWhenPlaying = NO;
            }
        }
    }
}

//route change callback
void audioRouteChangeListenerCallback (void                    *inUserData,
                                       AudioSessionPropertyID  inPropertyID,
                                       UInt32                  inPropertyValueS,
                                       const void              *inPropertyValue)
{
    ViewController *vc = (__bridge ViewController *)(inUserData);
    if ([vc isHeadsetPluggedIn]) {
        NSLog(@"耳机插入");
        if (!vc.hasHeadset) {
            vc.hasHeadset = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                [vc.statusView showWithText:@"耳机已插入"];
            });
        }
    }
    else {
        NSLog(@"启用扬声器模式");
        vc.hasHeadset = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [vc.statusView showWithText:@"启用扬声器模式"];
        });
    }
}

// check whether headset is plugged in
- (BOOL)isHeadsetPluggedIn {
#if TARGET_IPHONE_SIMULATOR
#warning *** Simulator mode: audio session code works only on a device
    return NO;
#else
    AVAudioSessionRouteDescription *route = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription *desc in [route outputs]) {
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones]) {
            return YES;
        }
    }
    return NO;
#endif
}


@end
