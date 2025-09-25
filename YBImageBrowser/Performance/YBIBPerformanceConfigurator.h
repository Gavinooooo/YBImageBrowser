//
//  YBIBPerformanceConfigurator.h
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "YBIBPerformanceManager.h"

NS_ASSUME_NONNULL_BEGIN

@class YBImageBrowser, YBIBImageData;

/**
 * 性能配置工具类
 * 提供简单易用的API来配置和优化YBImageBrowser性能
 */
@interface YBIBPerformanceConfigurator : NSObject

#pragma mark - 快速配置

/**
 * 一键性能优化 - 根据设备自动配置最佳参数
 * @param browser 图片浏览器实例
 * @param imageCount 预期图片数量
 * @param useAdvancedFeatures 是否启用高级功能(智能预加载、渐进式加载等)
 */
+ (void)optimizeBrowser:(YBImageBrowser *)browser
             imageCount:(NSInteger)imageCount
    useAdvancedFeatures:(BOOL)useAdvancedFeatures;

/**
 * 为大图浏览优化
 * @param browser 图片浏览器实例
 * @param averageImageSizeMB 平均图片大小(MB)
 */
+ (void)optimizeForLargeImages:(YBImageBrowser *)browser
             averageImageSizeMB:(CGFloat)averageImageSizeMB;

/**
 * 为多图浏览优化
 * @param browser 图片浏览器实例  
 * @param imageCount 图片总数
 */
+ (void)optimizeForManyImages:(YBImageBrowser *)browser
                   imageCount:(NSInteger)imageCount;

/**
 * 为低性能设备优化
 * @param browser 图片浏览器实例
 */
+ (void)optimizeForLowEndDevice:(YBImageBrowser *)browser;

#pragma mark - 场景化配置

/**
 * 相册浏览模式配置
 * 适用于本地相册图片浏览
 */
+ (void)configureForPhotoAlbum:(YBImageBrowser *)browser;

/**
 * 网络图片浏览模式配置
 * 适用于网络图片浏览，启用渐进式加载
 */
+ (void)configureForNetworkImages:(YBImageBrowser *)browser;

/**
 * 商品图片浏览模式配置
 * 适用于电商类应用的商品图片浏览
 */
+ (void)configureForProductImages:(YBImageBrowser *)browser;

/**
 * 社交媒体模式配置
 * 适用于朋友圈、微博等社交媒体图片浏览
 */
+ (void)configureForSocialMedia:(YBImageBrowser *)browser;

#pragma mark - 高级配置

/**
 * 自定义性能配置
 * @param browser 图片浏览器实例
 * @param config 配置字典
 */
+ (void)applyCustomConfiguration:(YBImageBrowser *)browser config:(NSDictionary *)config;

/**
 * 获取推荐配置
 * @param imageCount 图片数量
 * @param averageSize 平均图片大小类别
 * @return 推荐配置字典
 */
+ (NSDictionary *)recommendedConfigurationForImageCount:(NSInteger)imageCount
                                            averageSize:(YBIBImageSizeCategory)averageSize;

#pragma mark - 批量图片数据优化

/**
 * 批量优化图片数据
 * @param imageDatas 图片数据数组
 * @param scenario 使用场景
 */
+ (void)optimizeImageDatas:(NSArray<YBIBImageData *> *)imageDatas
               forScenario:(NSString *)scenario;

/**
 * 根据图片URL智能配置图片数据
 * @param imageData 图片数据
 * @param imageURL 图片URL
 */
+ (void)smartConfigureImageData:(YBIBImageData *)imageData withURL:(NSURL *)imageURL;

#pragma mark - 性能监控集成

/**
 * 启用完整性能监控和自动优化
 * @param browser 图片浏览器实例
 */
+ (void)enableFullPerformanceMode:(YBImageBrowser *)browser;

/**
 * 禁用性能监控
 * @param browser 图片浏览器实例  
 */
+ (void)disablePerformanceMode:(YBImageBrowser *)browser;

#pragma mark - 配置验证

/**
 * 验证当前配置是否合理
 * @param browser 图片浏览器实例
 * @return 验证结果和建议
 */
+ (NSDictionary *)validateConfiguration:(YBImageBrowser *)browser;

/**
 * 获取当前配置摘要
 * @param browser 图片浏览器实例
 * @return 配置摘要
 */
+ (NSDictionary *)getConfigurationSummary:(YBImageBrowser *)browser;

@end

NS_ASSUME_NONNULL_END