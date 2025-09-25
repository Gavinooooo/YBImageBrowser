//
//  YBIBSmartPreloader.m
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import "YBIBSmartPreloader.h"
#import "YBImageBrowser.h"
#import "YBIBDataProtocol.h"
#import "YBIBPerformanceManager.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

@interface YBIBSmartPreloader ()

@property (nonatomic, weak) YBImageBrowser *browser;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *pagePriorities;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *preloadingPages;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *preloadedPages;
@property (nonatomic, strong) dispatch_queue_t preloadQueue;
@property (nonatomic, strong) dispatch_semaphore_t concurrentSemaphore;

// 滑动行为分析
@property (nonatomic, assign) YBIBScrollDirection lastScrollDirection;
@property (nonatomic, assign) NSTimeInterval lastScrollTime;
@property (nonatomic, assign) CGFloat averageScrollVelocity;
@property (nonatomic, assign) NSInteger directionChangeCount;

// 网络状态
@property (nonatomic, assign) BOOL isWiFiConnected;
@property (nonatomic, assign) BOOL isSlowNetwork;

// 统计信息
@property (nonatomic, assign) NSUInteger totalPreloadRequests;
@property (nonatomic, assign) NSUInteger successfulPreloads;
@property (nonatomic, assign) NSUInteger cachedHits;

@end

@implementation YBIBSmartPreloader

- (instancetype)initWithBrowser:(YBImageBrowser *)browser {
    self = [super init];
    if (self) {
        _browser = browser;
        _pagePriorities = [NSMutableDictionary dictionary];
        _preloadingPages = [NSMutableSet set];
        _preloadedPages = [NSMutableSet set];
        _preloadQueue = dispatch_queue_create("com.ybib.smart_preload", DISPATCH_QUEUE_CONCURRENT);
        _concurrentSemaphore = dispatch_semaphore_create(2); // 限制最多2个并发解码
        
        [self setupNetworkMonitoring];
        [self setupMemoryNotifications];
    }
    return self;
}

- (void)dealloc {
    [self stopSmartPreloading];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupNetworkMonitoring {
    // 简化的网络监控，实际项目中可以使用 Reachability
    _isWiFiConnected = YES; // 默认假设WiFi
    _isSlowNetwork = NO;
}

- (void)setupMemoryNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
}

#pragma mark - 预加载策略

- (void)startSmartPreloading {
}

- (void)stopSmartPreloading {
    [_preloadingPages removeAllObjects];
    [_preloadedPages removeAllObjects];
    [_pagePriorities removeAllObjects];
}

- (void)updateWithScrollDirection:(YBIBScrollDirection)direction
                    scrollVelocity:(CGFloat)velocity
                       currentPage:(NSInteger)currentPage {
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    // 分析滑动行为
    if (direction != _lastScrollDirection) {
        _directionChangeCount++;
        _lastScrollDirection = direction;
    }
    
    // 更新平均滑动速度
    if (_lastScrollTime > 0) {
        // CGFloat timeDelta = currentTime - _lastScrollTime; // 暂未使用
        _averageScrollVelocity = (_averageScrollVelocity * 0.7) + (ABS(velocity) * 0.3);
    }
    _lastScrollTime = currentTime;
    
    // 根据滑动行为决定预加载策略
    [self adaptivePreloadForCurrentPage:currentPage
                              direction:direction
                               velocity:velocity];
}

- (void)adaptivePreloadForCurrentPage:(NSInteger)currentPage
                            direction:(YBIBScrollDirection)direction
                             velocity:(CGFloat)velocity {
    
    NSUInteger maxPreloadCount = [self calculateOptimalPreloadCount:velocity];
    NSArray *pagesToPreload = [self calculatePreloadPagesForCurrent:currentPage
                                                          direction:direction
                                                              count:maxPreloadCount];
    
    for (NSNumber *pageNumber in pagesToPreload) {
        NSInteger page = [pageNumber integerValue];
        if (![_preloadedPages containsObject:pageNumber] && 
            ![_preloadingPages containsObject:pageNumber]) {
            [self preloadPage:page withPriority:[self priorityForPage:page currentPage:currentPage]];
        }
    }
    
    // 清理过期的预加载
    [self cleanupDistantPreloads:currentPage];
}

- (NSUInteger)calculateOptimalPreloadCount:(CGFloat)velocity {
    YBIBPerformanceManager *manager = [YBIBPerformanceManager sharedManager];
    NSUInteger baseCount = 2;
    
    // 根据设备性能调整
    switch (manager.devicePerformanceLevel) {
        case YBIBPerformanceLevelLow:
            baseCount = 1;
            break;
        case YBIBPerformanceLevelMedium:
            baseCount = 2;
            break;
        case YBIBPerformanceLevelHigh:
            baseCount = 3;
            break;
        case YBIBPerformanceLevelUltra:
            baseCount = 4;
            break;
    }
    
    // 根据滑动速度调整
    if (velocity > 1000) {
        baseCount += 2; // 快速滑动，增加预加载
    } else if (velocity < 200) {
        baseCount = MAX(1, baseCount - 1); // 慢速滑动，减少预加载
    }
    
    // 根据网络状态调整
    if (!_isWiFiConnected || _isSlowNetwork) {
        baseCount = MAX(1, baseCount / 2);
    }
    
    // 根据可用内存调整
    NSUInteger availableMemory = manager.availableMemoryMB;
    if (availableMemory < 300) {
        baseCount = MAX(1, baseCount / 2);
    }
    
    return MIN(6, baseCount);
}

