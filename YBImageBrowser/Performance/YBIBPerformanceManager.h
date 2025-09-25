//
//  YBIBPerformanceManager.h
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class YBImageBrowser, YBIBImageData;

typedef NS_ENUM(NSUInteger, YBIBPerformanceLevel) {
    YBIBPerformanceLevelLow = 0,      // 低性能设备配置
    YBIBPerformanceLevelMedium = 1,   // 中等性能配置
    YBIBPerformanceLevelHigh = 2,     // 高性能配置
    YBIBPerformanceLevelUltra = 3     // 极致性能配置
};

typedef NS_ENUM(NSUInteger, YBIBImageSizeCategory) {
    YBIBImageSizeCategorySmall = 0,   // 小图 < 1MB
    YBIBImageSizeCategoryMedium = 1,  // 中图 1-5MB
    YBIBImageSizeCategoryLarge = 2,   // 大图 5-10MB
    YBIBImageSizeCategoryHuge = 3     // 超大图 > 10MB
};

/**
 * YBImageBrowser 性能优化管理器
 * 提供智能性能优化策略，根据设备性能和图片大小自动调优
 */
@interface YBIBPerformanceManager : NSObject

+ (instancetype)sharedManager;

#pragma mark - 设备性能检测

/// 当前设备性能等级
@property (nonatomic, assign, readonly) YBIBPerformanceLevel devicePerformanceLevel;

/// 当前可用内存 (MB)
@property (nonatomic, assign, readonly) NSUInteger availableMemoryMB;

/// 设备总物理内存 (MB)
@property (nonatomic, assign, readonly) NSUInteger totalPhysicalMemoryMB;

#pragma mark - 智能配置

/**
 * 为 YBImageBrowser 应用最佳性能配置
 * @param browser 图片浏览器实例
 * @param expectedImageCount 预期图片总数
 * @param averageImageSize 平均图片大小类别
 */
- (void)optimizeBrowser:(YBImageBrowser *)browser
       expectedImageCount:(NSInteger)expectedImageCount
       averageImageSize:(YBIBImageSizeCategory)averageImageSize;

/**
 * 为单个图片数据应用最佳配置
 * @param imageData 图片数据
 * @param imageSize 图片尺寸
 */
- (void)optimizeImageData:(YBIBImageData *)imageData imageSize:(CGSize)imageSize;

#pragma mark - 动态调优

/// 开始性能监控
- (void)startPerformanceMonitoring;

/// 停止性能监控
- (void)stopPerformanceMonitoring;

/// 响应内存压力，动态调整配置
- (void)handleMemoryPressure;

/// 获取推荐的预加载数量
- (NSUInteger)recommendedPreloadCountForImageCount:(NSInteger)imageCount
                                      averageSize:(YBIBImageSizeCategory)averageSize;

/// 获取推荐的缓存数量
- (NSUInteger)recommendedCacheCountForImageSize:(YBIBImageSizeCategory)averageSize;

#pragma mark - 性能统计

/// 获取性能统计信息
- (NSDictionary *)performanceStatistics;

/// 重置统计信息
- (void)resetStatistics;

@end

NS_ASSUME_NONNULL_END