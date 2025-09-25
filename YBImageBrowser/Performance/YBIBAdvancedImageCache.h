//
//  YBIBAdvancedImageCache.h
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, YBIBImageDecodeStrategy) {
    YBIBImageDecodeStrategyAuto = 0,      // 自动决策
    YBIBImageDecodeStrategyImmediate = 1, // 立即解码
    YBIBImageDecodeStrategyLazy = 2,      // 延迟解码
    YBIBImageDecodeStrategyNever = 3      // 不解码
};

typedef NS_ENUM(NSUInteger, YBIBImageCompressionLevel) {
    YBIBImageCompressionLevelNone = 0,   // 不压缩
    YBIBImageCompressionLevelLight = 1,  // 轻度压缩
    YBIBImageCompressionLevelMedium = 2, // 中度压缩
    YBIBImageCompressionLevelHeavy = 3   // 重度压缩
};

/**
 * 高级图片缓存管理器
 * 提供多级缓存、智能压缩、内存感知等高级功能
 */
@interface YBIBAdvancedImageCache : NSObject

+ (instancetype)sharedCache;

#pragma mark - 缓存配置

/// 最大内存缓存大小 (MB)
@property (nonatomic, assign) NSUInteger maxMemoryCacheSizeMB;

/// 最大磁盘缓存大小 (MB)
@property (nonatomic, assign) NSUInteger maxDiskCacheSizeMB;

/// 内存压力阈值 (MB)，低于此值时自动清理
@property (nonatomic, assign) NSUInteger memoryPressureThresholdMB;

#pragma mark - 图片缓存操作

/**
 * 存储图片到缓存
 * @param image 图片对象
 * @param key 缓存键值
 * @param compressionLevel 压缩等级
 * @param toDisk 是否写入磁盘
 */
- (void)storeImage:(UIImage *)image
            forKey:(NSString *)key
  compressionLevel:(YBIBImageCompressionLevel)compressionLevel
            toDisk:(BOOL)toDisk;

/**
 * 从缓存获取图片
 * @param key 缓存键值
 * @param completion 完成回调 (主线程)
 */
- (void)imageForKey:(NSString *)key
         completion:(void(^)(UIImage * _Nullable image, BOOL fromMemory))completion;

/**
 * 异步解码并缓存图片
 * @param imageData 原始图片数据
 * @param key 缓存键值
 * @param strategy 解码策略
 * @param completion 完成回调
 */
- (void)decodeAndCacheImageData:(NSData *)imageData
                         forKey:(NSString *)key
                       strategy:(YBIBImageDecodeStrategy)strategy
                     completion:(void(^)(UIImage * _Nullable image))completion;

#pragma mark - 内存管理

/// 清理内存缓存
- (void)clearMemoryCache;

/// 清理磁盘缓存
- (void)clearDiskCache;

/// 清理过期缓存
- (void)cleanExpiredCache;

/// 获取缓存统计信息
- (NSDictionary *)cacheStatistics;

#pragma mark - 智能压缩

/**
 * 根据图片大小和设备性能自动选择压缩等级
 * @param imageSize 图片尺寸
 * @return 推荐的压缩等级
 */
- (YBIBImageCompressionLevel)recommendedCompressionLevel:(CGSize)imageSize;

/**
 * 自定义图片压缩
 * @param image 原图
 * @param level 压缩等级
 * @return 压缩后图片
 */
- (UIImage *)compressImage:(UIImage *)image level:(YBIBImageCompressionLevel)level;

@end

NS_ASSUME_NONNULL_END