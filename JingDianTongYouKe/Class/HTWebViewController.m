//
//  HTWebViewController.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 2016/11/14.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "HTWebViewController.h"
#import "KVNProgress.h"

@interface HTWebViewController () <UIWebViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic, assign) NSTimeInterval timetap;

@property (nonatomic, assign) BOOL loadSuccess;

@end


@implementation HTWebViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.webView.scrollView.bounces = NO;
    
    self.webView.delegate = self;
    
    self.loadSuccess = NO;
    
    [self toWebView];
    
}

- (IBAction)back:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)toWebView {
    NSString *urlStr = @"http://m.wfzkd.com/#!/";
//    NSString *urlStr = @"http://www.baidu.com";

    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - UIWebView delegate methods

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [KVNProgress showWithStatus:@"正在加载..."];
    self.loadSuccess = NO;
    [self performSelector:@selector(checkTime) withObject:self afterDelay:15];

}

- (void)checkTime {
    if (!self.loadSuccess) {
        [KVNProgress dismiss];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"提示" message:@"网络君正忙,请稍后重试" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *action = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil];
            [alertC addAction:action];
            [self presentViewController:alertC animated:YES completion:nil];
        });
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.loadSuccess = YES;
    [KVNProgress dismiss];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [KVNProgress dismiss];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"提示" message:@"加载失败" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil];
        [alertC addAction:action];
        [self presentViewController:alertC animated:YES completion:nil];
    });
}

@end
