//
//  AppDelegate.h
//  videoCompressionTest
//
//  Created by INDIGO on 08/11/17.
//  Copyright © 2017 Kallysta. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#include <CoreServices/CoreServices.h>
#include <CoreAudio/CoreAudio.h>
@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    AVCaptureSession *_captureSession;
    AVSampleBufferDisplayLayer *_videoLayer;
    dispatch_queue_t _captureQueue;
    AVCaptureVideoPreviewLayer *_prevLayer;
    
    AVCaptureConnection* _audioConnection;
    AVCaptureConnection* _videoConnection;
    dispatch_queue_t _audioQueue;
}
@property (weak) IBOutlet NSView *previewView;
@property (weak) IBOutlet NSView *outputView;

@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
@property (nonatomic, assign) VTDecompressionSessionRef decompressionSession;
@property (nonatomic, retain) AVSampleBufferDisplayLayer *videoLayer;
@property (nonatomic, assign) int spsSize;
@property (nonatomic, assign) int ppsSize;

- (IBAction)startSession:(id)sender ;
- (IBAction)stopSession:(id)sender;

-(void)CompressAndConvertToData:(CMSampleBufferRef)sampleBuffer;

@end

