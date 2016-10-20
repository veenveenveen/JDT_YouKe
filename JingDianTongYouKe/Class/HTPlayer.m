//
//  HTPlayer.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/11.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "HTPlayer.h"
#import "GCDAsyncUdpSocket.h"
#import "RecordAmrCode.h"
#import <AVFoundation/AVFoundation.h>

#define kDefaultIP @"234.5.6.1"
#define kDefaultPort 8090

@interface HTPlayer () <GCDAsyncUdpSocketDelegate>
//接收数据的数组
@property (nonatomic, strong) NSMutableArray *receiveData;
@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;
@property (strong, nonatomic) RecordAmrCode *recordAmrCode;
//@property (nonatomic) NSTimeInterval timetap;
@end

@implementation HTPlayer

- (RecordAmrCode *)recordAmrCode{
    if (_recordAmrCode == nil) {
        _recordAmrCode = [[RecordAmrCode alloc] init];
    }
    return _recordAmrCode;
}

- (instancetype) init{
    self = [super init];
    if (self){
        dispatch_queue_t global = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:global];
        NSError *error;
        [self.udpSocket bindToPort:kDefaultPort error:&error];
        if (error != nil) {
            NSLog(@"error:%@",error.description);
        }
        //添加多地址发送，用于连接一个多组播
        [_udpSocket joinMulticastGroup:kDefaultIP error:&error];
        if (error != nil) {
            NSLog(@"error:%@",error.description);
        }
        //开始接收数据
        //[_udpSocket beginReceiving:&error];
        [_udpSocket pauseReceiving];
        if (error != nil) {
            NSLog(@"error:%@",error.description);
        }
        _receiveData = [NSMutableArray array];
        
        NSLog(@"instance me !");
        
        [self initAudioPlaying];
        
        [self setAudioSession];
        
    }
    return self;
}

- (void)setAudioSession {
    //音频会话
    AVAudioSession *session = [AVAudioSession sharedInstance];
    //设置会话类型(后台播放)
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    //激活会话
    [session setActive:YES error:nil];
}

//设置录音格式
- (void)setAudioFormat:(UInt32)inFormatID andSampleRate:(int)sampleRate{
    //重置
    memset(&_aqc.mDataFormat, 0, sizeof(_aqc.mDataFormat));
    _aqc.mDataFormat.mSampleRate = sampleRate;// 采样率 (立体声 = 8000)
    _aqc.mDataFormat.mFormatID = inFormatID;// PCM 格式 kAudioFormatLinearPCM
    _aqc.mDataFormat.mChannelsPerFrame = 1;//设置通道数 1:单声道；2:立体声
    if (inFormatID == kAudioFormatLinearPCM) {
        _aqc.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        //每个通道里，一帧采集的bit数目
        _aqc.mDataFormat.mBitsPerChannel = 16;// 语音每采样点占用位数//结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte
        _aqc.mDataFormat.mBytesPerPacket = 2;//(_recordFormat.mBitsPerChannel / 8) * _recordFormat.mChannelsPerFrame
        _aqc.mDataFormat.mFramesPerPacket = 1;//每一个packet一侦数据
    }
    _aqc.mDataFormat.mBytesPerFrame = 2;
}

//输出回调
void GenericOutputCallback (
                            void                 *inUserData,
                            AudioQueueRef        inAQ,
                            AudioQueueBufferRef  inBuffer
                            )
{
    NSLog(@"播放回调 GenericOutputCallback ");
    HTPlayer *player= (__bridge HTPlayer *)(inUserData);
    NSData *pcmData = nil;
    
    NSLog(@"receiveData count : %lu", (unsigned long)player.receiveData.count);
    
    if([player.receiveData count] > 0){
        NSData *amrData = [player.receiveData objectAtIndex:0];
        pcmData = [player.recordAmrCode decodeAMRDataToPCMData:amrData];
        if (pcmData) {
            Float32 gain = 1.0;
            AudioQueueSetParameter (player.aqc.outputQueue,kAudioQueueParam_Volume,gain);
            if(pcmData.length < 10000){
                memcpy(inBuffer->mAudioData, pcmData.bytes, pcmData.length);
                inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
                inBuffer->mPacketDescriptionCount = 0;
                NSLog(@" finished !");
            }
        }
        [player.receiveData removeObjectAtIndex:0];
    }else{
//            makeSilent(inBuffer);
//        静音
        Float32 gain = 0.0;
        AudioQueueSetParameter (player.aqc.outputQueue,kAudioQueueParam_Volume,gain);
    }
    AudioQueueEnqueueBuffer(player.aqc.outputQueue,inBuffer,0,NULL);
}

