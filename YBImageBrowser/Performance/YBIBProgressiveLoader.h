//
//  YBIBProgressiveLoader.h
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class YBIBImageData;

typedef void(^YBIBProgressiveLoadProgressBlock)(CGFloat progress);
typedef void(^YBIBProgressiveLoadCompletionBlock)(UIImage * _Nullable finalImage, NSError * _Nullable error);

/**
 * 渐进式图片加载器
 * 支持缩略图→中等质量→高清图的渐进式加载策略
 */
@interface YBIBProgressiveLoader : NSObject

#pragma mark - 创建实例

- (instancetype)initWithImageData:(YBIBImageData *)imageData;

#pragma mark - 配置选项

/// 是否启用渐进式加载 (默认YES)
@property (nonatomic, assign) BOOL enableProgressiveLoading;

/// 缩略图最大尺寸 (默认200x200)
@property (nonatomic, assign) CGSize thumbnailMaxSize;

/// 中等质量图最大尺寸 (默认800x800)
@property (nonatomic, assign) CGSize mediumQualityMaxSize;

/// 网络超时时间 (默认15秒)
@property (nonatomic, assign) NSTimeInterval networkTimeout;

#pragma mark - 加载控制

/**
 * 开始渐进式加载
 * @param progressBlock 进度回调 (0.0-1.0)
 * @param completionBlock 完成回调
 */
- (void)startProgressiveLoadingWithProgress:(nullable YBIBProgressiveLoadProgressBlock)progressBlock
                                 completion:(YBIBProgressiveLoadCompletionBlock)completionBlock;

/// 取消当前加载
- (void)cancelLoading;

/// 获取当前加载状态
- (BOOL)isLoading;

#pragma mark - 手动控制

/// 仅加载缩略图
- (void)loadThumbnailWithCompletion:(void(^)(UIImage * _Nullable thumbnail))completion;

/// 仅加载中等质量图
- (void)loadMediumQualityWithCompletion:(void(^)(UIImage * _Nullable mediumImage))completion;

/// 仅加载原图
- (void)loadOriginalImageWithCompletion:(void(^)(UIImage * _Nullable originalImage))completion;

@end

NS_ASSUME_NONNULL_END