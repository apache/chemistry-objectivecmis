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

#import "CMISHttpRequest.h"
#import "CMISHttpUtil.h"
#import "CMISHttpResponse.h"
#import "CMISErrors.h"
#import "CMISAuthenticationProvider.h"

//Exception names as returned in the <!--exception> tag
NSString * const kCMISExceptionInvalidArgument         = @"invalidArgument";
NSString * const kCMISExceptionNotSupported            = @"notSupported";
NSString * const kCMISExceptionObjectNotFound          = @"objectNotFound";
NSString * const kCMISExceptionPermissionDenied        = @"permissionDenied";
NSString * const kCMISExceptionRuntime                 = @"runtime";
NSString * const kCMISExceptionConstraint              = @"constraint";
NSString * const kCMISExceptionContentAlreadyExists    = @"contentAlreadyExists";
NSString * const kCMISExceptionFilterNotValid          = @"filterNotValid";
NSString * const kCMISExceptionNameConstraintViolation = @"nameConstraintViolation";
NSString * const kCMISExceptionStorage                 = @"storage";
NSString * const kCMISExceptionStreamNotSupported      = @"streamNotSupported";
NSString * const kCMISExceptionUpdateConflict          = @"updateConflict";
NSString * const kCMISExceptionVersioning              = @"versioning";


@implementation CMISHttpRequest

@synthesize requestMethod = _requestMethod;
@synthesize requestBody = _requestBody;
@synthesize responseBody = _responseBody;
@synthesize additionalHeaders = _additionalHeaders;
@synthesize response = _response;
@synthesize authenticationProvider = _authenticationProvider;
@synthesize completionBlock = _completionBlock;
@synthesize connection = _connection;

+ (CMISHttpRequest*)startRequest:(NSMutableURLRequest *)urlRequest
                  withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
                     requestBody:(NSData*)requestBody
                         headers:(NSDictionary*)additionalHeaders
          authenticationProvider:(id<CMISAuthenticationProvider>) authenticationProvider
                 completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    CMISHttpRequest *httpRequest = [[self alloc] initWithHttpMethod:httpRequestMethod
                                                    completionBlock:completionBlock];
    httpRequest.requestBody = requestBody;
    httpRequest.additionalHeaders = additionalHeaders;
    httpRequest.authenticationProvider = authenticationProvider;
    
    if ([httpRequest startRequest:urlRequest] == NO) {
        httpRequest = nil;
    }
    
    return httpRequest;
}


- (id)initWithHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
         completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    self = [super init];
    if (self) {
        _requestMethod = httpRequestMethod;
        _completionBlock = completionBlock;
    }
    return self;
}


- (BOOL)startRequest:(NSMutableURLRequest*)urlRequest
{
    if (self.requestBody) {
        [urlRequest setHTTPBody:self.requestBody];
    }
    
    [self.authenticationProvider.httpHeadersToApply enumerateKeysAndObjectsUsingBlock:^(NSString *headerName, NSString *header, BOOL *stop) {
        [urlRequest addValue:header forHTTPHeaderField:headerName];
    }];
    
    [self.additionalHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *headerName, NSString *header, BOOL *stop) {
        [urlRequest addValue:header forHTTPHeaderField:headerName];
    }];
    
    self.connection = [NSURLConnection connectionWithRequest:urlRequest delegate:self];
    if (self.connection) {
        return YES;
    } else {
        if (self.completionBlock) {
            NSString *detailedDescription = [NSString stringWithFormat:@"Could not create connection to %@", urlRequest.URL];
            NSError *cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection withDetailedDescription:detailedDescription];
            self.completionBlock(nil, cmisError);
        }
        return NO;
    }
}

