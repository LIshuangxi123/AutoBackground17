#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "AutoBGConfig.h"

// ============================================================
// 主方案：SpringBoard 侧阻止进程挂起（真后台）
//
// 说明：以下私有方法名基于 iOS 13-16 的 FrontBoard / SpringBoard
// 类 dump。若 iOS 17.x 上某个方法不存在，Logos 会自动跳过该 hook
// （不会崩溃），其余 hook 不受影响。启动日志里带“自检”的行会
// 直接报告每个类/方法在你当前系统上是否存在，便于真机验证。
// ============================================================

%hook FBApplicationProcess

- (void)suspend {
    if ([[AutoBGConfig shared] shouldKeepAliveBundle:[self bundleIdentifier]]) {
        return; // 阻止挂起：进程保持真正运行
    }
    %orig;
}

- (void)_suspend {
    if ([[AutoBGConfig shared] shouldKeepAliveBundle:[self bundleIdentifier]]) {
        return;
    }
    %orig;
}

- (void)killForReason:(long long)reason {
    if ([[AutoBGConfig shared] preventManualKill] &&
        [[AutoBGConfig shared] shouldKeepAliveBundle:[self bundleIdentifier]]) {
        return; // 阻止上滑终止
    }
    %orig;
}

%end

%hook SBApplication

- (void)suspend {
    if ([[AutoBGConfig shared] shouldKeepAliveBundle:[self bundleIdentifier]]) {
        return;
    }
    %orig;
}

- (void)killForReason:(long long)reason {
    if ([[AutoBGConfig shared] preventManualKill] &&
        [[AutoBGConfig shared] shouldKeepAliveBundle:[self bundleIdentifier]]) {
        return;
    }
    %orig;
}

// iOS 15+ 的“应用冻结”：返回 NO 则进程内存不被回收
- (BOOL)isFreezingEnabled {
    if ([[AutoBGConfig shared] shouldKeepAliveBundle:[self bundleIdentifier]]) {
        return NO;
    }
    return %orig;
}

%end

%ctor {
    NSLog(@"[AutoBackground17] SpringBoard 防挂起已加载 (v1.0.0)");

    // 自检：报告每个 hook 目标在当前系统上是否真实存在
    Class fbApp = objc_getClass("FBApplicationProcess");
    Class sbApp = objc_getClass("SBApplication");
    NSLog(@"[AutoBackground17] 自检: FBApplicationProcess=%@ SBApplication=%@",
        fbApp ? @"存在" : @"不存在", sbApp ? @"存在" : @"不存在");
    NSLog(@"[AutoBackground17] 自检: FBApplicationProcess -suspend=%@ -_suspend=%@ -killForReason:=%@",
        [fbApp instancesRespondToSelector:NSSelectorFromString(@"suspend")] ? @"YES" : @"NO",
        [fbApp instancesRespondToSelector:NSSelectorFromString(@"_suspend")] ? @"YES" : @"NO",
        [fbApp instancesRespondToSelector:NSSelectorFromString(@"killForReason:")] ? @"YES" : @"NO");
    NSLog(@"[AutoBackground17] 自检: SBApplication -suspend=%@ -isFreezingEnabled=%@ -killForReason:=%@",
        [sbApp instancesRespondToSelector:NSSelectorFromString(@"suspend")] ? @"YES" : @"NO",
        [sbApp instancesRespondToSelector:NSSelectorFromString(@"isFreezingEnabled")] ? @"YES" : @"NO",
        [sbApp instancesRespondToSelector:NSSelectorFromString(@"killForReason:")] ? @"YES" : @"NO");
}