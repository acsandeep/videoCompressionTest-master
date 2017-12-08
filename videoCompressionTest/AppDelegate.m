//
//  AppDelegate.m
//  videoCompressionTest
//
//  Created by INDIGO on 08/11/17.
//  Copyright © 2017 Kallysta. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

static AppDelegate *appDel = nil;
void OutputCallback(void *outputCallbackRefCon,
                    void *sourceFrameRefCon,
                    OSStatus status,
                    VTEncodeInfoFlags infoFlags,
                    CMSampleBufferRef sampleBuffer) {
    // Check if there were any errors encoding
    if (status != noErr) {
        NSLog(@"Error encoding video, err=%lld", (int64_t)status);
        return;
    }
    if(appDel)
        [appDel CompressAndConvertToData:sampleBuffer];
}



@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _captureQueue = dispatch_queue_create("AVCapture2", 0);
    [self initCaptureSession];
    appDel = self;
    [self initSampleBufferDisplayLayer];
    [_previewView.layer setBackgroundColor:[NSColor blackColor].CGColor];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}



- (IBAction)startSession:(id)sender {
    if (![_captureSession isRunning]) {
        
        NSRect r1 =[_prevLayer frame];
        r1.size = [_previewView frame].size;
        [_prevLayer setFrame:r1];
        [_captureSession startRunning];
    }
}

- (IBAction)stopSession:(id)sender {
    if ([_captureSession isRunning]) {
        [_captureSession stopRunning];
    }
}

- (void)initSampleBufferDisplayLayer
{
    _videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
    [_videoLayer setFrame:(CGRect){.origin=CGPointZero, .size=_outputView.frame.size}];
    _videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _videoLayer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
    _videoLayer.layoutManager  = [CAConstraintLayoutManager layoutManager];
    _videoLayer.autoresizingMask = kCALayerHeightSizable | kCALayerWidthSizable;
    _videoLayer.contentsGravity = kCAGravityResizeAspect;
    [_outputView.layer addSublayer:_videoLayer];
}


- (void)initCaptureSession
{
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession beginConfiguration];
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if(!captureDevice)
        NSLog(@"Error in getting capture device");
    NSError *error;
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if(input)
        [_captureSession addInput:input];
    else
    {
        NSLog(@"Error = %@", [error description]);
    }
    
    //Audio input
    // if([_audioPreviewBtn state])
    [self AddAudioInputAndOutputWithPreview:YES];
    //  else
    //     [self AddAudioInputAndOutputWithPreview:NO];
    
    
    //-- Create the output for the capture session.
    AVCaptureVideoDataOutput * dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [dataOutput setAlwaysDiscardsLateVideoFrames:YES]; // Probably want to set this to NO when recording
    
    for (int i = 0; i < dataOutput.availableVideoCVPixelFormatTypes.count; i++) {
        char fourr[5] = {0};
        *((int32_t *)fourr) = CFSwapInt32([dataOutput.availableVideoCVPixelFormatTypes[i] intValue]);
        //NSLog(@"%s", fourr);
    }
    
    NSDictionary* videoSettings ;
    
    //  if([_videoSettingsSelection state])
    {
        videoSettings = [self imageDisplaySettings];
    }
    //    else
    //    {
    //        videoSettings = [self OpenGlSettings];
    //    }
    if(videoSettings)
        [dataOutput setVideoSettings:videoSettings];
    
    // Set dispatch to be on the main thread so OpenGL can do things with the data
    [dataOutput setSampleBufferDelegate:self queue:_captureQueue];
    
    [_captureSession setSessionPreset:AVCaptureSessionPresetLow];
    
    
    
    NSAssert([_captureSession canAddOutput:dataOutput], @"can't output");
    [_captureSession addOutput:dataOutput];
    _videoConnection = [dataOutput connectionWithMediaType:AVMediaTypeVideo];
    [self AddAudioInputAndOutputToSession];
    
    [_captureSession commitConfiguration];
    [self AddingPreviewLayer];
}


