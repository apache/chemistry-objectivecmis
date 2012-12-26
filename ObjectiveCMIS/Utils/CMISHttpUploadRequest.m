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
#import "CMISHttpUploadRequest.h"

@interface CMISHttpUploadRequest ()

@property (nonatomic, assign) unsigned long long bytesUploaded;
@property (nonatomic, copy) void (^progressBlock)(unsigned long long bytesUploaded, unsigned long long bytesTotal);

@end


@implementation CMISHttpUploadRequest

@synthesize inputStream = _inputStream;
@synthesize progressBlock = _progressBlock;
@synthesize bytesExpected = _bytesExpected;
@synthesize bytesUploaded = _bytesUploaded;

+ (CMISHttpUploadRequest*)startRequest:(NSMutableURLRequest *)urlRequest
                        withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
                           inputStream:(NSInputStream*)inputStream
                               headers:(NSDictionary*)additionalHeaders
                         bytesExpected:(unsigned long long)bytesExpected
                authenticationProvider:(id<CMISAuthenticationProvider>) authenticationProvider
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
    
    if ([httpRequest startRequest:urlRequest]) {
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


- (BOOL)startRequest:(NSMutableURLRequest*)urlRequest
{
    if (self.inputStream) {
        urlRequest.HTTPBodyStream = self.inputStream;
    }

    return [super startRequest:urlRequest];
}


- (void)cancel
{
    self.progressBlock = nil;
    
    [super cancel];
}


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


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [super connection:connection didFailWithError:error];
    
    self.progressBlock = nil;
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [super connectionDidFinishLoading:connection];
    
    self.progressBlock = nil;
}


@end
