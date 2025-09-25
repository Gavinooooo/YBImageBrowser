//
//  YBIBAdvancedImageCache.m
//  YBImageBrowser
//
//  Created by Performance Optimizer
//  Copyright © 2024 YBImageBrowser. All rights reserved.
//

#import "YBIBAdvancedImageCache.h"
#import "YBIBPerformanceManager.h"
#import <CommonCrypto/CommonDigest.h>

// 缓存项结构
@interface YBIBCacheItem : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) NSTimeInterval accessTime;
@property (nonatomic, assign) NSUInteger accessCount;
@property (nonatomic, assign) NSUInteger memorySize;
@property (nonatomic, assign) YBIBImageCompressionLevel compressionLevel;
@end

@implementation YBIBCacheItem
@end

@interface YBIBAdvancedImageCache ()

// 内存缓存 - 使用LRU策略
@property (nonatomic, strong) NSMutableDictionary<NSString *, YBIBCacheItem *> *memoryCache;
@property (nonatomic, strong) NSMutableArray<NSString *> *accessOrder;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;
@property (nonatomic, strong) dispatch_queue_t diskQueue;

// 磁盘缓存路径
@property (nonatomic, strong) NSString *diskCachePath;

// 缓存统计
@property (nonatomic, assign) NSUInteger totalMemoryUsage;
@property (nonatomic, assign) NSUInteger hitCount;
@property (nonatomic, assign) NSUInteger missCount;
@property (nonatomic, assign) NSUInteger diskHitCount;

@end

@implementation YBIBAdvancedImageCache

+ (instancetype)sharedCache {
    static YBIBAdvancedImageCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YBIBAdvancedImageCache alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupCache];
        [self setupNotifications];
    }
    return self;
}

- (void)setupCache {
    _memoryCache = [NSMutableDictionary dictionary];
    _accessOrder = [NSMutableArray array];
    _cacheQueue = dispatch_queue_create("com.ybib.advanced_cache", DISPATCH_QUEUE_CONCURRENT);
    _diskQueue = dispatch_queue_create("com.ybib.disk_cache", DISPATCH_QUEUE_SERIAL);
    
    // 根据设备性能设置默认配置
    YBIBPerformanceManager *manager = [YBIBPerformanceManager sharedManager];
    switch (manager.devicePerformanceLevel) {
        case YBIBPerformanceLevelLow:
            _maxMemoryCacheSizeMB = 50;
            _maxDiskCacheSizeMB = 200;
            break;
        case YBIBPerformanceLevelMedium:
            _maxMemoryCacheSizeMB = 100;
            _maxDiskCacheSizeMB = 500;
            break;
        case YBIBPerformanceLevelHigh:
            _maxMemoryCacheSizeMB = 200;
            _maxDiskCacheSizeMB = 1000;
            break;
        case YBIBPerformanceLevelUltra:
            _maxMemoryCacheSizeMB = 300;
            _maxDiskCacheSizeMB = 2000;
            break;
    }
    
    _memoryPressureThresholdMB = 100;
    
    // 设置磁盘缓存路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    _diskCachePath = [[paths firstObject] stringByAppendingPathComponent:@"YBIBAdvancedCache"];
    [[NSFileManager defaultManager] createDirectoryAtPath:_diskCachePath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 图片缓存操作

- (void)storeImage:(UIImage *)image
            forKey:(NSString *)key
  compressionLevel:(YBIBImageCompressionLevel)compressionLevel
            toDisk:(BOOL)toDisk {
    
    if (!image || !key) return;
    
    dispatch_barrier_async(_cacheQueue, ^{
        // 应用压缩
        UIImage *processedImage = [self compressImage:image level:compressionLevel];
        
        // 创建缓存项
        YBIBCacheItem *item = [[YBIBCacheItem alloc] init];
        item.image = processedImage;
        item.accessTime = [[NSDate date] timeIntervalSince1970];
        item.accessCount = 1;
        item.compressionLevel = compressionLevel;
        item.memorySize = [self estimateImageMemorySize:processedImage];
        
        // 存储到内存缓存
        [self.memoryCache setObject:item forKey:key];
        [self updateAccessOrder:key];
        
        self.totalMemoryUsage += item.memorySize;
        
        // 检查内存限制
        [self enforceMemoryLimit];
        
        // 异步写入磁盘
        if (toDisk) {
            dispatch_async(self.diskQueue, ^{
                [self saveToDisk:processedImage forKey:key compressionLevel:compressionLevel];
            });
        }
        
        NSLog(@"💾 图片已缓存: %@ (压缩等级:%lu, 内存:%luKB)", 
              key, (unsigned long)compressionLevel, (unsigned long)(item.memorySize/1024));
    });
}

- (void)imageForKey:(NSString *)key
         completion:(void(^)(UIImage * _Nullable image, BOOL fromMemory))completion {
    
    if (!key || !completion) return;
    
    dispatch_async(_cacheQueue, ^{
        // 先查内存缓存
        YBIBCacheItem *item = self.memoryCache[key];
        if (item) {
            item.accessTime = [[NSDate date] timeIntervalSince1970];
            item.accessCount++;
            [self updateAccessOrder:key];
            
            self.hitCount++;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(item.image, YES);
            });
            return;
        }
        
        // 查磁盘缓存
        dispatch_async(self.diskQueue, ^{
            UIImage *diskImage = [self loadFromDisk:key];
            if (diskImage) {
                self.diskHitCount++;
                
                // 将磁盘图片加载到内存
                dispatch_barrier_async(self.cacheQueue, ^{
                    YBIBCacheItem *diskItem = [[YBIBCacheItem alloc] init];
                    diskItem.image = diskImage;
                    diskItem.accessTime = [[NSDate date] timeIntervalSince1970];
                    diskItem.accessCount = 1;
                    diskItem.memorySize = [self estimateImageMemorySize:diskImage];
                    
                    [self.memoryCache setObject:diskItem forKey:key];
                    [self updateAccessOrder:key];
                    self.totalMemoryUsage += diskItem.memorySize;
                    [self enforceMemoryLimit];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(diskImage, NO);
                    });
                });
            } else {
                self.missCount++;
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, NO);
                });
            }
        });
    });
}

