//
//  YBIBProgressiveLoader.m
//  YBImageBrowser
//
//  Created by Performance Optimizer  
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import "YBIBProgressiveLoader.h"
#import "YBIBImageData.h"
#import "YBIBAdvancedImageCache.h"
#import "YBIBPerformanceManager.h"

typedef NS_ENUM(NSUInteger, YBIBLoadingPhase) {
    YBIBLoadingPhaseIdle = 0,
    YBIBLoadingPhaseThumbnail = 1,
    YBIBLoadingPhaseMedium = 2,
    YBIBLoadingPhaseOriginal = 3,
    YBIBLoadingPhaseCompleted = 4
};

@interface YBIBProgressiveLoader ()

@property (nonatomic, weak) YBIBImageData *imageData;
@property (nonatomic, strong) NSURLSessionDataTask *currentTask;
@property (nonatomic, assign) YBIBLoadingPhase currentPhase;
@property (nonatomic, copy) YBIBProgressiveLoadProgressBlock progressBlock;
@property (nonatomic, copy) YBIBProgressiveLoadCompletionBlock completionBlock;

// 临时存储的图片
@property (nonatomic, strong) UIImage *thumbnailImage;
@property (nonatomic, strong) UIImage *mediumQualityImage;
@property (nonatomic, strong) UIImage *originalImage;

@end

@implementation YBIBProgressiveLoader

- (instancetype)initWithImageData:(YBIBImageData *)imageData {
    self = [super init];
    if (self) {
        _imageData = imageData;
        [self setupDefaultConfiguration];
    }
    return self;
}

- (void)setupDefaultConfiguration {
    _enableProgressiveLoading = YES;
    _thumbnailMaxSize = CGSizeMake(200, 200);
    _mediumQualityMaxSize = CGSizeMake(800, 800);
    _networkTimeout = 15.0;
    _currentPhase = YBIBLoadingPhaseIdle;
}

- (void)dealloc {
    [self cancelLoading];
}

#pragma mark - 加载控制

- (void)startProgressiveLoadingWithProgress:(YBIBProgressiveLoadProgressBlock)progressBlock
                                 completion:(YBIBProgressiveLoadCompletionBlock)completionBlock {
    
    if (!_imageData || !completionBlock) return;
    
    self.progressBlock = progressBlock;
    self.completionBlock = completionBlock;
    self.currentPhase = YBIBLoadingPhaseIdle;
    
    
    if (!_enableProgressiveLoading) {
        // 直接加载原图
        [self loadOriginalImageWithCompletion:^(UIImage *originalImage) {
            if (self.completionBlock) {
                self.completionBlock(originalImage, nil);
            }
        }];
        return;
    }
    
    // 开始渐进式加载流程
    [self loadNextPhase];
}

- (void)loadNextPhase {
    switch (_currentPhase) {
        case YBIBLoadingPhaseIdle:
            _currentPhase = YBIBLoadingPhaseThumbnail;
            [self loadThumbnailPhase];
            break;
            
        case YBIBLoadingPhaseThumbnail:
            _currentPhase = YBIBLoadingPhaseMedium;
            [self loadMediumQualityPhase];
            break;
            
        case YBIBLoadingPhaseMedium:
            _currentPhase = YBIBLoadingPhaseOriginal;
            [self loadOriginalPhase];
            break;
            
        case YBIBLoadingPhaseOriginal:
            _currentPhase = YBIBLoadingPhaseCompleted;
            [self completeLoading];
            break;
            
        case YBIBLoadingPhaseCompleted:
            // 已完成
            break;
    }
}

- (void)cancelLoading {
    if (_currentTask) {
        [_currentTask cancel];
        _currentTask = nil;
    }
    _currentPhase = YBIBLoadingPhaseIdle;
    self.progressBlock = nil;
    self.completionBlock = nil;
}

- (BOOL)isLoading {
    return _currentPhase != YBIBLoadingPhaseIdle && _currentPhase != YBIBLoadingPhaseCompleted;
}

#pragma mark - 分阶段加载

