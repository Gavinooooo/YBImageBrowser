//
//  YBIBMemoryAdaptiveManager.m
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import "YBIBMemoryAdaptiveManager.h"
#import "YBImageBrowser.h"
#import "YBIBImageCache.h"
#import "YBIBAdvancedImageCache.h"
#import <mach/mach.h>

// 优化记录
@interface YBIBOptimizationRecord : NSObject
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) YBIBMemoryPressureLevel pressureLevel;
@property (nonatomic, assign) NSUInteger memoryBeforeMB;
@property (nonatomic, assign) NSUInteger memoryAfterMB;
@property (nonatomic, strong) NSString *actionTaken;
@end

@implementation YBIBOptimizationRecord
@end

@interface YBIBMemoryAdaptiveManager ()

@property (nonatomic, assign) YBIBMemoryPressureLevel currentPressureLevel;
@property (nonatomic, strong) NSTimer *monitoringTimer;
@property (nonatomic, strong) NSHashTable<YBImageBrowser *> *registeredBrowsers;
@property (nonatomic, copy) YBIBMemoryPressureHandler pressureHandler;
@property (nonatomic, strong) NSMutableArray<YBIBOptimizationRecord *> *optimizationHistory;

// 统计数据
@property (nonatomic, assign) NSUInteger totalOptimizations;
@property (nonatomic, assign) NSUInteger totalMemoryFreedMB;
@property (nonatomic, assign) NSTimeInterval lastOptimizationTime;

@end

@implementation YBIBMemoryAdaptiveManager

+ (instancetype)sharedManager {
    static YBIBMemoryAdaptiveManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YBIBMemoryAdaptiveManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupDefaultConfiguration];
        [self setupNotifications];
    }
    return self;
}

- (void)setupDefaultConfiguration {
    _registeredBrowsers = [NSHashTable weakObjectsHashTable];
    _optimizationHistory = [NSMutableArray array];
    _currentPressureLevel = YBIBMemoryPressureLevelNormal;
    
    // 根据设备总内存设置阈值
    NSUInteger totalMemoryMB = (NSUInteger)([NSProcessInfo processInfo].physicalMemory / 1024 / 1024);
    
    if (totalMemoryMB <= 1024) {
        // 1GB及以下设备
        _warningThresholdMB = 150;
        _criticalThresholdMB = 100;
        _urgentThresholdMB = 50;
    } else if (totalMemoryMB <= 2048) {
        // 2GB设备
        _warningThresholdMB = 250;
        _criticalThresholdMB = 150;
        _urgentThresholdMB = 80;
    } else if (totalMemoryMB <= 4096) {
        // 4GB设备
        _warningThresholdMB = 400;
        _criticalThresholdMB = 250;
        _urgentThresholdMB = 150;
    } else {
        // 6GB及以上设备
        _warningThresholdMB = 600;
        _criticalThresholdMB = 400;
        _urgentThresholdMB = 250;
    }
    
    _monitoringInterval = 2.0;
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSystemMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
}

