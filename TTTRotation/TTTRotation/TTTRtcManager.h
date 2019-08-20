//
//  TTTRtcManager.h
//  TTTLive
//
//  Created by yanzhen on 2018/8/21.
//  Copyright © 2018年 yanzhen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TTTRtcEngineKit/TTTRtcEngineKit.h>

#define TTManager [TTTRtcManager manager]

@interface TTTRtcManager : NSObject

@property (nonatomic, strong) TTTRtcEngineKit *rtcEngine;
@property (nonatomic, assign) int64_t roomID;
@property (nonatomic, assign) int64_t uid;

+ (instancetype)manager;
@end
