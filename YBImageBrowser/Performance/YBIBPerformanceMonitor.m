//
//  YBIBPerformanceMonitor.m
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import "YBIBPerformanceMonitor.h"
#import "YBImageBrowser.h"
#import <mach/mach.h>
#import <sys/sysctl.h>

// 性能记录结构
@interface YBIBPerformanceRecord : NSObject
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) CGFloat fps;
@property (nonatomic, assign) CGFloat cpuUsage;
@property (nonatomic, assign) NSUInteger memoryUsage;
@end

@implementation YBIBPerformanceRecord
@end

@interface YBIBImageLoadRecord : NSObject
@property (nonatomic, strong) NSString *imageURL;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval endTime;
@property (nonatomic, assign) BOOL success;
@end

@implementation YBIBImageLoadRecord
@end

@interface YBIBPageSwitchRecord : NSObject
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) NSInteger fromPage;
@property (nonatomic, assign) NSInteger toPage;
@property (nonatomic, assign) NSTimeInterval switchTime;
@end

@implementation YBIBPageSwitchRecord
@end

@interface YBIBPerformanceMonitor ()

@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSTimer *performanceTimer;
@property (nonatomic, strong) NSHashTable<YBImageBrowser *> *monitoredBrowsers;

// 性能数据
@property (nonatomic, strong) NSMutableArray<YBIBPerformanceRecord *> *performanceRecords;
@property (nonatomic, strong) NSMutableArray<YBIBImageLoadRecord *> *imageLoadRecords;
@property (nonatomic, strong) NSMutableArray<YBIBPageSwitchRecord *> *pageSwitchRecords;
@property (nonatomic, strong) NSMutableDictionary<NSString *, YBIBImageLoadRecord *> *pendingImageLoads;

// 实时性能指标
@property (nonatomic, assign) CGFloat currentFPS;
@property (nonatomic, assign) CGFloat cpuUsage;
@property (nonatomic, assign) NSUInteger memoryUsageMB;

// FPS计算
@property (nonatomic, assign) NSTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;

// 统计数据
@property (nonatomic, assign) NSTimeInterval monitoringStartTime;
@property (nonatomic, assign) NSUInteger totalImageLoads;
@property (nonatomic, assign) NSUInteger successfulImageLoads;
@property (nonatomic, assign) NSUInteger totalPageSwitches;
@property (nonatomic, assign) NSTimeInterval totalLoadTime;
@property (nonatomic, assign) NSTimeInterval totalSwitchTime;

@end

@implementation YBIBPerformanceMonitor

+ (instancetype)sharedMonitor {
    static YBIBPerformanceMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YBIBPerformanceMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupMonitor];
    }
    return self;
}

- (void)setupMonitor {
    _monitoredBrowsers = [NSHashTable weakObjectsHashTable];
    _performanceRecords = [NSMutableArray array];
    _imageLoadRecords = [NSMutableArray array];
    _pageSwitchRecords = [NSMutableArray array];
    _pendingImageLoads = [NSMutableDictionary dictionary];
    _isMonitoring = NO;
}

- (void)dealloc {
    [self stopMonitoring];
}

#pragma mark - 监控控制

- (void)startMonitoring {
    if (_isMonitoring) return;
    
    _isMonitoring = YES;
    _monitoringStartTime = [[NSDate date] timeIntervalSince1970];
    
    // 启动FPS监控
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTick:)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    // 启动性能数据收集
    _performanceTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(collectPerformanceData)
                                                       userInfo:nil
                                                        repeats:YES];
    
    NSLog(@"📊 性能监控已启动");
}

- (void)stopMonitoring {
    if (!_isMonitoring) return;
    
    _isMonitoring = NO;
    
    if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    
    if (_performanceTimer) {
        [_performanceTimer invalidate];
        _performanceTimer = nil;
    }
    
    NSLog(@"📊 性能监控已停止");
}

#pragma mark - 浏览器监控

- (void)addBrowserToMonitor:(YBImageBrowser *)browser {
    if (!browser) return;
    
    [_monitoredBrowsers addObject:browser];
    NSLog(@"📝 添加浏览器到性能监控，当前总数: %lu", (unsigned long)_monitoredBrowsers.count);
}

- (void)removeBrowserFromMonitor:(YBImageBrowser *)browser {
    if (!browser) return;
    
    [_monitoredBrowsers removeObject:browser];
    NSLog(@"📝 从性能监控移除浏览器，当前总数: %lu", (unsigned long)_monitoredBrowsers.count);
}

#pragma mark - 性能指标记录

- (void)recordImageLoadStart:(NSString *)imageURL {
    if (!imageURL || !_isMonitoring) return;
    
    YBIBImageLoadRecord *record = [[YBIBImageLoadRecord alloc] init];
    record.imageURL = imageURL;
    record.startTime = [[NSDate date] timeIntervalSince1970];
    
    _pendingImageLoads[imageURL] = record;
}

