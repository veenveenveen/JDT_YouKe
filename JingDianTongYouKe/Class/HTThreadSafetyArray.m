//
//  ThreadSafetyArray.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 2016/11/4.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "HTThreadSafetyArray.h"

@implementation HTThreadSafetyArray

- (instancetype)init {
    self = [super init];
    if (self) {
        _array = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSUInteger)count {
    return _array.count;
}

//增加元素
- (void)addObject:(NSData *)obj {
    @synchronized (self) {
        [_array addObject:obj];
    }
}
//获取第一个元素
- (NSData *)getFirstObject {
    @synchronized (self) {
        if (_array.count > 0) {
            return [_array objectAtIndex:0];
        }
        else {
            return nil;
        }
    }
}
//获取第二个元素
- (NSData *)getSecondObject {
    @synchronized (self) {
        if (_array.count > 1) {
            return [_array objectAtIndex:1];
        }
        else {
            return nil;
        }
    }
}
//删除第一个元素
- (void)removeFirstObject {
    @synchronized (self) {
        if (_array.count > 0) {
            [_array removeObjectAtIndex:0];
        }
    }
}
//删除所有的元素
- (void)removeAll {
    @synchronized (self) {
        if (_array.count > 0) {
            [_array removeAllObjects];
        }
    }
}
@end
