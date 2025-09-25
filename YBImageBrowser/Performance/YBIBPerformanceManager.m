//
//  YBIBPerformanceManager.m
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import "YBIBPerformanceManager.h"
#import "YBImageBrowser.h"
#import "YBIBImageData.h"
#import "YBIBImageCache.h"
#import <mach/mach.h>
#import <sys/sysctl.h>

@interface YBIBPerformanceManager ()

@property (nonatomic, assign) YBIBPerformanceLevel devicePerformanceLevel;
@property (nonatomic, strong) NSTimer *monitoringTimer;
@property (nonatomic, strong) NSMutableDictionary *statistics;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSUInteger imageLoadCount;
@property (nonatomic, assign) NSUInteger cacheHitCount;

@end

@implementation YBIBPerformanceManager

+ (instancetype)sharedManager {
    static YBIBPerformanceManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YBIBPerformanceManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self detectDevicePerformance];
        [self setupMemoryNotifications];
        self.statistics = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    [self stopPerformanceMonitoring];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 设备性能检测

- (void)detectDevicePerformance {
    NSUInteger totalMemoryMB = self.totalPhysicalMemoryMB;
    NSString *deviceModel = [self deviceModel];
    
    // 基于内存和设备型号判断性能等级
    if (totalMemoryMB >= 6000) {
        _devicePerformanceLevel = YBIBPerformanceLevelUltra;
    } else if (totalMemoryMB >= 4000) {
        _devicePerformanceLevel = YBIBPerformanceLevelHigh;
    } else if (totalMemoryMB >= 2000) {
        _devicePerformanceLevel = YBIBPerformanceLevelMedium;
    } else {
        _devicePerformanceLevel = YBIBPerformanceLevelLow;
    }
    
    // 特殊设备优化
    if ([deviceModel hasPrefix:@"iPhone14,"] || [deviceModel hasPrefix:@"iPhone15,"] || [deviceModel hasPrefix:@"iPhone16,"]) {
        // iPhone 13/14/15 系列，提升一级
        if (_devicePerformanceLevel < YBIBPerformanceLevelUltra) {
            _devicePerformanceLevel++;
        }
    }
}

- (NSString *)deviceModel {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *model = [NSString stringWithUTF8String:machine];
    free(machine);
    return model;
}

- (NSUInteger)totalPhysicalMemoryMB {
    return (NSUInteger)([NSProcessInfo processInfo].physicalMemory / 1024 / 1024);
}

- (NSUInteger)availableMemoryMB {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(natural_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;
    
    host_page_size(host_port, &pagesize);
    host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
    
    NSUInteger freeMemory = (NSUInteger)(vm_stat.free_count * pagesize / 1024 / 1024);
    NSUInteger inactiveMemory = (NSUInteger)(vm_stat.inactive_count * pagesize / 1024 / 1024);
    
    return freeMemory + inactiveMemory;
}

- (void)setupMemoryNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMemoryPressure)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
}

#pragma mark - 智能配置

- (void)optimizeBrowser:(YBImageBrowser *)browser
       expectedImageCount:(NSInteger)expectedImageCount
       averageImageSize:(YBIBImageSizeCategory)averageImageSize {
    
    // 设置预加载数量
    browser.preloadCount = [self recommendedPreloadCountForImageCount:expectedImageCount
                                                         averageSize:averageImageSize];
    
    // 设置缓存数量
    browser.ybib_imageCache.imageCacheCountLimit = [self recommendedCacheCountForImageSize:averageImageSize];
    
    // 根据图片数量调整数据缓存
    NSUInteger dataCacheCount = MIN(50, MAX(10, expectedImageCount / 2));
    if ([browser.dataMediator respondsToSelector:@selector(setDataCacheCountLimit:)]) {
        [(id)browser.dataMediator setDataCacheCountLimit:dataCacheCount];
    }
    
    NSLog(@"🚀 YBImageBrowser 性能优化配置:");
    NSLog(@"   设备等级: %@", [self performanceLevelString:_devicePerformanceLevel]);
    NSLog(@"   预加载数量: %lu", (unsigned long)browser.preloadCount);
    NSLog(@"   图片缓存: %lu", (unsigned long)browser.ybib_imageCache.imageCacheCountLimit);
    NSLog(@"   数据缓存: %lu", (unsigned long)dataCacheCount);
}

