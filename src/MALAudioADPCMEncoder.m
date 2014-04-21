//
//  MALAudioADPCMEncoder.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/17.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include <arm_neon.h>
#import "MALAudioADPCMEncoder.h"

// IMA ADPCM Implementation referred:
// http://ww1.microchip.com/downloads/en/AppNotes/00643b.pdf

/* Table of index changes */
static const int IndexTable[16] = {
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8
};

/* Quantizer step size lookup table */
static const int32_t StepSizeTable[89] = {
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
};

@interface MALAudioADPCMEncoder() {
    int32_t _prevsample;
    int32_t _previndex;
}

@end

@implementation MALAudioADPCMEncoder

#if 0
static inline int16_t __decode_sample(const uint8_t code, int32_t *p_prevsample, int32_t *p_previndex)
{
    /* Restore previous values of predicted sample and quantizer step
     size index
     */
    int32_t predsample = *p_prevsample;
    int index = *p_previndex;
    /* Find quantizer step size from lookup table using index
     */
    int32_t step = StepSizeTable[index];
    /* Inverse quantize the ADPCM code into a difference using the
     quantizer step size
     */
    int32_t diffq = step >> 3;
    if( code & 4 ) diffq += step;
    if( code & 2 ) diffq += step >> 1;
    if( code & 1 ) diffq += step >> 2;
    /* Add the difference to the predicted sample
     */
    if( code & 8 ) {
        predsample -= diffq;
    } else {
        predsample += diffq;
    }
    /* Check for overflow of the new predicted sample*/
    if( predsample > 32767 ) {
        predsample = 32767;
    } else if( predsample < -32768 ) {
        predsample = -32768;
    }
    /* Find new quantizer step size by adding the old index and a
     table lookup using the ADPCM code
     */
    index += IndexTable[code];
    /* Check for overflow of the new quantizer step size index
     */
    if( index < 0 ) index = 0;
    if( index > 88 ) index = 88;
    /* Save predicted sample and quantizer step size index for next
     iteration
     */
    *p_prevsample = predsample;
    *p_previndex = index;

    return predsample;
}

#endif

static inline uint8_t __encode_sample(int32_t sample, int32_t *p_prevsample, int32_t *p_previndex)
{
    uint8_t code; /* ADPCM output value */

    /* Restore previous values of predicted sample and quantizer step
     size index
     */
    int32_t predsample = *p_prevsample; /* Output of ADPCM predictor */
    int index = *p_previndex; /* Index into step size table */
    const int32_t step = StepSizeTable[index]; /* Quantizer step size */

    /* Compute the difference between the actual sample (sample) and the
     the predicted sample (predsample)
     */
    int32_t diff = sample - predsample; /* Difference between sample and predicted sample */
    if(diff >= 0) {
        code = 0;
    } else {
        code = 8;
        diff = -diff;
    }
    /* Quantize the difference into the 4-bit ADPCM code using the
     the quantizer step size
     */
    int32_t tempstep = step;  /* Temporary step size */
    if( diff >= tempstep ) {
        code |= 4;
        diff -= tempstep;
    }
    tempstep >>= 1;
    if( diff >= tempstep ) {
        code |= 2;
        diff -= tempstep;
    }
    tempstep >>= 1;
    if( diff >= tempstep ) code |= 1;
    /* Inverse quantize the ADPCM code into a predicted difference
     using the quantizer step size
     */
    int32_t diffq = step >> 3; /* Dequantized predicted difference */
    if( code & 4 ) diffq += step;
    if( code & 2 ) diffq += step >> 1;
    if( code & 1 ) diffq += step >> 2;
    /* Fixed predictor computes new predicted sample by adding the
     old predicted sample to predicted difference
     */
    if( code & 8 ) {
        predsample -= diffq;
    } else {
        predsample += diffq;
    }
    /* Check for overflow of the new predicted sample
     */
    if( predsample > 32767 ) {
        predsample = 32767;
    } else if( predsample < -32768 ) {
        predsample = -32768;
    }
    /* Find new quantizer stepsize index by adding the old index
     to a table lookup using the ADPCM code
     */
    index += IndexTable[code];
    /* Check for overflow of the new quantizer step size index
     */
    if( index < 0 ) index = 0;
    if( index > 88 ) index = 88;

/*
    int32_t dummy_prevsample = *p_prevsample;
    int32_t dummy_previndex = *p_previndex;
    int16_t decoded = __decode_sample(code, &dummy_prevsample, &dummy_previndex);
    if (decoded != predsample) {
        abort();
    }
 */
    /* Save the predicted sample and quantizer step size index for
     next iteration
     */
    *p_prevsample = predsample;
    *p_previndex = index;



    return code;
}

#define UNROLL2(code) code code
#define UNROLL4(code) UNROLL2(code) UNROLL2(code)
#define UNROLL8(code) UNROLL4(code) UNROLL4(code)
#define UNROLL16(code) UNROLL8(code) UNROLL8(code)

