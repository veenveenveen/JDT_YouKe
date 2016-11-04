//
//  HTPlayer.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/11.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "HTPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import "HTSpeexCodec.h"
#import "HTThreadSafetyArray.h"

@implementation HTPlayer {
    
    AudioStreamBasicDescription mDataFormat;//音频流描述对象  格式化音频数据
    AudioQueueRef               outputQueue;//音频输出队列
    AudioQueueBufferRef         outputBuffers[kNumberBuffers];
    
    NSLock *synlock ;//同步控制
    
    NSMutableData  *tempData;    //用于输入的speex切割剩余
    NSMutableArray *speexArrs;//保存切割的speex数据块
    
    NSMutableArray *emptyAudioQueueBufferIndexs;
    
    dispatch_queue_t _decode_queue;
    dispatch_queue_t _receive_queue;
    
    GCDAsyncUdpSocket *udpSocket;
    
    HTSpeexCodec *spxCodec;
    HTThreadSafetyArray *receiveArray;//接收数据的数组

}

- (instancetype) init{
    self = [super init];
    if (self){
        
        emptyAudioQueueBufferIndexs = [[NSMutableArray alloc] initWithCapacity:kNumberBuffers];
        
        tempData = [[NSMutableData alloc] init];
        speexArrs = [NSMutableArray array];
        
        spxCodec = [[HTSpeexCodec alloc] init];
        receiveArray = [[HTThreadSafetyArray alloc] init];
        
        _decode_queue = dispatch_queue_create("com.JDTYouKe.decodeQueue", DISPATCH_QUEUE_SERIAL);
        
        _receive_queue = dispatch_queue_create("com.JDTYouKe.receiveQueue", DISPATCH_QUEUE_SERIAL);
        udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:_receive_queue];
        NSError *error;
        //绑定端口号
        [udpSocket bindToPort:kDefaultPort error:&error];
        if (error != nil) {
            NSLog(@"error:%@",error.description);
        }
        //添加多地址发送，用于连接一个多组播
        [udpSocket joinMulticastGroup:kDefaultIP error:&error];
        if (error != nil) {
            NSLog(@"error:%@",error.description);
        }
        
        [self initAudioPlaying];
        [self setAudioSession];
    }
    return self;
}