- (NSArray<NSNumber *> *)calculatePreloadPagesForCurrent:(NSInteger)currentPage
                                               direction:(YBIBScrollDirection)direction
                                                   count:(NSUInteger)count {
    NSMutableArray *pages = [NSMutableArray array];
    NSInteger totalPages = self.browser.dataSourceArray.count;
    
    if (direction == YBIBScrollDirectionRight) {
        // 向右滑动，预加载右侧页面
        for (NSInteger i = 1; i <= count; i++) {
            NSInteger targetPage = currentPage + i;
            if (targetPage < totalPages) {
                [pages addObject:@(targetPage)];
            }
        }
        // 适量预加载左侧
        NSInteger leftCount = MAX(1, count / 3);
        for (NSInteger i = 1; i <= leftCount; i++) {
            NSInteger targetPage = currentPage - i;
            if (targetPage >= 0) {
                [pages addObject:@(targetPage)];
            }
        }
    } else if (direction == YBIBScrollDirectionLeft) {
        // 向左滑动，预加载左侧页面
        for (NSInteger i = 1; i <= count; i++) {
            NSInteger targetPage = currentPage - i;
            if (targetPage >= 0) {
                [pages addObject:@(targetPage)];
            }
        }
        // 适量预加载右侧
        NSInteger rightCount = MAX(1, count / 3);
        for (NSInteger i = 1; i <= rightCount; i++) {
            NSInteger targetPage = currentPage + i;
            if (targetPage < totalPages) {
                [pages addObject:@(targetPage)];
            }
        }
    } else {
        // 无明确方向，对称预加载
        NSInteger halfCount = count / 2;
        for (NSInteger i = 1; i <= halfCount; i++) {
            NSInteger leftPage = currentPage - i;
            NSInteger rightPage = currentPage + i;
            
            if (leftPage >= 0) {
                [pages addObject:@(leftPage)];
            }
            if (rightPage < totalPages) {
                [pages addObject:@(rightPage)];
            }
        }
    }
    
    return [pages copy];
}

- (NSInteger)priorityForPage:(NSInteger)page currentPage:(NSInteger)currentPage {
    NSInteger distance = ABS(page - currentPage);
    NSNumber *customPriority = _pagePriorities[@(page)];
    
    if (customPriority) {
        return [customPriority integerValue];
    }
    
    // 距离越近优先级越高
    return 100 - (distance * 10);
}

- (void)preloadPage:(NSInteger)page withPriority:(NSInteger)priority {
    [_preloadingPages addObject:@(page)];
    _totalPreloadRequests++;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(_preloadQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // 信号量控制并发数量，避免CPU峰值
        dispatch_semaphore_wait(strongSelf.concurrentSemaphore, DISPATCH_TIME_FOREVER);
        
        // 检查数组边界
        if (page < 0 || page >= strongSelf.browser.dataSourceArray.count) {
            dispatch_semaphore_signal(strongSelf.concurrentSemaphore);
            return;
        }
        id<YBIBDataProtocol> data = strongSelf.browser.dataSourceArray[page];
        if ([data respondsToSelector:@selector(yb_preload)]) {
            [data yb_preload];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf.preloadingPages removeObject:@(page)];
                [strongSelf.preloadedPages addObject:@(page)];
                strongSelf.successfulPreloads++;
                
            });
        }
        
        // 释放信号量
        dispatch_semaphore_signal(strongSelf.concurrentSemaphore);
    });
}

- (void)cleanupDistantPreloads:(NSInteger)currentPage {
    NSInteger maxDistance = 10; // 清理距离当前页面超过10页的预加载
    
    NSMutableSet *toRemove = [NSMutableSet set];
    for (NSNumber *pageNumber in _preloadedPages) {
        NSInteger page = [pageNumber integerValue];
        if (ABS(page - currentPage) > maxDistance) {
            [toRemove addObject:pageNumber];
        }
    }
    
    [_preloadedPages minusSet:toRemove];
    
    if (toRemove.count > 0) {
    }
}

#pragma mark - 网络自适应

- (void)updateNetworkStatus:(BOOL)isWiFi isSlowNetwork:(BOOL)isSlowNetwork {
    _isWiFiConnected = isWiFi;
    _isSlowNetwork = isSlowNetwork;
}

#pragma mark - 优先级预加载

- (void)setPriority:(NSInteger)priority forPage:(NSInteger)page {
    _pagePriorities[@(page)] = @(priority);
}

- (void)preloadPageImmediately:(NSInteger)page {
    if (![_preloadedPages containsObject:@(page)] && 
        ![_preloadingPages containsObject:@(page)]) {
        [self preloadPage:page withPriority:1000]; // 最高优先级
    }
}

#pragma mark - 内存管理

- (void)handleMemoryWarning:(NSNotification *)notification {
    
    // 清理所有预加载状态
    [_preloadingPages removeAllObjects];
    [_preloadedPages removeAllObjects];
    [_pagePriorities removeAllObjects];
}

#pragma mark - 统计信息

- (NSDictionary *)preloadStatistics {
    CGFloat successRate = _totalPreloadRequests > 0 ? 
        (CGFloat)_successfulPreloads / _totalPreloadRequests : 0.0;
    
    return @{
        @"totalRequests": @(_totalPreloadRequests),
        @"successfulPreloads": @(_successfulPreloads),
        @"successRate": @(successRate),
        @"currentPreloadingCount": @(_preloadingPages.count),
        @"currentPreloadedCount": @(_preloadedPages.count),
        @"averageScrollVelocity": @(_averageScrollVelocity),
        @"directionChangeCount": @(_directionChangeCount),
        @"isWiFiConnected": @(_isWiFiConnected),
        @"isSlowNetwork": @(_isSlowNetwork)
    };
}

@end