- (void)dealloc {
    [self stopMemoryMonitoring];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 内存监控

- (void)startMemoryMonitoring {
    if (_monitoringTimer) {
        [_monitoringTimer invalidate];
    }
    
    
    _monitoringTimer = [NSTimer scheduledTimerWithTimeInterval:_monitoringInterval
                                                        target:self
                                                      selector:@selector(checkMemoryStatus)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopMemoryMonitoring {
    if (_monitoringTimer) {
        [_monitoringTimer invalidate];
        _monitoringTimer = nil;
    }
}

- (void)checkMemoryStatus {
    NSUInteger availableMemory = [self availableMemoryMB];
    YBIBMemoryPressureLevel newLevel = [self calculatePressureLevel:availableMemory];
    
    if (newLevel != _currentPressureLevel) {
        YBIBMemoryPressureLevel oldLevel = _currentPressureLevel;
        _currentPressureLevel = newLevel;
        
        [self handlePressureLevelChange:newLevel];
    }
}

- (YBIBMemoryPressureLevel)calculatePressureLevel:(NSUInteger)availableMemoryMB {
    if (availableMemoryMB <= _urgentThresholdMB) {
        return YBIBMemoryPressureLevelUrgent;
    } else if (availableMemoryMB <= _criticalThresholdMB) {
        return YBIBMemoryPressureLevelCritical;
    } else if (availableMemoryMB <= _warningThresholdMB) {
        return YBIBMemoryPressureLevelWarning;
    } else {
        return YBIBMemoryPressureLevelNormal;
    }
}

- (void)handlePressureLevelChange:(YBIBMemoryPressureLevel)newLevel {
    if (newLevel > YBIBMemoryPressureLevelNormal) {
        [self optimizeForPressureLevel:newLevel];
    }
    
    if (_pressureHandler) {
        _pressureHandler(newLevel);
    }
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

- (CGFloat)memoryUsagePercentage {
    NSUInteger totalMemory = (NSUInteger)([NSProcessInfo processInfo].physicalMemory / 1024 / 1024);
    NSUInteger availableMemory = [self availableMemoryMB];
    NSUInteger usedMemory = totalMemory - availableMemory;
    
    return (CGFloat)usedMemory / totalMemory;
}

#pragma mark - 自适应策略

- (void)registerBrowser:(YBImageBrowser *)browser {
    if (!browser) return;
    
    [_registeredBrowsers addObject:browser];
}

- (void)unregisterBrowser:(YBImageBrowser *)browser {
    if (!browser) return;
    
    [_registeredBrowsers removeObject:browser];
}

- (void)optimizeMemoryUsage {
    NSUInteger memoryBefore = [self availableMemoryMB];
    [self optimizeForPressureLevel:_currentPressureLevel];
    NSUInteger memoryAfter = [self availableMemoryMB];
    
}

- (void)optimizeForPressureLevel:(YBIBMemoryPressureLevel)level {
    NSUInteger memoryBefore = [self availableMemoryMB];
    NSMutableArray *actions = [NSMutableArray array];
    
    switch (level) {
        case YBIBMemoryPressureLevelWarning:
            [self performWarningLevelOptimization:actions];
            break;
            
        case YBIBMemoryPressureLevelCritical:
            [self performWarningLevelOptimization:actions];
            [self performCriticalLevelOptimization:actions];
            break;
            
        case YBIBMemoryPressureLevelUrgent:
            [self performWarningLevelOptimization:actions];
            [self performCriticalLevelOptimization:actions];
            [self performUrgentLevelOptimization:actions];
            break;
            
        case YBIBMemoryPressureLevelNormal:
        default:
            return;
    }
    
    NSUInteger memoryAfter = [self availableMemoryMB];
    [self recordOptimization:level
                memoryBefore:memoryBefore
                 memoryAfter:memoryAfter
                     actions:actions];
    
    _totalOptimizations++;
    _totalMemoryFreedMB += (memoryAfter - memoryBefore);
    _lastOptimizationTime = [[NSDate date] timeIntervalSince1970];
}

- (void)performWarningLevelOptimization:(NSMutableArray *)actions {
    // 1. 清理高级缓存中的部分内容
    [[YBIBAdvancedImageCache sharedCache] clearMemoryCache];
    [actions addObject:@"清理高级图片缓存"];
    
    // 2. 减少所有浏览器的缓存限制
    for (YBImageBrowser *browser in _registeredBrowsers) {
        NSUInteger originalLimit = browser.ybib_imageCache.imageCacheCountLimit;
        browser.ybib_imageCache.imageCacheCountLimit = MAX(3, originalLimit / 2);
        [actions addObject:[NSString stringWithFormat:@"减少缓存限制: %lu→%lu", 
                           (unsigned long)originalLimit, 
                           (unsigned long)browser.ybib_imageCache.imageCacheCountLimit]];
    }
}

- (void)performCriticalLevelOptimization:(NSMutableArray *)actions {
    // 1. 进一步减少预加载数量
    for (YBImageBrowser *browser in _registeredBrowsers) {
        NSUInteger originalPreload = browser.preloadCount;
        browser.preloadCount = MAX(1, originalPreload / 2);
        [actions addObject:[NSString stringWithFormat:@"减少预加载: %lu→%lu", 
                           (unsigned long)originalPreload,
                           (unsigned long)browser.preloadCount]];
    }
    
    // 2. 清理磁盘缓存的部分内容
    [[YBIBAdvancedImageCache sharedCache] cleanExpiredCache];
    [actions addObject:@"清理过期磁盘缓存"];
}

- (void)performUrgentLevelOptimization:(NSMutableArray *)actions {
    // 1. 最小化缓存配置
    for (YBImageBrowser *browser in _registeredBrowsers) {
        browser.ybib_imageCache.imageCacheCountLimit = 1;
        browser.preloadCount = 0;
        [actions addObject:@"启用最小化配置"];
    }
    
    // 2. 清理所有可清理的缓存
    [[YBIBAdvancedImageCache sharedCache] clearDiskCache];
    [actions addObject:@"清理所有磁盘缓存"];
    
    // 3. 发送紧急优化通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YBIBMemoryUrgentOptimization"
                                                        object:nil];
    [actions addObject:@"发送紧急优化通知"];
}

- (void)recordOptimization:(YBIBMemoryPressureLevel)level
              memoryBefore:(NSUInteger)memoryBefore
               memoryAfter:(NSUInteger)memoryAfter
                   actions:(NSArray *)actions {
    
    YBIBOptimizationRecord *record = [[YBIBOptimizationRecord alloc] init];
    record.timestamp = [[NSDate date] timeIntervalSince1970];
    record.pressureLevel = level;
    record.memoryBeforeMB = memoryBefore;
    record.memoryAfterMB = memoryAfter;
    record.actionTaken = [actions componentsJoinedByString:@"; "];
    
    [_optimizationHistory addObject:record];
    
    // 保持历史记录不超过100条
    if (_optimizationHistory.count > 100) {
        [_optimizationHistory removeObjectAtIndex:0];
    }
}

- (void)setMemoryPressureHandler:(YBIBMemoryPressureHandler)handler {
    _pressureHandler = handler;
}

#pragma mark - 统计信息

- (NSDictionary *)memoryStatistics {
    NSUInteger currentAvailable = [self availableMemoryMB];
    CGFloat usagePercentage = [self memoryUsagePercentage];
    
    return @{
        @"currentAvailableMemoryMB": @(currentAvailable),
        @"memoryUsagePercentage": @(usagePercentage),
        @"currentPressureLevel": @(_currentPressureLevel),
        @"pressureLevelString": [self pressureLevelString:_currentPressureLevel],
        @"totalOptimizations": @(_totalOptimizations),
        @"totalMemoryFreedMB": @(_totalMemoryFreedMB),
        @"lastOptimizationTime": @(_lastOptimizationTime),
        @"registeredBrowserCount": @(_registeredBrowsers.count),
        @"warningThresholdMB": @(_warningThresholdMB),
        @"criticalThresholdMB": @(_criticalThresholdMB),
        @"urgentThresholdMB": @(_urgentThresholdMB)
    };
}

- (NSArray *)optimizationHistory {
    NSMutableArray *history = [NSMutableArray array];
    
    for (YBIBOptimizationRecord *record in _optimizationHistory) {
        NSDictionary *recordDict = @{
            @"timestamp": @(record.timestamp),
            @"pressureLevel": @(record.pressureLevel),
            @"pressureLevelString": [self pressureLevelString:record.pressureLevel],
            @"memoryBeforeMB": @(record.memoryBeforeMB),
            @"memoryAfterMB": @(record.memoryAfterMB),
            @"memoryFreedMB": @(record.memoryAfterMB - record.memoryBeforeMB),
            @"actionTaken": record.actionTaken,
            @"date": [NSDate dateWithTimeIntervalSince1970:record.timestamp]
        };
        [history addObject:recordDict];
    }
    
    return [history copy];
}

#pragma mark - 通知处理

- (void)handleSystemMemoryWarning:(NSNotification *)notification {
    
    // 强制设置为紧急级别并优化
    _currentPressureLevel = YBIBMemoryPressureLevelUrgent;
    [self optimizeForPressureLevel:YBIBMemoryPressureLevelUrgent];
}

- (void)handleAppWillTerminate:(NSNotification *)notification {
    [self stopMemoryMonitoring];
}

#pragma mark - 工具方法

- (NSString *)pressureLevelString:(YBIBMemoryPressureLevel)level {
    switch (level) {
        case YBIBMemoryPressureLevelNormal: return @"正常";
        case YBIBMemoryPressureLevelWarning: return @"警告";
        case YBIBMemoryPressureLevelCritical: return @"严重";
        case YBIBMemoryPressureLevelUrgent: return @"紧急";
    }
}

@end