- (void)optimizeImageData:(YBIBImageData *)imageData imageSize:(CGSize)imageSize {
    YBIBImageSizeCategory category = [self categorizeBySizeOnly:imageSize];
    
    // 根据图片大小和设备性能配置解码策略
    switch (category) {
        case YBIBImageSizeCategorySmall:
            imageData.shouldPreDecodeAsync = YES;
            imageData.cuttingZoomScale = 6.0;
            // maxZoomScale属性在当前版本不存在
            break;
            
        case YBIBImageSizeCategoryMedium:
            imageData.shouldPreDecodeAsync = (_devicePerformanceLevel >= YBIBPerformanceLevelMedium);
            imageData.cuttingZoomScale = 4.0;
            // maxZoomScale属性在当前版本不存在
            break;
            
        case YBIBImageSizeCategoryLarge:
            imageData.shouldPreDecodeAsync = (_devicePerformanceLevel >= YBIBPerformanceLevelHigh);
            imageData.cuttingZoomScale = 3.0;
            // maxZoomScale属性在当前版本不存在
            break;
            
        case YBIBImageSizeCategoryHuge:
            imageData.shouldPreDecodeAsync = NO; // 超大图不预解码
            imageData.cuttingZoomScale = 2.0;
            // maxZoomScale属性在当前版本不存在
            break;
    }
    
    // 自定义预解码决策
    __weak typeof(imageData) weakImageData = imageData;
    imageData.preDecodeDecision = ^BOOL(YBIBImageData *data, CGSize size, CGFloat scale) {
        __strong typeof(weakImageData) strongImageData = weakImageData;
        if (!strongImageData) return NO;
        
        // 计算图片内存占用 (RGBA = 4 bytes per pixel)
        CGFloat memoryMB = (size.width * size.height * scale * scale * 4) / (1024 * 1024);
        NSUInteger availableMemory = [[YBIBPerformanceManager sharedManager] availableMemoryMB];
        
        // 如果图片占用超过可用内存的1/10，不预解码
        return memoryMB < (availableMemory / 10.0);
    };
}

- (YBIBImageSizeCategory)categorizeBySizeOnly:(CGSize)imageSize {
    CGFloat pixels = imageSize.width * imageSize.height;
    CGFloat estimatedMB = (pixels * 4) / (1024 * 1024); // RGBA
    
    if (estimatedMB < 1.0) {
        return YBIBImageSizeCategorySmall;
    } else if (estimatedMB < 5.0) {
        return YBIBImageSizeCategoryMedium;
    } else if (estimatedMB < 10.0) {
        return YBIBImageSizeCategoryLarge;
    } else {
        return YBIBImageSizeCategoryHuge;
    }
}

#pragma mark - 推荐配置计算

- (NSUInteger)recommendedPreloadCountForImageCount:(NSInteger)imageCount
                                      averageSize:(YBIBImageSizeCategory)averageSize {
    NSUInteger basePreload = 2;
    
    // 根据设备性能调整
    switch (_devicePerformanceLevel) {
        case YBIBPerformanceLevelLow:
            basePreload = 1;
            break;
        case YBIBPerformanceLevelMedium:
            basePreload = 2;
            break;
        case YBIBPerformanceLevelHigh:
            basePreload = 4;
            break;
        case YBIBPerformanceLevelUltra:
            basePreload = 6;
            break;
    }
    
    // 根据图片大小调整
    switch (averageSize) {
        case YBIBImageSizeCategorySmall:
            basePreload += 2;
            break;
        case YBIBImageSizeCategoryMedium:
            // 保持基础值
            break;
        case YBIBImageSizeCategoryLarge:
            basePreload = MAX(1, basePreload - 1);
            break;
        case YBIBImageSizeCategoryHuge:
            basePreload = MAX(1, basePreload - 2);
            break;
    }
    
    // 根据图片总数调整
    if (imageCount > 100) {
        basePreload = MAX(1, basePreload - 1);
    } else if (imageCount < 10) {
        basePreload += 1;
    }
    
    return MIN(8, basePreload); // 最大预加载8张
}

