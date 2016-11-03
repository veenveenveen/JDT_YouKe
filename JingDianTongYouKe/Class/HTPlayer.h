//
//  HTPlayer.h
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/11.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

//定义缓冲区
#define kNumberBuffers 4
//采样率为8000
#define kSamplingRate 8000

#define kDefaultOutputBufferSize 320

#define EVERY_READ_LENGTH 320 //每次读取的长度
#define MIN_SIZE_PER_FRAME 320//每侦最小数据长

#define FRAME_SIZE 160 // PCM音频8khz*20ms -> 8000*0.02=160

typedef struct AQCallbackStruct{
    AudioStreamBasicDescription mDataFormat;//音频流描述对象  格式化音频数据
    AudioQueueRef               outputQueue;//音频输出队列
    AudioQueueBufferRef     outputBuffers[kNumberBuffers];
    UInt32                      frameSize;
} AQCallbackStruct;

@interface HTPlayer : NSObject

@property (nonatomic, assign) AQCallbackStruct aqc;

@property (nonatomic, assign) BOOL isplaying;

- (void)startPlaying;

- (void)stopPlaying;

@end