- (void)cancel
{
    if (self.connection) {
        void (^completionBlock)(CMISHttpResponse *httpResponse, NSError *error);
        completionBlock = self.completionBlock; // remember completion block in order to invoke it after the connection was cancelled
        
        self.completionBlock = nil; // prevent potential NSURLConnection delegate callbacks to invoke the completion block redundantly
        
        [self.connection cancel];
        
        self.connection = nil;
        
        NSError *cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeCancelled withDetailedDescription:@"Request was cancelled"];
        completionBlock(nil, cmisError);
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseBody = [[NSMutableData alloc] init];
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        self.response = (NSHTTPURLResponse*)response;
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.responseBody appendData:data];
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.authenticationProvider updateWithHttpURLResponse:self.response];

    if (self.completionBlock) {
        CMISErrorCodes cmisErrorCode = (error.code == NSURLErrorCancelled) ? kCMISErrorCodeCancelled : kCMISErrorCodeConnection;
        NSError *cmisError = [CMISErrors cmisError:error withCMISErrorCode:cmisErrorCode];
        self.completionBlock(nil, cmisError);
    }
    
    self.completionBlock = nil;
    
    self.connection = nil;
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.authenticationProvider updateWithHttpURLResponse:self.response];
    
    if (self.completionBlock) {
        NSError *cmisError = nil;
        CMISHttpResponse *httpResponse = [CMISHttpResponse responseUsingURLHTTPResponse:self.response andData:self.responseBody];
        if ([self checkStatusCodeForResponse:httpResponse withHttpRequestMethod:self.requestMethod error:&cmisError]) {
            self.completionBlock(httpResponse, nil);
        } else {
            self.completionBlock(nil, cmisError);
        }
    }
    
    self.completionBlock = nil;
    
    self.connection = nil;
}

- (BOOL)checkStatusCodeForResponse:(CMISHttpResponse *)response withHttpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod error:(NSError **)error
{
    if ( (httpRequestMethod == HTTP_GET && response.statusCode != 200)
        || (httpRequestMethod == HTTP_POST && response.statusCode != 201)
        || (httpRequestMethod == HTTP_DELETE && response.statusCode != 204)
        || (httpRequestMethod == HTTP_PUT && ((response.statusCode < 200 || response.statusCode > 299))))
    {
        log(@"Error content: %@", [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
        
        if (error) {
            NSString *exception = response.exception;
            NSString *errorMessage = response.errorMessage;
            if (errorMessage == nil) {
                errorMessage = response.statusCodeMessage; // fall back to HTTP error message
            }
            
            switch (response.statusCode)
            {
                case 400:
                    if ([exception isEqualToString:kCMISExceptionFilterNotValid]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeFilterNotValid
                                             withDetailedDescription:errorMessage];
                    } else {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                             withDetailedDescription:errorMessage];
                    }
                    break;
                case 401:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeUnauthorized
                                         withDetailedDescription:errorMessage];
                    break;
                case 403:
                    if ([exception isEqualToString:kCMISExceptionStreamNotSupported]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeStreamNotSupported
                                             withDetailedDescription:errorMessage];
                    } else {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodePermissionDenied
                                             withDetailedDescription:errorMessage];
                    }
                    break;
                case 404:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound
                                         withDetailedDescription:errorMessage];
                    break;
                case 405:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeNotSupported
                                         withDetailedDescription:errorMessage];
                    break;
                case 407:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeProxyAuthentication
                                         withDetailedDescription:errorMessage];
                    break;
                case 409:
                    if ([exception isEqualToString:kCMISExceptionContentAlreadyExists]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeContentAlreadyExists
                                             withDetailedDescription:errorMessage];
                    } else if ([exception isEqualToString:kCMISExceptionVersioning]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeVersioning
                                             withDetailedDescription:errorMessage];
                    } else if ([exception isEqualToString:kCMISExceptionUpdateConflict]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeUpdateConflict
                                             withDetailedDescription:errorMessage];
                    } else if ([exception isEqualToString:kCMISExceptionNameConstraintViolation]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeNameConstraintViolation
                                             withDetailedDescription:errorMessage];
                    } else {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConstraint
                                             withDetailedDescription:errorMessage];
                    }
                    break;
                default:
                    if ([exception isEqualToString:kCMISExceptionStorage]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeStorage
                                             withDetailedDescription:errorMessage];
                    } else {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                             withDetailedDescription:response.errorMessage];
                    }
            }
        }
        return NO;
    } else {
        return YES;
    }
}

@end
