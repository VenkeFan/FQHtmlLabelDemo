//
//  ViewController.m
//  FQHtmlLabelDemo
//
//  Created by fan qi on 2019/3/15.
//  Copyright © 2019 fan qi. All rights reserved.
//

#import "ViewController.h"
#import "FQLabel/FQHtmlLabel.h"
#import "WebViewController.h"
#import "ImageViewController.h"

@interface ViewController () <FQHtmlLabelDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    FQHtmlLabel *htmlLabel = [[FQHtmlLabel alloc] init];
    htmlLabel.htmlDelegate = self;
    htmlLabel.typingAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:16], NSForegroundColorAttributeName: [UIColor blackColor]};
    htmlLabel.linkTextAttributes = @{NSUnderlineStyleAttributeName: @(YES),
                                      NSForegroundColorAttributeName: [UIColor redColor]};
    htmlLabel.backgroundColor = [UIColor lightGrayColor];
    htmlLabel.frame = CGRectMake(12, [UIApplication sharedApplication].statusBarFrame.size.height + 44 + 12, [UIScreen mainScreen].bounds.size.width - 24, 500);
    htmlLabel.layer.borderWidth = 1.0;
    htmlLabel.layer.borderColor = [UIColor blackColor].CGColor;
    htmlLabel.imagePaddingY = 10;
    [self.view addSubview:htmlLabel];
    
    NSURL *testFileUrl = [[NSBundle mainBundle] URLForResource:@"index2" withExtension:@"html"];
    NSData *data = [NSData dataWithContentsOfURL:testFileUrl];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    //    NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:str attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:16], NSForegroundColorAttributeName: [UIColor cyanColor]}];
    //    htmlLabel.attributedText = attrStr;
    
    htmlLabel.text = str;
}

#pragma mark - FQHtmlLabelDelegate

- (void)htmlLabel:(FQHtmlLabel *)htmlLabel didHighlight:(FQHtmlHighlight *)highlight {
    NSLog(@"--->%@ - %@ - %@", highlight.text, highlight.linkUrl, highlight.imgUrl);
    
    if (highlight.type == FQHtmlHighlightType_Link) {
        WebViewController *ctr = [[WebViewController alloc] initWithUrlStr:highlight.linkUrl];
        [self.navigationController pushViewController:ctr animated:YES];
    } else {
        ImageViewController *ctr = [[ImageViewController alloc] initWithImgUrl:highlight.imgUrl];
        [self.navigationController pushViewController:ctr animated:YES];
    }
}

- (void)htmlLabelContentSizeChanged:(FQHtmlLabel *)htmlLabel {
//    CGRect frame = htmlLabel.frame;
//    frame.size.height = htmlLabel.contentSize.height;
//    htmlLabel.frame = frame;
}


@end
