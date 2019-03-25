//
//  FQHtmlParser.m
//  FQWidgets
//
//  Created by fan qi on 2019/3/5.
//  Copyright © 2019 fan qi. All rights reserved.
//

#import "FQHtmlParser.h"
#import "UIImageView+WebCache.h"
#import "FQHtmlTextAttachment.h"
#import "FQHtmlRunDelegate.h"
#import "FQHtmlHighlight.h"
#import "FQHtmlAnimatedView.h"
#import "FLAnimatedImage.h"

#define kUIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#define kAnchorFontColor        kUIColorFromRGB(0x48779D)


NSString * const FQHtmlDelegateAttributeName    = @"FQHtmlDelegateAttribute";
NSString * const FQHtmlImageAttributeName       = @"FQHtmlImageAttribute";
NSString * const FQHtmlUrlAttributeName         = @"FQHtmlUrlAttribute";
NSString * const FQHtmlEmojiAttributeName       = @"FQHtmlEmojiAttribute";

static char * const kFQHtmlParserQueueKey       = "com.widgets.htmlparser.fq";

static NSString * const kRegExScriptPattern         = @"<script(.*?)>(.|\n)*?</script>";
static NSString * const kRegExStylePattern          = @"<style(.*?)>(.|\n)*?</style>";
static NSString * const kRegExAnchorPattern         = @"<a[^<>]+>(.|\n)*?</a>";
static NSString * const kRegExAnchorHeadPattern     = @"<a[^<>]+>";
static NSString * const kRegExAnchorTailPattern     = @"</a>";
static NSString * const kRegExBoldPattern           = @"<b>[^<]*</b>";
static NSString * const kRegExImgPattern            = @"<img(.*?)>";
static NSString * const kRegExBrakePattern          = @"<br([ |/]?)>";
static NSString * const kRegExImgSrcPattern         = @"src=['|\"](.*?)['|\"]";
static NSString * const kRegExLinkUrlPattern        = @"((http[s]{0,1}|ftp)://[a-zA-Z0-9\\.\\-]+\\.([a-zA-Z]{2,4})(:\\d+)?(/[a-zA-Z0-9\\.\\-~!@#$%^&*+?:_/=<>]*)?)"
"|(www.[a-zA-Z0-9\\.\\-]+\\.([a-zA-Z]{2,4})(:\\d+)?(/[a-zA-Z0-9\\.\\-~!@#$%^&*+?:_/=<>]*)?)";

@interface FQHtmlParser ()

@property (nonatomic, strong) NSArray *validTags;
@property (nonatomic, strong) NSArray *ambiguousTags;
@property (nonatomic, strong) NSArray *invalidTags;
@property (nonatomic, copy, readwrite) NSString *html;
@property (nonatomic, copy, readwrite) NSAttributedString *attributedText;
@property (nonatomic, strong) NSMutableArray *highlightArrayM;
@property (nonatomic, strong) NSMutableArray *renderViewArrayM;

@end

@implementation FQHtmlParser {
    dispatch_queue_t _parseQueue;
}

