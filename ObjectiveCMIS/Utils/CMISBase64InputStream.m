/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CMISBase64InputStream.h"
#import "CMISBase64Encoder.h"
#import "CMISConstants.h"
#import "CMISAtomEntryWriter.h"
#import "CMISLog.h"

NSString * HTTPSPACE = @" ";

/**
 * The class inherits from NSInputStream and implements the NSStreamDelegate.
 * In order to work with NSURL loading system, 3 methods have to be implemented:
    * - (void)_scheduleInCFRunLoop:(CFRunLoopRef)runLoop forMode:(CFStringRef)mode
    * - (BOOL)_setCFClientFlags:(CFOptionFlags)flags callback:(CFReadStreamClientCallBack)callback context:(CFStreamClientContext*)context
    * - (void)_unscheduleInCFRunLoop:(CFRunLoopRef)runLoop forMode:(CFStringRef)mode
 * See the following blogs on this subject
 * http://blog.octiplex.com/2011/06/how-to-implement-a-corefoundation-toll-free-bridged-nsinputstream-subclass/
 * http://bjhomer.blogspot.co.uk/2011/04/subclassing-nsinputstream.html
 *
 * The 3 methods are Core Foundation methods. The underscore implies they are private API calls.
 * The class does not call any of the 3 methods directly. Nevertheless, they MUST be provided in cases where the inputstream is being used in
 * URL connections. E.g. when the HTTPBodyStream property on NSMutableURLRequest is set to the subclass of an NSInputStream.
 * If the 3 methods are NOT provided, the app will crash with "[unrecognized selector...." errors.
 * 
 * For an alternative approach to use base64 encoding while streaming, take a look at the class
 * CMISHttpUploadRequest
 */


@interface CMISBase64InputStream ()
{
	CFReadStreamClientCallBack copiedCallback;
	CFStreamClientContext copiedContext;
	CFOptionFlags requestedEvents;
}
@property (nonatomic, strong) NSInputStream * nonEncodedStream;
@property (nonatomic, weak) id<NSStreamDelegate> delegate;
@property (nonatomic, assign) NSStreamStatus streamStatus;
@property (nonatomic, assign) NSUInteger nonEncodedBytes;
@property (nonatomic, assign) BOOL encodedStreamHasBytesAvailable;
@property (nonatomic, strong) CMISAtomEntryWriter *atomEntryWriter;
@property (nonatomic, strong) NSData *xmlContentClosure;
@property (nonatomic, assign, readwrite) NSUInteger encodedBytes;
@property (nonatomic, strong) NSMutableData * residualDataBuffer;
+ (NSUInteger)base64EncodedLength:(NSUInteger)contentSize;
+ (NSInteger)base64BufferLength:(NSInteger)rawLength;
- (void)prepareXML;
- (void)storeResidualBytesFromBuffer:(NSData *)buffer fullSize:(NSInteger)expectedLength allowedSize:(NSInteger)actualLength;

@end



@implementation CMISBase64InputStream
@synthesize delegate = _delegate;

- (id)initWithInputStream:(NSInputStream *)nonEncodedStream
           cmisProperties:(CMISProperties *)cmisProperties
                 mimeType:(NSString *)mimeType
          nonEncodedBytes:(NSUInteger)nonEncodedBytes
{
    self = [super init];
    if (nil != self)
    {
        self.nonEncodedStream = nonEncodedStream;
        [_nonEncodedStream setDelegate:self];
        [self setDelegate:self];
        _streamStatus = NSStreamStatusNotOpen;
        self.nonEncodedBytes = nonEncodedBytes;
        self.encodedBytes = 0;
        self.atomEntryWriter = [[CMISAtomEntryWriter alloc] init];
        self.atomEntryWriter.cmisProperties = cmisProperties;
        self.atomEntryWriter.mimeType = mimeType;
        [self prepareXML];
    }
    return self;
}