- (void)loadThumbnailPhase {
    NSString *thumbnailKey = [self cacheKeyForSize:_thumbnailMaxSize];
    
    // 先检查缓存
    [[YBIBAdvancedImageCache sharedCache] imageForKey:thumbnailKey completion:^(UIImage *image, BOOL fromMemory) {
        if (image) {
            self.thumbnailImage = image;
            [self updateProgress:0.2]; // 缩略图完成20%
            [self provideIntermediateResult:image];
            [self loadNextPhase];
        } else {
            [self downloadImageWithSize:self.thumbnailMaxSize completion:^(UIImage *downloadedImage) {
                if (downloadedImage) {
                    self.thumbnailImage = downloadedImage;
                    
                    // 缓存缩略图
                    [[YBIBAdvancedImageCache sharedCache] storeImage:downloadedImage
                                                              forKey:thumbnailKey
                                                    compressionLevel:YBIBImageCompressionLevelLight
                                                              toDisk:YES];
                    
                    [self updateProgress:0.2];
                    [self provideIntermediateResult:downloadedImage];
                }
                [self loadNextPhase];
            }];
        }
    }];
}

- (void)loadMediumQualityPhase {
    NSString *mediumKey = [self cacheKeyForSize:_mediumQualityMaxSize];
    
    [[YBIBAdvancedImageCache sharedCache] imageForKey:mediumKey completion:^(UIImage *image, BOOL fromMemory) {
        if (image) {
            self.mediumQualityImage = image;
            [self updateProgress:0.6]; // 中等质量完成60%
            [self provideIntermediateResult:image];
            [self loadNextPhase];
        } else {
            [self downloadImageWithSize:self.mediumQualityMaxSize completion:^(UIImage *downloadedImage) {
                if (downloadedImage) {
                    self.mediumQualityImage = downloadedImage;
                    
                    // 缓存中等质量图
                    [[YBIBAdvancedImageCache sharedCache] storeImage:downloadedImage
                                                              forKey:mediumKey
                                                    compressionLevel:YBIBImageCompressionLevelMedium
                                                              toDisk:YES];
                    
                    [self updateProgress:0.6];
                    [self provideIntermediateResult:downloadedImage];
                }
                [self loadNextPhase];
            }];
        }
    }];
}

- (void)loadOriginalPhase {
    NSString *originalKey = [self cacheKeyForOriginal];
    
    [[YBIBAdvancedImageCache sharedCache] imageForKey:originalKey completion:^(UIImage *image, BOOL fromMemory) {
        if (image) {
            self.originalImage = image;
            [self updateProgress:1.0];
            [self loadNextPhase];
        } else {
            [self downloadOriginalImageWithCompletion:^(UIImage *downloadedImage) {
                if (downloadedImage) {
                    self.originalImage = downloadedImage;
                    
                    // 缓存原图
                    YBIBImageCompressionLevel compression = [[YBIBAdvancedImageCache sharedCache] 
                                                           recommendedCompressionLevel:downloadedImage.size];
                    [[YBIBAdvancedImageCache sharedCache] storeImage:downloadedImage
                                                              forKey:originalKey
                                                    compressionLevel:compression
                                                              toDisk:YES];
                }
                [self updateProgress:1.0];
                [self loadNextPhase];
            }];
        }
    }];
}

- (void)completeLoading {
    UIImage *finalImage = _originalImage ?: _mediumQualityImage ?: _thumbnailImage;
    
          _originalImage ? @"原图" : (_mediumQualityImage ? @"中等质量" : @"缩略图"));
    
    if (self.completionBlock) {
        self.completionBlock(finalImage, nil);
    }
    
    // 清理
    self.progressBlock = nil;
    self.completionBlock = nil;
}

#pragma mark - 下载实现

- (void)downloadImageWithSize:(CGSize)maxSize completion:(void(^)(UIImage *image))completion {
    if (!_imageData.imageURL || !completion) {
        completion(nil);
        return;
    }
    
    // 构建带尺寸参数的URL（如果服务器支持）
    NSURL *downloadURL = [self buildURLForSize:maxSize];
    NSURLRequest *request = [NSURLRequest requestWithURL:downloadURL 
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:_networkTimeout];
    
    __weak typeof(self) weakSelf = self;
    _currentTask = [[NSURLSession sharedSession] dataTaskWithRequest:request 
                                                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        strongSelf.currentTask = nil;
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
            return;
        }
        
        if (data) {
            // 在后台解码图片
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImage *image = [UIImage imageWithData:data];
                if (image && !CGSizeEqualToSize(maxSize, CGSizeZero)) {
                    image = [strongSelf resizeImage:image toMaxSize:maxSize];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(image);
                });
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }];
    
    [_currentTask resume];
}

