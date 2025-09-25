//
//  YBIBSmartPreloader.h
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class YBImageBrowser;
@protocol YBIBDataProtocol;

typedef NS_ENUM(NSUInteger, YBIBScrollDirection) {
    YBIBScrollDirectionNone = 0,
    YBIBScrollDirectionLeft = 1,
    YBIBScrollDirectionRight = 2
};

/**
 * 智能预加载器
 * 基于用户滑动行为、网络状况、内存状态动态调整预加载策略
 */
@interface YBIBSmartPreloader : NSObject

- (instancetype)initWithBrowser:(YBImageBrowser *)browser;

#pragma mark - 预加载策略

/// 开始智能预加载
- (void)startSmartPreloading;

/// 停止智能预加载
- (void)stopSmartPreloading;

/// 根据滑动行为更新预加载策略
- (void)updateWithScrollDirection:(YBIBScrollDirection)direction
                    scrollVelocity:(CGFloat)velocity
                       currentPage:(NSInteger)currentPage;

#pragma mark - 网络自适应

/// 设置网络状态（影响预加载策略）
- (void)updateNetworkStatus:(BOOL)isWiFi isSlowNetwork:(BOOL)isSlowNetwork;

#pragma mark - 优先级预加载

/// 为指定页面设置预加载优先级
- (void)setPriority:(NSInteger)priority forPage:(NSInteger)page;

/// 立即预加载指定页面
- (void)preloadPageImmediately:(NSInteger)page;

#pragma mark - 统计信息

/// 获取预加载统计信息
- (NSDictionary *)preloadStatistics;

@end

NS_ASSUME_NONNULL_END