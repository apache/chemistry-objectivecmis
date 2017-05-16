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

#import "CMISHttpRequest.h"
#import "CMISHttpResponse.h"
#import "CMISErrors.h"
#import "CMISLog.h"
#import "CMISReachability.h"
#import "CMISConstants.h"
#import "CMISURLSessionUtil.h"

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


+ (id)startRequest:(NSMutableURLRequest *)urlRequest
        httpMethod:(CMISHttpRequestMethod)httpRequestMethod
       requestBody:(NSData*)requestBody
           headers:(NSDictionary*)additionalHeaders
           session:(CMISBindingSession *)session
   completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    CMISHttpRequest *httpRequest = [[self alloc] initWithHttpMethod:httpRequestMethod
                                                    completionBlock:completionBlock];
    httpRequest.requestBody = requestBody;
    httpRequest.additionalHeaders = additionalHeaders;
    httpRequest.session = session;
    
    if (![httpRequest startRequest:urlRequest]) {
        httpRequest = nil;
    }
    
    return httpRequest;
}

- (id)initWithHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
         completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    self = [super init];
    if (self) {
        _originalThread = [NSThread currentThread];
        _requestMethod = httpRequestMethod;
        _completionBlock = completionBlock;
    }
    return self;
}


- (BOOL)startRequest:(NSMutableURLRequest*)urlRequest
{
    // check network reachability (unless it's disabled) and return early if appropriate
    id checkNetworkReachability = [self.session objectForKey:kCMISSessionParameterCheckNetworkReachability];
    if (!checkNetworkReachability || [checkNetworkReachability boolValue]) {
        CMISReachability *reachability = [CMISReachability networkReachability];
        if (!reachability.hasNetworkConnection) {
            NSError *noConnectionError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeNoNetworkConnection detailedDescription:kCMISErrorDescriptionNoNetworkConnection];
            [self URLSession:self.urlSession task:self.sessionTask didCompleteWithError:noConnectionError];
            return NO;
        }
    }
    
    if (self.requestBody) {
        if ([CMISLog sharedInstance].logLevel == CMISLogLevelTrace) {
            CMISLogTrace(@"Request body: %@", [[NSString alloc] initWithData:self.requestBody encoding:NSUTF8StringEncoding]);
        }
        
        [urlRequest setHTTPBody:self.requestBody];
    }
    
    void (^continueWithStartRequest)(NSDictionary*) = ^(NSDictionary *headers) {
        [headers enumerateKeysAndObjectsUsingBlock:^(NSString *headerName, id header, BOOL *stop) {
            if ([header isKindOfClass:NSSet.class]) {
                for (NSString *headerValue in header) {
                    [urlRequest addValue:headerValue forHTTPHeaderField:headerName];
                }
            } else {
                [urlRequest addValue:header forHTTPHeaderField:headerName];
            }
        }];
        
        [self.additionalHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *headerName, NSString *header, BOOL *stop) {
            [urlRequest addValue:header forHTTPHeaderField:headerName];
        }];
        
        if ([CMISLog sharedInstance].logLevel == CMISLogLevelTrace) {
            CMISLogTrace(@"Added headers: %@", urlRequest.allHTTPHeaderFields);
        }
            
        // create session and task
        self.urlSession = [CMISURLSessionUtil internalUrlSessionWithParameters:self.session delegate:self];
        self.sessionTask = [self taskForRequest:urlRequest];
        
        if (self.sessionTask) {
            // start the task
            [self.sessionTask resume];
        } else {
            if (self.completionBlock) {
                NSString *detailedDescription = [NSString stringWithFormat:@"Could not create network session for %@", urlRequest.URL];
                NSError *cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection detailedDescription:detailedDescription];
                [self executeCompletionBlockResponse:nil error:cmisError];
            }
        }
    };
    
    if ([self shouldApplyHttpHeaders]) {
        if ([self.session.authenticationProvider respondsToSelector:@selector(asyncHttpHeadersToApply:)]) {
            [self.session.authenticationProvider asyncHttpHeadersToApply:^(NSDictionary *headers, NSError *cmisError) {
                if (cmisError) {;
                    [self executeCompletionBlockResponse:nil error:cmisError];
                } else {
                    continueWithStartRequest(headers);
                }
            }];
        } else {
            continueWithStartRequest(self.session.authenticationProvider.httpHeadersToApply);
        }
    } else { // when OAuth tokens are fetched we do not apply the headers of the CMISOAuthAuthenticationProvider
        continueWithStartRequest(nil);
    }

    return YES; //TODO check if we need to remove the return value as it cannot be used anymore because of async behavior
}

// will be overwritten by CMISOAuthHttpRequest
- (BOOL)shouldApplyHttpHeaders
{
    return YES;
}

- (NSURLSessionTask *)taskForRequest:(NSURLRequest *)request
{
    return [self.urlSession dataTaskWithRequest:request];
}

#pragma mark CMISCancellableRequest method

- (void)cancel
{
    if (self.urlSession) {
        void (^completionBlock)(CMISHttpResponse *httpResponse, NSError *error);
        completionBlock = self.completionBlock; // remember completion block in order to invoke it after the connection was cancelled
        
        self.completionBlock = nil; // prevent potential NSURLSession delegate callbacks to invoke the completion block redundantly
        
        [self.urlSession invalidateAndCancel];
        
        self.urlSession = nil;
        
        if (completionBlock) {
            NSError *cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeCancelled detailedDescription:@"Request was cancelled"];
            completionBlock(nil, cmisError);
        }
    }
}

#pragma mark Session delegate methods

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self.session.authenticationProvider updateWithHttpURLResponse:self.response];
    [self didCompleteWithError:error];
}

