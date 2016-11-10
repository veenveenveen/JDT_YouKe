//
//  AppDelegate.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 16/7/8.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate () {
    UIBackgroundTaskIdentifier taskID;
}

@property (nonatomic, strong) ViewController *vc;


@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.vc = [[ViewController alloc] init];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = self.vc;
    
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
//    
//    if(taskID) {
//        [application endBackgroundTask:taskID];
//        taskID = UIBackgroundTaskInvalid;
//    }
//    
//    taskID = [application beginBackgroundTaskWithExpirationHandler:^{
//        if (!taskID) {
//            return;
//        }
//        [application endBackgroundTask:taskID];
//        taskID = UIBackgroundTaskInvalid;
//    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

@end
