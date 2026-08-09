#import <Preferences/Preferences.h>
#import "AutoBGConfig.h"

static NSString *const AutoBGPrefsDomain = @"com.autobg.autobackground17";

@interface AutoBGRootListController : PSListController
@end

@implementation AutoBGRootListController

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id defaultValue = [specifier propertyForKey:@"default"];

    CFTypeRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)AutoBGPrefsDomain);
    if (!value) {
        return defaultValue;
    }
    return (__bridge_transfer id)value;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (value) {
        CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)AutoBGPrefsDomain);
    } else {
        CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, (__bridge CFStringRef)AutoBGPrefsDomain);
    }
    CFPreferencesAppSynchronize((__bridge CFStringRef)AutoBGPrefsDomain);
}

- (PSSpecifier *)switchSpecifierWithLabel:(NSString *)label
                                      key:(NSString *)key
                             defaultValue:(BOOL)defaultValue
                                   footer:(NSString *)footer {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:label
                                                       target:self
                                                          set:@selector(setPreferenceValue:specifier:)
                                                          get:@selector(readPreferenceValue:)
                                                       detail:nil
                                                         cell:PSSwitchCell
                                                         edit:nil];
    [spec setProperty:key forKey:@"key"];
    [spec setProperty:@(defaultValue) forKey:@"default"];
    if (footer.length > 0) {
        [spec setProperty:footer forKey:@"footerText"];
    }
    return spec;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];

        PSSpecifier *introGroup = [PSSpecifier groupSpecifierWithName:@"自动真后台"];
        [introGroup setProperty:@"应用进入后台后保持进程真正运行（不被挂起/冻结）。\n\n支持 iOS 17.0-17.3.1 无根越狱。后台持续运行会明显增加耗电。" forKey:@"footerText"];
        [specs addObject:introGroup];

        [specs addObject:[self switchSpecifierWithLabel:@"启用"
                                                    key:@"Enabled"
                                           defaultValue:YES
                                                 footer:nil]];

        [specs addObject:[self switchSpecifierWithLabel:@"保持所有应用"
                                                    key:@"KeepAllApps"
                                           defaultValue:YES
                                                 footer:@"开启：所有应用默认保持后台运行；关闭：仅“应用管理”中手动打开的应用保持后台运行。"]];

        [specs addObject:[self switchSpecifierWithLabel:@"音频保活（备用）"
                                                    key:@"AudioFallback"
                                           defaultValue:NO
                                                 footer:@"兜底方案：进入后台时播放静音音频维持进程。可能显示播放指示，建议仅在主方案失效时开启。"]];

        [specs addObject:[self switchSpecifierWithLabel:@"禁止上滑终止"
                                                    key:@"PreventManualKill"
                                           defaultValue:NO
                                                 footer:@"开启后，被保持的应用在 App 切换器中上滑也不会被杀掉（重启设备可恢复）。"]];

        PSSpecifier *appList = [PSSpecifier preferenceSpecifierNamed:@"应用管理"
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:NSClassFromString(@"AutoBGAppListController")
                                                                cell:PSLinkCell
                                                                edit:nil];
        [specs addObject:appList];

        _specifiers = [specs copy];
    }
    return _specifiers;
}

@end