//
//  ThreadSafetyArray.h
//  JingDianTongYouKe
//
//  Created by 黄启明 on 2016/11/4.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HTThreadSafetyArray : NSObject
{
@private
    NSMutableArray *_array;
    
}

@property (nonatomic, assign) NSUInteger count;

- (void)addObject:(NSData *)obj;

- (NSData *)getFirstObject;
- (void)removeFirstObject;

- (NSData *)getObjectAtIndex:(int)index;

- (void)insertObj:(NSData *)data atIndex:(int)index;
- (void)removeObjAtIndex:(int)index;

- (void)removeAll;

@end