- (void)downloadOriginalImageWithCompletion:(void(^)(UIImage *image))completion {
    if (!_imageData.imageURL || !completion) {
        completion(nil);
        return;
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:_imageData.imageURL 
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:_networkTimeout];
    
    __weak typeof(self) weakSelf = self;
    _currentTask = [[NSURLSession sharedSession] dataTaskWithRequest:request 
                                                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        strongSelf.currentTask = nil;
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
            return;
        }
        
        if (data) {
            // 使用高级缓存的解码功能
            [[YBIBAdvancedImageCache sharedCache] decodeAndCacheImageData:data
                                                                   forKey:[strongSelf cacheKeyForOriginal]
                                                                 strategy:YBIBImageDecodeStrategyAuto
                                                               completion:^(UIImage *image) {
                completion(image);
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }];
    
    [_currentTask resume];
}

#pragma mark - 手动控制

- (void)loadThumbnailWithCompletion:(void(^)(UIImage *thumbnail))completion {
    if (!completion) return;
    
    NSString *thumbnailKey = [self cacheKeyForSize:_thumbnailMaxSize];
    [[YBIBAdvancedImageCache sharedCache] imageForKey:thumbnailKey completion:^(UIImage *image, BOOL fromMemory) {
        if (image) {
            completion(image);
        } else {
            [self downloadImageWithSize:self.thumbnailMaxSize completion:completion];
        }
    }];
}

- (void)loadMediumQualityWithCompletion:(void(^)(UIImage *mediumImage))completion {
    if (!completion) return;
    
    NSString *mediumKey = [self cacheKeyForSize:_mediumQualityMaxSize];
    [[YBIBAdvancedImageCache sharedCache] imageForKey:mediumKey completion:^(UIImage *image, BOOL fromMemory) {
        if (image) {
            completion(image);
        } else {
            [self downloadImageWithSize:self.mediumQualityMaxSize completion:completion];
        }
    }];
}

- (void)loadOriginalImageWithCompletion:(void(^)(UIImage *originalImage))completion {
    if (!completion) return;
    
    NSString *originalKey = [self cacheKeyForOriginal];
    [[YBIBAdvancedImageCache sharedCache] imageForKey:originalKey completion:^(UIImage *image, BOOL fromMemory) {
        if (image) {
            completion(image);
        } else {
            [self downloadOriginalImageWithCompletion:completion];
        }
    }];
}

#pragma mark - 工具方法

- (NSURL *)buildURLForSize:(CGSize)maxSize {
    // 这里可以根据具体的图片服务实现URL参数
    // 例如：http://example.com/image.jpg?w=200&h=200&q=80
    
    if (CGSizeEqualToSize(maxSize, _thumbnailMaxSize)) {
        // 缩略图URL构建逻辑
        NSString *urlString = [NSString stringWithFormat:@"%@?w=%.0f&h=%.0f&q=60",
                              _imageData.imageURL.absoluteString,
                              maxSize.width, maxSize.height];
        return [NSURL URLWithString:urlString];
    } else if (CGSizeEqualToSize(maxSize, _mediumQualityMaxSize)) {
        // 中等质量URL构建逻辑
        NSString *urlString = [NSString stringWithFormat:@"%@?w=%.0f&h=%.0f&q=80",
                              _imageData.imageURL.absoluteString,
                              maxSize.width, maxSize.height];
        return [NSURL URLWithString:urlString];
    }
    
    // 默认返回原URL
    return _imageData.imageURL;
}

- (UIImage *)resizeImage:(UIImage *)image toMaxSize:(CGSize)maxSize {
    CGSize imageSize = image.size;
    
    if (imageSize.width <= maxSize.width && imageSize.height <= maxSize.height) {
        return image;
    }
    
    CGFloat scale = MIN(maxSize.width / imageSize.width, maxSize.height / imageSize.height);
    CGSize targetSize = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
    
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resizedImage;
}

- (NSString *)cacheKeyForSize:(CGSize)size {
    return [NSString stringWithFormat:@"%@_%.0fx%.0f", 
            _imageData.imageURL.absoluteString, size.width, size.height];
}

- (NSString *)cacheKeyForOriginal {
    return _imageData.imageURL.absoluteString;
}

- (void)updateProgress:(CGFloat)progress {
    if (self.progressBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressBlock(progress);
        });
    }
}

- (void)provideIntermediateResult:(UIImage *)image {
    // 这里可以通过通知或回调提供中间结果
    // 让UI能够立即显示低质量图片
}

@end