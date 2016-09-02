//
//  HTPlayer.h
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/11.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

//定义三个缓冲区
#define kNumberBuffers 1
//采样率为8000
#define kSamplingRate 8000

#define kDefaultOutputBufferSize 7040

typedef struct AQCallbackStruct{
    AudioStreamBasicDescription mDataFormat;//音频流描述对象  格式化音频数据
    AudioQueueRef               outputQueue;//音频输出队列
    AudioQueueBufferRef     outputBuffers[kNumberBuffers];
    AudioFileID                 outputFile;
    UInt32                      frameSize;
    long long                   recPtr;
} AQCallbackStruct;

@interface HTPlayer : NSObject

@property (nonatomic, assign) AQCallbackStruct aqc;

@property (nonatomic, assign) BOOL isplaying;

- (void)startPlaying;

- (void)stopPlaying;

@end
