#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutoBGConfig : NSObject

+ (instancetype)shared;

/// 总开关（设置 → 自动真后台 → 启用），默认开启
@property (nonatomic, readonly) BOOL enabled;

/// 是否默认保持所有应用；关闭时只保持 AppOverrides 中显式打开的应用
@property (nonatomic, readonly) BOOL keepAllApps;

/// 应用侧静音音频保活（备用方案，可能显示播放指示）
@property (nonatomic, readonly) BOOL audioFallback;

/// 禁止在 App 切换器中上滑终止被保持的应用
@property (nonatomic, readonly) BOOL preventManualKill;

/// 判断某个 bundle id 是否应保持后台运行
- (BOOL)shouldKeepAliveBundle:(nullable NSString *)bundleID;

@end

NS_ASSUME_NONNULL_END