#import <Preferences/Preferences.h>
#import "AutoBGConfig.h"

// 自声明私有类接口（避免新版 SDK 头文件缺失导致编译失败）
@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSString *applicationType;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

static NSString *const AutoBGPrefsDomain = @"com.autobg.autobackground17";

@interface AutoBGAppListController : PSListController
@end

@implementation AutoBGAppListController

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"key"];

    CFTypeRef raw = CFPreferencesCopyAppValue(CFSTR("AppOverrides"), (__bridge CFStringRef)AutoBGPrefsDomain);
    NSDictionary *overrides = raw && CFGetTypeID(raw) == CFDictionaryGetTypeID()
        ? (__bridge_transfer NSDictionary *)raw
        : nil;

    NSNumber *override = overrides[bundleID];
    if (override) {
        return override;
    }
    // 默认状态跟随“保持所有应用”
    return @([[AutoBGConfig shared] keepAllApps]);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"key"];

    NSMutableDictionary *overrides = [NSMutableDictionary dictionary];
    CFTypeRef raw = CFPreferencesCopyAppValue(CFSTR("AppOverrides"), (__bridge CFStringRef)AutoBGPrefsDomain);
    if (raw && CFGetTypeID(raw) == CFDictionaryGetTypeID()) {
        [overrides addEntriesFromDictionary:(__bridge_transfer NSDictionary *)raw];
    } else if (raw) {
        CFRelease(raw);
    }

    overrides[bundleID] = value;
    CFPreferencesSetAppValue(CFSTR("AppOverrides"), (__bridge CFPropertyListRef)overrides, (__bridge CFStringRef)AutoBGPrefsDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)AutoBGPrefsDomain);
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];

        BOOL keepAll = [[AutoBGConfig shared] keepAllApps];
        NSString *footer = keepAll
            ? @"开 = 保持后台运行，关 = 后台时正常挂起（默认全部保持）"
            : @"开 = 仅这些应用保持后台运行（默认全部挂起）";
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"应用"];
        [group setProperty:footer forKey:@"footerText"];
        [specs addObject:group];

        for (LSApplicationProxy *proxy in [self installedUserApps]) {
            NSString *bundleID = proxy.bundleIdentifier;
            NSString *name = proxy.localizedName.length > 0 ? proxy.localizedName : bundleID;

            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name
                                                               target:self
                                                                  set:@selector(setPreferenceValue:specifier:)
                                                                  get:@selector(readPreferenceValue:)
                                                               detail:nil
                                                                 cell:PSSwitchCell
                                                                 edit:nil];
            [spec setProperty:bundleID forKey:@"key"];
            [specs addObject:spec];
        }

        _specifiers = [specs copy];
    }
    return _specifiers;
}

- (NSArray *)installedUserApps {
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
    NSArray *proxies = [workspace allInstalledApplications];

    NSMutableArray *apps = [NSMutableArray array];
    for (LSApplicationProxy *proxy in proxies) {
        NSString *type = proxy.applicationType;
        if (type.length == 0 || [type isEqualToString:@"User"]) {
            [apps addObject:proxy];
        }
    }

    [apps sortUsingComparator:^NSComparisonResult(LSApplicationProxy *a, LSApplicationProxy *b) {
        NSString *an = a.localizedName ?: a.bundleIdentifier;
        NSString *bn = b.localizedName ?: b.bundleIdentifier;
        return [an localizedStandardCompare:bn];
    }];

    return apps;
}

@end