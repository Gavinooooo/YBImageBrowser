//
//  YBIBMemoryAdaptiveManager.h
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class YBImageBrowser;

typedef NS_ENUM(NSUInteger, YBIBMemoryPressureLevel) {
    YBIBMemoryPressureLevelNormal = 0,    // 内存正常
    YBIBMemoryPressureLevelWarning = 1,   // 内存警告
    YBIBMemoryPressureLevelCritical = 2,  // 内存严重不足
    YBIBMemoryPressureLevelUrgent = 3     // 内存紧急状态
};

typedef void(^YBIBMemoryPressureHandler)(YBIBMemoryPressureLevel level);

/**
 * 内存自适应管理器
 * 实时监控系统内存状态，动态调整YBImageBrowser的内存策略
 */
@interface YBIBMemoryAdaptiveManager : NSObject

+ (instancetype)sharedManager;

#pragma mark - 内存监控

/// 当前内存压力等级
@property (nonatomic, assign, readonly) YBIBMemoryPressureLevel currentPressureLevel;

/// 开始内存监控
- (void)startMemoryMonitoring;

/// 停止内存监控
- (void)stopMemoryMonitoring;

/// 获取当前可用内存（MB）
- (NSUInteger)availableMemoryMB;

/// 获取当前内存使用率（0.0-1.0）
- (CGFloat)memoryUsagePercentage;

#pragma mark - 自适应策略

/// 注册YBImageBrowser实例进行自适应管理
- (void)registerBrowser:(YBImageBrowser *)browser;

/// 注销YBImageBrowser实例
- (void)unregisterBrowser:(YBImageBrowser *)browser;

/// 手动触发内存优化
- (void)optimizeMemoryUsage;

/// 设置内存压力处理器
- (void)setMemoryPressureHandler:(YBIBMemoryPressureHandler)handler;

#pragma mark - 配置策略

/// 内存警告阈值（MB），低于此值触发警告级别优化
@property (nonatomic, assign) NSUInteger warningThresholdMB;

/// 内存严重不足阈值（MB），低于此值触发严重级别优化
@property (nonatomic, assign) NSUInteger criticalThresholdMB;

/// 内存紧急阈值（MB），低于此值触发紧急级别优化
@property (nonatomic, assign) NSUInteger urgentThresholdMB;

/// 监控频率（秒），默认2秒
@property (nonatomic, assign) NSTimeInterval monitoringInterval;

#pragma mark - 统计信息

/// 获取内存管理统计信息
- (NSDictionary *)memoryStatistics;

/// 获取优化历史记录
- (NSArray *)optimizationHistory;

@end

NS_ASSUME_NONNULL_END