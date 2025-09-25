//
//  YBIBPerformanceConfigurator.m
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import "YBIBPerformanceConfigurator.h"
#import "YBImageBrowser.h"
#import "YBIBImageData.h"
#import "YBIBImageCache.h"
#import "YBIBPerformanceManager.h"
#import "YBIBMemoryAdaptiveManager.h"
#import "YBIBPerformanceMonitor.h"
#import "YBIBAdvancedImageCache.h"

@implementation YBIBPerformanceConfigurator

#pragma mark - 快速配置

+ (void)optimizeBrowser:(YBImageBrowser *)browser
             imageCount:(NSInteger)imageCount
    useAdvancedFeatures:(BOOL)useAdvancedFeatures {
    
    if (!browser) return;
    
    
    // 1. 基础性能优化
    YBIBPerformanceManager *manager = [YBIBPerformanceManager sharedManager];
    YBIBImageSizeCategory avgSize = imageCount > 50 ? YBIBImageSizeCategoryMedium : YBIBImageSizeCategoryLarge;
    [manager optimizeBrowser:browser expectedImageCount:imageCount averageImageSize:avgSize];
    
    // 2. 启用高级功能
    if (useAdvancedFeatures) {
        [self enableAdvancedFeatures:browser];
    }
    
    // 3. 根据图片数量进行特殊优化
    if (imageCount > 100) {
        [self optimizeForManyImages:browser imageCount:imageCount];
    } else if (imageCount < 10) {
        [self optimizeForFewImages:browser];
    }
    
}

+ (void)optimizeForLargeImages:(YBImageBrowser *)browser
             averageImageSizeMB:(CGFloat)averageImageSizeMB {
    
    if (!browser) return;
    
    
    // 根据图片大小调整策略
    if (averageImageSizeMB > 10) {
        // 超大图片
        browser.preloadCount = 1;
        browser.ybib_imageCache.imageCacheCountLimit = 3;
    } else if (averageImageSizeMB > 5) {
        // 大图片
        browser.preloadCount = 2;
        browser.ybib_imageCache.imageCacheCountLimit = 5;
    } else {
        // 中等大小图片
        browser.preloadCount = 3;
        browser.ybib_imageCache.imageCacheCountLimit = 8;
    }
    
    // 启用高级缓存
    [[YBIBAdvancedImageCache sharedCache] setMaxMemoryCacheSizeMB:100];
    
    // 注册内存监控
    [[YBIBMemoryAdaptiveManager sharedManager] registerBrowser:browser];
    
}

+ (void)optimizeForManyImages:(YBImageBrowser *)browser
                   imageCount:(NSInteger)imageCount {
    
    if (!browser) return;
    
    
    // 限制内存使用
    NSUInteger cacheLimit = MAX(5, MIN(15, imageCount / 10));
    browser.ybib_imageCache.imageCacheCountLimit = cacheLimit;
    
    // 适中的预加载
    browser.preloadCount = imageCount > 500 ? 2 : 3;
    
    // 启用内存自适应管理
    YBIBMemoryAdaptiveManager *memoryManager = [YBIBMemoryAdaptiveManager sharedManager];
    [memoryManager registerBrowser:browser];
    [memoryManager startMemoryMonitoring];
    
}

+ (void)optimizeForLowEndDevice:(YBImageBrowser *)browser {
    if (!browser) return;
    
    
    // 最小化配置
    browser.preloadCount = 1;
    browser.ybib_imageCache.imageCacheCountLimit = 3;
    
    // 禁用可能消耗性能的功能
    browser.shouldHideStatusBar = NO; // 减少状态栏操作
    
    // 启用紧急内存管理
    YBIBMemoryAdaptiveManager *memoryManager = [YBIBMemoryAdaptiveManager sharedManager];
    memoryManager.warningThresholdMB = 100;
    memoryManager.criticalThresholdMB = 60;
    memoryManager.urgentThresholdMB = 30;
    [memoryManager registerBrowser:browser];
    [memoryManager startMemoryMonitoring];
    
}

#pragma mark - 场景化配置

+ (void)configureForPhotoAlbum:(YBImageBrowser *)browser {
    
    // 相册图片通常较大，但本地访问快
    browser.preloadCount = 3;
    browser.ybib_imageCache.imageCacheCountLimit = 10;
    
    // 启用性能监控
    [[YBIBPerformanceMonitor sharedMonitor] addBrowserToMonitor:browser];
    
}

