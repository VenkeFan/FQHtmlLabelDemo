//
//  WebViewController.m
//  FQHtmlLabelDemo
//
//  Created by fan qi on 2019/3/15.
//  Copyright © 2019 fan qi. All rights reserved.
//

#import "WebViewController.h"
#import <WebKit/WebKit.h>

@interface WebViewController ()

@end

@implementation WebViewController {
    NSString *_urlStr;
}

- (instancetype)initWithUrlStr:(NSString *)urlStr {
    if (self = [super init]) {
        _urlStr = [urlStr copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    if (_urlStr.length == 0) {
        return;
    }
    
    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.selectionGranularity = WKSelectionGranularityCharacter;
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    [self.view addSubview:webView];
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:_urlStr]];
    [webView loadRequest:request];
}

@end
