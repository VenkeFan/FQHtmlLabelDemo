//
//  ImageViewController.m
//  FQHtmlLabelDemo
//
//  Created by fan qi on 2019/3/15.
//  Copyright © 2019 fan qi. All rights reserved.
//

#import "ImageViewController.h"
#import "FLAnimatedImageView+WebCache.h"

@interface ImageViewController ()

@property (nonatomic, strong) FLAnimatedImageView *imgView;
@property (nonatomic, copy) NSString *imgUrl;

@end

@implementation ImageViewController

- (instancetype)initWithImgUrl:(NSString *)imgUrl {
    if (self = [super init]) {
        _imgUrl = [imgUrl copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    if (_imgUrl.length == 0) {
        return;
    }
    
    _imgView = [[FLAnimatedImageView alloc] initWithFrame:self.view.bounds];
    _imgView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:_imgView];
    
    [_imgView sd_setImageWithURL:[NSURL URLWithString:_imgUrl]
                placeholderImage:[UIImage imageNamed:@"html_bg.png"]
                         options:kNilOptions
                        progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
                            
                        }
                       completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           
                       }];
}

@end
