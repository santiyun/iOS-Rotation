//
//  TTTLiveViewController.m
//  TTTLive
//
//  Created by yanzhen on 2018/8/21.
//  Copyright © 2018年 yanzhen. All rights reserved.
//

#import "TTTLiveViewController.h"
#import "TTTRtcManager.h"
#import "TTProgressHud.h"
#import "UIView+Toast.h"

@interface TTTLiveViewController ()<TTTRtcEngineDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *anchorVideoView;
@property (weak, nonatomic) IBOutlet UIButton *voiceBtn;
@property (weak, nonatomic) IBOutlet UILabel *roomIDLabel;
@property (weak, nonatomic) IBOutlet UILabel *anchorIdLabel;
@property (weak, nonatomic) IBOutlet UILabel *audioStatsLabel;
@property (weak, nonatomic) IBOutlet UILabel *videoStatsLabel;
@property (weak, nonatomic) IBOutlet UIView *avRegionsView;

@property (nonatomic, strong) TTTRtcVideoCompositingLayout *videoLayout;
@end

@implementation TTTLiveViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    TTManager.rtcEngine.delegate = self;
    
    _roomIDLabel.text = [NSString stringWithFormat:@"房号: %lld", TTManager.roomID];
    _anchorIdLabel.text = [NSString stringWithFormat:@"主播ID: %lld", TTManager.uid];
    //开启预览...显示视频
    [TTManager.rtcEngine startPreview];
    TTTRtcVideoCanvas *videoCanvas = [[TTTRtcVideoCanvas alloc] init];
    videoCanvas.renderMode = TTTRtc_Render_Adaptive;
    videoCanvas.uid = TTManager.uid;
    videoCanvas.view = _anchorVideoView;
    [TTManager.rtcEngine setupLocalVideo:videoCanvas];
    
    //for sei
    _videoLayout = [[TTTRtcVideoCompositingLayout alloc] init];
    _videoLayout.canvasWidth = 352;
    _videoLayout.canvasHeight = 640;
    _videoLayout.backgroundColor = @"#e8e6e8";
    
#warning mark - 方向改变监听
    //监听电池方向改变
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(didChangeRotate:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
}

//设置再不同方向下是否交换视频宽高
- (void)didChangeRotate:(NSNotification *)note {
    BOOL swapWH = UIInterfaceOrientationIsPortrait(UIApplication.sharedApplication.statusBarOrientation);
    [TTManager.rtcEngine setVideoProfile:TTTRtc_VideoProfile_360P swapWidthAndHeight:swapWH];
}

- (IBAction)exitChannel:(id)sender {
    __weak TTTLiveViewController *weakSelf = self;
    UIAlertController *alert  = [UIAlertController alertControllerWithTitle:@"提示" message:@"您确定要退出房间吗？" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //开启预览必须关闭预览
        [TTManager.rtcEngine stopPreview];
        [TTManager.rtcEngine leaveChannel:nil];
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    }];
    [alert addAction:sureAction];
    [self presentViewController:alert animated:YES completion:nil];
    
    
    
}

#pragma mark - TTTRtcEngineDelegate
- (void)rtcEngine:(TTTRtcEngineKit *)engine localVideoFrameCaptured:(TTTRtcVideoFrame *)videoFrame {
//    NSLog(@"TTLog------%d -- %d",videoFrame.strideInPixels, videoFrame.height);
}

//有用户加入房间--测试播放远端声音
-(void)rtcEngine:(TTTRtcEngineKit *)engine didJoinedOfUid:(int64_t)uid clientRole:(TTTRtcClientRole)clientRole isVideoEnabled:(BOOL)isVideoEnabled elapsed:(NSInteger)elapsed {
    if (clientRole == TTTRtc_ClientRole_Audience) {
        return;
    }
//    [_audioCapture startPlay:YES];
}

//用户掉线--房间内没有发言用户关闭播放音频
- (void)rtcEngine:(TTTRtcEngineKit *)engine didOfflineOfUid:(int64_t)uid reason:(TTTRtcUserOfflineReason)reason {
//    [_audioCapture startPlay:NO];
}

