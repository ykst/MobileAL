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

#import "MALRawAudioFreight.h" // TODO: remove application specific dependency

@protocol MALRawAudioCaptureDelegate <NSObject>

- (void)saveCurrentGrantedStatus:(BOOL)granted;
- (BOOL)lastGrantedStatus;

@end

// PCM (float, int16) monoral capture
@interface MALRawAudioCapture : NSObject {
    @protected
    AudioBufferList *_input_buffer;
    MTNode *_conduit;
}

@property (nonatomic, readonly) MTNode *conduit;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic, readonly) BOOL interrupted;
@property (nonatomic, readonly) MALRawAudioFormat format;

@property (nonatomic, weak, readwrite) id<MALRawAudioCaptureDelegate> delegate;
+ (instancetype)createWithConduit:(MTNode *)conduit withFormat:(MALRawAudioFormat)format;
+ (instancetype)createWithConduit:(MTNode *)conduit withFormat:(MALRawAudioFormat)format withDelegate:(id<MALRawAudioCaptureDelegate>)delegate;

+ (BOOL)microphoneAccessGranted;
- (void)start;
- (void)pause;

- (void)appendMetaInfo:(MALRawAudioFreight *)captured_buf; // override this to append extra information at captured time
@end