-(void) didCompleteWithError:(NSError *)error {
    if (self.completionBlock) {
        
        NSError *cmisError = nil;
        CMISHttpResponse *httpResponse = nil;
        
        if (error) {
            if ([CMISLog sharedInstance].logLevel == CMISLogLevelTrace) {
                CMISLogTrace(@"Request did complete with error: %@", error);
            }
            
            CMISErrorCodes cmisErrorCode = kCMISErrorCodeConnection;
            
            // swap error code if necessary
            if (error.code == NSURLErrorCancelled) {
                cmisErrorCode = kCMISErrorCodeCancelled;
            } else if (error.code == kCMISErrorCodeNoNetworkConnection) {
                cmisErrorCode = kCMISErrorCodeNoNetworkConnection;
            }
            
            cmisError = [CMISErrors cmisError:error cmisErrorCode:cmisErrorCode];
        } else {
            // no error returned but we also need to check response code
            httpResponse = [CMISHttpResponse responseUsingURLHTTPResponse:self.response data:self.responseBody];
            if (![CMISHttpRequest checkStatusCodeForResponse:httpResponse httpRequestMethod:self.requestMethod error:&cmisError]) {
                httpResponse = nil;
            }
        }
        if ([self callCompletionBlockOnOriginalThread] && self.originalThread) { // call the completion block on the original thread
            if(cmisError) {
                [self performSelector:@selector(executeCompletionBlockError:) onThread:self.originalThread withObject:cmisError waitUntilDone:NO];
            } else {
                [self performSelector:@selector(executeCompletionBlockResponse:) onThread:self.originalThread withObject:httpResponse waitUntilDone:NO];
            }
        } else {
            [self executeCompletionBlockResponse:httpResponse error:cmisError];
        }
    }
    
    // clean up
    self.sessionTask = nil;
    self.urlSession = nil;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.responseBody appendData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    self.responseBody = [[NSMutableData alloc] init];
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        self.response = (NSHTTPURLResponse*)response;
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    [self.session.authenticationProvider didReceiveChallenge:challenge completionHandler:completionHandler];
}

+ (BOOL)checkStatusCodeForResponse:(CMISHttpResponse *)response httpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod error:(NSError **)error
{
    if ([CMISLog sharedInstance].logLevel == CMISLogLevelTrace) {
        CMISLogTrace(@"Response status code: %d, Response body: %@", (int)response.statusCode, [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
    }
    
    if ([CMISHttpRequest isErrorResponse:response.statusCode httpRequestMethod:httpRequestMethod]) {
        if (error) {
            NSString *exception = response.exception;
            NSString *errorMessage = response.errorMessage;
            if (errorMessage == nil) {
                errorMessage = response.statusCodeMessage; // fall back to HTTP error message
            }
            
            switch (response.statusCode) {
                case 400:
                    if ([exception isEqualToString:kCMISExceptionFilterNotValid]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeFilterNotValid
                                                 detailedDescription:errorMessage];
                    } else {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                                 detailedDescription:errorMessage];
                    }
                    break;
                case 401:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeUnauthorized
                                             detailedDescription:errorMessage];
                    break;
                case 403:
                    if ([exception isEqualToString:kCMISExceptionStreamNotSupported]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeStreamNotSupported
                                                 detailedDescription:errorMessage];
                    } else {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodePermissionDenied
                                                 detailedDescription:errorMessage];
                    }
                    break;
                case 404:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound
                                             detailedDescription:errorMessage];
                    break;
                case 405:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeNotSupported
                                             detailedDescription:errorMessage];
                    break;
                case 407:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeProxyAuthentication
                                             detailedDescription:errorMessage];
                    break;
                case 409:
                    if ([exception isEqualToString:kCMISExceptionContentAlreadyExists]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeContentAlreadyExists
                                                 detailedDescription:errorMessage];
                    } else if ([exception isEqualToString:kCMISExceptionVersioning]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeVersioning
                                                 detailedDescription:errorMessage];
                    } else if ([exception isEqualToString:kCMISExceptionUpdateConflict]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeUpdateConflict
                                                 detailedDescription:errorMessage];
                    } else if ([exception isEqualToString:kCMISExceptionNameConstraintViolation]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeNameConstraintViolation
                                                 detailedDescription:errorMessage];
                    } else {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConstraint
                                                 detailedDescription:errorMessage];
                    }
                    break;
                default:
                    if ([exception isEqualToString:kCMISExceptionStorage]) {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeStorage
                                                 detailedDescription:errorMessage];
                    } else {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                                 detailedDescription:response.errorMessage];
                    }
            }
        }
        return NO;
    }
    return YES;
}

+ (BOOL)isErrorResponse:(NSInteger)statusCode httpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
{
    return (httpRequestMethod == HTTP_GET && statusCode != 200 && statusCode != 206)
            || (httpRequestMethod == HTTP_POST && statusCode != 200 && statusCode != 201)
            || (httpRequestMethod == HTTP_DELETE && statusCode != 204)
            || (httpRequestMethod == HTTP_PUT && ((statusCode < 200 || statusCode > 299)));
}

-(BOOL)callCompletionBlockOnOriginalThread
{
    return YES;
}

- (void)executeCompletionBlockResponse:(CMISHttpResponse*)response {
    [self executeCompletionBlockResponse:response error:nil];
}

- (void)executeCompletionBlockError:(NSError*)error {
    [self executeCompletionBlockResponse:nil error:error];
}

- (void)executeCompletionBlockResponse:(CMISHttpResponse*)response error:(NSError*)error {
    if (self.completionBlock) {
        void (^completionBlock)(CMISHttpResponse *httpResponse, NSError *error);
        completionBlock = self.completionBlock;
        self.completionBlock = nil; // Prevent multiple execution if method on this request gets called inside completion block
        completionBlock(response, error);
    }
}

@end