- (NSUInteger)recommendedCacheCountForImageSize:(YBIBImageSizeCategory)averageSize {
    NSUInteger baseCache = 12;
    
    // 根据设备性能调整
    switch (_devicePerformanceLevel) {
        case YBIBPerformanceLevelLow:
            baseCache = 6;
            break;
        case YBIBPerformanceLevelMedium:
            baseCache = 12;
            break;
        case YBIBPerformanceLevelHigh:
            baseCache = 20;
            break;
        case YBIBPerformanceLevelUltra:
            baseCache = 30;
            break;
    }
    
    // 根据图片大小调整
    switch (averageSize) {
        case YBIBImageSizeCategorySmall:
            baseCache += 10;
            break;
        case YBIBImageSizeCategoryMedium:
            // 保持基础值
            break;
        case YBIBImageSizeCategoryLarge:
            baseCache = MAX(3, baseCache / 2);
            break;
        case YBIBImageSizeCategoryHuge:
            baseCache = MAX(2, baseCache / 3);
            break;
    }
    
    return baseCache;
}

#pragma mark - 动态调优

- (void)startPerformanceMonitoring {
    if (self.monitoringTimer) {
        [self.monitoringTimer invalidate];
    }
    
    self.startTime = [[NSDate date] timeIntervalSince1970];
    self.monitoringTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                            target:self
                                                          selector:@selector(monitorPerformance)
                                                          userInfo:nil
                                                           repeats:YES];
}

- (void)stopPerformanceMonitoring {
    if (self.monitoringTimer) {
        [self.monitoringTimer invalidate];
        self.monitoringTimer = nil;
    }
}

- (void)monitorPerformance {
    NSUInteger availableMemory = self.availableMemoryMB;
    [self.statistics setObject:@(availableMemory) forKey:@"currentAvailableMemory"];
    
    // 如果内存不足200MB，触发内存压力处理
    if (availableMemory < 200) {
        [self handleMemoryPressure];
    }
}

- (void)handleMemoryPressure {
    NSLog(@"⚠️ 检测到内存压力，启动紧急优化...");
    
    // 通知所有YBImageBrowser实例降低缓存
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YBIBPerformanceEmergencyOptimization"
                                                        object:nil
                                                      userInfo:@{
                                                          @"recommendedCacheCount": @(3),
                                                          @"recommendedPreloadCount": @(1)
                                                      }];
}

#pragma mark - 性能统计

- (NSDictionary *)performanceStatistics {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval duration = currentTime - self.startTime;
    
    return @{
        @"devicePerformanceLevel": @(_devicePerformanceLevel),
        @"totalPhysicalMemoryMB": @(self.totalPhysicalMemoryMB),
        @"currentAvailableMemoryMB": @(self.availableMemoryMB),
        @"monitoringDuration": @(duration),
        @"imageLoadCount": @(self.imageLoadCount),
        @"cacheHitCount": @(self.cacheHitCount),
        @"cacheHitRate": self.imageLoadCount > 0 ? @((double)self.cacheHitCount / self.imageLoadCount) : @(0)
    };
}

- (void)resetStatistics {
    [self.statistics removeAllObjects];
    self.startTime = [[NSDate date] timeIntervalSince1970];
    self.imageLoadCount = 0;
    self.cacheHitCount = 0;
}

#pragma mark - Helper Methods

- (NSString *)performanceLevelString:(YBIBPerformanceLevel)level {
    switch (level) {
        case YBIBPerformanceLevelLow: return @"Low";
        case YBIBPerformanceLevelMedium: return @"Medium";
        case YBIBPerformanceLevelHigh: return @"High";
        case YBIBPerformanceLevelUltra: return @"Ultra";
    }
}

@end