- (instancetype)init {
    if (self = [super init]) {
        _parseQueue = dispatch_queue_create(kFQHtmlParserQueueKey, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)dealloc {
    
}

#pragma mark - Public

- (void)parseHtmlStr:(NSString *)htmlStr finished:(void(^)(NSAttributedString *attributedTxt))finished {
    dispatch_async(_parseQueue, ^{
        NSString *html = [self p_filterInvalidTagsAndContent:htmlStr pattern:kRegExScriptPattern];
        html = [self p_filterInvalidTagsAndContent:html pattern:kRegExStylePattern];
        html = [self p_filterValidHtmlTags:html];
        html = [self p_filterWhitespaceAndNewline:html];
        self.html = html;
        
        if (html.length == 0) {
            if (finished) {
                finished(nil);
            }
            return;
        }
        
        self.attributedText = [[NSAttributedString alloc] initWithString:html attributes:self.typingAttributes];
        
        self.attributedText = [self p_parseBoldHtmlString:self.attributedText];
        self.attributedText = [self p_parseImgHtmlString:self.attributedText];
        self.attributedText = [self p_parseLineBreakHtmlString:self.attributedText];
        self.attributedText = [self p_parseAnchorHtmlString:self.attributedText];
        
        if (finished) {
            finished(self.attributedText);
        }
    });
}

#pragma mark - Private

- (NSString *)p_filterInvalidTagsAndContent:(NSString *)htmlString pattern:(NSString *)pattern {
    if (htmlString.length == 0) {
        return htmlString;
    }
    
    NSArray<NSTextCheckingResult *> *resultArray = [self p_regExWithPattern:pattern str:htmlString];
    if (resultArray.count == 0) {
        return htmlString;
    }
    
    NSMutableString *strM = [NSMutableString stringWithString:htmlString];
    NSInteger scriptLength = 0;
    for (NSTextCheckingResult *result in resultArray) {
        NSRange range = result.range;
        range.location -= scriptLength;
        
        if ([self p_isOutOfRange:range str:strM]) {
            continue;
        }
        
        [strM deleteCharactersInRange:range];
        scriptLength += range.length;
    }
    return strM;
}

- (NSString *)p_filterValidHtmlTags:(NSString *)htmlString {
    if (htmlString.length == 0) {
        return htmlString;
    }
    
    if ([htmlString containsString:@"&lt;"]) {
        htmlString = [htmlString stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    }
    if ([htmlString containsString:@"&gt;"]) {
        htmlString = [htmlString stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:htmlString];
    NSString *text = nil;
    BOOL isValid = NO;
    
    while (!scanner.isAtEnd) {
        [scanner scanUpToString:@"<" intoString:nil];
        [scanner scanUpToString:@">" intoString:&text];
        isValid = NO;
        
        for (int i = 0 ; i < self.validTags.count; i++) {
            if ([text containsString:self.validTags[i]]) {
                isValid = YES;
                break;
            }
        }
        if (isValid) {
            continue;
        }
        
        for (int i = 0; i < self.ambiguousTags.count; i++) {
            if ([text isEqualToString:self.ambiguousTags[i]]) {
                isValid = YES;
                break;
            }
        }
        if (isValid) {
            continue;
        }
        
        NSString *tmp = [NSString stringWithFormat:@"%@>", text];
        if ([tmp isEqualToString:@"<p>"] || [tmp isEqualToString:@"</p>"]) {
            htmlString = [htmlString stringByReplacingOccurrencesOfString:tmp withString:@"<br/>"];
        } else {
            htmlString = [htmlString stringByReplacingOccurrencesOfString:tmp withString:@""];
        }
    }
    
    return htmlString;
}

- (NSString *)p_filterWhitespaceAndNewline:(NSString *)htmlString {
    if (htmlString.length == 0) {
        return htmlString;
    }
    
    htmlString = [htmlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSArray *components = [htmlString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *arrayM = [NSMutableArray arrayWithCapacity:components.count];
    for (int i = 0; i < components.count; i++) {
        NSString *tmp = [components[i] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        if ([tmp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length != 0) {
            [arrayM addObject:tmp];
        }
    }
    components = [arrayM filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self <> ''"]];
    htmlString = [components componentsJoinedByString:@"\n"];
//    htmlString = [htmlString stringByReplacingOccurrencesOfString:@" " withString:@"😄"]; // just for test
    
    return htmlString;
}

- (NSAttributedString *)p_parseAnchorHtmlString:(NSAttributedString *)attrStr {
    NSArray<NSTextCheckingResult *> *resultArray = [self p_regExWithPattern:kRegExAnchorPattern str:attrStr.string];
    if (resultArray.count == 0) {
        return attrStr;
    }
    
    NSMutableAttributedString *mutAttr = [[NSMutableAttributedString alloc] initWithAttributedString:attrStr];
    NSInteger txtOffset = 0;
    for (NSTextCheckingResult *result in resultArray) {
        NSRange range = result.range;
        range.location -= txtOffset;
        
        if ([self p_isOutOfRange:range str:mutAttr.string]) {
            continue;
        }
        
        NSAttributedString *anchorHtmlTxt = [mutAttr attributedSubstringFromRange:range];
        
        NSString *urlStr = nil;
        if ([anchorHtmlTxt.string containsString:@"href"]) {
            urlStr = [self p_parseUrlLink:anchorHtmlTxt.string];
        }
        urlStr = [self p_convertUrlStr:urlStr];
        if (!urlStr) {
            urlStr = @"";
        }
        
//        NSString *anchorTxt = [self p_filterHtmlTags:anchorHtmlTxt.string];
        NSString *anchorTxt = [anchorHtmlTxt.string stringByReplacingOccurrencesOfString:kRegExAnchorHeadPattern withString:@"" options:NSRegularExpressionSearch range:NSMakeRange (0, anchorHtmlTxt.length)];
        anchorTxt = [anchorTxt stringByReplacingOccurrencesOfString:kRegExAnchorTailPattern withString:@"" options:NSRegularExpressionSearch range:NSMakeRange (0, anchorTxt.length)];
        anchorTxt = [anchorTxt stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (anchorTxt.length == 0) {
            anchorTxt = urlStr;
        }
        if (!anchorTxt) {
            anchorTxt = @"";
        }
        
        NSRange anchorTxtRange = [anchorHtmlTxt.string rangeOfString:anchorTxt];
        NSDictionary *originalAttrs = nil;
        if (![self p_isOutOfRange:anchorTxtRange str:anchorHtmlTxt.string]) {
            originalAttrs = [anchorHtmlTxt attributesAtIndex:anchorTxtRange.location effectiveRange:nil];
        }
        
        NSString *imgUrl = nil;
        if ([originalAttrs objectForKey:FQHtmlImageAttributeName]) {
            FQHtmlTextAttachment *attachment = (FQHtmlTextAttachment *)[originalAttrs objectForKey:FQHtmlImageAttributeName];
            imgUrl = attachment.imgUrl;
        }
        
        NSRange anchorTagRange = NSMakeRange(range.location, anchorTxt.length);
        
        BOOL isExist = NO;
        if (imgUrl) {
            for (int i = 0; i < self.highlightArrayM.count; i++) {
                FQHtmlHighlight *tmp = self.highlightArrayM[i];
                if ([tmp.imgUrl isEqualToString:imgUrl]) {
                    tmp.range = anchorTagRange;
                    tmp.linkUrl = urlStr;
                    isExist = YES;
                    break;
                }
            }
        }
        
        for (int i = 0; i < self.highlightArrayM.count; i++) {
            FQHtmlHighlight *tmp = self.highlightArrayM[i];
            if (tmp.range.location >= range.location + range.length) {
                CGFloat tmpLoc = tmp.range.location - (range.length - anchorTxt.length);
                tmp.range = NSMakeRange(tmpLoc, tmp.range.length);
            }
        }
        
        if (!isExist && anchorTxt.length > 0) {
            FQHtmlHighlight *highlight = [FQHtmlHighlight new];
            highlight.range = anchorTagRange;
            highlight.text = anchorTxt;
            highlight.linkUrl = urlStr;
            highlight.imgUrl = imgUrl;
            [self.highlightArrayM addObject:highlight];
        }
        
        NSAttributedString *anchorAttrStr = [[NSAttributedString alloc] initWithString:anchorTxt attributes:originalAttrs];
        [mutAttr replaceCharactersInRange:range withAttributedString:anchorAttrStr];
        
        if (!imgUrl) {
            if (![self p_isOutOfRange:anchorTagRange str:mutAttr.string]) {
                [mutAttr addAttributes:self.linkTextAttributes
                                 range:anchorTagRange];
            }
        }
        
        txtOffset += range.length - anchorTxt.length;
    }
    
    return mutAttr;
}

- (NSAttributedString *)p_parseBoldHtmlString:(NSAttributedString *)attrStr {
    NSArray<NSTextCheckingResult *> *resultArray = [self p_regExWithPattern:kRegExBoldPattern str:attrStr.string];
    if (resultArray.count == 0) {
        return attrStr;
    }
    
    NSMutableAttributedString *mutAttr = [[NSMutableAttributedString alloc] initWithAttributedString:attrStr];
    NSInteger txtOffset = 0;
    for (NSTextCheckingResult *result in resultArray) {
        NSRange range = result.range;
        range.location -= txtOffset;
        
        if ([self p_isOutOfRange:range str:mutAttr.string]) {
            continue;
        }
        
        NSAttributedString *boldHtmlText = [mutAttr attributedSubstringFromRange:range];
        NSString *boldText = [self p_filterHtmlTags:boldHtmlText.string];
        if (!boldText) {
            boldText = @"";
        }
        
        NSRange boldTxtRange = [boldHtmlText.string rangeOfString:boldText];
        NSDictionary *originalAttrs = nil;
        if (![self p_isOutOfRange:boldTxtRange str:boldHtmlText.string]) {
            originalAttrs = [boldHtmlText attributesAtIndex:boldTxtRange.location effectiveRange:nil];
        }
        
        NSRange boldTagRange = NSMakeRange(range.location, boldText.length);
        
        NSAttributedString *boldAttrStr = [[NSAttributedString alloc] initWithString:boldText attributes:originalAttrs];
        [mutAttr replaceCharactersInRange:range withAttributedString:boldAttrStr];
        
        if (![self p_isOutOfRange:boldTagRange str:mutAttr.string]) {
            UIFont *font = [boldHtmlText attribute:NSFontAttributeName atIndex:0 effectiveRange:nil];
            [mutAttr addAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:font.pointSize]} range:boldTagRange];
        }
        
        txtOffset += range.length - boldText.length;
    }
    
    return mutAttr;
}

- (NSAttributedString *)p_parseImgHtmlString:(NSAttributedString *)attrStr {
    NSArray<NSTextCheckingResult *> *resultArray = [self p_regExWithPattern:kRegExImgPattern str:attrStr.string];
    if (resultArray.count == 0) {
        return attrStr;
    }
    
    NSMutableAttributedString *mutAttr = [[NSMutableAttributedString alloc] initWithAttributedString:attrStr];
    NSInteger txtOffset = 0;
    for (NSTextCheckingResult *result in resultArray) {
        NSRange range = result.range;
        range.location -= txtOffset;
        
        if ([self p_isOutOfRange:range str:mutAttr.string]) {
            continue;
        }
        
        NSString *imgHtmlText = [mutAttr.string substringWithRange:range];
        
        NSString *imgSrc = [self p_parseImgSrc:imgHtmlText];
        imgSrc = [self p_convertUrlStr:imgSrc];
        
        UIImage *customImg = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:imgSrc];
        if (!customImg) {
            customImg = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:imgSrc];
        }
        
        if (!customImg) {
            [self p_downloadWebImage:imgSrc];
        }
        
        NSMutableAttributedString *imgAttr = [self p_parseImage:customImg
                                                       imageUrl:imgSrc
                                                  imageLocation:range.location];
        if (imgAttr) {
            [mutAttr replaceCharactersInRange:range withAttributedString:imgAttr];
        }
        
        txtOffset += range.length - imgAttr.length;
    }
    
    return mutAttr;
}

- (NSMutableAttributedString *)p_parseImage:(UIImage *)image
                                   imageUrl:(NSString *)imageUrl
                              imageLocation:(CGFloat)imageLocation {
    unichar objectReplacementChar = 0xFFFC;
    NSString *content = [NSString stringWithCharacters:&objectReplacementChar length:1];
    NSMutableAttributedString *imageText = [[NSMutableAttributedString alloc] initWithString:content];
    
    NSRange range = NSMakeRange(0, imageText.length);
    
    FQHtmlRunDelegate *delegate = [FQHtmlRunDelegate new];
    
    FQHtmlTextAttachment *attachment = [[FQHtmlTextAttachment alloc] init];
    attachment.imgUrl = imageUrl;
    if ([self p_isGif:imageUrl]) {
        FQHtmlAnimatedViewManager *viewManager = [FQHtmlAnimatedViewManager new];
        attachment.content = viewManager;
        [self.renderViewArrayM addObject:viewManager];
        [self p_setDelegate:delegate size:viewManager.frame.size];
    } else {
        image = image ?: [FQHtmlTextAttachment placeholder];
        attachment.content = image;
        [self p_setDelegate:delegate size:image.size];
    }
    if (!attachment) {
        return nil;
    }
    
    FQHtmlHighlight *highlight = [FQHtmlHighlight new];
    highlight.range = NSMakeRange(imageLocation, imageText.length);
    highlight.text = content;
    highlight.imgUrl = imageUrl;
    highlight.attachment = attachment;
    highlight.runDelegate = delegate;
    [self.highlightArrayM addObject:highlight];
    
    if ([self p_isOutOfRange:range str:imageText.string]) {
        return nil;
    }
    [imageText addAttributes:@{FQHtmlImageAttributeName: attachment,
                               FQHtmlDelegateAttributeName: delegate,
                               (id)kCTRunDelegateAttributeName: (id)delegate.delegateRef} range:range];
    CFRelease(delegate.delegateRef);
    
    return imageText;
}

- (NSAttributedString *)p_parseLineBreakHtmlString:(NSAttributedString *)attrStr {
    NSArray<NSTextCheckingResult *> *resultArray = [self p_regExWithPattern:kRegExBrakePattern str:attrStr.string];
    if (resultArray.count == 0) {
        return attrStr;
    }
    
    NSMutableAttributedString *mutAttr = [[NSMutableAttributedString alloc] initWithAttributedString:attrStr];
    NSInteger txtOffset = 0;
    for (NSTextCheckingResult *result in resultArray) {
        NSRange range = result.range;
        range.location -= txtOffset;
        
        if ([self p_isOutOfRange:range str:mutAttr.string]) {
            continue;
        }
        
        NSString *breakText = @"\n";
        [mutAttr replaceCharactersInRange:range withString:breakText];
        txtOffset += range.length - breakText.length;
    }
    
    return mutAttr;
}

- (void)p_downloadWebImage:(NSString *)urlStr {
    if (urlStr.length == 0) {
        return;
    }
    
    urlStr = [self p_convertUrlStr:urlStr];
    
    NSURL *url = nil;
    if ([urlStr isKindOfClass:[NSString class]]) {
        url = [NSURL URLWithString:urlStr];
    } else if ([urlStr isKindOfClass:[NSURL class]]) {
        url = (NSURL *)urlStr;
    }
    
    if (!url) {
        return;
    }
    
    [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:url
                                                          options:kNilOptions
                                                         progress:nil
                                                        completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
                                                            if (error) {
                                                                return;
                                                            }

                                                            [self p_downloadedImage:image
                                                                          imageData:data
                                                                             urlStr:urlStr];
                                                        }];
}

- (void)p_downloadedImage:(UIImage *)image imageData:(NSData *)imageData urlStr:(NSString *)urlStr {
    if (![self p_isGif:urlStr]) {
        [[SDImageCache sharedImageCache] storeImage:image forKey:urlStr toDisk:YES completion:nil];
    }
    
    for (int i = 0; i < self.highlightArrayM.count; i++) {
        FQHtmlHighlight *highlight = self.highlightArrayM[i];
        if ([highlight.imgUrl isEqualToString:urlStr]) {
            if ([highlight.attachment.content isKindOfClass:[UIImage class]]) {
                highlight.attachment.content = image;
                [self p_setDelegate:highlight.runDelegate size:image.size];
                
            } else if ([highlight.attachment.content isKindOfClass:[FQHtmlAnimatedViewManager class]]) {
                FLAnimatedImage *animatedImg = [FLAnimatedImage animatedImageWithGIFData:imageData];
                FQHtmlAnimatedViewManager *viewManager = (FQHtmlAnimatedViewManager *)highlight.attachment.content;
                viewManager.animatedImage = animatedImg;
                viewManager.frame = CGRectMake(0, 0, animatedImg.size.width, animatedImg.size.height);
                [self p_setDelegate:highlight.runDelegate size:viewManager.frame.size];
            }
            
            if ([self.delegate respondsToSelector:@selector(htmlParserAttributedTextChanged:)]) {
                [self.delegate htmlParserAttributedTextChanged:self];
            }
        }
    }
}

- (void)p_setDelegate:(FQHtmlRunDelegate *)delegate size:(CGSize)size {
    CGFloat width = self.contentWidth;
    CGFloat height = kFQHtmlTextAttachmentDefaultHeight;
    
    if (size.width > 0 && size.height > 0) {
        height = size.height / size.width * width;
    }
    
    height += (self.imagePaddingY * 2);
    
    delegate.width = width;
    delegate.height = height;
}

- (NSString *)p_parseImgSrc:(NSString *)imgHtmlText {
    NSString *imgSrc = @"";
    
    if (imgHtmlText.length == 0) {
        return imgSrc;
    }
    
    NSRange srcRange = [imgHtmlText rangeOfString:kRegExImgSrcPattern options:NSRegularExpressionSearch];
    if ([self p_isOutOfRange:srcRange str:imgHtmlText]) {
        return imgSrc;
    }
    
    NSString *srcStr = [imgHtmlText substringWithRange:srcRange];
    NSRange range = [srcStr rangeOfString:@"src="];
    range = NSMakeRange(range.length + 1, srcStr.length - (range.length + 1) - 1);
    if ([self p_isOutOfRange:range str:srcStr]) {
        return imgSrc;
    }
    
    imgSrc = [srcStr substringWithRange:range];
    
    return imgSrc;
}

- (NSString *)p_parseUrlLink:(NSString *)str {
    NSString *urlStr = @"";
    
    if (str.length == 0) {
        return urlStr;
    }
    
    NSRange range = [str rangeOfString:kRegExLinkUrlPattern options:NSRegularExpressionSearch];
    if ([self p_isOutOfRange:range str:str]) {
        return urlStr;
    }
    urlStr = [str substringWithRange:range];
    
    return urlStr;
}

- (NSString *)p_filterHtmlTags:(NSString *)htmlString {
    if (htmlString.length == 0) {
        return htmlString;
    }
    
    if ([htmlString containsString:@"&lt;"]) {
        htmlString = [htmlString stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    }
    if ([htmlString containsString:@"&gt;"]) {
        htmlString = [htmlString stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:htmlString];
    NSString *text = nil;
    
    while (!scanner.isAtEnd) {
        [scanner scanUpToString:@"<" intoString:nil];
        [scanner scanUpToString:@">" intoString:&text];
        htmlString = [htmlString stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@>", text] withString:@""];
    }
    
    return htmlString;
}

- (BOOL)p_isBoldFont:(UIFont *)font {
    UIFontDescriptor *fontDescriptor = font.fontDescriptor;
    UIFontDescriptorSymbolicTraits fontDescriptorSymbolicTraits = fontDescriptor.symbolicTraits;
    BOOL isBold = (fontDescriptorSymbolicTraits & UIFontDescriptorTraitBold) != 0;
    
    return isBold;
}

- (BOOL)p_isGif:(NSString *)imageUrl {
    if (imageUrl.length == 0) {
        return NO;
    }
    
    return [imageUrl hasSuffix:@".gif"] || [imageUrl hasSuffix:@".gif/"]
    || [imageUrl hasSuffix:@".webp"] || [imageUrl hasSuffix:@".webp/"];
}

- (BOOL)p_isOutOfRange:(NSRange)range str:(NSString *)str {
    if (range.location == NSNotFound || range.location < 0 || range.length <= 0) {
        return YES;
    }
    
    if (range.location > str.length || range.location + range.length > str.length) {
        return YES;
    }
    
    return NO;
}

- (NSArray<NSTextCheckingResult *> *)p_regExWithPattern:(NSString *)pattern str:(NSString *)str {
    if (pattern.length == 0 || str.length == 0) {
        return nil;
    }
    
    NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                             options:kNilOptions
                                                                               error:nil];
    NSArray<NSTextCheckingResult *> *resultArray = [regular matchesInString:str
                                                                    options:kNilOptions
                                                                      range:NSMakeRange(0, str.length)];
    return resultArray;
}

- (NSString *)p_convertUrlStr:(NSString *)urlStr {
    if (urlStr.length == 0) {
        return urlStr;
    }
    
    {
        // 适配taobao的imgUrl
        if (urlStr.length >= 2) {
            NSString *str = [urlStr substringWithRange:NSMakeRange(0, 2)];
            if ([str isEqualToString:@"//"]) {
                urlStr = [NSString stringWithFormat:@"https:%@", urlStr];
                return urlStr;
            }
        }
    }
    
    if (![urlStr hasPrefix:@"http"] && ![urlStr hasPrefix:@"https"]) {
        urlStr = [NSString stringWithFormat:@"https://%@", urlStr];
    }
    return urlStr;
}

#pragma mark - Getter

- (NSArray *)validTags {
    if (!_validTags) {
        _validTags = @[@"<a ", @"</a",
                       @"<img", @"</img",
                       @"<br", @"</br", @"<br/", @"<br /"];
    }
    return _validTags;
}

- (NSArray *)ambiguousTags {
    if (!_ambiguousTags) {
        _ambiguousTags = @[@"<b", @"</b"];
    }
    return _ambiguousTags;
}

- (NSArray *)invalidTags {
    if (!_invalidTags) {
        _invalidTags = @[@"<script", @"</script"];
    }
    return _invalidTags;
}

- (NSMutableArray *)highlightArrayM {
    if (!_highlightArrayM) {
        _highlightArrayM = [NSMutableArray array];
    }
    return _highlightArrayM;
}

- (NSArray *)highlightArray {
    return _highlightArrayM;
}

- (NSMutableArray *)renderViewArrayM {
    if (!_renderViewArrayM) {
        _renderViewArrayM = [NSMutableArray array];
    }
    return _renderViewArrayM;
}

- (NSArray *)renderViewArray {
    return _renderViewArrayM;
}

- (NSDictionary<NSAttributedStringKey,id> *)typingAttributes {
    if (!_typingAttributes) {
        _typingAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:16], NSForegroundColorAttributeName: kUIColorFromRGB(0x616161)};
    }
    return _typingAttributes;
}

- (NSDictionary<NSAttributedStringKey,id> *)linkTextAttributes {
    if (!_linkTextAttributes) {
        _linkTextAttributes = @{NSUnderlineStyleAttributeName: @(YES),
                                NSForegroundColorAttributeName: kAnchorFontColor};
    }
    return _linkTextAttributes;
}

@end
