//
//  HTWebViewController.m
//  JingDianTongYouKe
//
//  Created by 黄启明 on 2016/11/14.
//  Copyright © 2016年 huatengIOT. All rights reserved.
//

#import "HTWebViewController.h"
#import "KVNProgress.h"
#import <WebKit/WebKit.h>

#define WEB_W [UIScreen mainScreen].bounds.size.width
#define WEB_H [UIScreen mainScreen].bounds.size.height

@interface HTWebViewController () <WKNavigationDelegate,NSURLConnectionDelegate,NSURLConnectionDataDelegate>
{
    NSURLConnection *_theConnection;
}

@property (nonatomic, strong) WKWebView *webView;

@end

@implementation HTWebViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 44+20, WEB_W, WEB_H-64)];
    
    self.webView.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1];
    
    self.webView.scrollView.scrollEnabled = NO;
    
    self.webView.navigationDelegate = self;
    
    [self reloadView];
    
    [self.view addSubview:self.webView];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
//返回
- (IBAction)back:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        //清空网页内容
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]];
        [self.webView loadRequest:request];
    }];
}

#pragma mark - load webView

- (void)toWebView {
    //@"http://m.wfzkd.com/#!/"
    NSString *urlStr = @"http://m.wfzkd.com/#!/";
//    NSString *urlStr = @"http://www.baidu.com";
    NSLog(@"%@",urlStr);
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20];
    
    [self.webView loadRequest:request];
    if (_theConnection) {
        [_theConnection cancel];
        NSLog(@"safe release connection");
    }
    _theConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)reloadView {
    [self toWebView];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]){
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if ((([httpResponse statusCode]/100) == 2)){//成功响应
            NSLog(@"connection ok statusCode %ld",(long)[httpResponse statusCode]);
            [KVNProgress dismiss];
        }
        else{
            NSError *error = [NSError errorWithDomain:@"HTTP" code:[httpResponse statusCode] userInfo:nil];
            if ([error code] == 404){
                NSLog(@"404");
                [KVNProgress dismiss];
                [self showAlertWithMessage:@"服务器找不到所请求的资源"];
            }
        }
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (error.code == 22) {//The operation couldn’t be completed. Invalid argument
        NSLog(@"22");
        [self performSelector:@selector(showAlertWithMessage:) withObject:@"操作无法完成！" afterDelay:2];
    }
    else if (error.code == -1001) {//The request timed out.
        NSLog(@"-1001");
        [self performSelector:@selector(showAlertWithMessage:) withObject:@"网络君正忙,请稍后重试" afterDelay:2];
    }
    else if (error.code == -1005) {//The network connection was lost.
        NSLog(@"-1005");
        [self performSelector:@selector(showAlertWithMessage:) withObject:@"网络不可用,请尝试重新连接" afterDelay:2];
    }
    else if (error.code == -1009){ //The Internet connection appears to be offline
        NSLog(@"-1009");
        [self performSelector:@selector(showAlertWithMessage:) withObject:@"网络未连接,请检查网络后重试" afterDelay:2];
        
    }
}

#pragma mark - WKWebView delegate methods

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [KVNProgress showWithStatus:@"正在加载..."];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [KVNProgress dismiss];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self showAlertWithMessage:@"加载失败,请稍后重试"];
}

#pragma mark - showAlert method

- (void)showAlertWithMessage:(NSString *)message {
    [KVNProgress dismiss];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil];
        [alertC addAction:action];
        [self presentViewController:alertC animated:YES completion:nil];
    });
}

@end