- (id<NSStreamDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<NSStreamDelegate>)delegate
{
    if (nil == delegate)
    {
        _delegate = self;
    }
    else
    {
        _delegate = delegate;
    }
}


- (void)open
{
    _streamStatus = NSStreamStatusOpen;
    self.encodedStreamHasBytesAvailable = YES;
        
    if (self.nonEncodedStream.streamStatus != NSStreamStatusOpen)
    {
        [self.nonEncodedStream open];
    }
    else
    {
        [self.nonEncodedStream setProperty:[NSNumber numberWithInt:0] forKey:NSStreamFileCurrentOffsetKey];
    }
}

- (void)close
{
    _streamStatus = NSStreamStatusClosed;
    if (self.nonEncodedStream.streamStatus != NSStreamStatusClosed)
    {
        [self.nonEncodedStream close];
    }
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    // this doesn't seem to be called. But you never know
    [self.nonEncodedStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    // this doesn't seem to be called. But you never know
    [self.nonEncodedStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (NSStreamStatus)streamStatus
{
    // we probably cannot simply pass through the original source status. In case the source stream closes before we
    // have read in all encoded and XML data
    NSStreamStatus status = self.nonEncodedStream.streamStatus;
    return status;
}

- (NSError *)streamError
{
    NSError *error = [self.nonEncodedStream streamError];
    CMISLogError(@"error in raw data stream: code = %d message = %@", [error code], [error localizedDescription]);
    return error;
}

/**
 there are 2 main operations in this read method. 
 A.) read in the raw data and encode them
 B.) copy the encoded bytes and any required encapsulating XML data into the read buffer passed in to the method
 
 Because the amount of data we read in from the source is not equal to the amount of data we need to fill the overall inputstream with, we need to do some
 byte jiggling.
 
 Basically, we create 3 buffers
 1. writeBuffer - this contains data to be copied into the read buffer passed into this method. The size of this must NOT exceed maxLength
 2. encodedBuffer - this is the base64 encoded data set - after we read in chunk of data from the original source
 3. residualDataBuffer - this contains any bytes we couldn't store into writeBuffer as it would have exceeded the allowed buffer size
 
 - At the beginning of each read call we clear out the residualDataBuffer as much as we can. If this means, that the maxLength is reached we return straightaway with a
   complete read buffer
 - We then read in from the source. This will be in multiples of 3 - to avoid any base64 padding at the end, which is only permitted at the end of a base64 encoded
   data set.
 - All the time we keep track of any residual bytes we could not write out to the read buffer and store them until the next read.
 
 We know the input stream has ended if the read from the source returns less bytes than requested (or 0). In this case we get the closing XML elements.
 We have to be careful to tell the stream that it has still bytes available at that point.
 
 Any read error from the source will be passed straight on - there is no point in continuing if that happens.
 */
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    NSMutableData *writeBuffer = [NSMutableData data];
    if (self.residualDataBuffer.length > 0)
    {
        [writeBuffer appendData:self.residualDataBuffer];
        [self.residualDataBuffer setLength:0];
    }

    NSInteger bytesOut = len - writeBuffer.length;
    if (0 >= bytesOut)
    {
        [writeBuffer getBytes:buffer length:len];
        [self storeResidualBytesFromBuffer:writeBuffer fullSize:writeBuffer.length allowedSize:len];
        return len;
    }
    
    NSUInteger rawMaxLength = [CMISBase64InputStream base64BufferLength:len];
    uint8_t rawBuffer[rawMaxLength];
    NSInteger rawDataReadIn = [self.nonEncodedStream read:rawBuffer maxLength:rawMaxLength];
    
    if ( 0 < rawDataReadIn )
    {
        NSMutableData *encodedBuffer = [NSMutableData dataWithData:[CMISBase64Encoder dataByEncodingText:[NSData dataWithBytes:rawBuffer
                                                                                                                        length:rawDataReadIn]]];
        
        //if the read data is less than requested we reached the end. Add closing XML elements
        if (rawDataReadIn < rawMaxLength) {
            [encodedBuffer appendData:self.xmlContentClosure];
        }
        NSInteger encodedTotalLength = encodedBuffer.length;
        NSUInteger encodedOutLength = (bytesOut <= encodedTotalLength) ? bytesOut : encodedTotalLength;
        
        [self storeResidualBytesFromBuffer:encodedBuffer fullSize:encodedTotalLength allowedSize:encodedOutLength];
        
        [writeBuffer appendData:[encodedBuffer subdataWithRange:NSMakeRange(0, encodedOutLength)]];
        
        NSUInteger encodedBytes = writeBuffer.length;
        [writeBuffer getBytes:buffer length:encodedBytes];
        return encodedBytes;
    }
    else if( 0 == rawDataReadIn )
    {
        //at this stage we have reached the end of the source input stream. Read out any residual bytes
        //be careful, as we may have more than 1 maxLength buffer left
        NSUInteger bufferLength = writeBuffer.length;
        bytesOut = (bufferLength <= len) ? bufferLength : len;
        if (0 < bytesOut) {
            [self storeResidualBytesFromBuffer:writeBuffer fullSize:bufferLength allowedSize:len];
            [writeBuffer getBytes:buffer length:bytesOut];
        }
        else
            self.encodedStreamHasBytesAvailable = NO;
        return bytesOut;
    }
    
    self.encodedStreamHasBytesAvailable = NO;
    return -1;
    
//    return [self.nonEncodedStream read:buffer maxLength:len];
}




- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len
{
    ///hmmm - we never seem to enter this method
    if (self.nonEncodedStream)
    {
        return [self.nonEncodedStream getBuffer:buffer length:len];
    }
	return NO;
}

- (BOOL)hasBytesAvailable
{
    BOOL rawDataAvailable = [self.nonEncodedStream hasBytesAvailable];
    if (rawDataAvailable || self.encodedStreamHasBytesAvailable)
    {
        return YES;
    }
    return NO;
//	return [self.nonEncodedStream hasBytesAvailable];
}


#pragma Private methods based on CFReadStream.
/**
 we must override the following 4 methods - otherwise subclassing NSInputStream will crash
 */

- (void)_scheduleInCFRunLoop:(CFRunLoopRef)runLoop forMode:(CFStringRef)mode
{
    if (_nonEncodedStream)
    {
        CFReadStreamScheduleWithRunLoop((CFReadStreamRef)_nonEncodedStream, runLoop, mode);
    }
}

- (BOOL)_setCFClientFlags:(CFOptionFlags)flags
                 callback:(CFReadStreamClientCallBack)callback
                  context:(CFStreamClientContext*)context
{
    if (NULL != callback)
    {
        requestedEvents = flags;
        copiedCallback = callback;
        memcpy(&copiedContext, context, sizeof(CFStreamClientContext));
        if (copiedContext.info && copiedContext.retain)
        {
            copiedContext.retain(copiedContext.info);
        }
    }
    else
    {
        requestedEvents = kCFStreamEventNone;
        copiedCallback = NULL;
        if (copiedContext.info && copiedContext.retain)
        {
            copiedContext.retain(copiedContext.info);
        }
        memset(&copiedContext, 0, sizeof(CFStreamClientContext));
    }
    return YES;
}

/**
 */
- (void)_unscheduleInCFRunLoop:(CFRunLoopRef)runLoop forMode:(CFStringRef)mode
{
    if (_nonEncodedStream)
    {
        CFReadStreamUnscheduleFromRunLoop((CFReadStreamRef)_nonEncodedStream, runLoop, mode);
    }
}

- (void)stream:(NSStream *)aStream
   handleEvent:(NSStreamEvent)eventCode {
	
//    NSLog(@"**** we are in the NSStream delegate method stream:handleEvent");
	assert(aStream == _nonEncodedStream);
	
	switch (eventCode) {
		case NSStreamEventOpenCompleted:
//            NSLog(@"**** we are in the NSStream delegate method stream:handleEvent NSStreamEventOpenCompleted");
			if (requestedEvents & kCFStreamEventOpenCompleted) {
				copiedCallback((__bridge CFReadStreamRef)self,
							   kCFStreamEventOpenCompleted,
							   copiedContext.info);
			}
			break;
			
		case NSStreamEventHasBytesAvailable:
//            NSLog(@"**** we are in the NSStream delegate method stream:handleEvent NSStreamEventHasBytesAvailable");
			if (requestedEvents & kCFStreamEventHasBytesAvailable) {
				copiedCallback((__bridge CFReadStreamRef)self,
							   kCFStreamEventHasBytesAvailable,
							   copiedContext.info);
			}
			break;
			
		case NSStreamEventErrorOccurred:
//            NSLog(@"**** we are in the NSStream delegate method stream:handleEvent NSStreamEventErrorOccurred");
			if (requestedEvents & kCFStreamEventErrorOccurred) {
				copiedCallback((__bridge CFReadStreamRef)self,
							   kCFStreamEventErrorOccurred,
							   copiedContext.info);
			}
			break;
			
		case NSStreamEventEndEncountered:
//            NSLog(@"**** we are in the NSStream delegate method stream:handleEvent NSStreamEventEndEncountered");
			if (requestedEvents & kCFStreamEventEndEncountered) {
				copiedCallback((__bridge CFReadStreamRef)self,
							   kCFStreamEventEndEncountered,
							   copiedContext.info);
			}
			break;
			
		case NSStreamEventHasSpaceAvailable:
//            not sure this makes sense in this case;
			break;
			
		default:
			break;
	}
}

#pragma private methods
- (void)storeResidualBytesFromBuffer:(NSData *)buffer
                            fullSize:(NSInteger)fullSize
                         allowedSize:(NSInteger)allowedSize
{
    NSInteger restSize = fullSize - allowedSize;
    if (0 < restSize) {
        [self.residualDataBuffer appendData:[buffer subdataWithRange:NSMakeRange(allowedSize, restSize)]];
        self.encodedStreamHasBytesAvailable = YES;
    }
}

+ (NSUInteger)base64EncodedLength:(NSUInteger)contentSize
{
    if (0 == contentSize)
    {
        return 0;
    }
    NSUInteger adjustedThirdPartOfSize = (contentSize / 3) + ( (0 == contentSize % 3 ) ? 0 : 1 );
    
    return 4 * adjustedThirdPartOfSize;
}

- (void)prepareXML
{
    self.encodedBytes = [CMISBase64InputStream base64EncodedLength:self.nonEncodedBytes];
    NSMutableData *startData = [NSMutableData data];
    [startData appendData:[[self.atomEntryWriter xmlStartElement] dataUsingEncoding:NSUTF8StringEncoding]];
    [startData appendData:[[self.atomEntryWriter xmlContentStartElement] dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    NSMutableData *endData = [NSMutableData data];
    [endData appendData:[[self.atomEntryWriter xmlContentEndElement] dataUsingEncoding:NSUTF8StringEncoding]];
    [endData appendData:[[self.atomEntryWriter xmlPropertiesElements] dataUsingEncoding:NSUTF8StringEncoding]];
    
    self.xmlContentClosure = endData;
    self.encodedBytes += startData.length;
    self.encodedBytes += endData.length;
    self.residualDataBuffer = [NSMutableData dataWithData:startData];
}

+ (NSInteger)base64BufferLength:(NSInteger)rawLength
{
    NSInteger base64Length = (rawLength / 3) * 3;
    if (0 == base64Length) {
        base64Length = rawLength;
    }
    return base64Length;
}


@end