- (void)recordImageLoadComplete:(NSString *)imageURL loadTime:(NSTimeInterval)loadTime success:(BOOL)success {
    if (!imageURL || !_isMonitoring) return;
    
    YBIBImageLoadRecord *record = _pendingImageLoads[imageURL];
    if (record) {
        record.endTime = record.startTime + loadTime;
        record.success = success;
        
        [_imageLoadRecords addObject:record];
        [_pendingImageLoads removeObjectForKey:imageURL];
        
        _totalImageLoads++;
        if (success) {
            _successfulImageLoads++;
            _totalLoadTime += loadTime;
        }
        
        // 保持记录数量在合理范围
        if (_imageLoadRecords.count > 1000) {
            [_imageLoadRecords removeObjectAtIndex:0];
        }
    }
}

- (void)recordPageSwitch:(NSInteger)fromPage toPage:(NSInteger)toPage switchTime:(NSTimeInterval)switchTime {
    if (!_isMonitoring) return;
    
    YBIBPageSwitchRecord *record = [[YBIBPageSwitchRecord alloc] init];
    record.timestamp = [[NSDate date] timeIntervalSince1970];
    record.fromPage = fromPage;
    record.toPage = toPage;
    record.switchTime = switchTime;
    
    [_pageSwitchRecords addObject:record];
    
    _totalPageSwitches++;
    _totalSwitchTime += switchTime;
    
    // 保持记录数量在合理范围
    if (_pageSwitchRecords.count > 500) {
        [_pageSwitchRecords removeObjectAtIndex:0];
    }
}

- (void)recordTransitionAnimation:(NSTimeInterval)duration {
    // 可以扩展为动画性能记录
    NSLog(@"🎬 转场动画耗时: %.3fs", duration);
}

- (void)recordMemoryPeak:(NSUInteger)memoryUsageMB {
    NSLog(@"📈 内存使用峰值: %luMB", (unsigned long)memoryUsageMB);
}

#pragma mark - 实时监控

- (void)displayLinkTick:(CADisplayLink *)displayLink {
    if (_lastTimestamp <= 0) {
        _lastTimestamp = displayLink.timestamp;
        return;
    }
    
    _frameCount++;
    
    NSTimeInterval deltaTime = displayLink.timestamp - _lastTimestamp;
    if (deltaTime >= 1.0) {
        _currentFPS = _frameCount / deltaTime;
        _frameCount = 0;
        _lastTimestamp = displayLink.timestamp;
    }
}

- (void)collectPerformanceData {
    if (!_isMonitoring) return;
    
    // 更新CPU和内存使用率
    _cpuUsage = [self getCurrentCPUUsage];
    _memoryUsageMB = [self getCurrentMemoryUsage];
    
    // 记录性能快照
    YBIBPerformanceRecord *record = [[YBIBPerformanceRecord alloc] init];
    record.timestamp = [[NSDate date] timeIntervalSince1970];
    record.fps = _currentFPS;
    record.cpuUsage = _cpuUsage;
    record.memoryUsage = _memoryUsageMB;
    
    [_performanceRecords addObject:record];
    
    // 保持记录数量在合理范围
    if (_performanceRecords.count > 300) { // 5分钟数据
        [_performanceRecords removeObjectAtIndex:0];
    }
}

- (CGFloat)getCurrentCPUUsage {
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return 0.0;
    }
    
    thread_array_t thread_list;
    mach_msg_type_number_t thread_count;
    
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return 0.0;
    }
    
    float tot_cpu = 0;
    for (int j = 0; j < thread_count; j++) {
        thread_info_data_t thinfo;
        mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO, (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            continue;
        }
        
        thread_basic_info_t basic_info_th = (thread_basic_info_t)thinfo;
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_cpu += basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }
    }
    
    vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    
    return tot_cpu;
}

- (NSUInteger)getCurrentMemoryUsage {
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    if (kerr == KERN_SUCCESS) {
        return (NSUInteger)(info.resident_size / 1024 / 1024);
    }
    return 0;
}

#pragma mark - 性能统计