static void __encode_adpcm_simd(const int16_t *samples, size_t num_samples, uint8_t *dst,
                                int32_t *p_prevsample, int32_t *p_previndex)
{
    int32_t prevsample = *p_prevsample;
    int previndex = *p_previndex;

    int cycles = num_samples / 16;
/*
    while (cycles > 0) {
        uint64_t code16 = 0ULL;

        UNROLL16({
            code16 = code16 << 4;
            code16 |= __encode_sample(*samples, &prevsample, &previndex);;
            ++samples;
        });

        uint8x8_t code16_vector = vrev64_u8(vcreate_u8(code16));
        vst1_u8(dst, code16_vector);
        --cycles;
        dst += 8;
    }
 */
    while (cycles > 0) {
        uint8x8_t code16;

        code16[0] = __encode_sample(*samples++, &prevsample, &previndex) << 4;
        code16[0] |= __encode_sample(*samples++, &prevsample, &previndex);

        code16[1] = __encode_sample(*samples++, &prevsample, &previndex) << 4;
        code16[1] |= __encode_sample(*samples++, &prevsample, &previndex);

        code16[2] = __encode_sample(*samples++, &prevsample, &previndex) << 4;
        code16[2] |= __encode_sample(*samples++, &prevsample, &previndex);

        code16[3] = __encode_sample(*samples++, &prevsample, &previndex) << 4;
        code16[3] |= __encode_sample(*samples++, &prevsample, &previndex);

        code16[4] = __encode_sample(*samples++, &prevsample, &previndex) << 4;
        code16[4] |= __encode_sample(*samples++, &prevsample, &previndex);

        code16[5] = __encode_sample(*samples++, &prevsample, &previndex) << 4;
        code16[5] |= __encode_sample(*samples++, &prevsample, &previndex);

        code16[6] = __encode_sample(*samples++, &prevsample, &previndex) << 4;
        code16[6] |= __encode_sample(*samples++, &prevsample, &previndex);

        code16[7] = __encode_sample(*samples++, &prevsample, &previndex) << 4;
        code16[7] |= __encode_sample(*samples++, &prevsample, &previndex);

        vst1_u8(dst, code16);
        --cycles;
        dst += 8;
    }

    *p_previndex = previndex;
    *p_prevsample = prevsample;
}
/*
static void __encode_adpcm(const int16_t *samples, size_t num_samples, uint8_t *dst)
{
    int32_t prevsample = 0;
    int previndex = 0;

    for (int i = 0; i < num_samples; ++i) {
        uint8_t code = __encode_sample(samples[i], &prevsample, &previndex);
        if ((i % 2) == 1) {
            dst[i/2] |= code;
        } else {
            dst[i/2] = code << 4;
        }
    }
}
 */

static void __decode_adpcm(const uint8_t *nibbles, size_t num_samples, float *dst)
{
    int32_t prevsample = 0;
    int previndex = 0;

    for (int i = 0; i < num_samples; ++i) {
        uint8_t code;
        if ((i % 2) == 1) {
            code = nibbles[i/2] & 0xf;
        } else {
            code = (nibbles[i/2] >> 4) & 0xf;
        }
        /* Restore previous values of predicted sample and quantizer step
         size index
         */
        int32_t predsample = prevsample;
        int index = previndex;
        /* Find quantizer step size from lookup table using index
         */
        int32_t step = StepSizeTable[index];
        /* Inverse quantize the ADPCM code into a difference using the
         quantizer step size
         */
        int32_t diffq = step >> 3;
        if( code & 4 ) diffq += step;
        if( code & 2 ) diffq += step >> 1;
        if( code & 1 ) diffq += step >> 2;
        /* Add the difference to the predicted sample
         */
        if( code & 8 ) {
            predsample -= diffq;
        } else {
            predsample += diffq;
        }
        /* Check for overflow of the new predicted sample*/
        if( predsample > 32767 ) {
            predsample = 32767;
        } else if( predsample < -32768 ) {
            predsample = -32768;
        }
        /* Find new quantizer step size by adding the old index and a
         table lookup using the ADPCM code
         */
        index += IndexTable[code];
        /* Check for overflow of the new quantizer step size index
         */
        if( index < 0 ) index = 0;
        if( index > 88 ) index = 88;
        /* Save predicted sample and quantizer step size index for next
         iteration
         */
        prevsample = predsample;
        previndex = index;

        /* Return the new speech sample */
        dst[i] = predsample / (float)0x7FFF;
    }
}

+ (instancetype)create
{
    MALAudioADPCMEncoder *obj = [[[self class] alloc] init];

    ASSERT([obj _setup], return nil);

    return obj;
}

- (BOOL)_setup
{
    _previndex = 0;
    _prevsample = 0;
    
    return YES;
}

- (BOOL)process:(VSRawAudioFreight *)src to:(VSEncodedAudioFreight *)dst
{
    ASSERT(src.format == VSRAWAUDIO_FORMAT_PCM_INT16, return NO);
    ASSERT(dst.format == VSENCODED_AUDIO_FORMAT_ADPCM, return NO);

    size_t num_samples = src.num_samples;
    uint8_t *dst_u8 = (uint8_t *)[dst invalidateRange:(num_samples / 2)];

    ASSERT(dst_u8 != NULL, return NO);

    //BENCHMARK("encode adpcm")
    const int16_t *in_i16 = src.data.bytes;
    //uint8_t *check = malloc(num_samples /2);

    dst.start_sample = _prevsample;
    dst.start_index = _previndex;

    BENCHMARK("adpcm simd")
    __encode_adpcm_simd(in_i16, num_samples, dst_u8, &_prevsample, &_previndex);

    //BENCHMARK("adpcm scholar")
    //__encode_adpcm(in_i16, num_samples, check);

    //free(check);
    return YES;
}

-(BOOL)debugDecode:(MCVByteFreight *)src to:(VSRawAudioFreight *)dst
{
    ASSERT(dst.format == VSRAWAUDIO_FORMAT_PCM_FLOAT32, return NO);

    float *dst_float = (float *)[dst invalidateRange:(src.data.length * 8)];

    ASSERT(dst_float != NULL, return NO);

    __decode_adpcm(src.data.bytes, src.data.length * 2, dst_float);

    return YES;
}
@end
