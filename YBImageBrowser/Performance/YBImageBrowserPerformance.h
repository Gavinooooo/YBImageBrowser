//
//  YBImageBrowserPerformance.h
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for YBImageBrowserPerformance.
FOUNDATION_EXPORT double YBImageBrowserPerformanceVersionNumber;

//! Project version string for YBImageBrowserPerformance.
FOUNDATION_EXPORT const unsigned char YBImageBrowserPerformanceVersionString[];

// 性能优化模块统一导入头文件

// 核心管理器
#import "YBIBPerformanceManager.h"
#import "YBIBMemoryAdaptiveManager.h"
#import "YBIBPerformanceMonitor.h"

// 高级功能
#import "YBIBSmartPreloader.h"
#import "YBIBAdvancedImageCache.h"
#import "YBIBProgressiveLoader.h"

// 配置工具
#import "YBIBPerformanceConfigurator.h"