- (void)decodeAndCacheImageData:(NSData *)imageData
                         forKey:(NSString *)key
                       strategy:(YBIBImageDecodeStrategy)strategy
                     completion:(void(^)(UIImage * _Nullable image))completion {
    
    if (!imageData || !key || !completion) return;
    
    // 根据策略决定解码方式
    dispatch_queue_t decodeQueue;
    switch (strategy) {
        case YBIBImageDecodeStrategyImmediate:
            decodeQueue = dispatch_get_main_queue();
            break;
        case YBIBImageDecodeStrategyLazy:
        case YBIBImageDecodeStrategyAuto:
            decodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            break;
        case YBIBImageDecodeStrategyNever:
            // 直接创建图片不解码
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *image = [UIImage imageWithData:imageData];
                completion(image);
            });
            return;
    }
    
    dispatch_async(decodeQueue, ^{
        // 创建并解码图片
        UIImage *image = [UIImage imageWithData:imageData];
        if (image) {
            // 强制解码
            UIImage *decodedImage = [self forceDecodeImage:image];
            
            // 自动选择压缩等级
            YBIBImageCompressionLevel compression = [self recommendedCompressionLevel:decodedImage.size];
            
            // 缓存图片
            [self storeImage:decodedImage
                      forKey:key
            compressionLevel:compression
                      toDisk:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(decodedImage);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    });
}

#pragma mark - 内存管理

- (void)updateAccessOrder:(NSString *)key {
    [_accessOrder removeObject:key];
    [_accessOrder addObject:key];
}

- (void)enforceMemoryLimit {
    NSUInteger limitBytes = _maxMemoryCacheSizeMB * 1024 * 1024;
    
    while (_totalMemoryUsage > limitBytes && _memoryCache.count > 0) {
        // 移除最久未使用的项目 (LRU)
        NSString *oldestKey = _accessOrder.firstObject;
        if (oldestKey) {
            YBIBCacheItem *item = _memoryCache[oldestKey];
            if (item) {
                _totalMemoryUsage -= item.memorySize;
            }
            [_memoryCache removeObjectForKey:oldestKey];
            [_accessOrder removeObject:oldestKey];
        } else {
            break;
        }
    }
}

- (UIImage *)forceDecodeImage:(UIImage *)image {
    if (!image) return nil;
    
    // 创建图形上下文强制解码
    CGImageRef imageRef = image.CGImage;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 CGImageGetWidth(imageRef),
                                                 CGImageGetHeight(imageRef),
                                                 8,
                                                 CGImageGetWidth(imageRef) * 4,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    
    if (context) {
        CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef)), imageRef);
        CGImageRef decodedImageRef = CGBitmapContextCreateImage(context);
        
        UIImage *decodedImage = [UIImage imageWithCGImage:decodedImageRef scale:image.scale orientation:image.imageOrientation];
        
        CGContextRelease(context);
        CGImageRelease(decodedImageRef);
        CGColorSpaceRelease(colorSpace);
        
        return decodedImage;
    }
    
    return image;
}