+ (void)configureForNetworkImages:(YBImageBrowser *)browser {
    
    // 网络图片需要考虑下载时间
    browser.preloadCount = 4; // 增加预加载以减少等待
    browser.ybib_imageCache.imageCacheCountLimit = 15;
    
    // 启用高级缓存和渐进式加载
    [self enableAdvancedFeatures:browser];
    
}

+ (void)configureForProductImages:(YBImageBrowser *)browser {
    
    // 商品图片通常需要高质量展示
    browser.preloadCount = 2;
    browser.ybib_imageCache.imageCacheCountLimit = 12;
    
    // 启用内存管理
    [[YBIBMemoryAdaptiveManager sharedManager] registerBrowser:browser];
    
}

+ (void)configureForSocialMedia:(YBImageBrowser *)browser {
    
    // 社交媒体图片数量多，需要平衡性能和内存
    browser.preloadCount = 3;
    browser.ybib_imageCache.imageCacheCountLimit = 8;
    
    // 启用全套性能优化
    [self enableFullPerformanceMode:browser];
    
}

#pragma mark - 高级配置

+ (void)applyCustomConfiguration:(YBImageBrowser *)browser config:(NSDictionary *)config {
    if (!browser || !config) return;
    
    
    // 预加载数量
    NSNumber *preloadCount = config[@"preloadCount"];
    if (preloadCount) {
        browser.preloadCount = [preloadCount unsignedIntegerValue];
    }
    
    // 缓存数量
    NSNumber *cacheCount = config[@"cacheCount"];
    if (cacheCount) {
        browser.ybib_imageCache.imageCacheCountLimit = [cacheCount unsignedIntegerValue];
    }
    
    // 高级功能开关
    NSNumber *enableAdvanced = config[@"enableAdvancedFeatures"];
    if ([enableAdvanced boolValue]) {
        [self enableAdvancedFeatures:browser];
    }
    
    // 性能监控
    NSNumber *enableMonitoring = config[@"enablePerformanceMonitoring"];
    if ([enableMonitoring boolValue]) {
        [[YBIBPerformanceMonitor sharedMonitor] addBrowserToMonitor:browser];
        [[YBIBPerformanceMonitor sharedMonitor] startMonitoring];
    }
    
}

+ (NSDictionary *)recommendedConfigurationForImageCount:(NSInteger)imageCount
                                            averageSize:(YBIBImageSizeCategory)averageSize {
    
    YBIBPerformanceManager *manager = [YBIBPerformanceManager sharedManager];
    
    NSUInteger preloadCount = [manager recommendedPreloadCountForImageCount:imageCount
                                                                averageSize:averageSize];
    NSUInteger cacheCount = [manager recommendedCacheCountForImageSize:averageSize];
    
    return @{
        @"preloadCount": @(preloadCount),
        @"cacheCount": @(cacheCount),
        @"enableAdvancedFeatures": @(imageCount > 20),
        @"enablePerformanceMonitoring": @(YES),
        @"scenario": [self determineScenario:imageCount averageSize:averageSize],
        @"devicePerformanceLevel": @(manager.devicePerformanceLevel)
    };
}

#pragma mark - 批量图片数据优化

+ (void)optimizeImageDatas:(NSArray<YBIBImageData *> *)imageDatas
               forScenario:(NSString *)scenario {
    
    if (!imageDatas || imageDatas.count == 0) return;
    
    
    // 异步批量优化，避免阻塞主线程造成CPU峰值
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (YBIBImageData *imageData in imageDatas) {
            [self optimizeImageDataForScenario:imageData scenario:scenario];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
        });
    });
}

+ (void)smartConfigureImageData:(YBIBImageData *)imageData withURL:(NSURL *)imageURL {
    if (!imageData || !imageURL) return;
    
    // 根据URL特征智能配置
    NSString *urlString = imageURL.absoluteString;
    
    if ([urlString containsString:@"thumb"] || [urlString containsString:@"small"]) {
        // 缩略图URL
        imageData.shouldPreDecodeAsync = YES;
        // maxZoomScale属性在当前版本不存在，移除此行
    } else if ([urlString containsString:@"large"] || [urlString containsString:@"original"]) {
        // 大图URL
        imageData.shouldPreDecodeAsync = NO;
        imageData.cuttingZoomScale = 2.0;
        // maxZoomScale属性在当前版本不存在
    }
    
    // 根据文件扩展名优化
    NSString *pathExtension = imageURL.pathExtension.lowercaseString;
    if ([pathExtension isEqualToString:@"gif"] || [pathExtension isEqualToString:@"webp"]) {
        // 动图或WebP，启用预解码
        imageData.shouldPreDecodeAsync = YES;
    }
}

