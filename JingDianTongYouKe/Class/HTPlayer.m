//
//  HTPlayer.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/11.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "HTPlayer.h"
#import "GCDAsyncUdpSocket.h"
#import <AVFoundation/AVFoundation.h>
#import "SpeexCodec.h"
#import "HTSpeexCodec.h"

#define kDefaultIP @"234.5.6.1"
//#define kDefaultIP @"255.255.255.255"
//#define kDefaultIP @"172.16.78.138"

//#define kDefaultPort 8090
//#define kDefaultPort 5760
//#define kDefaultPort 5761
#define kDefaultPort 9081

@interface HTPlayer () <GCDAsyncUdpSocketDelegate>
{
    NSLock *synlock ;//同步控制
    
    NSMutableData *tempData;    //用于输入的speex切割剩余
    NSMutableArray *speexDatas;//保存切割的speex数据块
    
    NSMutableArray *emptyAudioQueueBufferIndexs;
    
    SpeexCodec *codec;
    
    char encoded[FRAME_SIZE * 2];
    short decoded[FRAME_SIZE];
    
    size_t encoded_count;
    size_t decoded_count;
}

@property dispatch_queue_t myqueue;
@property (nonatomic, strong) HTSpeexCodec *spxCodec;

//接收数据的数组
@property (atomic, strong) NSMutableArray *receiveData;
@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;
    
@end

@implementation HTPlayer

