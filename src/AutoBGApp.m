#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <stdlib.h>
#import "AutoBGConfig.h"

// ============================================================
// 备用方案：应用进程内静音音频保活
// 仅在 设置 → 自动真后台 → “音频保活（备用）”开启时生效。
// 主方案（SpringBoard 防挂起）正常时一般用不到。
// ============================================================

static AVAudioPlayer *gAutoBGPlayer;

static NSData *AutoBGSilentWAV(void) {
    // 44 字节 WAV 头 + 1 秒静音（8kHz 单声道 8bit，约 8KB）
    const uint32_t sampleRate = 8000;
    const uint32_t dataSize = sampleRate; // 1 秒
    NSMutableData *data = [NSMutableData dataWithCapacity:44 + dataSize];

    const char *riff = "RIFF";
    uint32_t chunkSize = 36 + dataSize;
    const char *wave = "WAVE";
    const char *fmt = "fmt ";
    uint32_t fmtChunkSize = 16;
    uint16_t audioFormat = 1;       // PCM
    uint16_t numChannels = 1;
    uint32_t byteRate = sampleRate; // 8bit 单声道：每秒字节数 = 采样率
    uint16_t blockAlign = 1;
    uint16_t bitsPerSample = 8;
    const char *dataTag = "data";

    [data appendBytes:riff length:4];
    [data appendBytes:&chunkSize length:4];
    [data appendBytes:wave length:4];
    [data appendBytes:fmt length:4];
    [data appendBytes:&fmtChunkSize length:4];
    [data appendBytes:&audioFormat length:2];
    [data appendBytes:&numChannels length:2];
    [data appendBytes:&sampleRate length:4];
    [data appendBytes:&byteRate length:4];
    [data appendBytes:&blockAlign length:2];
    [data appendBytes:&bitsPerSample length:2];
    [data appendBytes:dataTag length:4];
    [data appendBytes:&dataSize length:4];

    uint8_t *silence = calloc(1, dataSize);
    if (silence) {
        [data appendBytes:silence length:dataSize];
        free(silence);
    }

    return data;
}

static void AutoBGStartAudio(void) {
    if (gAutoBGPlayer.isPlaying) {
        return;
    }

    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    [session setActive:YES error:&error];

    gAutoBGPlayer = [[AVAudioPlayer alloc] initWithData:AutoBGSilentWAV() error:&error];
    if (!gAutoBGPlayer) {
        NSLog(@"[AutoBackground17] 音频保活启动失败: %@", error);
        return;
    }
    gAutoBGPlayer.numberOfLoops = -1; // 无限循环
    gAutoBGPlayer.volume = 0.0;       // 完全静音，仅维持音频会话
    [gAutoBGPlayer play];
}

static void AutoBGStopAudio(void) {
    if (gAutoBGPlayer.isPlaying) {
        [gAutoBGPlayer stop];
    }
    gAutoBGPlayer = nil;

    NSError *error = nil;
    [[AVAudioSession sharedInstance] setActive:NO
                                       withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                             error:&error];
}

static void AutoBGHandleBackground(NSNotification *notification) {
    AutoBGConfig *config = [AutoBGConfig shared];
    if (!config.enabled || !config.audioFallback) {
        return;
    }

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if ([config shouldKeepAliveBundle:bundleID]) {
        NSLog(@"[AutoBackground17] %@ 进入后台，启动音频保活", bundleID);
        AutoBGStartAudio();
    }
}

static void AutoBGHandleForeground(NSNotification *notification) {
    AutoBGStopAudio();
}

__attribute__((constructor))
static void AutoBGInitialize(void) {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        AutoBGHandleBackground(note);
                    }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        AutoBGHandleForeground(note);
                    }];
}