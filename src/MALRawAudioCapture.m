//
//  MCVAudioPCMCapture.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/06.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import "MALRawAudioCapture.h"
#import "MALRawAudioFreight.h"

@interface MALRawAudioCapture() {
}

@property (nonatomic, readonly) AudioUnit io_unit;
@property (nonatomic, readonly) AudioBufferList *input_buffer;
@property (nonatomic, readonly) UInt32 num_bytes_per_sample;
@property (nonatomic, readonly) NSInteger num_input_channels;
@property (nonatomic, readonly) BOOL is_interleaved;
@property (nonatomic, readonly) float *work_float;

@property (nonatomic, readwrite) MALRawAudioFreight *keep_buf;

@end

@implementation MALRawAudioCapture

static BOOL __granted = NO;

+ (instancetype)createWithConduit:(MTNode *)conduit withFormat:(MALRawAudioFormat)format
{
    return [[self class] createWithConduit:conduit withFormat:format withDelegate:nil];
}

+ (instancetype)createWithConduit:(MTNode *)conduit withFormat:(MALRawAudioFormat)format withDelegate:(id<MALRawAudioCaptureDelegate>)delegate
{
    MALRawAudioCapture *obj = [[[self class] alloc] init];

    obj.delegate = delegate;

    ASSERT([obj _setupWithConduit:conduit withFormat:format], return nil);

    return obj;
}

+ (BOOL)microphoneAccessGranted
{
    return __granted;
}

- (BOOL)_setupWithConduit:(MTNode *)conduit withFormat:(MALRawAudioFormat)format
{
    _format = format;

    _conduit = conduit;

    [self _checkPermission:^{
        [self _setupAudio];
    }];

    [self pause];

    return YES;
}

- (void)_checkPermission:(void (^)(void))continuation
{
    AVAudioSession *session = [AVAudioSession sharedInstance];

    if ([session respondsToSelector:@selector(requestRecordPermission:)]) {
        [session performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            __granted = granted;

            if (granted) {
                continuation();
                if (_playing) {
                    [self pause];
                    [self start];
                }
            } else {
                if ([_delegate respondsToSelector:@selector(lastGrantedStatus)] &&
                    [_delegate lastGrantedStatus] == YES) {
                    if ([_delegate respondsToSelector:@selector(permissionNotGranted)]) {
                        [_delegate permissionNotGranted];
                    }
                }
            }

            if ([_delegate respondsToSelector:@selector(saveCurrentGrantedStatus:)]) {
                [_delegate saveCurrentGrantedStatus:__granted];
            }
        }];
    } else {
        __granted = YES;
        continuation();
    }
}

- (BOOL)_setupAudio
{
    ASSERT([self _setupAudioNotifications] == YES, return NO);
    ASSERT([self _setupAudioSession] == YES, return NO);
    ASSERT([self _setupAudioUnit] == YES, return NO);

    return YES;
}

- (BOOL)_setupAudioUnit
{
    ASSERT((_io_unit = [self _setupAudioUnitInput]) != NULL, return NO);
    ASSERT([self _setupAudioUnitBuffer:_io_unit] == YES, return NO);
    ASSERT([self _setupAudioUnitCallbacks:_io_unit] == YES, return NO);
    ASSERT([self _setupAudioUnitInitialize:_io_unit] == YES, return NO);

    return YES;
}

- (void)_audioSessionDidChangeInterruption:(NSNotification *)notification
{
    AVAudioSessionInterruptionType interruptionType = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];

    if (AVAudioSessionInterruptionTypeBegan == interruptionType) {
        DBG("AVAudio: interruption began");
        _interrupted = YES;
    } else if (AVAudioSessionInterruptionTypeEnded == interruptionType) {
        DBG("AVAudio: interruption ended");

        if (__granted) {
            [self _cleanup];
            [self _setupAudio];
        }
        if (_playing) {
            [self _forceStart];
        }

        _interrupted = NO;
    }
}

- (void)_audioSessionDidChangeRoute:(NSNotification *)notification
{
#ifdef DEBUG
    AVAudioSessionRouteDescription *description = [[AVAudioSession sharedInstance] currentRoute];

    NSUInteger reason_code = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];

    DBG("AVAudio: rounte change (in:%@)(out:%@)(reason:%u)", description.inputs, description.outputs, (unsigned)reason_code);
#endif
}

