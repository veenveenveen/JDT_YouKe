//
//  HTEchoCancel.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 2016/11/4.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "HTEchoCanceller.h"

@implementation HTEchoCanceller {
    
    SpeexEchoState *echoState;
    SpeexPreprocessState *preprocessorState;
    
    BOOL isInit;

    int frameSize;
    int filterLen;
    int sampleRate;
    int *pNoise;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        echoState = nil;
        preprocessorState = nil;
        
        isInit = false;
        
        frameSize = 160;
        filterLen = 160*8;
        sampleRate = 8000;
        pNoise = nil;
    }
    return self;
}

- (void)initWithFrameSize:(int)size andFilterLength:(int)length andSampleRate:(int)rate {
    
    [self reset];
    
    if (size <= 0 || length <= 0 || rate <= 0){
        frameSize =160;
        filterLen = 160*8;
        sampleRate = 8000;
    }
    else{
        frameSize = size;
        filterLen = length;
        sampleRate = rate;
    }
    
    echoState = speex_echo_state_init(frameSize, filterLen);
    pNoise = &pNoise[frameSize+1];
    isInit = true;
}

- (void)reset {
    if (echoState != nil){
        speex_echo_state_destroy(echoState);
        echoState = nil;
    }
    if (preprocessorState != nil){
        speex_preprocess_state_destroy(preprocessorState);
        preprocessorState = nil;
    }
    if (pNoise != nil){
        pNoise = nil;
    }
    isInit = false;
}

- (NSData *)doEchoCancellationWith:(NSData *)mic and:(NSData *)ref {
    if (!isInit) {
        return nil;
    }
    [self initWithFrameSize:0 andFilterLength:0 andSampleRate:0];
    NSMutableData *output = [NSMutableData data];
    speex_echo_cancel(echoState, (short *)mic.bytes, (short *)ref.bytes, (short *)output.bytes, pNoise);
    speex_preprocess(preprocessorState, (short *)output.bytes, pNoise);
    
    return output;
}

@end
