//
//  HTPlayer.h
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/11.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "GCDAsyncUdpSocket.h"

//缓冲区
#define kNumberBuffers 3
//采样率为8000
#define kSamplingRate 8000
#define kDefaultOutputBufferSize 640
//ip地址
#define kDefaultIP @"234.5.6.1"
//#define kDefaultIP @"255.255.255.255"
//#define kDefaultIP @"172.16.78.138"
//端口号
#define kDefaultPort 9081
//#define kDefaultPort 8090
//#define kDefaultPort 5760
//#define kDefaultPort 5761

@interface HTPlayer : NSObject <GCDAsyncUdpSocketDelegate>

@property (nonatomic, assign) BOOL isplaying;

- (void)startPlaying;

- (void)stopPlaying;

@end