-(void)AddAudioInputAndOutputToSession
{
    NSError *error = nil;
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    if (error) {
        NSLog(@"Error getting audio input device: %@", error.description);
    }
    if ([_captureSession canAddInput:audioInput]) {
        [_captureSession addInput:audioInput];
    }
    
    _audioQueue = dispatch_queue_create("Audio Queue", DISPATCH_QUEUE_SERIAL);
    AVCaptureAudioDataOutput* audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioOutput setSampleBufferDelegate:self queue:_audioQueue];
    if ([_captureSession canAddOutput:audioOutput]) {
        [_captureSession addOutput:audioOutput];
    }
    _audioConnection = [audioOutput connectionWithMediaType:AVMediaTypeAudio];
}



-(NSDictionary*)imageDisplaySettings
{
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    
    return [NSDictionary dictionaryWithObject:value forKey:key];
}

-(void)AddingPreviewLayer
{
    _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession: _captureSession];
    _prevLayer.frame = CGRectMake(0, 0, [_previewView frame].size.width, [_previewView frame].size.height);
    _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [[_previewView layer] addSublayer: _prevLayer];
}

-(void)AddAudioInputAndOutputWithPreview:(BOOL)preview
{
    NSError* error;
    AVCaptureDevice* audioDevice     = [AVCaptureDevice defaultDeviceWithMediaType: AVMediaTypeAudio];
    
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error ];
    
    if(preview)
    {
        AVCaptureAudioPreviewOutput* audioOutput = [[AVCaptureAudioPreviewOutput alloc] init];
        
        audioOutput.volume = 1.0;
        
        [_captureSession addOutput:audioOutput];
    }
    
    [_captureSession addInput:audioInput];
    
    AVCaptureAudioDataOutput* audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    [_captureSession addOutput:audioDataOutput];
    
    dispatch_queue_t audioDataOutputQueue = dispatch_queue_create( "com.example.capturesession.audiodata", DISPATCH_QUEUE_SERIAL );
    
    [audioDataOutput setSampleBufferDelegate:(id)self queue:audioDataOutputQueue];
}

#pragma mark - AVCaptureOutput callback

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if (connection == _videoConnection) {
        [self CompressFrames:sampleBuffer];
    }
    
    if (connection == _audioConnection)
    {
        
    }
}


-(void)CompressFrames:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    NSLog(@"Width = %d height = %d", (int)width, (int) height);
    
    
    VTCompressionSessionRef session;
    OSStatus ret = VTCompressionSessionCreate(NULL, (int)width, (int)height, kCMVideoCodecType_H264, NULL, NULL, NULL, OutputCallback, NULL, &session);
    if (ret == noErr) {
        VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        
        CMTime presentationTimestamp = CMTimeMake(20, 30);
        VTCompressionSessionEncodeFrame(session, imageBuffer, presentationTimestamp, kCMTimeInvalid, NULL, NULL, NULL);
        VTCompressionSessionEndPass(session, false, NULL);
    }
    
    if (session) {
        VTCompressionSessionInvalidate(session);
        CFRelease(session);
    }
}

