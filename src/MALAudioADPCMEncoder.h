//
//  MALAudioADPCMEncoder.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/17.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VSRawAudioFreight.h"
#import "MCVByteFreight.h"
#import "VSEncodedAudioFreight.h"

// IMA 4:1 ADPCM.
@interface MALAudioADPCMEncoder : NSObject

+ (instancetype)create;

- (BOOL)process:(VSRawAudioFreight *)src to:(VSEncodedAudioFreight *)dst;

- (BOOL)debugDecode:(MCVByteFreight *)src to:(VSRawAudioFreight *)dst;
@end
