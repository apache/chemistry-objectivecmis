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

/*
 The base64 Encoding part of this class is based on the PostController.m class
 of the sample app 'SimpleURLConnections' provided by Apple.
 http://developer.apple.com/library/ios/#samplecode/SimpleURLConnections/Introduction/Intro.html
*/

#import "CMISHttpUploadRequest.h"
#import "CMISBase64Encoder.h"
#import "CMISAtomEntryWriter.h"
#import "CMISLog.h"
/**
 this is the buffer size for the input/output stream pair containing the base64 encoded data
 */
const NSUInteger kFullBufferSize = 32768;
/**
 this is the buffer size for the raw data. It must be an integer multiple of 3. Base64 encoding uses
 4 bytes for each 3 bytes of raw data. Therefore, the amount of raw data we take is
 kFullBufferSize/4 * 3.
 */
const NSUInteger kRawBufferSize = 24576;

/**
 A category that extends the NSStream class in order to pair an inputstream with an outputstream.
 The input stream will be used by NSURLConnection via the HTTPBodyStream property of the URL request.
 The paired output stream will buffer base64 encoded as well as XML data.
 
 NOTE: the original sample code also provides a method for backward compatibility w.r.t  iOS versions below 5.0
 However, since the CMIS library is only to be used with iOS version 5.1 and higher, this code is obsolete and has
 been omitted here.
 */

@interface NSStream (StreamPair)
+ (void)createBoundInputStream:(NSInputStream **)inputStreamPtr
                  outputStream:(NSOutputStream **)outputStreamPtr;
@end

@implementation NSStream (StreamPair)
+ (void)createBoundInputStream:(NSInputStream **)inputStreamPtr
                  outputStream:(NSOutputStream **)outputStreamPtr
{
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;
    
    assert( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );
    
    readStream = NULL;
    writeStream = NULL;
    CFStreamCreateBoundPair(
                            NULL,
                            ((inputStreamPtr  != nil) ? &readStream : NULL),
                            ((outputStreamPtr != nil) ? &writeStream : NULL),
                            (CFIndex) kFullBufferSize
                            );
    
    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
}
@end


@interface CMISHttpUploadRequest ()

@property (nonatomic, assign) unsigned long long bytesUploaded;
@property (nonatomic, copy) void (^progressBlock)(unsigned long long bytesUploaded, unsigned long long bytesTotal);
@property (nonatomic, assign) BOOL base64Encoding;
@property (nonatomic, strong) NSInputStream * base64InputStream;
@property (nonatomic, strong) NSOutputStream * encoderStream;
@property (nonatomic, strong) NSData * streamStartData;
@property (nonatomic, strong) NSData * streamEndData;
@property (nonatomic, assign) unsigned long long encodedLength;
@property (nonatomic, strong) NSData                    *   dataBuffer;
@property (nonatomic, assign, readwrite) size_t             bufferOffset;
@property (nonatomic, assign, readwrite) size_t             bufferLimit;

- (void)stopSendWithStatus:(NSString *)statusString;
+ (NSUInteger)base64EncodedLength:(NSUInteger)contentSize;
- (void)prepareXMLWithCMISProperties:(CMISProperties *)cmisProperties mimeType:(NSString *)mimeType;
- (void)prepareStreams;

- (id)initWithHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
         completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
           progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock;

@end


@implementation CMISHttpUploadRequest


+ (id)startRequest:(NSMutableURLRequest *)urlRequest
                            httpMethod:(CMISHttpRequestMethod)httpRequestMethod
                           inputStream:(NSInputStream*)inputStream
                               headers:(NSDictionary*)additionalHeaders
                         bytesExpected:(unsigned long long)bytesExpected
                authenticationProvider:(id<CMISAuthenticationProvider>) authenticationProvider
                      useTrustedSSLServer:(BOOL)trustedSSLServer
                       completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
                         progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    CMISHttpUploadRequest *httpRequest = [[self alloc] initWithHttpMethod:httpRequestMethod
                                                          completionBlock:completionBlock
                                                            progressBlock:progressBlock];
    httpRequest.inputStream = inputStream;
    httpRequest.additionalHeaders = additionalHeaders;
    httpRequest.bytesExpected = bytesExpected;
    httpRequest.authenticationProvider = authenticationProvider;
    httpRequest.base64Encoding = NO;
    httpRequest.base64InputStream = nil;
    httpRequest.encoderStream = nil;
    httpRequest.trustedSSLServer = trustedSSLServer;
    
    if ([httpRequest startRequest:urlRequest] == NO) {
        httpRequest = nil;
    }
    
    return httpRequest;
}