-(void)CompressAndConvertToData:(CMSampleBufferRef)sampleBuffer
{
    NSMutableData *elementaryStream = [NSMutableData data];
    
    OSStatus status;
    // Find out if the sample buffer contains an I-Frame.
    // If so we will write the SPS and PPS NAL units to the elementary stream.
    BOOL isIFrame = NO;
    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, 0);
    if (CFArrayGetCount(attachmentsArray)) {
        CFBooleanRef notSync;
        CFDictionaryRef dict = CFArrayGetValueAtIndex(attachmentsArray, 0);
        BOOL keyExists = CFDictionaryGetValueIfPresent(dict,
                                                       kCMSampleAttachmentKey_NotSync,
                                                       (const void **)&notSync);
        // An I-Frame is a sync frame
        isIFrame = !keyExists || !CFBooleanGetValue(notSync);
    }
    
    // This is the start code that we will write to
    // the elementary stream before every NAL unit
    static const size_t startCodeLength = 4;
    static const uint8_t startCode[] = {0x00, 0x00, 0x00, 0x01};
    
    // Write the SPS and PPS NAL units to the elementary stream before every I-Frame
    if (isIFrame) {
        CMFormatDescriptionRef description = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // Find out how many parameter sets there are
        size_t numberOfParameterSets;
        status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           0, NULL, NULL,
                                                           &numberOfParameterSets,
                                                           NULL);
        
        // Write each parameter set to the elementary stream
        for (int i = 0; i < numberOfParameterSets; i++) {
            const uint8_t *parameterSetPointer;
            size_t parameterSetLength;
            status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                               i,
                                                               &parameterSetPointer,
                                                               &parameterSetLength,
                                                               NULL, NULL);
            if(status != noErr) NSLog(@"\t\t Format Description ERROR type: %d", (int)status);
            // Write the parameter set to the elementary stream
            [elementaryStream appendBytes:startCode length:startCodeLength];
            [elementaryStream appendBytes:parameterSetPointer length:parameterSetLength];
        }
    }
    
    // Get a pointer to the raw AVCC NAL unit data in the sample buffer
    size_t blockBufferLength;
    uint8_t *bufferDataPointer = NULL;
    CMBlockBufferGetDataPointer(CMSampleBufferGetDataBuffer(sampleBuffer),
                                0,
                                NULL,
                                &blockBufferLength,
                                (char **)&bufferDataPointer);
    
    // Loop through all the NAL units in the block buffer
    // and write them to the elementary stream with
    // start codes instead of AVCC length headers
    size_t bufferOffset = 0;
    static const int AVCCHeaderLength = 4;
    while (bufferOffset < blockBufferLength - AVCCHeaderLength) { // Read the NAL unit
        
        uint32_t NALUnitLength = 0; memcpy(&NALUnitLength, bufferDataPointer + bufferOffset, AVCCHeaderLength);
        // Convert the length value from Big-endian to Little-endian
        NALUnitLength = CFSwapInt32BigToHost(NALUnitLength); // Write start code to the elementary stream
        [elementaryStream appendBytes:startCode length:startCodeLength]; // Write the NAL unit without the AVCC length header to the elementary stream
        [elementaryStream appendBytes:bufferDataPointer + bufferOffset + AVCCHeaderLength length:NALUnitLength]; // Move to the next NAL unit in the block buffer
        bufferOffset += AVCCHeaderLength + NALUnitLength;
        
        
        
        
    }
    
    uint8_t *bytes = (uint8_t*)[elementaryStream bytes];
    int size = (int)[elementaryStream length];
    
    [self receivedRawVideoFrame:bytes withSize:size];




}


#pragma mark - Decompression code

