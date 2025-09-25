//
//  YBIBPerformanceMonitor.h
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class YBImageBrowser;

/**
 * 性能监控工具
 * 实时监控YBImageBrowser的各项性能指标
 */
@interface YBIBPerformanceMonitor : NSObject

+ (instancetype)sharedMonitor;

#pragma mark - 监控控制

/// 开始性能监控
- (void)startMonitoring;

/// 停止性能监控
- (void)stopMonitoring;

/// 是否正在监控
@property (nonatomic, assign, readonly) BOOL isMonitoring;

#pragma mark - 浏览器监控

/// 添加浏览器到监控列表
- (void)addBrowserToMonitor:(YBImageBrowser *)browser;

/// 从监控列表移除浏览器
- (void)removeBrowserFromMonitor:(YBImageBrowser *)browser;

#pragma mark - 性能指标记录

/// 记录图片加载开始
- (void)recordImageLoadStart:(NSString *)imageURL;

/// 记录图片加载完成
- (void)recordImageLoadComplete:(NSString *)imageURL loadTime:(NSTimeInterval)loadTime success:(BOOL)success;

/// 记录页面切换
- (void)recordPageSwitch:(NSInteger)fromPage toPage:(NSInteger)toPage switchTime:(NSTimeInterval)switchTime;

/// 记录转场动画
- (void)recordTransitionAnimation:(NSTimeInterval)duration;

/// 记录内存使用峰值
- (void)recordMemoryPeak:(NSUInteger)memoryUsageMB;

#pragma mark - 实时监控数据

/// 获取当前FPS
@property (nonatomic, assign, readonly) CGFloat currentFPS;

/// 获取CPU使用率
@property (nonatomic, assign, readonly) CGFloat cpuUsage;

/// 获取内存使用量(MB)
@property (nonatomic, assign, readonly) NSUInteger memoryUsageMB;

#pragma mark - 性能统计

/// 获取完整的性能报告
- (NSDictionary *)generatePerformanceReport;

/// 获取图片加载统计
- (NSDictionary *)imageLoadingStatistics;

/// 获取页面切换统计
- (NSDictionary *)pageSwitchStatistics;

/// 重置所有统计数据
- (void)resetStatistics;

#pragma mark - 性能分析

/// 分析当前性能状态
- (NSDictionary *)analyzePerformanceStatus;

/// 获取性能优化建议
- (NSArray<NSString *> *)performanceOptimizationSuggestions;

#pragma mark - 导出数据

/// 导出性能数据到JSON
- (NSString *)exportPerformanceDataAsJSON;

/// 导出性能数据到CSV
- (NSString *)exportPerformanceDataAsCSV;

@end

NS_ASSUME_NONNULL_END