- (BOOL)_setupAudioNotifications
{
    // interruption
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_audioSessionDidChangeInterruption:)
                                                 name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];

    // route change
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_audioSessionDidChangeRoute:)
                                                 name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];

    return YES;
}

- (void *)_getOutputPointer:(UInt32)num_samples
{
    if (_keep_buf == nil) {
        EXPECT(_conduit.num_out_get > 0, return NULL);

        _keep_buf = [_conduit outGet];

        EXPECT(_keep_buf != nil, return NULL);

        [_keep_buf reset];

        [self appendMetaInfo:_keep_buf];
    }

    return [_keep_buf invalidateRange:(num_samples * _keep_buf.bytes_per_sample)];
}

- (void)_pushOutput
{
    if (_keep_buf.filled) {
        [_conduit outPut:_keep_buf];
        _keep_buf = nil;
    }
}

OSStatus __audio_input_callback_float(void *inRefCon,
                                      AudioUnitRenderActionFlags* ioActionFlags,
                                      const AudioTimeStamp * inTimeStamp,
                                      UInt32 inOutputBusNumber,
                                      UInt32 inNumberFrames,
                                      AudioBufferList * ioData)
{
    MALRawAudioCapture *sm = (__bridge MALRawAudioCapture *)inRefCon;

    if (!sm.playing || sm.interrupted) return noErr;

    AudioBufferList *input_buffer = sm.input_buffer;

    OSStatus result;
    ASSERT((result = AudioUnitRender(sm.io_unit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, input_buffer)) == noErr, return result);

    UInt32 num_bytes_per_sample = sm.num_bytes_per_sample;
    NSInteger num_input_channels = sm.num_input_channels;

    float *out_data = [sm _getOutputPointer:inNumberFrames];

    if (out_data == NULL) return noErr;

    if ( num_bytes_per_sample == 4 ) {

        if (num_input_channels == 1) {
            memcpy(out_data, (float *)input_buffer->mBuffers[0].mData, input_buffer->mBuffers[0].mDataByteSize);
        } else {
            // FUTUREWORK: mix stereo? well..
            memcpy(out_data, (float *)input_buffer->mBuffers[0].mData, input_buffer->mBuffers[0].mDataByteSize);
        }
    } else if (num_bytes_per_sample == 2) {
        if (num_input_channels == 1) {
            vDSP_vflt16((SInt16 *)input_buffer->mBuffers[0].mData, 1, out_data, 1, inNumberFrames);
        } else {
            // FUTUREWORK: mix stereo? well..
            vDSP_vflt16((SInt16 *)input_buffer->mBuffers[0].mData, 1, out_data, 1, inNumberFrames);
        }

        float scale = 1.0 / (float)INT16_MAX;
        vDSP_vsmul(out_data, 1, &scale, out_data, 1, inNumberFrames * num_input_channels);
    }

    [sm _pushOutput];

    return noErr;
}

OSStatus __audio_input_callback_i16(void *inRefCon,
                                    AudioUnitRenderActionFlags * ioActionFlags,
                                    const AudioTimeStamp  * inTimeStamp,
                                    UInt32 inOutputBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList * ioData)
{
    MALRawAudioCapture *sm = (__bridge MALRawAudioCapture *)inRefCon;

    if (!sm.playing || sm.interrupted) return noErr;

    AudioBufferList *input_buffer = sm.input_buffer;

    OSStatus result;
    ASSERT((result = AudioUnitRender(sm.io_unit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, input_buffer)) == noErr, return result);

    UInt32 num_bytes_per_sample = sm.num_bytes_per_sample;
    NSInteger num_input_channels = sm.num_input_channels;

    int16_t *out_data = [sm _getOutputPointer:inNumberFrames];

    if (out_data == NULL) return noErr;

    if ( num_bytes_per_sample == 4 ) {
        float *work_float = sm.work_float;
        if (num_input_channels == 1) {

            float scale = (float)INT16_MAX;
            vDSP_vsmul((float *)input_buffer->mBuffers[0].mData, 1, &scale, work_float, 1, inNumberFrames);
            vDSP_vfix16(work_float, 1, out_data, 1, inNumberFrames);
        } else {
            // FUTUREWORK: mix stereo? well..
            float scale = (float)INT16_MAX;
            vDSP_vsmul((float *)input_buffer->mBuffers[0].mData, 1, &scale, work_float, 1, inNumberFrames);
            vDSP_vfix16(work_float, 1, out_data, 1, inNumberFrames);
        }
    } else if (num_bytes_per_sample == 2) {
        if (num_input_channels == 1) {
            memcpy(out_data, (float *)input_buffer->mBuffers[0].mData, input_buffer->mBuffers[0].mDataByteSize);
        } else {
            // FUTUREWORK: mix stereo? well..
            memcpy(out_data, (float *)input_buffer->mBuffers[0].mData, input_buffer->mBuffers[0].mDataByteSize);
        }
    }

    [sm _pushOutput];
    
    return noErr;
}

