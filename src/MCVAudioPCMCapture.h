//
//  MCVAudioPCMCapture.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/06.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <MTPipeline.h>

#import "VSRawAudioFreight.h" // TODO: remove application specific dependency

@protocol  MCVAudioPCMCaptureDelegate <NSObject>

- (void)saveCurrentGrantedStatus:(BOOL)granted;
- (BOOL)lastGrantedStatus;

@end

// PCM (float, int16) monoral capture
@interface MCVAudioPCMCapture : NSObject {
    @protected
    AudioBufferList *_input_buffer;
    MTNode *_conduit;
}

@property (nonatomic, readonly) MTNode *conduit;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic, readonly) BOOL interrupted;
@property (nonatomic, readonly) VSRawAudioFormat format;

@property (nonatomic, weak, readwrite) id<MCVAudioPCMCaptureDelegate> delegate;
+ (instancetype)createWithConduit:(MTNode *)conduit withFormat:(VSRawAudioFormat)format;
+ (instancetype)createWithConduit:(MTNode *)conduit withFormat:(VSRawAudioFormat)format withDelegate:(id<MCVAudioPCMCaptureDelegate>)delegate;

+ (BOOL)microphoneAccessGranted;
- (void)start;
- (void)pause;

- (void)appendMetaInfo:(VSRawAudioFreight *)captured_buf; // override this to append extra information at captured time
@end
