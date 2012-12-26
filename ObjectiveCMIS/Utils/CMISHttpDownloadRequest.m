/*
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "CMISHttpDownloadRequest.h"
#import "CMISErrors.h"

@interface CMISHttpDownloadRequest ()

@property (nonatomic, copy) void (^progressBlock)(unsigned long long bytesDownloaded, unsigned long long bytesTotal);
@property (nonatomic, assign) unsigned long long bytesDownloaded;

@end


@implementation CMISHttpDownloadRequest

@synthesize outputStream = _outputStream;
@synthesize progressBlock = _progressBlock;
@synthesize bytesDownloaded = _bytesDownloaded;
@synthesize bytesExpected = _bytesExpected;

+ (CMISHttpDownloadRequest*)startRequest:(NSMutableURLRequest *)urlRequest
                          withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
                            outputStream:(NSOutputStream*)outputStream
                           bytesExpected:(unsigned long long)bytesExpected
                  authenticationProvider:(id<CMISAuthenticationProvider>) authenticationProvider
                         completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
                           progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock;
{
    CMISHttpDownloadRequest *httpRequest = [[self alloc] initWithHttpMethod:httpRequestMethod
                                                            completionBlock:completionBlock
                                                              progressBlock:progressBlock];
    httpRequest.outputStream = outputStream;
    httpRequest.bytesExpected = bytesExpected;
    httpRequest.authenticationProvider = authenticationProvider;
    
    if ([httpRequest startRequest:urlRequest] == NO) {
        httpRequest = nil;
    };
    
    return httpRequest;
}


- (id)initWithHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
         completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
           progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock
{
    self = [super initWithHttpMethod:httpRequestMethod
                     completionBlock:completionBlock];
    if (self) {
        _progressBlock = progressBlock;
    }
    return self;
}


- (void)cancel
{
    [self.outputStream close];
    
    self.progressBlock = nil;
    
    [super cancel];
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [super connection:connection didReceiveResponse:response];
    
    // update statistics
    if (self.bytesExpected == 0 && response.expectedContentLength != NSURLResponseUnknownLength) {
        self.bytesExpected = response.expectedContentLength;
    }
    self.bytesDownloaded = 0;

    // set up output stream if available
    if (self.outputStream) { // otherwise store data in memory in self.data
        // create file for downloaded content
        BOOL isStreamReady = self.outputStream.streamStatus == NSStreamStatusOpen;
        if (!isStreamReady) {
            [self.outputStream open];
            isStreamReady = self.outputStream.streamStatus == NSStreamStatusOpen;
        }
    
        if (!isStreamReady) {
            [connection cancel];
            
            if (self.completionBlock)
            {
                NSError *cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeStorage
                                                 withDetailedDescription:@"Could not open output stream"];
                self.completionBlock(nil, cmisError);
            }
        }
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (self.outputStream == nil) { // if there is no outputStream then store data in memory in self.data
        [super connection:connection didReceiveData:data];
    } else {
        const uint8_t *bytes = data.bytes;
        NSUInteger length = data.length;
        NSUInteger offset = 0;
        do {
            NSUInteger written = [self.outputStream write:&bytes[offset] maxLength:length - offset];
            if (written <= 0) {
                log(@"Error while writing downloaded data to file");
                [connection cancel];
                return;
            } else {
                offset += written;
            }
        } while (offset < length);
    }
    
    // update statistics
    self.bytesDownloaded += data.length;
    // pass progress to progressBlock
    if (self.progressBlock) {
        self.progressBlock(self.bytesDownloaded, self.bytesExpected);
    }
    
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.outputStream close];

    self.progressBlock = nil;

    [super connection:connection didFailWithError:error];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.outputStream close];

    self.progressBlock = nil;

    [super connectionDidFinishLoading:connection];
}

@end
