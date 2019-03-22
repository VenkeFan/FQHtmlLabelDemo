//
//  FQHtmlTextAttachment.m
//  FQWidgets
//
//  Created by fan qi on 2019/3/7.
//  Copyright © 2019 fan qi. All rights reserved.
//

#import "FQHtmlTextAttachment.h"

#define kPadding            12.0

NSString * const FQHtmlTextAttachmentToken = @"\uFFFC";
static NSString * const FQHtmlTextAttachmentPlaceholder = @"html_bg.png";

@interface FQHtmlTextAttachment ()

@end

@implementation FQHtmlTextAttachment

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}

- (void)dealloc {
    
}

+ (UIImage *)placeholder {
    return [UIImage imageNamed:FQHtmlTextAttachmentPlaceholder];
}

@end
