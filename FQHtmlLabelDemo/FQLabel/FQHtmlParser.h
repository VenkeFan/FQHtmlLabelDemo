//
//  FQHtmlParser.h
//  FQWidgets
//
//  Created by fan qi on 2019/3/5.
//  Copyright © 2019 fan qi. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const FQHtmlDelegateAttributeName;
extern NSString * const FQHtmlImageAttributeName;
extern NSString * const FQHtmlUrlAttributeName;
extern NSString * const FQHtmlEmojiAttributeName;

@class FQHtmlParser;

@protocol FQHtmlParserDelegate <NSObject>

- (void)htmlParserAttributedTextChanged:(FQHtmlParser *)parser;

@end

@interface FQHtmlParser : NSObject

@property (nonatomic, strong) NSDictionary<NSAttributedStringKey,id> *typingAttributes;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey,id> *linkTextAttributes;
@property (nonatomic, copy, readonly) NSString *html;
@property (nonatomic, copy, readonly) NSAttributedString *attributedText;
@property (nonatomic, strong, readonly) NSArray *highlightArray;
@property (nonatomic, strong, readonly) NSArray *renderViewArray;
@property (nonatomic, assign) float contentWidth;
@property (nonatomic, assign) float imagePaddingY;

@property (nonatomic, weak) id<FQHtmlParserDelegate> delegate;

- (void)parseHtmlStr:(NSString *)htmlStr finished:(void(^)(NSAttributedString *attributedTxt))finished;

@end