- (NSDictionary *)generatePerformanceReport {
    NSTimeInterval monitoringDuration = [[NSDate date] timeIntervalSince1970] - _monitoringStartTime;
    
    // 计算平均值
    CGFloat avgFPS = [self calculateAverageFPS];
    CGFloat avgCPU = [self calculateAverageCPU];
    NSUInteger avgMemory = [self calculateAverageMemory];
    CGFloat avgLoadTime = _totalImageLoads > 0 ? _totalLoadTime / _successfulImageLoads : 0;
    CGFloat avgSwitchTime = _totalPageSwitches > 0 ? _totalSwitchTime / _totalPageSwitches : 0;
    
    return @{
        @"monitoringDuration": @(monitoringDuration),
        @"currentMetrics": @{
            @"fps": @(_currentFPS),
            @"cpuUsage": @(_cpuUsage),
            @"memoryUsageMB": @(_memoryUsageMB)
        },
        @"averageMetrics": @{
            @"fps": @(avgFPS),
            @"cpuUsage": @(avgCPU),
            @"memoryUsageMB": @(avgMemory)
        },
        @"imageLoading": @{
            @"totalLoads": @(_totalImageLoads),
            @"successfulLoads": @(_successfulImageLoads),
            @"successRate": @(_totalImageLoads > 0 ? (CGFloat)_successfulImageLoads / _totalImageLoads : 0),
            @"averageLoadTime": @(avgLoadTime)
        },
        @"pageSwitching": @{
            @"totalSwitches": @(_totalPageSwitches),
            @"averageSwitchTime": @(avgSwitchTime)
        },
        @"monitoredBrowserCount": @(_monitoredBrowsers.count)
    };
}

- (NSDictionary *)imageLoadingStatistics {
    if (_imageLoadRecords.count == 0) {
        return @{@"message": @"暂无图片加载数据"};
    }
    
    NSTimeInterval minLoadTime = CGFLOAT_MAX;
    NSTimeInterval maxLoadTime = 0;
    NSTimeInterval totalTime = 0;
    NSUInteger successCount = 0;
    
    for (YBIBImageLoadRecord *record in _imageLoadRecords) {
        if (record.success) {
            NSTimeInterval loadTime = record.endTime - record.startTime;
            minLoadTime = MIN(minLoadTime, loadTime);
            maxLoadTime = MAX(maxLoadTime, loadTime);
            totalTime += loadTime;
            successCount++;
        }
    }
    
    return @{
        @"totalRecords": @(_imageLoadRecords.count),
        @"successfulLoads": @(successCount),
        @"failedLoads": @(_imageLoadRecords.count - successCount),
        @"successRate": @(_imageLoadRecords.count > 0 ? (CGFloat)successCount / _imageLoadRecords.count : 0),
        @"minLoadTime": @(minLoadTime == CGFLOAT_MAX ? 0 : minLoadTime),
        @"maxLoadTime": @(maxLoadTime),
        @"averageLoadTime": @(successCount > 0 ? totalTime / successCount : 0)
    };
}

- (NSDictionary *)pageSwitchStatistics {
    if (_pageSwitchRecords.count == 0) {
        return @{@"message": @"暂无页面切换数据"};
    }
    
    NSTimeInterval minSwitchTime = CGFLOAT_MAX;
    NSTimeInterval maxSwitchTime = 0;
    NSTimeInterval totalTime = 0;
    
    for (YBIBPageSwitchRecord *record in _pageSwitchRecords) {
        minSwitchTime = MIN(minSwitchTime, record.switchTime);
        maxSwitchTime = MAX(maxSwitchTime, record.switchTime);
        totalTime += record.switchTime;
    }
    
    return @{
        @"totalSwitches": @(_pageSwitchRecords.count),
        @"minSwitchTime": @(minSwitchTime == CGFLOAT_MAX ? 0 : minSwitchTime),
        @"maxSwitchTime": @(maxSwitchTime),
        @"averageSwitchTime": @(_pageSwitchRecords.count > 0 ? totalTime / _pageSwitchRecords.count : 0)
    };
}

- (void)resetStatistics {
    [_performanceRecords removeAllObjects];
    [_imageLoadRecords removeAllObjects];
    [_pageSwitchRecords removeAllObjects];
    [_pendingImageLoads removeAllObjects];
    
    _totalImageLoads = 0;
    _successfulImageLoads = 0;
    _totalPageSwitches = 0;
    _totalLoadTime = 0;
    _totalSwitchTime = 0;
    _monitoringStartTime = [[NSDate date] timeIntervalSince1970];
    
    NSLog(@"📊 性能统计数据已重置");
}

#pragma mark - 性能分析