-(void) receivedRawVideoFrame:(uint8_t *)frame withSize:(uint32_t)frameSize
{
    OSStatus status;
    
    uint8_t *data = NULL;
    uint8_t *pps = NULL;
    uint8_t *sps = NULL;
    
    // I know how my H.264 data source's NALUs looks like so I know start code index is always 0.
    // if you don't know where it starts, you can use a for loop similar to how I find the 2nd and 3rd start codes
    int startCodeIndex = 0;
    int secondStartCodeIndex = 0;
    int thirdStartCodeIndex = 0;
    
    long blockLength = 0;
    
    CMSampleBufferRef sampleBuffer = NULL;
    CMBlockBufferRef blockBuffer = NULL;
    
    int nalu_type = (frame[startCodeIndex + 4] & 0x1F);
    NSLog(@"~~~~~~~ Received NALU Type \"%d\" ~~~~~~~~", nalu_type);
    
    // if we havent already set up our format description with our SPS PPS parameters, we
    // can't process any frames except type 7 that has our parameters
    if (nalu_type != 7 && _formatDesc == NULL)
    {
        NSLog(@"Video error: Frame is not an I Frame and format description is null");
        return;
    }
    
    // NALU type 7 is the SPS parameter NALU
    if (nalu_type == 7)
    {
        // find where the second PPS start code begins, (the 0x00 00 00 01 code)
        // from which we also get the length of the first SPS code
        for (int i = startCodeIndex + 4; i < startCodeIndex + 40; i++)
        {
            if (frame[i] == 0x00 && frame[i+1] == 0x00 && frame[i+2] == 0x00 && frame[i+3] == 0x01)
            {
                secondStartCodeIndex = i;
                _spsSize = secondStartCodeIndex;   // includes the header in the size
                break;
            }
        }
        
        // find what the second NALU type is
        nalu_type = (frame[secondStartCodeIndex + 4] & 0x1F);
        NSLog(@"~~~~~~~ Received NALU Type \"%d\" ~~~~~~~~", nalu_type);
    }
    
    
    // type 8 is the PPS parameter NALU
    if(nalu_type == 8) {
        
        // find where the NALU after this one starts so we know how long the PPS parameter is
        for (int i = _spsSize + 12; i < _spsSize + 50; i++)
        {
            if (frame[i] == 0x00 && frame[i+1] == 0x00 && frame[i+2] == 0x00 && frame[i+3] == 0x01)
            {
                thirdStartCodeIndex = i;
                _ppsSize = thirdStartCodeIndex - _spsSize;
                break;
            }
        }
        
        // allocate enough data to fit the SPS and PPS parameters into our data objects.
        // VTD doesn't want you to include the start code header (4 bytes long) so we add the - 4 here
        sps = malloc(_spsSize - 4);
        pps = malloc(_ppsSize - 4);
        
        // copy in the actual sps and pps values, again ignoring the 4 byte header
        memcpy (sps, &frame[4], _spsSize-4);
        
        //was crashing here
        if(_ppsSize == 0)
            _ppsSize = 4;
        
        
        
        
        memcpy (pps, &frame[_spsSize+4], _ppsSize-4);
        
        // now we set our H264 parameters
        uint8_t*  parameterSetPointers[2] = {sps, pps};
        size_t parameterSetSizes[2] = {_spsSize-4, _ppsSize-4};
        
        status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2,
                                                                     (const uint8_t *const*)parameterSetPointers,
                                                                     parameterSetSizes, 4,
                                                                     &_formatDesc);
        
        NSLog(@"\t\t Creation of CMVideoFormatDescription: %@", (status == noErr) ? @"successful!" : @"failed...");
        if(status != noErr) NSLog(@"\t\t Format Description ERROR type: %d", (int)status);
        
        // See if decomp session can convert from previous format description
        // to the new one, if not we need to remake the decomp session.
        // This snippet was not necessary for my applications but it could be for yours
        /*BOOL needNewDecompSession = (VTDecompressionSessionCanAcceptFormatDescription(_decompressionSession, _formatDesc) == NO);
         if(needNewDecompSession)
         {
         [self createDecompSession];
         }*/
        
        // now lets handle the IDR frame that (should) come after the parameter sets
        // I say "should" because that's how I expect my H264 stream to work, YMMV
        nalu_type = (frame[thirdStartCodeIndex + 4] & 0x1F);
        NSLog(@"~~~~~~~ Received NALU Type \"%d\" ~~~~~~~~", nalu_type);
    }
    
    // create our VTDecompressionSession.  This isnt neccessary if you choose to use AVSampleBufferDisplayLayer
    if((status == noErr) && (_decompressionSession == NULL))
    {
        [self createDecompSession];
    }
    
    // type 5 is an IDR frame NALU.  The SPS and PPS NALUs should always be followed by an IDR (or IFrame) NALU, as far as I know
    if(nalu_type == 5)
    {
        // find the offset, or where the SPS and PPS NALUs end and the IDR frame NALU begins
        int offset = _spsSize + _ppsSize;
        blockLength = frameSize - offset;
        //        NSLog(@"Block Length : %ld", blockLength);
        data = malloc(blockLength);
        data = memcpy(data, &frame[offset], blockLength);
        
        // replace the start code header on this NALU with its size.
        // AVCC format requires that you do this.
        // htonl converts the unsigned int from host to network byte order
        uint32_t dataLength32 = htonl (blockLength - 4);
        memcpy (data, &dataLength32, sizeof (uint32_t));
        
        // create a block buffer from the IDR NALU
        status = CMBlockBufferCreateWithMemoryBlock(NULL, data,  // memoryBlock to hold buffered data
                                                    blockLength,  // block length of the mem block in bytes.
                                                    kCFAllocatorNull, NULL,
                                                    0, // offsetToData
                                                    blockLength,   // dataLength of relevant bytes, starting at offsetToData
                                                    0, &blockBuffer);
        
        NSLog(@"\t\t BlockBufferCreation: \t %@", (status == kCMBlockBufferNoErr) ? @"successful!" : @"failed...");
    }
    
    // NALU type 1 is non-IDR (or PFrame) picture
    if (nalu_type == 1)
    {
        // non-IDR frames do not have an offset due to SPS and PSS, so the approach
        // is similar to the IDR frames just without the offset
        blockLength = frameSize;
        data = malloc(blockLength);
        data = memcpy(data, &frame[0], blockLength);
        
        // again, replace the start header with the size of the NALU
        uint32_t dataLength32 = htonl (blockLength - 4);
        memcpy (data, &dataLength32, sizeof (uint32_t));
        
        status = CMBlockBufferCreateWithMemoryBlock(NULL, data,  // memoryBlock to hold data. If NULL, block will be alloc when needed
                                                    blockLength,  // overall length of the mem block in bytes
                                                    kCFAllocatorNull, NULL,
                                                    0,     // offsetToData
                                                    blockLength,  // dataLength of relevant data bytes, starting at offsetToData
                                                    0, &blockBuffer);
        
        NSLog(@"\t\t BlockBufferCreation: \t %@", (status == kCMBlockBufferNoErr) ? @"successful!" : @"failed...");
    }
    
    // now create our sample buffer from the block buffer,
    if(status == noErr)
    {
        // here I'm not bothering with any timing specifics since in my case we displayed all frames immediately
        const size_t sampleSize = blockLength;
        status = CMSampleBufferCreate(kCFAllocatorDefault,
                                      blockBuffer, true, NULL, NULL,
                                      _formatDesc, 1, 0, NULL, 1,
                                      &sampleSize, &sampleBuffer);
        
        NSLog(@"\t\t SampleBufferCreate: \t %@", (status == noErr) ? @"successful!" : @"failed...");
    }
    
    if(status == noErr)
    {
        // set some values of the sample buffer's attachments
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        
        // either send the samplebuffer to a VTDecompressionSession or to an AVSampleBufferDisplayLayer
        if(sampleBuffer)
        {
            NSLog(@"Got sample Buffer to display");
            [self render:sampleBuffer];
        }
    }
    
    // free memory to avoid a memory leak, do the same for sps, pps and blockbuffer
    if (NULL != data)
    {
        free (data);
        data = NULL;
    }
}