- (NSUInteger)estimateImageMemorySize:(UIImage *)image {
    if (!image || !image.CGImage) return 0;
    
    CGImageRef imageRef = image.CGImage;
    return CGImageGetWidth(imageRef) * CGImageGetHeight(imageRef) * 4; // RGBA
}

- (void)clearMemoryCache {
    dispatch_barrier_async(_cacheQueue, ^{
        [self.memoryCache removeAllObjects];
        [self.accessOrder removeAllObjects];
        self.totalMemoryUsage = 0;
        NSLog(@"🧹 内存缓存已清理");
    });
}

- (void)clearDiskCache {
    dispatch_async(_diskQueue, ^{
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:self.diskCachePath error:&error];
        [[NSFileManager defaultManager] createDirectoryAtPath:self.diskCachePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        NSLog(@"🧹 磁盘缓存已清理");
    });
}

- (void)cleanExpiredCache {
    // 清理7天前的磁盘缓存
    NSTimeInterval expireTime = 7 * 24 * 60 * 60; // 7天
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    dispatch_async(_diskQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:self.diskCachePath error:nil];
        
        for (NSString *filename in contents) {
            NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:filename];
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
            NSTimeInterval fileTime = [attributes.fileCreationDate timeIntervalSince1970];
            
            if (now - fileTime > expireTime) {
                [fileManager removeItemAtPath:filePath error:nil];
            }
        }
    });
}

#pragma mark - 磁盘缓存操作

- (void)saveToDisk:(UIImage *)image forKey:(NSString *)key compressionLevel:(YBIBImageCompressionLevel)compressionLevel {
    if (!image || !key) return;
    
    NSString *filename = [self filenameForKey:key];
    NSString *filePath = [_diskCachePath stringByAppendingPathComponent:filename];
    
    // 根据压缩级别选择保存格式和质量
    NSData *imageData;
    if (compressionLevel == YBIBImageCompressionLevelNone) {
        imageData = UIImagePNGRepresentation(image);
    } else {
        CGFloat quality = 1.0;
        switch (compressionLevel) {
            case YBIBImageCompressionLevelLight: quality = 0.8; break;
            case YBIBImageCompressionLevelMedium: quality = 0.6; break;
            case YBIBImageCompressionLevelHeavy: quality = 0.4; break;
            default: quality = 0.8; break;
        }
        imageData = UIImageJPEGRepresentation(image, quality);
    }
    
    [imageData writeToFile:filePath atomically:YES];
}

- (UIImage *)loadFromDisk:(NSString *)key {
    NSString *filename = [self filenameForKey:key];
    NSString *filePath = [_diskCachePath stringByAppendingPathComponent:filename];
    
    NSData *imageData = [NSData dataWithContentsOfFile:filePath];
    return imageData ? [UIImage imageWithData:imageData] : nil;
}