- (NSDictionary *)analyzePerformanceStatus {
    NSMutableArray *issues = [NSMutableArray array];
    NSMutableArray *suggestions = [NSMutableArray array];
    
    // 分析FPS
    CGFloat avgFPS = [self calculateAverageFPS];
    if (avgFPS < 45) {
        [issues addObject:@"FPS过低"];
        [suggestions addObject:@"考虑减少预加载数量或优化图片解码"];
    }
    
    // 分析CPU使用率
    CGFloat avgCPU = [self calculateAverageCPU];
    if (avgCPU > 50) {
        [issues addObject:@"CPU使用率过高"];
        [suggestions addObject:@"减少并发处理或优化算法"];
    }
    
    // 分析内存使用
    if (_memoryUsageMB > 200) {
        [issues addObject:@"内存使用过多"];
        [suggestions addObject:@"减少缓存数量或启用内存压缩"];
    }
    
    // 分析加载时间
    CGFloat avgLoadTime = _successfulImageLoads > 0 ? _totalLoadTime / _successfulImageLoads : 0;
    if (avgLoadTime > 2.0) {
        [issues addObject:@"图片加载速度慢"];
        [suggestions addObject:@"启用渐进式加载或优化网络请求"];
    }
    
    return @{
        @"performanceScore": @([self calculatePerformanceScore]),
        @"issues": [issues copy],
        @"suggestions": [suggestions copy],
        @"status": issues.count == 0 ? @"良好" : @"需要优化"
    };
}

- (NSArray<NSString *> *)performanceOptimizationSuggestions {
    NSMutableArray *suggestions = [NSMutableArray array];
    
    CGFloat avgFPS = [self calculateAverageFPS];
    CGFloat avgCPU = [self calculateAverageCPU];
    NSUInteger avgMemory = [self calculateAverageMemory];
    
    if (avgFPS < 50) {
        [suggestions addObject:@"降低预加载数量以提高FPS"];
        [suggestions addObject:@"启用图片压缩以减少内存占用"];
    }
    
    if (avgCPU > 40) {
        [suggestions addObject:@"减少同时解码的图片数量"];
        [suggestions addObject:@"使用异步图片处理"];
    }
    
    if (avgMemory > 150) {
        [suggestions addObject:@"启用内存自适应管理"];
        [suggestions addObject:@"增加缓存清理频率"];
    }
    
    CGFloat successRate = _totalImageLoads > 0 ? (CGFloat)_successfulImageLoads / _totalImageLoads : 1.0;
    if (successRate < 0.9) {
        [suggestions addObject:@"检查网络连接和重试机制"];
        [suggestions addObject:@"增加网络超时时间"];
    }
    
    if (suggestions.count == 0) {
        [suggestions addObject:@"当前性能表现良好，建议保持现有配置"];
    }
    
    return [suggestions copy];
}

#pragma mark - 导出数据

- (NSString *)exportPerformanceDataAsJSON {
    NSDictionary *data = @{
        @"performanceReport": [self generatePerformanceReport],
        @"imageLoadingStats": [self imageLoadingStatistics],
        @"pageSwitchStats": [self pageSwitchStatistics],
        @"performanceAnalysis": [self analyzePerformanceStatus],
        @"exportTime": @([[NSDate date] timeIntervalSince1970])
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (error) {
        NSLog(@"❌ JSON导出失败: %@", error.localizedDescription);
        return nil;
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)exportPerformanceDataAsCSV {
    NSMutableString *csv = [NSMutableString string];
    
    // CSV Header
    [csv appendString:@"Timestamp,FPS,CPU Usage,Memory Usage MB\n"];
    
    // Performance Records
    for (YBIBPerformanceRecord *record in _performanceRecords) {
        [csv appendFormat:@"%.3f,%.2f,%.2f,%lu\n",
         record.timestamp, record.fps, record.cpuUsage, (unsigned long)record.memoryUsage];
    }
    
    return [csv copy];
}

#pragma mark - 辅助方法

- (CGFloat)calculateAverageFPS {
    if (_performanceRecords.count == 0) return 0;
    
    CGFloat total = 0;
    for (YBIBPerformanceRecord *record in _performanceRecords) {
        total += record.fps;
    }
    return total / _performanceRecords.count;
}

- (CGFloat)calculateAverageCPU {
    if (_performanceRecords.count == 0) return 0;
    
    CGFloat total = 0;
    for (YBIBPerformanceRecord *record in _performanceRecords) {
        total += record.cpuUsage;
    }
    return total / _performanceRecords.count;
}

- (NSUInteger)calculateAverageMemory {
    if (_performanceRecords.count == 0) return 0;
    
    NSUInteger total = 0;
    for (YBIBPerformanceRecord *record in _performanceRecords) {
        total += record.memoryUsage;
    }
    return total / _performanceRecords.count;
}

- (CGFloat)calculatePerformanceScore {
    CGFloat avgFPS = [self calculateAverageFPS];
    CGFloat avgCPU = [self calculateAverageCPU];
    NSUInteger avgMemory = [self calculateAverageMemory];
    
    CGFloat fpsScore = MIN(100, (avgFPS / 60.0) * 100);
    CGFloat cpuScore = MAX(0, 100 - avgCPU);
    CGFloat memoryScore = MAX(0, 100 - (avgMemory / 3.0)); // 假设300MB为满分
    
    return (fpsScore + cpuScore + memoryScore) / 3.0;
}

@end