+ (id)startRequest:(NSMutableURLRequest *)urlRequest
        httpMethod:(CMISHttpRequestMethod)httpRequestMethod
       inputStream:(NSInputStream*)inputStream
           headers:(NSDictionary*)addionalHeaders
     bytesExpected:(unsigned long long)bytesExpected
authenticationProvider:(id<CMISAuthenticationProvider>) authenticationProvider
    cmisProperties:(CMISProperties *)cmisProperties
          mimeType:(NSString *)mimeType
  useTrustedSSLServer:(BOOL)trustedSSLServer
   completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
     progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    CMISHttpUploadRequest *httpRequest = [[self alloc] initWithHttpMethod:httpRequestMethod
                                                          completionBlock:completionBlock
                                                            progressBlock:progressBlock];
    
    httpRequest.inputStream = inputStream;
    httpRequest.additionalHeaders = addionalHeaders;
    httpRequest.bytesExpected = bytesExpected;
    httpRequest.base64Encoding = YES;
    httpRequest.authenticationProvider = authenticationProvider;
    httpRequest.trustedSSLServer = trustedSSLServer;
    
    [httpRequest prepareStreams];
    [httpRequest prepareXMLWithCMISProperties:cmisProperties mimeType:mimeType];
    if ([httpRequest startRequest:urlRequest] == NO) {
        httpRequest = nil;
    }
    
    return httpRequest;
}


- (id)initWithHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
         completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
           progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    self = [super initWithHttpMethod:httpRequestMethod
                     completionBlock:completionBlock];
    if (self) {
        _progressBlock = progressBlock;
    }
    return self;
}


/**
 if we are using on-the-go base64 encoding, we will use the base64InputStream in URL connections/request.
 In this case a little extra work is required: i.e. we need to provide the length of the encoded data stream (including
 the XML data).
 */
- (BOOL)startRequest:(NSMutableURLRequest*)urlRequest
{
    if (self.base64Encoding)
    {
        if (self.base64InputStream) {
            urlRequest.HTTPBodyStream = self.base64InputStream;
            NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:self.additionalHeaders];
            [headers setValue:[NSString stringWithFormat:@"%llu", self.encodedLength] forKey:@"Content-Length"];
            self.additionalHeaders = [NSDictionary dictionaryWithDictionary:headers];
//            [self.encoderStream open];
        }
    }
    else
    {
        if (self.inputStream) {
            urlRequest.HTTPBodyStream = self.inputStream;
        }
    }
    BOOL startSuccess = [super startRequest:urlRequest];
    if (self.base64Encoding) {
        [self.encoderStream open];
    }

    return startSuccess;
}

#pragma CMISCancellableRequest method
- (void)cancel
{
    self.progressBlock = nil;
    
    [super cancel];
    if (self.base64Encoding) {
        [self stopSendWithStatus:@"connection has been cancelled."];
    }
}

#pragma NSURLConnectionDataDelegate methods
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [super connection:connection didReceiveResponse:response];
    
    self.bytesUploaded = 0;
}

- (void)connection:(NSURLConnection *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (self.progressBlock) {
        if (self.bytesExpected == 0) {
            self.progressBlock((NSUInteger)totalBytesWritten, (NSUInteger)totalBytesExpectedToWrite);
        } else {
            self.progressBlock((NSUInteger)totalBytesWritten, self.bytesExpected);
        }
    }
}