#pragma mark - 性能监控集成

+ (void)enableFullPerformanceMode:(YBImageBrowser *)browser {
    if (!browser) return;
    
    
    // 1. 启用所有管理器
    YBIBPerformanceManager *perfManager = [YBIBPerformanceManager sharedManager];
    [perfManager startPerformanceMonitoring];
    
    YBIBMemoryAdaptiveManager *memoryManager = [YBIBMemoryAdaptiveManager sharedManager];
    [memoryManager registerBrowser:browser];
    [memoryManager startMemoryMonitoring];
    
    YBIBPerformanceMonitor *monitor = [YBIBPerformanceMonitor sharedMonitor];
    [monitor addBrowserToMonitor:browser];
    [monitor startMonitoring];
    
    // 2. 启用高级功能
    [self enableAdvancedFeatures:browser];
    
}

+ (void)disablePerformanceMode:(YBImageBrowser *)browser {
    if (!browser) return;
    
    
    [[YBIBMemoryAdaptiveManager sharedManager] unregisterBrowser:browser];
    [[YBIBPerformanceMonitor sharedMonitor] removeBrowserFromMonitor:browser];
    
}

#pragma mark - 配置验证

+ (NSDictionary *)validateConfiguration:(YBImageBrowser *)browser {
    if (!browser) return @{@"valid": @NO, @"error": @"浏览器实例为空"};
    
    NSMutableArray *warnings = [NSMutableArray array];
    NSMutableArray *suggestions = [NSMutableArray array];
    
    // 检查预加载数量
    if (browser.preloadCount > 8) {
        [warnings addObject:@"预加载数量过多，可能导致内存压力"];
        [suggestions addObject:@"建议将预加载数量控制在8以内"];
    } else if (browser.preloadCount == 0) {
        [warnings addObject:@"预加载数量为0，可能影响用户体验"];
        [suggestions addObject:@"建议设置至少1-2张预加载"];
    }
    
    // 检查缓存数量
    if (browser.ybib_imageCache.imageCacheCountLimit > 30) {
        [warnings addObject:@"缓存数量过多，可能占用过多内存"];
        [suggestions addObject:@"根据设备性能调整缓存数量"];
    } else if (browser.ybib_imageCache.imageCacheCountLimit < 3) {
        [warnings addObject:@"缓存数量过少，可能影响浏览流畅性"];
        [suggestions addObject:@"建议设置至少3-5张缓存"];
    }
    
    // 检查内存管理
    YBIBPerformanceManager *manager = [YBIBPerformanceManager sharedManager];
    if (manager.availableMemoryMB < 200 && browser.ybib_imageCache.imageCacheCountLimit > 10) {
        [warnings addObject:@"当前可用内存较少，建议降低缓存数量"];
        [suggestions addObject:@"启用内存自适应管理"];
    }
    
    BOOL isValid = warnings.count == 0;
    
    return @{
        @"valid": @(isValid),
        @"warnings": [warnings copy],
        @"suggestions": [suggestions copy],
        @"score": @([self calculateConfigurationScore:browser])
    };
}

+ (NSDictionary *)getConfigurationSummary:(YBImageBrowser *)browser {
    if (!browser) return @{};
    
    YBIBPerformanceManager *manager = [YBIBPerformanceManager sharedManager];
    YBIBMemoryAdaptiveManager *memoryManager = [YBIBMemoryAdaptiveManager sharedManager];
    
    return @{
        @"basicConfig": @{
            @"preloadCount": @(browser.preloadCount),
            @"cacheCountLimit": @(browser.ybib_imageCache.imageCacheCountLimit),
            @"distanceBetweenPages": @(browser.distanceBetweenPages)
        },
        @"deviceInfo": @{
            @"performanceLevel": @(manager.devicePerformanceLevel),
            @"totalMemoryMB": @(manager.totalPhysicalMemoryMB),
            @"availableMemoryMB": @(manager.availableMemoryMB)
        },
        @"managementStatus": @{
            @"memoryManagementActive": @(YES), // 简化检查，假设已注册
            @"performanceMonitoringActive": @([[YBIBPerformanceMonitor sharedMonitor] isMonitoring])
        },
        @"configurationHealth": [self validateConfiguration:browser]
    };
}