- (void)initAudioPlaying{
    //设置录音格式
    [self setAudioFormat:kAudioFormatLinearPCM andSampleRate:kSamplingRate];
    AudioQueueNewOutput(&_aqc.mDataFormat, GenericOutputCallback, (__bridge void *) self, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 0,&_aqc.outputQueue);
    //创建并分配缓冲区空间 3个缓冲区
    for (int i = 0; i < kNumberBuffers; ++i)
    {
        AudioQueueAllocateBuffer(_aqc.outputQueue, kDefaultOutputBufferSize, &_aqc.outputBuffers[i]);
    }
    for (int i = 0; i < kNumberBuffers; ++i) {
        //改变数据
        makeSilent(_aqc.outputBuffers[i]);
        //给输出队列完成配置
        AudioQueueEnqueueBuffer(_aqc.outputQueue,_aqc.outputBuffers[i],0,NULL);
    }
    //Optionally, allow user to override gain setting here 设置音量
    Float32 gain = 1.0;
    AudioQueueSetParameter (_aqc.outputQueue,kAudioQueueParam_Volume,gain);
    //开启播放队列
    //AudioQueueStart(_aqc.outputQueue,NULL);
}

//把缓冲区置空
void makeSilent(AudioQueueBufferRef buffer){
    for (int i=0; i < buffer->mAudioDataBytesCapacity; i++) {
        buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
        UInt8 * samples = (UInt8 *) buffer->mAudioData;
        samples[i]=0;
        NSLog(@"make silent!");
    }
}

//开始
- (void)startPlaying{
    if(!self.isplaying){
        Float32 gain = 1.0;
        AudioQueueSetParameter (_aqc.outputQueue,kAudioQueueParam_Volume,gain);
        //开始接收数据
        [_udpSocket beginReceiving:nil];
        //开启播放队列
        AudioQueueStart(_aqc.outputQueue,NULL);
        // 更新数组
        self.isplaying = YES;
    }
}

//暂停
- (void)stopPlaying{
    if(self.isplaying){
        //暂停接收数据
        [self.udpSocket pauseReceiving];
        //暂停播放队列
        AudioQueuePause(_aqc.outputQueue);
        self.isplaying = NO;
        Float32 gain = 0.0;
        AudioQueueSetParameter (_aqc.outputQueue,kAudioQueueParam_Volume,gain);
        for (int i = 0; i < kNumberBuffers; ++i) {
            //改变数据
            makeSilent(_aqc.outputBuffers[i]);
            //给输出队列完成配置
            AudioQueueEnqueueBuffer(_aqc.outputQueue,_aqc.outputBuffers[i],0,NULL);
        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext{
    
    if (!_isplaying) {
        return;
    }
//    if (_timetap) {
//        NSTimeInterval tap = [NSDate date].timeIntervalSince1970 - _timetap;
//        if (tap > 0.01) {
//            self.timetap = [NSDate date].timeIntervalSince1970;
//        } else {
//            NSLog(@"skip time interval too close");
//            return;
//        }
//    } else {
//        self.timetap = [NSDate date].timeIntervalSince1970;
//    }
//    NSLog(@"%@",data);
    NSLog(@"udp socket receive");
//    NSLog(@"%ld",data.length);
    
    if (data.length <= 667) {
        [_receiveData addObject:data];
        return;
    }
    NSUInteger num = (data.length)/667;
    int sum = 0;
    for (int i=0; i<num; i++)
    {
        NSData *receviceData = [data subdataWithRange:NSMakeRange(i*667,667)];
        [_receiveData addObject:receviceData];
        sum = sum + 667;
    }
    if(sum < data.length)
    {
        NSData *otherData = [data subdataWithRange:NSMakeRange(sum, (data.length-sum))];
        [_receiveData addObject:otherData];
    }
}

- (void)dealloc {
    [_udpSocket close];
    _udpSocket = nil;
}


@end