/**
 In addition to closing the connection we also have to close/reset all streams used in this class.
 This is for base64 encoding only
 */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [super connection:connection didFailWithError:error];
    
    if (self.base64Encoding) {
        [self stopSendWithStatus:@"connection is being terminated with error."];
    }
    self.progressBlock = nil;
}


/**
 In addition to closing the connection we also have to close/reset all streams used in this class.
 This is for base64 encoding only
 */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [super connectionDidFinishLoading:connection];
    if (self.base64Encoding) {
        [self stopSendWithStatus:@"Connection finished as expected."];
    }
    
    self.progressBlock = nil;
}

#pragma NSStreamDelegate method
/**
 For encoding base64 data - this is the meat of this class.
 The action is in the case where the eventCode == NSStreamEventHasSpaceAvailable
 
 Note 1:
 The output stream (encoderStream) is paired with the encoded input stream (base64InputStream) which is the one
 the active URL connection uses to read from. Thereby any data made available to the outputstream will be available to this input stream as well.
 Any action on the output stream (like close) will also affect this base64InputStream.
 
 Note 2:
 since we are encoding "on the fly" we are dealing with 2 different buffer sizes. The encoded buffer size kFullBufferSize, and the
 buffer size of the raw/non-encoded data kRawBufferSize.
 
 Note 3:
 the reading from the source input stream, as well as the writing to the encoderStream is regulated via 2 variables: bufferLimit and bufferOffset
 bufferLimit is the size of the XML data or the No of bytes read in from the raw data set (inputstream)
 At each readIn, the bufferOffset will be reset to 0 to indicate a free buffer to write to.
 When the data are finally written to the output stream, both bufferLimit and bufferOffset should be having the same value (unless we attempt to
 write more bytes than are available in the buffer).
 
 Once we reach the end of the raw data set, both bufferLimit and bufferOffset are set to 0. This indicates that the outputStream (and its paired
 input stream) can be closed.
 
 (Final Note:The Apple source code discourages removing the stream from the runloop in this method as it can cause random crashes.)
 */
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode){
        case NSStreamEventOpenCompleted:{
            if (self.inputStream.streamStatus != NSStreamStatusOpen) {
                [self.inputStream open];
            }
        }
            break;
        case NSStreamEventHasBytesAvailable: {
        } break;
        case NSStreamEventHasSpaceAvailable: {
            /*
             first we check if we can fill the output stream buffer with data
             the criteria for that is that bufferOffset equals the buffer limit
             */
            if (self.base64InputStream) {
                NSStreamStatus inputStatus = self.base64InputStream.streamStatus;
                if (inputStatus == NSStreamStatusNotOpen || inputStatus == NSStreamStatusClosed) {
                    CMISLogDebug(@"*** Base 64 Input Stream is not yet open or closed. The status is %d ***", inputStatus);
                }
                else if (inputStatus == NSStreamStatusAtEnd){
                    CMISLogDebug(@"*** Base 64 Input Stream has reached the end ***");
                }
                else if (inputStatus == NSStreamStatusError){
                    CMISLogDebug(@"Input stream error");
                    [self stopSendWithStatus:@"Network read error"];
                }
            }
            
            
            if (self.bufferOffset == self.bufferLimit) {
                if (self.streamStartData != nil) {
                    self.streamStartData = nil;
                    self.bufferOffset = 0;
                    self.bufferLimit = 0;
                }
                if (self.inputStream != nil) {
                    NSInteger rawBytesRead;
                    uint8_t rawBuffer[kRawBufferSize];
                    rawBytesRead = [self.inputStream read:rawBuffer maxLength:kRawBufferSize];
                    if (-1 == rawBytesRead) {
                        [self stopSendWithStatus:@"Error while reading from source input stream"];
                    }
                    else if (0 != rawBytesRead){
                        NSData *encodedBuffer = [CMISBase64Encoder dataByEncodingText:[NSData dataWithBytes:rawBuffer length:rawBytesRead]];
                        self.dataBuffer = [NSData dataWithData:encodedBuffer];
                        self.bufferOffset = 0;
                        self.bufferLimit = encodedBuffer.length;
                    }
                    else{
                        [self.inputStream close];
                        self.inputStream = nil;
                        self.bufferOffset = 0;
                        self.bufferLimit = self.streamEndData.length;
                        self.dataBuffer = [NSData dataWithData:self.streamEndData];
                    }
                    if ((self.bufferLimit == self.bufferOffset) && self.encoderStream != nil) {
                        self.encoderStream.delegate = nil;
                        [self.encoderStream close];
                    }
                }
                
                if ((self.bufferOffset == self.bufferLimit) && (self.encoderStream != nil)) {
                    self.encoderStream.delegate = nil;
                    [self.encoderStream close];
                }
                
            }
            if (self.bufferOffset != self.bufferLimit) {
                NSUInteger length = self.dataBuffer.length;
                uint8_t buffer[length];
                [self.dataBuffer getBytes:buffer length:length];
                NSInteger bytesWritten;
                bytesWritten = [self.encoderStream write:&buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                if (bytesWritten <= 0) {
                    [self stopSendWithStatus:@"Network write error"];
                }
                else{
                    self.bufferOffset += bytesWritten;
                }
            }
            
        }break;
        case NSStreamEventErrorOccurred: {
            [self stopSendWithStatus:@"Stream open error"];
        }break;
        case NSStreamEventEndEncountered: {
        }break;
        default:
            break;
    }
}


