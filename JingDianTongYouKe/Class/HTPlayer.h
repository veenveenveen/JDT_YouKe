//
//  HTPlayer.h
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/11.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
//#import <AudioToolbox/AudioFile.h>
#import <AVFoundation/AVFoundation.h>

// Audio Settings
#define kNumberBuffers      3 //定义的三个缓冲区
//#define kDefaultBufferDurationSeconds 0.1279   //调整这个值使得录音的缓冲区大小为2048bytes
//#define t_sample            SInt16
/**
 *  采样率，要转码为amr的话必须为8000
 */
#define kSamplingRate       8000 //采样率为8000
//#define kNumberChannels     1
//#define kBitsPerChannels    (sizeof(t_sample) * 8)
//#define kBytesPerFrame      (kNumberChannels * sizeof(t_sample))
//#define kFrameSize          1000

//#define kDefaultInputBufferSize 7360
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

- (void)initAudioPlaying;

@end