- (BOOL)_setupAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];

    NSError *error = nil;

    ASSERT(session.inputAvailable == YES, return NO);

    ASSERT([session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error] == YES, DBG(@"%@", error);return NO);
    ASSERT([session setPreferredIOBufferDuration:0.0232 error:&error] == YES, DBG(@"%@", error);return NO);
    ASSERT([session setActive:YES error:&error] == YES, DBG(@"%@", error);return NO);
    ASSERT([session setPreferredSampleRate:44100 error:&error] == YES, DBG(@"%@", error);return NO);

    NSInteger num_input_channels = session.inputNumberOfChannels;

    DBG(@"AVAudio: input channels = %d", (int)num_input_channels);
    DBG(@"AVAudio: output channels = %d", (int)session.outputNumberOfChannels);
    DBG(@"AVAudio: sample rate = %.f", session.sampleRate);

    _num_input_channels = num_input_channels;

    return YES;
}

- (AudioUnit)_setupAudioUnitInput
{
    AudioComponentDescription input_description = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_RemoteIO,
        .componentManufacturer = kAudioUnitManufacturer_Apple
    };

    AudioComponent input_component = AudioComponentFindNext(NULL, &input_description);

    OSStatus result;
    AudioUnit io_unit;

    ASSERT((result = AudioComponentInstanceNew(input_component, &io_unit)) == noErr, goto error);

    // enable michrophone input which is disabled by default.
    UInt32 flag = 1;
    ASSERT((result = AudioUnitSetProperty(io_unit,
                                          kAudioOutputUnitProperty_EnableIO,
                                          kAudioUnitScope_Input,
                                          1,
                                          &flag,
                                          sizeof(flag))) == noErr, goto error);

    // disable output to ensure it will never be used
    flag = 0;
    ASSERT((result = AudioUnitSetProperty(io_unit,
                                          kAudioOutputUnitProperty_EnableIO,
                                          kAudioUnitScope_Output,
                                          0,
                                          &flag,
                                          sizeof(flag))) == noErr, goto error);

    return io_unit;

error:
    DBG(@"%08x", (int)result);

    if (io_unit) {
        AudioComponentInstanceDispose(io_unit);
    }
    
    return NULL;
}

- (BOOL)_setupAudioUnitCallbacks:(AudioUnit)io_unit
{
    AURenderCallbackStruct callback_struct = {};
    switch (_format) {
        case MAL_RAWAUDIO_FORMAT_PCM_FLOAT32:
            callback_struct.inputProc = __audio_input_callback_float;
            break;
        case MAL_RAWAUDIO_FORMAT_PCM_INT16:
            callback_struct.inputProc = __audio_input_callback_i16;
            break;
        default:
            NSASSERT(!"unexpected format");
            break;
    }

    callback_struct.inputProcRefCon = (__bridge void *)self;

    // since we are only interested in audio input,
    // it is suffice to set an input callback only that pulls the audio buffer
    // by AudioUnitRender() in it.
    OSStatus result;
    ASSERT((result = AudioUnitSetProperty(io_unit,
                                          kAudioOutputUnitProperty_SetInputCallback,
                                          kAudioUnitScope_Global,
                                          0,
                                          &callback_struct,
                                          sizeof(callback_struct))) == noErr, DBG(@"%08x", (int)result); return NO);
    
    return YES;
}