#pragma private methods
- (void)prepareXMLWithCMISProperties:(CMISProperties *)cmisProperties mimeType:(NSString *)mimeType
{
    self.bufferOffset = 0;
    CMISAtomEntryWriter *writer = [[CMISAtomEntryWriter alloc] init];
    writer.cmisProperties = cmisProperties;
    writer.mimeType = mimeType;
    
    NSString *xmlStart = [writer xmlStartElement];
    NSString *xmlContentStart = [writer xmlContentStartElement];
    
    NSString *start = [NSString stringWithFormat:@"%@%@", xmlStart, xmlContentStart];
    self.streamStartData = [NSMutableData dataWithData:[start dataUsingEncoding:NSUTF8StringEncoding]];
    self.bufferLimit = self.streamStartData.length;
    self.dataBuffer = [NSData dataWithData:self.streamStartData];
    
    NSString *xmlContentEnd = [writer xmlContentEndElement];
    NSString *xmlProperties = [writer xmlPropertiesElements];
    NSString *end = [NSString stringWithFormat:@"%@%@", xmlContentEnd, xmlProperties];
    self.streamEndData = [end dataUsingEncoding:NSUTF8StringEncoding];
    
    NSUInteger encodedLength = [CMISHttpUploadRequest base64EncodedLength:self.bytesExpected];
    encodedLength += start.length;
    encodedLength += end.length;
    self.encodedLength = encodedLength;
}

- (void)prepareStreams
{
    /*
     */
    if (self.inputStream.streamStatus != NSStreamStatusOpen) {
        [self.inputStream open];
    }
    
    NSInputStream *requestInputStream;
    NSOutputStream *outputStream;
    [NSStream createBoundInputStream:&requestInputStream outputStream:&outputStream];
    assert(requestInputStream != nil);
    assert(outputStream != nil);
    self.base64InputStream = requestInputStream;
    self.encoderStream = outputStream;
    self.encoderStream.delegate = self;
    [self.encoderStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
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

- (void)stopSendWithStatus:(NSString *)statusString
{
    if(nil != statusString)
        CMISLogDebug([NSString stringWithFormat:@"Upload request terminated: Message is %@", statusString]);
    self.bufferOffset = 0;
    self.bufferLimit  = 0;
    self.dataBuffer = nil;
    if (self.connection != nil) {
        [self.connection cancel];
        self.connection = nil;
    }
    if (self.encoderStream != nil) {
        self.encoderStream.delegate = nil;
        [self.encoderStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.encoderStream close];
        self.encoderStream = nil;
    }
    self.base64InputStream = nil;
    if(self.inputStream != nil){
        [self.inputStream close];
        self.inputStream = nil;
    }
    self.streamEndData = nil;
    self.streamStartData = nil;
}


@end
