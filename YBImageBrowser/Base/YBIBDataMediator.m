//
//  YBIBDataMediator.m
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2019/6/6.
//  Copyright © 2019 波儿菜. All rights reserved.
//

#import "YBIBDataMediator.h"
#import "YBImageBrowser+Internal.h"

@implementation YBIBDataMediator {
    __weak YBImageBrowser *_browser;
    NSCache<NSNumber *, id<YBIBDataProtocol>> *_dataCache;
}

#pragma mark - life cycle

- (instancetype)initWithBrowser:(YBImageBrowser *)browser {
    if (self = [super init]) {
        _browser = browser;
        _dataCache = [NSCache new];
    }
    return self;
}

#pragma mark - public

- (NSInteger)numberOfCells {
    return _browser.dataSource ? [_browser.dataSource yb_numberOfCellsInImageBrowser:_browser] : _browser.dataSourceArray.count;
}

- (id<YBIBDataProtocol>)dataForCellAtIndex:(NSInteger)index {
    if (index < 0 || index > self.numberOfCells - 1) return nil;
    
    id<YBIBDataProtocol> data = [_dataCache objectForKey:@(index)];
    if (!data) {
        data = _browser.dataSource ? [_browser.dataSource yb_imageBrowser:_browser dataForCellAtIndex:index] : _browser.dataSourceArray[index];
        [_dataCache setObject:data forKey:@(index)];
        [_browser implementGetBaseInfoProtocol:data];
    }
    return data;
}

- (void)clear {
    [_dataCache removeAllObjects];
}

- (void)preloadWithPage:(NSInteger)page {
    if (_preloadCount == 0) return;
    
    NSInteger left = -(_preloadCount / 2), right = _preloadCount - ABS(left);
    NSInteger totalPages = [self numberOfCells];
    
    // 性能优化：优先级预加载，距离当前页越近优先级越高
    NSMutableArray *preloadTasks = [NSMutableArray array];
    
    for (NSInteger i = left; i <= right; ++i) {
        if (i == 0) continue;
        NSInteger targetPage = page + i;
        
        // 边界检查
        if (targetPage < 0 || targetPage >= totalPages) continue;
        
        NSDictionary *task = @{
            @"page": @(targetPage),
            @"priority": @(ABS(i)) // 距离越近优先级数字越小
        };
        [preloadTasks addObject:task];
    }
    
    // 按优先级排序
    [preloadTasks sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        return [obj1[@"priority"] compare:obj2[@"priority"]];
    }];
    
    // 按优先级顺序预加载
    for (NSDictionary *task in preloadTasks) {
        NSInteger targetPage = [task[@"page"] integerValue];
        id<YBIBDataProtocol> targetData = [self dataForCellAtIndex:targetPage];
        if ([targetData respondsToSelector:@selector(yb_preload)]) {
            // 性能优化：在后台队列执行预加载，避免阻塞主线程
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [targetData yb_preload];
            });
        }
    }
}

#pragma mark - getters & setters

- (void)setDataCacheCountLimit:(NSUInteger)dataCacheCountLimit {
    _dataCacheCountLimit = dataCacheCountLimit;
    _dataCache.countLimit = dataCacheCountLimit;
}

@end
