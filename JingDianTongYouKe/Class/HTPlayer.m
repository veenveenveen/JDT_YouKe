//
//  HTPlayer.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/11.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "HTPlayer.h"
#import "HTSpeexCodec.h"
#import "HTThreadSafetyArray.h"

@interface HTPlayer()
@end

@implementation HTPlayer {
    AudioStreamBasicDescription mDataFormat;//音频流描述对象  格式化音频数据
    AudioQueueRef               outputQueue;//音频输出队列
    AudioQueueBufferRef         outputBuffers[kNumberBuffers];
    
    dispatch_queue_t _decode_queue;
    dispatch_queue_t _receive_queue;
    
    GCDAsyncUdpSocket *udpSocket;
    
    HTThreadSafetyArray *receiveArray;//接收数据的数组
    HTSpeexCodec *spxCodec;//编码器
    
    int j;
}

#pragma mark - life cycle

- (instancetype) init{
    self = [super init];
    if (self){
        
        j = 0;
        
        spxCodec = [[HTSpeexCodec alloc] init];
        
        receiveArray = [[HTThreadSafetyArray alloc] init];
        
        _receive_queue = dispatch_queue_create("com.JDTYouKe.receiveQueue", DISPATCH_QUEUE_SERIAL);
        
        udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:_receive_queue];
        NSError *error = nil;
        //绑定端口号
        [udpSocket bindToPort:kDefaultPort error:&error];
        if (error != nil) {
            NSLog(@"bind To Port error:%@",error.description);
        }
        //添加多地址发送，用于连接一个多组播
//        [udpSocket joinMulticastGroup:@"234.5.6.1" error:&error];
        
        [udpSocket joinMulticastGroup:@"224.0.0.1"  error:&error];
        if (error != nil) {
            NSLog(@"join Multicast Group error:%@",error.description);
        }
        
        [udpSocket enableBroadcast:YES error:&error];
        if (error != nil) {
            NSLog(@"enable Broadcast error:%@",error.description);
        }
        
        self.isplaying = NO;

        [self setupAudioPlaying];
    }
    return self;
}

- (void)dealloc {
    [udpSocket close];
    udpSocket = nil;
    spxCodec = nil;
    receiveArray = nil;
}

#pragma mark - setup AudioQueue and AVAudioSession

//输出回调
void outputCallback (void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    @autoreleasepool {
        
        //NSLog(@"播放回调");
        
        HTPlayer *player = (__bridge HTPlayer *)(inUserData);
        
        if (player->receiveArray.count > 0) {
            [player setVolume:1.0];
            
            //获取数组的第一个元素
            NSData *speexData = [player->receiveArray getFirstObject];
            [player->receiveArray removeFirstObject];
            if (speexData) {
                
                NSData *pcmData = [player->spxCodec decodeToPcmDataFromData:speexData];
                
                memcpy(inBuffer->mAudioData, pcmData.bytes, pcmData.length);
                
                inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
            }
            
            //[player->receiveArray removeFirstObject];
            
        } else {
            [player setVolume:0.0];
        }
        
        OSStatus errorStatus = AudioQueueEnqueueBuffer(player->outputQueue, inBuffer, 0, NULL);
        if (errorStatus) {
            NSLog(@"MyInputBufferHandler error:%d", (int)errorStatus);
            return;
        }
        
    }
}

- (void)setupAudioPlaying{
    //设置录音格式
    [self setupAudioFormat:kAudioFormatLinearPCM andSampleRate:kSamplingRate];
    
    // 创建一个新的从audioqueue到硬件层的通道; 使用player的内部线程播
    AudioQueueNewOutput(&mDataFormat, outputCallback, (__bridge void *) self, nil, nil, 0, &outputQueue);
    
    /* 创建并分配缓冲区空间 3个缓冲区
     * 创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
     */
    for (int i = 0; i < kNumberBuffers; ++i){
        AudioQueueAllocateBuffer(outputQueue, kDefaultOutputBufferSize, &outputBuffers[i]);
    }
    for (int i = 0; i < kNumberBuffers; ++i) {
        //重置缓冲区的大小，并把内容置为0
        [self makeSilent:outputBuffers[i]];
        //给输出队列完成配置
        AudioQueueEnqueueBuffer(outputQueue, outputBuffers[i], 0, NULL);
    }
    
    //设置音量
    [self setVolume:1.0];
    
    //开始接收数据
    [udpSocket beginReceiving:nil];
    
    //开启播放队列
    AudioQueueStart(outputQueue,NULL);
}

//设置录音格式
- (void)setupAudioFormat:(UInt32)inFormatID andSampleRate:(int)sampleRate{
    //重置
    memset(&mDataFormat, 0, sizeof(mDataFormat));
    mDataFormat.mSampleRate = sampleRate;// 采样率 (立体声 = 8000)
    mDataFormat.mFormatID = inFormatID;// PCM 格式 kAudioFormatLinearPCM
    mDataFormat.mChannelsPerFrame = 1;//设置通道数 1:单声道；2:立体声
    //每个通道里，一帧采集的bit数目
    mDataFormat.mBytesPerFrame = 2;
    if (inFormatID == kAudioFormatLinearPCM) {
        mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        mDataFormat.mBitsPerChannel = 16;// 语音每采样点占用位数//结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte
        mDataFormat.mBytesPerPacket = 2;// 16/8*1 = 2()
        mDataFormat.mFramesPerPacket = 1;//每一个packet一侦数据
    }
}
// 设置音量
- (void)setVolume:(Float32)volume {
    AudioQueueSetParameter (outputQueue, kAudioQueueParam_Volume, volume);
}

//把缓冲区置空
- (void) makeSilent:(AudioQueueBufferRef)buffer {
    buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
    UInt8 * samples = (UInt8 *) buffer->mAudioData;
    for (int i = 0; i < buffer->mAudioDataBytesCapacity; i++) {
        samples[i]=0;
    }
}

#pragma mark - start and stop methods

//开始
- (void)startPlaying{
    if(!self.isplaying){
        self.isplaying = YES;
        
        AudioQueueStart(outputQueue, NULL);
        
        [self setVolume:1.0];
    }
}
//暂停
- (void)stopPlaying{
    if(self.isplaying){
        self.isplaying = NO;
        
        [self setVolume:0.0];
        
        //删除数组中所有的数据
        [receiveArray removeAll];
    }
}

#pragma mark - Socket delegate method

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext{
    if (!self.isplaying) {
        return;
    }
    
//    if (receiveArray.count < 12) {//会接收不到某些数据 但基本不会影响语音流畅度 需要改善
        [receiveArray addObject:data];
//    }
    
    NSLog(@"udp socket receive data len = %lu; waiting count : %lu", (unsigned long)data.length, (unsigned long)receiveArray.count);
//    j++;
//    NSLog(@"receive number = %d",j);
    
    //test
//    [data getBytes: &j length: sizeof(int)];
//    NSLog(@"receive number = %d",j);
}

@end