//上报音量(包含所有房间内用户)
- (void)rtcEngine:(TTTRtcEngineKit *)engine reportAudioLevel:(int64_t)userID audioLevel:(NSUInteger)audioLevel audioLevelFullRange:(NSUInteger)audioLevelFullRange {
    [_voiceBtn setImage:[self getVoiceImage:audioLevel] forState:UIControlStateNormal];
}

//本地音视频码率
-(void)rtcEngine:(TTTRtcEngineKit *)engine reportRtcStats:(TTTRtcStats *)stats {
    _audioStatsLabel.text = [NSString stringWithFormat:@"A-↑%ldkbps", stats.txAudioKBitrate];
    _videoStatsLabel.text = [NSString stringWithFormat:@"V-↑%ldkbps", stats.txVideoKBitrate];
}

//网络链接丢失，默认自动重连
- (void)rtcEngineConnectionDidLost:(TTTRtcEngineKit *)engine {
    [TTProgressHud showHud:self.view message:@"网络链接丢失，正在重连..."];
}

//网络重连失败...不再尝试重连，需要退出房间
- (void)rtcEngineReconnectServerTimeout:(TTTRtcEngineKit *)engine {
    [TTProgressHud hideHud:self.view];
    [self.view.window showToast:@"网络丢失，请检查网络"];
    [engine leaveChannel:nil];
    [engine stopPreview];
    [self dismissViewControllerAnimated:YES completion:nil];
}

//网络重连成功
- (void)rtcEngineReconnectServerSucceed:(TTTRtcEngineKit *)engine {
    [TTProgressHud hideHud:self.view];
}

//在房间内被踢出
- (void)rtcEngine:(TTTRtcEngineKit *)engine didKickedOutOfUid:(int64_t)uid reason:(TTTRtcKickedOutReason)reason {
    NSString *errorInfo = @"";
    switch (reason) {
        case TTTRtc_KickedOut_PushRtmpFailed:
            errorInfo = @"rtmp推流失败";
            break;
        case TTTRtc_KickedOut_ReLogin:
            errorInfo = @"重复登录";
            break;
        case TTTRtc_KickedOut_NoAudioData:
            errorInfo = @"长时间没有上行音频数据";
            break;
        case TTTRtc_KickedOut_NoVideoData:
            errorInfo = @"长时间没有上行视频数据";
            break;
        case TTTRtc_KickedOut_NewChairEnter:
            errorInfo = @"其他人以主播身份进入";
            break;
        case TTTRtc_KickedOut_ChannelKeyExpired:
            errorInfo = @"Channel Key失效";
            break;
        default:
            errorInfo = @"未知错误";
            break;
    }
    [self.view.window showToast:errorInfo];
    [engine leaveChannel:nil];
    [engine stopPreview];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - helper mehtod
- (void)refreshVideoCompositingLayout {
    TTTRtcVideoCompositingLayout *videoLayout = _videoLayout;
    [videoLayout.regions removeAllObjects];
    TTTRtcVideoCompositingRegion *anchorRegion = [[TTTRtcVideoCompositingRegion alloc] init];
    anchorRegion.uid = TTManager.uid;
    anchorRegion.x = 0;
    anchorRegion.y = 0;
    anchorRegion.width = 1;
    anchorRegion.height = 1;
    anchorRegion.zOrder = 0;
    anchorRegion.alpha = 1;
    anchorRegion.renderMode = TTTRtc_Render_Adaptive;
    [videoLayout.regions addObject:anchorRegion];
    [TTManager.rtcEngine setVideoCompositingLayout:videoLayout];
}

- (UIImage *)getVoiceImage:(NSUInteger)level {
    UIImage *image = nil;
    if (level < 4) {
        image = [UIImage imageNamed:@"volume_1"];
    } else if (level < 7) {
        image = [UIImage imageNamed:@"volume_2"];
    } else {
        image = [UIImage imageNamed:@"volume_3"];
    }
    return image;
}
@end