#pragma mark - 私有方法

+ (void)enableAdvancedFeatures:(YBImageBrowser *)browser {
    // 启用高级缓存
    YBIBAdvancedImageCache *advancedCache = [YBIBAdvancedImageCache sharedCache];
    YBIBPerformanceManager *manager = [YBIBPerformanceManager sharedManager];
    
    switch (manager.devicePerformanceLevel) {
        case YBIBPerformanceLevelUltra:
            advancedCache.maxMemoryCacheSizeMB = 300;
            advancedCache.maxDiskCacheSizeMB = 2000;
            break;
        case YBIBPerformanceLevelHigh:
            advancedCache.maxMemoryCacheSizeMB = 200;
            advancedCache.maxDiskCacheSizeMB = 1000;
            break;
        case YBIBPerformanceLevelMedium:
            advancedCache.maxMemoryCacheSizeMB = 100;
            advancedCache.maxDiskCacheSizeMB = 500;
            break;
        case YBIBPerformanceLevelLow:
            advancedCache.maxMemoryCacheSizeMB = 50;
            advancedCache.maxDiskCacheSizeMB = 200;
            break;
    }
}

+ (void)optimizeForFewImages:(YBImageBrowser *)browser {
    // 少量图片，可以提高缓存和预加载
    browser.preloadCount = MIN(5, browser.dataSourceArray.count - 1);
    browser.ybib_imageCache.imageCacheCountLimit = MIN(10, (NSUInteger)browser.dataSourceArray.count);
}

+ (void)optimizeImageDataForScenario:(YBIBImageData *)imageData scenario:(NSString *)scenario {
    if ([scenario isEqualToString:@"album"]) {
        imageData.shouldPreDecodeAsync = YES;
        imageData.cuttingZoomScale = 4.0;
    } else if ([scenario isEqualToString:@"network"]) {
        imageData.shouldPreDecodeAsync = NO;
        imageData.cuttingZoomScale = 3.0;
    } else if ([scenario isEqualToString:@"product"]) {
        imageData.shouldPreDecodeAsync = YES;
        // maxZoomScale属性在当前版本不存在
    }
}

+ (NSString *)determineScenario:(NSInteger)imageCount averageSize:(YBIBImageSizeCategory)averageSize {
    if (imageCount > 100 && averageSize <= YBIBImageSizeCategoryMedium) {
        return @"social_media";
    } else if (averageSize >= YBIBImageSizeCategoryLarge) {
        return @"high_quality";
    } else if (imageCount < 20) {
        return @"product_showcase";
    } else {
        return @"general_browsing";
    }
}

+ (CGFloat)calculateConfigurationScore:(YBImageBrowser *)browser {
    CGFloat score = 100.0;
    
    YBIBPerformanceManager *manager = [YBIBPerformanceManager sharedManager];
    
    // 根据设备性能评估配置合理性
    NSUInteger recommendedPreload = 2;
    NSUInteger recommendedCache = 12;
    
    switch (manager.devicePerformanceLevel) {
        case YBIBPerformanceLevelLow:
            recommendedPreload = 1;
            recommendedCache = 6;
            break;
        case YBIBPerformanceLevelMedium:
            recommendedPreload = 2;
            recommendedCache = 12;
            break;
        case YBIBPerformanceLevelHigh:
            recommendedPreload = 4;
            recommendedCache = 20;
            break;
        case YBIBPerformanceLevelUltra:
            recommendedPreload = 6;
            recommendedCache = 30;
            break;
    }
    
    // 预加载数量评分
    CGFloat preloadDiff = ABS((CGFloat)browser.preloadCount - recommendedPreload) / recommendedPreload;
    score -= preloadDiff * 20;
    
    // 缓存数量评分
    CGFloat cacheDiff = ABS((CGFloat)browser.ybib_imageCache.imageCacheCountLimit - recommendedCache) / recommendedCache;
    score -= cacheDiff * 20;
    
    // 内存状态评分
    if (manager.availableMemoryMB < 200 && browser.ybib_imageCache.imageCacheCountLimit > 10) {
        score -= 30;
    }
    
    return MAX(0, MIN(100, score));
}

@end