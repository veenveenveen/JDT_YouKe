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

//定义缓冲区
#define kNumberBuffers 4
//采样率为8000
#define kSamplingRate 8000
#define kDefaultOutputBufferSize 960
#define EVERY_READ_LENGTH 960 //每次读取的长度
#define MIN_SIZE_PER_FRAME 960//每侦最小数据长
#define FRAME_SIZE 160 // PCM音频8khz*20ms -> 8000*0.02=160
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
