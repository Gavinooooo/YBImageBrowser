//
//  YBIBCopywriter.m
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2018/9/13.
//  Copyright © 2018年 波儿菜. All rights reserved.
//

#import "YBIBCopywriter.h"

@implementation YBIBCopywriter

#pragma mark - life cycle

+ (instancetype)sharedCopywriter {
    static YBIBCopywriter *copywriter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        copywriter = [YBIBCopywriter new];
    });
    return copywriter;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = YBIBCopywriterTypeSimplifiedChinese;
        NSArray *appleLanguages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
        if (appleLanguages && appleLanguages.count > 0) {
            NSString *languages = appleLanguages[0];
            if ([languages hasPrefix:@"zh-Hans"]) {
                _type = YBIBCopywriterTypeSimplifiedChinese;
            } else if ([languages hasPrefix:@"zh-Hant"]) {
                _type = YBIBCopywriterTypeTraditionalChinese;
            } else if ([languages hasPrefix:@"ja"]) {
                _type = YBIBCopywriterTypeJapanese;
            } else if ([languages hasPrefix:@"ko"]) {
                _type = YBIBCopywriterTypeKorean;
            } else {
                _type = YBIBCopywriterTypeEnglish;
            }
        }
        
        [self initCopy];
    }
    return self;
}

#pragma mark - private

- (void)initCopy {
    switch (self.type) {
        case YBIBCopywriterTypeEnglish:
            self.videoIsInvalid = @"Video is invalid";
            self.videoError = @"Video error";
            self.unableToSave = @"Unable to save";
            self.imageIsInvalid = @"Image is invalid";
            self.downloadFailed = @"Download failed";
            self.getPhotoAlbumAuthorizationFailed = @"Failed to get album authorization";
            self.saveToPhotoAlbumSuccess = @"Save successful";
            self.saveToPhotoAlbumFailed = @"Save failed";
            self.saveToPhotoAlbum = @"Save";
            self.cancel = @"Cancel";
            break;
            
        case YBIBCopywriterTypeTraditionalChinese:
            self.videoIsInvalid = @"影片無效";
            self.videoError = @"影片錯誤";
            self.unableToSave = @"無法儲存";
            self.imageIsInvalid = @"圖片無效";
            self.downloadFailed = @"載入圖片失敗";
            self.getPhotoAlbumAuthorizationFailed = @"獲取相簿權限失敗";
            self.saveToPhotoAlbumSuccess = @"已儲存至系統相簿";
            self.saveToPhotoAlbumFailed = @"儲存失敗";
            self.saveToPhotoAlbum = @"儲存到相簿";
            self.cancel = @"取消";
            break;
            
        case YBIBCopywriterTypeJapanese:
            self.videoIsInvalid = @"動画が無効です";
            self.videoError = @"動画エラー";
            self.unableToSave = @"保存できません";
            self.imageIsInvalid = @"画像が無効です";
            self.downloadFailed = @"画像の読み込みに失敗しました";
            self.getPhotoAlbumAuthorizationFailed = @"写真アルバムの権限取得に失敗しました";
            self.saveToPhotoAlbumSuccess = @"システムアルバムに保存されました";
            self.saveToPhotoAlbumFailed = @"保存に失敗しました";
            self.saveToPhotoAlbum = @"保存";
            self.cancel = @"キャンセル";
            break;
            
        case YBIBCopywriterTypeKorean:
            self.videoIsInvalid = @"동영상이 유효하지 않습니다";
            self.videoError = @"동영상 오류";
            self.unableToSave = @"저장할 수 없습니다";
            self.imageIsInvalid = @"이미지가 유효하지 않습니다";
            self.downloadFailed = @"이미지 로드 실패";
            self.getPhotoAlbumAuthorizationFailed = @"앨범 권한 획득 실패";
            self.saveToPhotoAlbumSuccess = @"시스템 앨범에 저장되었습니다";
            self.saveToPhotoAlbumFailed = @"저장 실패";
            self.saveToPhotoAlbum = @"저장";
            self.cancel = @"취소";
            break;
            
        default: // YBIBCopywriterTypeSimplifiedChinese
            self.videoIsInvalid = @"视频无效";
            self.videoError = @"视频错误";
            self.unableToSave = @"无法保存";
            self.imageIsInvalid = @"图片无效";
            self.downloadFailed = @"加载图片失败";
            self.getPhotoAlbumAuthorizationFailed = @"获取相册权限失败";
            self.saveToPhotoAlbumSuccess = @"已保存到系统相册";
            self.saveToPhotoAlbumFailed = @"保存失败";
            self.saveToPhotoAlbum = @"保存到相册";
            self.cancel = @"取消";
            break;
    }
}

#pragma mark - public

- (void)setType:(YBIBCopywriterType)type {
    _type = type;
    [self initCopy];
}

@end