- (NSString *)filenameForKey:(NSString *)key {
    // 使用MD5生成文件名
    const char *cStr = [key UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return [output stringByAppendingString:@".jpg"];
}

#pragma mark - 智能压缩

- (YBIBImageCompressionLevel)recommendedCompressionLevel:(CGSize)imageSize {
    CGFloat pixels = imageSize.width * imageSize.height;
    CGFloat estimatedMB = (pixels * 4) / (1024 * 1024);
    
    YBIBPerformanceManager *manager = [YBIBPerformanceManager sharedManager];
    NSUInteger availableMemory = manager.availableMemoryMB;
    
    // 根据图片大小和可用内存选择压缩级别
    if (estimatedMB < 2 && availableMemory > 500) {
        return YBIBImageCompressionLevelNone;
    } else if (estimatedMB < 5 && availableMemory > 300) {
        return YBIBImageCompressionLevelLight;
    } else if (estimatedMB < 10 && availableMemory > 200) {
        return YBIBImageCompressionLevelMedium;
    } else {
        return YBIBImageCompressionLevelHeavy;
    }
}

- (UIImage *)compressImage:(UIImage *)image level:(YBIBImageCompressionLevel)level {
    if (!image || level == YBIBImageCompressionLevelNone) return image;
    
    CGSize originalSize = image.size;
    CGSize targetSize = originalSize;
    CGFloat quality = 1.0;
    
    switch (level) {
        case YBIBImageCompressionLevelLight:
            if (originalSize.width > 2048 || originalSize.height > 2048) {
                CGFloat scale = 2048.0 / MAX(originalSize.width, originalSize.height);
                targetSize = CGSizeMake(originalSize.width * scale, originalSize.height * scale);
            }
            quality = 0.8;
            break;
            
        case YBIBImageCompressionLevelMedium:
            if (originalSize.width > 1536 || originalSize.height > 1536) {
                CGFloat scale = 1536.0 / MAX(originalSize.width, originalSize.height);
                targetSize = CGSizeMake(originalSize.width * scale, originalSize.height * scale);
            }
            quality = 0.6;
            break;
            
        case YBIBImageCompressionLevelHeavy:
            if (originalSize.width > 1024 || originalSize.height > 1024) {
                CGFloat scale = 1024.0 / MAX(originalSize.width, originalSize.height);
                targetSize = CGSizeMake(originalSize.width * scale, originalSize.height * scale);
            }
            quality = 0.4;
            break;
            
        default:
            return image;
    }
    
    // 重绘图片到新尺寸
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resizedImage ?: image;
}

#pragma mark - 统计信息

- (NSDictionary *)cacheStatistics {
    __block NSDictionary *stats;
    dispatch_sync(_cacheQueue, ^{
        NSUInteger totalRequests = self.hitCount + self.missCount;
        CGFloat memoryHitRate = totalRequests > 0 ? (CGFloat)self.hitCount / totalRequests : 0.0;
        CGFloat diskHitRate = totalRequests > 0 ? (CGFloat)self.diskHitCount / totalRequests : 0.0;
        
        stats = @{
            @"memoryItemCount": @(self.memoryCache.count),
            @"totalMemoryUsageMB": @(self.totalMemoryUsage / (1024 * 1024)),
            @"maxMemoryCacheSizeMB": @(self.maxMemoryCacheSizeMB),
            @"memoryUsagePercent": @((CGFloat)self.totalMemoryUsage / (self.maxMemoryCacheSizeMB * 1024 * 1024)),
            @"totalHits": @(self.hitCount),
            @"totalMisses": @(self.missCount),
            @"diskHits": @(self.diskHitCount),
            @"memoryHitRate": @(memoryHitRate),
            @"diskHitRate": @(diskHitRate)
        };
    });
    return stats;
}

#pragma mark - 通知处理

- (void)handleMemoryWarning:(NSNotification *)notification {
    NSLog(@"⚠️ 收到内存警告，执行缓存清理");
    
    dispatch_barrier_async(_cacheQueue, ^{
        // 清理一半的内存缓存
        NSUInteger targetCount = self.memoryCache.count / 2;
        while (self.memoryCache.count > targetCount && self.accessOrder.count > 0) {
            NSString *oldestKey = self.accessOrder.firstObject;
            if (oldestKey) {
                YBIBCacheItem *item = self.memoryCache[oldestKey];
                if (item) {
                    self.totalMemoryUsage -= item.memorySize;
                }
                [self.memoryCache removeObjectForKey:oldestKey];
                [self.accessOrder removeObject:oldestKey];
            }
        }
    });
}

- (void)handleAppWillTerminate:(NSNotification *)notification {
    // 清理过期缓存
    [self cleanExpiredCache];
}

@end