- (BOOL)_setupAudioUnitBuffer:(AudioUnit)io_unit
{

    OSStatus result;

    AudioStreamBasicDescription input_asbd, output_asbd;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    ASSERT((result = AudioUnitGetProperty(io_unit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Input,
                                          1, // remote input
                                          &input_asbd,
                                          &size)) == noErr, DBG(@"%08x", (int)result); return NO);

    ASSERT((result = AudioUnitGetProperty(io_unit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Output,
                                          1, // remote input
                                          &output_asbd,
                                          &size)) == noErr, DBG(@"%08x", (int)result); return NO);

    input_asbd.mSampleRate = 44100.0f;
    output_asbd.mSampleRate = 44100.0f;

    UInt32 num_bytes_per_sample = input_asbd.mBitsPerChannel / 8;
    DBG(@"AVAudio: bytes per sample = %zd", num_bytes_per_sample);

    ASSERT((result = AudioUnitSetProperty(io_unit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Output,
                                          1, // remote input
                                          &output_asbd,
                                          sizeof(AudioStreamBasicDescription))) == noErr, DBG(@"%08x", (int)result); return NO);

    UInt32 num_frames_per_buffer;
    size = sizeof(UInt32);
    ASSERT((result = AudioUnitGetProperty(io_unit,
                                          kAudioUnitProperty_MaximumFramesPerSlice,
                                          kAudioUnitScope_Global,
                                          0, // remote output
                                          &num_frames_per_buffer,
                                          &size)) == noErr, DBG(@"%08x", (int)result); return NO);
    UInt32 input_buffer_size = output_asbd.mBytesPerFrame * output_asbd.mFramesPerPacket * num_frames_per_buffer;

    BOOL is_interleaved;
    if (output_asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
        DBG("Input is not interleaved\n");
        is_interleaved = NO;

        UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * output_asbd.mChannelsPerFrame);

        _input_buffer = (AudioBufferList *)malloc(propsize);
        _input_buffer->mNumberBuffers = output_asbd.mChannelsPerFrame;

        for(UInt32 i = 0; i< _input_buffer->mNumberBuffers ; ++i) {
            _input_buffer->mBuffers[i].mNumberChannels = 1;
            _input_buffer->mBuffers[i].mDataByteSize = input_buffer_size;
            _input_buffer->mBuffers[i].mData = malloc(input_buffer_size);
            memset(_input_buffer->mBuffers[i].mData, 0, input_buffer_size);
        }

    } else {
        DBG ("Input is interleaved\n");
        is_interleaved = YES;

        UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * 1);

        _input_buffer = (AudioBufferList *)malloc(propsize);
        _input_buffer->mNumberBuffers = 1;
        _input_buffer->mBuffers[0].mNumberChannels = output_asbd.mChannelsPerFrame;
        _input_buffer->mBuffers[0].mDataByteSize = num_frames_per_buffer;
        _input_buffer->mBuffers[0].mData = malloc(num_frames_per_buffer);

        memset(_input_buffer->mBuffers[0].mData, 0, num_frames_per_buffer);
    }

    _num_bytes_per_sample = num_bytes_per_sample;
    _is_interleaved = is_interleaved;
    _work_float = (float *)calloc(num_frames_per_buffer * sizeof(float) * _num_input_channels, 1);

    return YES;
}

- (BOOL)_setupAudioUnitInitialize:(AudioUnit)io_unit
{
    OSStatus result;

    ASSERT((result = AudioUnitInitialize(io_unit)) == noErr, DBG(@"%08x", (int)result); return NO);

    return YES;
}

- (void)_cleanup
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    FREE(_work_float);

    if (_input_buffer) {
        for (UInt32 i = 0; i< _input_buffer->mNumberBuffers ; ++i) {
            FREE(_input_buffer->mBuffers[i].mData);
        }
        FREE(_input_buffer);
    }

    if (_io_unit) {
        AudioComponentInstanceDispose(_io_unit);
        _io_unit = NULL;
    }
}

- (void)dealloc
{
    [self _cleanup];
}

- (void)appendMetaInfo:(MALRawAudioFreight *)captured_buf
{
    // override
}

- (BOOL)_forceStart
{
    if (__granted) {
        ASSERT([[AVAudioSession sharedInstance] isInputAvailable] == YES, return NO);

        OSStatus result;
        ASSERT((result = AudioOutputUnitStart(_io_unit)) == noErr, DBG(@"%08x", (int)result); return NO);
    }

    return YES;
}

- (void)start
{
    if (_playing) return;

    ASSERT([self _forceStart] == YES, return);

    _playing = YES;
}

- (void)pause
{
    if (!_playing) return;

    OSStatus result;
    ASSERT((result = AudioOutputUnitStop(_io_unit)) == noErr, DBG(@"%08x", (int)result); return);

    _playing = NO;
}

@end