-(void) createDecompSession
{
    // make sure to destroy the old VTD session
    _decompressionSession = NULL;
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = decompressionSessionDecodeFrameCallback;
    
    // this is necessary if you need to make calls to Objective C "self" from within in the callback method.
    callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
    
    // you can set some desired attributes for the destination pixel buffer.  I didn't use this but you may
    // if you need to set some attributes, be sure to uncomment the dictionary in VTDecompressionSessionCreate
    /*NSDictionary *destinationImageBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithBool:YES],
     (id)kCVPixelBufferOpenGLESCompatibilityKey,
     nil];*/
    
    OSStatus status =  VTDecompressionSessionCreate(NULL, _formatDesc, NULL,
                                                    NULL, // (__bridge CFDictionaryRef)(destinationImageBufferAttributes)
                                                    &callBackRecord, &_decompressionSession);
    NSLog(@"Video Decompression Session Create: \t %@", (status == noErr) ? @"successful!" : @"failed...");
    if(status != noErr) NSLog(@"\t\t VTD ERROR type: %d", (int)status);
}

void decompressionSessionDecodeFrameCallback(void *decompressionOutputRefCon,
                                             void *sourceFrameRefCon,
                                             OSStatus status,
                                             VTDecodeInfoFlags infoFlags,
                                             CVImageBufferRef imageBuffer,
                                             CMTime presentationTimeStamp,
                                             CMTime presentationDuration)
{
    
    if (status != noErr)
    {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Decompressed error: %@", error);
    }
    else
    {
        NSLog(@"Decompressed sucessfully");
        
    }
}

- (void) render:(CMSampleBufferRef)sampleBuffer
{
    /*
     VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
     VTDecodeInfoFlags flagOut;
     NSDate* currentTime = [NSDate date];
     VTDecompressionSessionDecodeFrame(_decompressionSession, sampleBuffer, flags,
     (void*)CFBridgingRetain(currentTime), &flagOut);
     
     CFRelease(sampleBuffer);*/
    
    // if you're using AVSampleBufferDisplayLayer, you only need to use this line of code
    if (_videoLayer) {
        NSLog(@"Success ****");
        [_videoLayer enqueueSampleBuffer:sampleBuffer];
    }
    
}






@end