- (instancetype) init{
    self = [super init];
    if (self){
        
        emptyAudioQueueBufferIndexs = [[NSMutableArray alloc] initWithCapacity:kNumberBuffers];
        codec = [[SpeexCodec alloc] init];
        tempData = [[NSMutableData alloc] init];
        speexDatas = [[NSMutableArray alloc] init];
        _spxCodec = [[HTSpeexCodec alloc] init];
        
        _myqueue = dispatch_queue_create("com.JDTYouKe.serialQueue", DISPATCH_QUEUE_SERIAL);
//        dispatch_queue_t global = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:_myqueue];
        NSLog(@"-------------current thread: %@",[NSThread currentThread]);
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
    AudioQueueNewOutput(&_aqc.mDataFormat, GenericOutputCallback, (__bridge void *) self, nil, nil, 0, &_aqc.outputQueue);//使用player的内部线程播
    //创建并分配缓冲区空间 3个缓冲区
    for (int i = 0; i < kNumberBuffers; ++i){
        AudioQueueAllocateBuffer(_aqc.outputQueue, MIN_SIZE_PER_FRAME, &_aqc.outputBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
    }
    for (int i = 0; i < kNumberBuffers; ++i) {
        //改变数据
        makeSilent(_aqc.outputBuffers[i]);
        //给输出队列完成配置
        AudioQueueEnqueueBuffer(_aqc.outputQueue,_aqc.outputBuffers[i],0,NULL);
    }
    //设置音量
    Float32 gain = 1.0;
    AudioQueueSetParameter (_aqc.outputQueue,kAudioQueueParam_Volume,gain);
    //开始接收数据
    [_udpSocket beginReceiving:nil];
    //开启播放队列
    AudioQueueStart(_aqc.outputQueue,NULL);
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
    //每个通道里，一帧采集的bit数目
    _aqc.mDataFormat.mBitsPerChannel = 16;// 语音每采样点占用位数//结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte
    _aqc.mDataFormat.mBytesPerFrame = 2;
    _aqc.mDataFormat.mFramesPerPacket = 1;//每一个packet一侦数据
    _aqc.mDataFormat.mBytesPerPacket = 2;// 16/8*1 = 2() (_recordFormat.mBitsPerChannel / 8) * _recordFormat.mChannelsPerFrame
    if (inFormatID == kAudioFormatLinearPCM) {
        _aqc.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    }
}
//输出回调
void GenericOutputCallback (void                 *inUserData,
                            AudioQueueRef        inAQ,
                            AudioQueueBufferRef  inBuffer)
{
    @autoreleasepool{
        //NSLog(@"*******current thread: %@",[NSThread currentThread]);
        NSLog(@"播放回调 GenericOutputCallback ");
        HTPlayer *player = (__bridge HTPlayer *)(inUserData);
        
        if (player.receiveData.count > 0) {
            @synchronized (player) {
                //音量
                Float32 gain = 1.0;
                AudioQueueSetParameter (player.aqc.outputQueue,kAudioQueueParam_Volume,gain);
                
                NSData *speexData = [player.receiveData objectAtIndex:0];
                NSData *pcmData = [player.spxCodec decodeToPcmDataFromData:speexData];
                
                //            NSData *pcmData = [player decodeToPcmFromData:speexData];
                NSLog(@"pcm data = %lu", pcmData.length);
                
                memcpy(inBuffer->mAudioData, pcmData.bytes, pcmData.length);
                
                inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
                
                [player.receiveData removeObjectAtIndex:0];
            }
        }
        else {
            Float32 gain = 0.0;
            AudioQueueSetParameter (player.aqc.outputQueue,kAudioQueueParam_Volume,gain);
        }
        
        OSStatus errorStatus = AudioQueueEnqueueBuffer(player.aqc.outputQueue, inBuffer, 0, NULL);
        if (errorStatus) {
            NSLog(@"MyInputBufferHandler error:%d", (int)errorStatus);
            return;
        }
        
//        [player putEmptyBuffer:inBuffer];
//        [player readSpeexAndPlay:inAQ buffer:inBuffer];
//        dispatch_async(dispatch_queue_create("com.JDTYouke.decode", DISPATCH_QUEUE_SERIAL), ^{
//        });
    }
}

- (NSData *)decodeToPcmFromData: (NSData *)spxData {
    
    [codec open:4];
    
    NSData *pcmRawData = [codec decode: (char *)spxData.bytes length:(int)spxData.length];

    [codec close];
    
    return pcmRawData;
}

- (void)readSpeexAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB{
    [synlock lock];
    //填充queue buffer
    [self putEmptyBuffer:outQB];
    if (_receiveData.count > 0) {
        if ([emptyAudioQueueBufferIndexs count] > 0) {
            [self removeEmptyBuffer:outQB];
            NSData *mSpxData = [_receiveData objectAtIndex:0];
            if (mSpxData) {
                [self inputSpeexDataFromData:mSpxData];
                
                NSData *mPcmData = [self decodeToPcmFromSpeexData];
//                NSLog(@"mpcmData length === %lu",mPcmData.length);
                memcpy(outQB->mAudioData, mPcmData.bytes, mPcmData.length);
                outQB->mAudioDataByteSize = (UInt32)mPcmData.length;
                
                [_receiveData removeObjectAtIndex:0];
            }
        }
    }
    else {
        //当未接收到数据时 设置静音
        Float32 gain = 0.0;
        AudioQueueSetParameter (_aqc.outputQueue,kAudioQueueParam_Volume,gain);
    }
    AudioQueueEnqueueBuffer(_aqc.outputQueue, outQB, 0, NULL);
    [synlock unlock];
}
//将保存了分割好的speex数据的数组解码成pcm数据
- (NSData *)decodeToPcmFromSpeexData {
    NSData *pcmRawData = [NSData data];
    [codec open:4];
//    short decodedBuffer[1024];
    
    while ([[self getSpeexDatas] count] > 0) {
//        NSLog(@"pcmDatas count : %lu",(unsigned long)[[self getSpeexDatas] count]);
        NSData *spxData = [[self getSpeexDatas] objectAtIndex:0];
//        NSLog(@"pcmData length === %lu",spxData.length);
        
        
//        decoded_count = [voiceCodec voice_decode:spxData.bytes andSize:spxData.length toNew:decoded and:FRAME_SIZE];
        pcmRawData = [codec decode: (char *)spxData.bytes length:(int)spxData.length];
        
        short * bytes = (short *)[pcmRawData bytes];
        
        printf("bytes %lu :", pcmRawData.length);
        for (int i=0; i<pcmRawData.length; ++i) {
            printf("%d - ", bytes[i]);
        }
        printf("\n");
        
        
        [[self getSpeexDatas] removeObjectAtIndex:0];
    }
    [codec close];
    return pcmRawData;
}
//将接收到的数据分割成小段，每段20byte
- (void)inputSpeexDataFromData:(NSData *)data {
    int packetSize = FRAME_SIZE * 2 / 16;
    @synchronized(speexDatas) {
        [tempData appendBytes:(__bridge const void * _Nonnull)(data) length:data.length];
        while ([tempData length] >= packetSize) {
            @autoreleasepool {
                NSData *spxData = [NSData dataWithBytes:[tempData bytes] length:packetSize];
                
                
                
                
                
                [speexDatas addObject:spxData];
                
                Byte *dataPtr = (Byte *)[tempData bytes];
                dataPtr += packetSize;
                tempData = [NSMutableData dataWithBytesNoCopy:dataPtr length:[tempData length] - packetSize freeWhenDone:NO];
            }
        }
    }
}

- (NSMutableArray *)getSpeexDatas {
    @synchronized(speexDatas) {
        return speexDatas;
    }
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
    if(qbuf == _aqc.outputBuffers[0]) {
        bufferIndex = 0;
    }
    if(qbuf == _aqc.outputBuffers[1]) {
        bufferIndex = 1;
    }
    if(qbuf == _aqc.outputBuffers[2]) {
        bufferIndex = 2;
    }
//    if(qbuf == _aqc.outputBuffers[3]) {
//        bufferIndex = 3;
//    }
    return bufferIndex;
}

//把缓冲区置空
void makeSilent(AudioQueueBufferRef buffer){
    for (int i = 0; i < buffer->mAudioDataBytesCapacity; i++) {
        buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
        UInt8 * samples = (UInt8 *) buffer->mAudioData;
        samples[i]=0;
//        NSLog(@"make silent!");
    }
}
//开始
- (void)startPlaying{
    if(!self.isplaying){
        self.isplaying = YES;
        Float32 gain = 1.0;
        AudioQueueSetParameter (_aqc.outputQueue,kAudioQueueParam_Volume,gain);
    }
}
//暂停
- (void)stopPlaying{
    if(self.isplaying){
        //暂停接收数据
//        [self.udpSocket pauseReceiving];
//        [_receiveData removeAllObjects];
        //暂停播放队列
//        AudioQueuePause(_aqc.outputQueue);
        self.isplaying = NO;
        Float32 gain = 0.0;
        AudioQueueSetParameter (_aqc.outputQueue,kAudioQueueParam_Volume,gain);
//        for (int i = 0; i < kNumberBuffers; ++i) {
//            //改变数据
//            makeSilent(_aqc.outputBuffers[i]);
//            //给输出队列完成配置
//            AudioQueueEnqueueBuffer(_aqc.outputQueue,_aqc.outputBuffers[i],0,NULL);
//        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    NSLog(@"connect");
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext{
//    NSLog(@"<<<<<<<current thread: %@",[NSThread currentThread]);
    if (!_isplaying) {
        return;
    }
    NSLog(@"udp socket receive");
    
    [_receiveData addObject:data];
    
    NSLog(@"_receiveData count : %lu",_receiveData.count);
    NSLog(@"speex data length%ld",(unsigned long)data.length);
}

- (void)dealloc {
    [_udpSocket close];
    
    _udpSocket = nil;
}

@end