- (void)initAudioPlaying{
    //设置录音格式
    [self setAudioFormat:kAudioFormatLinearPCM andSampleRate:kSamplingRate];
    ///创建一个新的从audioqueue到硬件层的通道
//    AudioQueueNewOutput(&_aqc.mDataFormat, GenericOutputCallback, (__bridge void *) self, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 0,&_aqc.outputQueue);//使用当前线程播
    AudioQueueNewOutput(&mDataFormat, outputCallback, (__bridge void *) self, nil, nil, 0, &outputQueue);//使用player的内部线程播
    //创建并分配缓冲区空间 3个缓冲区
    for (int i = 0; i < kNumberBuffers; ++i){
        AudioQueueAllocateBuffer(outputQueue, MIN_SIZE_PER_FRAME, &outputBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
    }
    for (int i = 0; i < kNumberBuffers; ++i) {
        //改变数据
        makeSilent(outputBuffers[i]);
        //给输出队列完成配置
        AudioQueueEnqueueBuffer(outputQueue,outputBuffers[i],0,NULL);
    }
    //设置音量
    Float32 gain = 1.0;
    AudioQueueSetParameter (outputQueue,kAudioQueueParam_Volume,gain);
    //开始接收数据
    [udpSocket beginReceiving:nil];
    //开启播放队列
    AudioQueueStart(outputQueue,NULL);
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
    memset(&mDataFormat, 0, sizeof(mDataFormat));
    mDataFormat.mSampleRate = sampleRate;// 采样率 (立体声 = 8000)
    mDataFormat.mFormatID = inFormatID;// PCM 格式 kAudioFormatLinearPCM
    mDataFormat.mChannelsPerFrame = 1;//设置通道数 1:单声道；2:立体声
    //每个通道里，一帧采集的bit数目
    mDataFormat.mBitsPerChannel = 16;// 语音每采样点占用位数//结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte
    mDataFormat.mBytesPerFrame = 2;
    mDataFormat.mFramesPerPacket = 1;//每一个packet一侦数据
    mDataFormat.mBytesPerPacket = 2;// 16/8*1 = 2() (_recordFormat.mBitsPerChannel / 8) * _recordFormat.mChannelsPerFrame
    if (inFormatID == kAudioFormatLinearPCM) {
        mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    }
}
//输出回调
void outputCallback (void                 *inUserData,
                     AudioQueueRef        inAQ,
                     AudioQueueBufferRef  inBuffer)
{
    @autoreleasepool{
        NSLog(@"*******current thread: %@",[NSThread currentThread]);
        NSLog(@"播放回调 GenericOutputCallback ");
        HTPlayer *player = (__bridge HTPlayer *)(inUserData);
//        dispatch_async(player->_decode_queue, ^{
        dispatch_async(dispatch_queue_create("sss", DISPATCH_QUEUE_CONCURRENT), ^{
            NSLog(@"------current thread: %@",[NSThread currentThread]);
            if (player->receiveArray.count > 0) {
                //音量
                Float32 gain = 1.0;
                AudioQueueSetParameter (player->outputQueue,kAudioQueueParam_Volume,gain);
                //获取数组的第一个元素
                NSData *speexData = [player->receiveArray getFirstObject];
                if (speexData) {
                    NSData *pcmData = [player decodeToPcmData:speexData];
//                    NSData *pcmData = [player->spxCodec decodeToPcmDataFromData:speexData];//单帧数据测试 320B
                    NSLog(@"pcm data = %lu", pcmData.length);
                    memcpy(inBuffer->mAudioData, pcmData.bytes, pcmData.length);
                    inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
                }
                [player->receiveArray removeFirstObject];
            }
            else {
                Float32 gain = 0.0;
                AudioQueueSetParameter (player->outputQueue,kAudioQueueParam_Volume,gain);
            }
            OSStatus errorStatus = AudioQueueEnqueueBuffer(player->outputQueue, inBuffer, 0, NULL);
            if (errorStatus) {
                NSLog(@"MyInputBufferHandler error:%d", (int)errorStatus);
                return;
            }
        });
    }
}
//将保存了分割好的speex数据的数组解码成pcm数据
- (NSData *)decodeToPcmData:(NSData *)speexData {
    NSMutableData *pcmData = [NSMutableData data];
    [self cutDataFromData:speexData];
    while ([[self getSpeexArrs] count] > 0) {
        NSData *spxData = [[self getSpeexArrs] objectAtIndex:0];
        NSData *pData = [spxCodec decodeToPcmDataFromData:spxData];
        [pcmData appendData:pData];
        [[self getSpeexArrs] removeObjectAtIndex:0];
    }
    return pcmData;
}
//将接收到的数据分割成小段，每段20byte
- (void)cutDataFromData:(NSData *)data {
    int packetSize = FRAME_SIZE * 2 / 16;
    @synchronized(speexArrs) {
        [tempData appendData:data];
        while ([tempData length] >= packetSize) {
            NSData *spxData = [NSData dataWithBytes:[tempData bytes] length:packetSize];
            [speexArrs addObject:spxData];
            Byte *dataPtr = (Byte *)[tempData bytes];
            dataPtr += packetSize;
            tempData = [NSMutableData dataWithBytesNoCopy:dataPtr length:tempData.length - packetSize freeWhenDone:NO];
        }
    }
}

- (NSMutableArray *)getSpeexArrs {
    @synchronized(speexArrs) {
        return speexArrs;
    }
}

//把缓冲区置空
void makeSilent(AudioQueueBufferRef buffer){
    for (int i = 0; i < buffer->mAudioDataBytesCapacity; i++) {
        buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
        UInt8 * samples = (UInt8 *) buffer->mAudioData;
        samples[i]=0;
    }
}
//开始
- (void)startPlaying{
    if(!self.isplaying){
        self.isplaying = YES;
        Float32 gain = 1.0;
        AudioQueueSetParameter (outputQueue,kAudioQueueParam_Volume,gain);
    }
}
//暂停
- (void)stopPlaying{
    if(self.isplaying){
        self.isplaying = NO;
        Float32 gain = 0.0;
        AudioQueueSetParameter (outputQueue,kAudioQueueParam_Volume,gain);
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext{
    if (!_isplaying) {
        return;
    }
    [receiveArray addObject:data];
    
    NSLog(@"<<<<<<<current thread: %@",[NSThread currentThread]);
    NSLog(@"udp socket receive");
    NSLog(@"_receiveData count : %lu",receiveArray.count);
    NSLog(@"speex data length%ld",(unsigned long)data.length);
}

- (void)dealloc {
    [udpSocket close];
    
    udpSocket = nil;
}


- (void)putEmptyBuffer:(AudioQueueBufferRef)buffer {
    BOOL isInArray = NO;
    int indexValue = [self checkUsedQueueBuffer:buffer];
    for (NSNumber *index in emptyAudioQueueBufferIndexs) {
        if ([index intValue] == indexValue) {
            isInArray = YES;
        }
    }
    if ( !isInArray) {
        [emptyAudioQueueBufferIndexs addObject:[NSNumber numberWithInt:indexValue]];
    }
}

- (void)removeEmptyBuffer:(AudioQueueBufferRef)buffer {
    int indexValue = [self checkUsedQueueBuffer:buffer];
    for (NSNumber *index in emptyAudioQueueBufferIndexs) {
        if ([index intValue] == indexValue) {
            [emptyAudioQueueBufferIndexs removeObject:index];
            return;
        }
    }
}

- (int)checkUsedQueueBuffer:(AudioQueueBufferRef)qbuf {
    int bufferIndex = 0;
    if(qbuf == outputBuffers[0]) {
        bufferIndex = 0;
    }
    if(qbuf == outputBuffers[1]) {
        bufferIndex = 1;
    }
    if(qbuf == outputBuffers[2]) {
        bufferIndex = 2;
    }
    //    if(qbuf == outputBuffers[3]) {
    //        bufferIndex = 3;
    //    }
    return bufferIndex;
}


@end
