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

#import "CMISOAuthAuthenticationProvider.h"
#import "CMISOAuthToken.h"
#import "CMISLog.h"
#import "CMISBindingSession.h"
#import "CMISErrors.h"
#import "CMISHttpResponse.h"
#import "CMISHttpRequest.h"
#import "CMISURLUtil.h"
#import "CMISDictionaryUtil.h"
#import "CMISDefaultNetworkProvider.h"
#import "CMISOAuthHttpRequest.h"
#import "CMISOAuthHttpResponse.h"

@interface CMISOAuthAuthenticationProvider ()

@property (nonatomic, strong, readwrite) CMISOAuthToken *token;
@property (nonatomic, strong) NSNumber *defaultTokenLifetime;

@property (nonatomic, weak) CMISBindingSession *session;

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@interface CMISOAuthFetchOperation : NSOperation {
    BOOL executing;
    BOOL finished;
}

@property (nonatomic, weak) CMISOAuthAuthenticationProvider *authProvider;
@property (nonatomic, weak) NSThread *originalThread;
@property (nonatomic, copy) void (^operationCompletionBlock)(NSString *accessToken, NSError *error);

- (instancetype)initWithOAuthProvider:(CMISOAuthAuthenticationProvider *)authProvider completionBlock:(void(^)(NSString *accessToken, NSError *error))completionBlock;
- (void)completeOperation;

@end

@implementation CMISOAuthAuthenticationProvider

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.defaultTokenLifetime = [NSNumber numberWithInt:3600];
        
        self.operationQueue = [[NSOperationQueue alloc] init];
        /* We need a serial queue as we need to make sure that only one thread at a time requests or refreshes the token
         * We cannot use a NSLock object to synchronize or else we would run into a deadlock because of the asynchronous call to the server */
        [self.operationQueue setMaxConcurrentOperationCount:1];
        if ([self.operationQueue respondsToSelector:@selector(setQualityOfService:)]) {
            // Supported since iOS8
            [self.operationQueue setQualityOfService:NSQualityOfServiceBackground];
        }
    }
    return self;
}

- (void)setSession:(CMISBindingSession *)session
{
    _session = session;
    
    if (self.token == nil) {
        // get predefined access token
        NSString *accessToken = nil;
        if ([[self.session objectForKey:kCMISSessionParameterOAuthAccessToken] isKindOfClass:NSString.class]) {
            accessToken = (NSString *)[self.session objectForKey:kCMISSessionParameterOAuthAccessToken];
        }
        
        // get predefined refresh token
        NSString *refreshToken = nil;
        if ([[self.session objectForKey:kCMISSessionParameterOAuthRefreshToken] isKindOfClass:NSString.class]) {
            refreshToken = (NSString *)[self.session objectForKey:kCMISSessionParameterOAuthRefreshToken];
        }
        
        // get predefined expiration timestamp
        NSNumber *expirationTimestamp = [NSNumber numberWithInt:0];
        if ([[self.session objectForKey:kCMISSessionParameterOAuthExpirationTimestamp] isKindOfClass:NSString.class]) {
            expirationTimestamp = [NSNumber numberWithLongLong:[[self.session objectForKey:kCMISSessionParameterOAuthExpirationTimestamp] longLongValue]];
        } else if ([[self.session objectForKey:kCMISSessionParameterOAuthExpirationTimestamp] isKindOfClass:NSNumber.class]) {
            expirationTimestamp = (NSNumber *)[self.session objectForKey:kCMISSessionParameterOAuthExpirationTimestamp];
        }
        
        // get default token lifetime
        if ([[self.session objectForKey:kCMISSessionParameterOAuthDefaultTokenLifetime] isKindOfClass:NSString.class]) {
            self.defaultTokenLifetime = [NSNumber numberWithLongLong:[[self.session objectForKey:kCMISSessionParameterOAuthDefaultTokenLifetime] longLongValue]];
        } else if ([[self.session objectForKey:kCMISSessionParameterOAuthDefaultTokenLifetime] isKindOfClass:NSNumber.class]) {
            self.defaultTokenLifetime = (NSNumber *)[self.session objectForKey:kCMISSessionParameterOAuthDefaultTokenLifetime];
        }
        
        self.token = [[CMISOAuthToken alloc] initWithAccessToken:accessToken refreshToken:refreshToken expirationTimestamp:expirationTimestamp];
    }
}

- (void)asyncHttpHeadersToApply:(void(^)(NSDictionary *headers, NSError *cmisError))completionBlock
{
    CMISOAuthFetchOperation *oAuthFetchOperation = [[CMISOAuthFetchOperation alloc] initWithOAuthProvider:self completionBlock:^(NSString *accessToken, NSError *error) {
        if (error) {
            completionBlock(nil, error);
        } else {
            NSMutableDictionary *headers = [[super httpHeadersToApply] mutableCopy]; //TODO check if httpHeadersToApply should be called
            if(!headers) {
                headers = [NSMutableDictionary new];
            }
            
            [headers setObject:[NSSet setWithObject:[NSString stringWithFormat:@"Bearer %@", accessToken]] forKey:@"Authorization"];
            
            completionBlock(headers, nil);
        }
    }];
    
    [self.operationQueue addOperation:oAuthFetchOperation];
}


@end

@implementation CMISOAuthFetchOperation

- (instancetype)initWithOAuthProvider:(CMISOAuthAuthenticationProvider *)authProvider completionBlock:(void (^)(NSString *, NSError *))completionBlock
{
    self = [super init];
    if (self) {
        self.authProvider = authProvider;
        self.operationCompletionBlock = completionBlock;
        self.originalThread = [NSThread currentThread];
    }
    return self;
}

- (void)main
{
    // do not invoke super!
    
    if (self.isCancelled) {
        NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeCancelled detailedDescription:@"Could not get token as CMISOAuthFetchOperation was cancelled"];
        [self performSelector:@selector(executeCompletionBlockError:) onThread:self.originalThread withObject:error waitUntilDone:NO];
    } else {
        [self accessTokenWithCompletionBlock:^(NSError *error) {
            // call the completion block on the original thread
            if (self.originalThread) {
                if (error) {
                    [self performSelector:@selector(executeCompletionBlockError:) onThread:self.originalThread withObject:error waitUntilDone:NO];
                } else {
                    [self performSelector:@selector(executeCompletionBlockAccessToken:) onThread:self.originalThread withObject:self.authProvider.token.accessToken waitUntilDone:NO];
                }
            }
        }];
    }
}

- (void)accessTokenWithCompletionBlock:(void(^)(NSError *error))completionBlock
{
    void (^continueWithUpdatedToken)(NSError*) = ^(NSError *error) {
        
        [self.authProvider.delegate cmisOAuthAuthenticationProvider:self.authProvider didUpdateToken:self.authProvider.token withError:error];
        
        completionBlock(error);
    };
    
    if (!self.authProvider.token.accessToken) {
        if (!self.authProvider.token.refreshToken) {
            [self requestToken:continueWithUpdatedToken];
        } else {
            [self refreshToken:continueWithUpdatedToken];
        }
    } else if ([self.authProvider.token isExpired]) {
        [self refreshToken:continueWithUpdatedToken];
    } else { // we already have a valid token
        completionBlock(nil);
    }
}

- (void)requestToken:(void(^)(NSError *error))completionBlock
{
    if ([CMISLog sharedInstance].logLevel == CMISLogLevelDebug) {
        CMISLogDebug(@"Requesting new OAuth access token.");
    }
    
    [self makeRequestIsRefresh:NO completionBlock:^(NSError *error) {
        if ([CMISLog sharedInstance].logLevel == CMISLogLevelTrace) {
            CMISLogTrace(@"%@", [self.authProvider.token description]);
        }
        
        completionBlock(error);
    }];
}

- (void)refreshToken:(void(^)(NSError *error))completionBlock
{
    if ([CMISLog sharedInstance].logLevel == CMISLogLevelDebug) {
        CMISLogDebug(@"Refreshing OAuth access token.");
    }
    
    [self makeRequestIsRefresh:YES completionBlock:^(NSError *error) {
        if ([CMISLog sharedInstance].logLevel == CMISLogLevelTrace) {
            CMISLogTrace(@"%@", [self.authProvider.token description]);
        }
        
        completionBlock(error);
    }];
}

- (void)makeRequestIsRefresh:(BOOL)isRefresh completionBlock:(void(^)(NSError *error))completionBlock
{
    id tokenEndpoint = [self.authProvider.session objectForKey:kCMISSessionParameterOAuthTokenEndpoint];
    if (![tokenEndpoint isKindOfClass:NSString.class]) {
        completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection detailedDescription:@"Token endpoint not set!"]);
    }
    
    if (isRefresh && !self.authProvider.token.refreshToken) {
        completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection detailedDescription:@"No refresh token!"]);
    }
    
    NSDictionary *headers = @{@"Content-Type" : @"application/x-www-form-urlencoded; charset=UTF-8"};
    
    NSMutableData *requestBody = [NSMutableData new];
    // compile request
    if (isRefresh) {
        [self appendString:@"grant_type=refresh_token" toData:requestBody];
        
        [self appendString:@"&refresh_token=" toData:requestBody];
        [self appendString:[CMISURLUtil encodeUrlParameterValue:self.authProvider.token.refreshToken] toData:requestBody];
    } else {
        [self appendString:@"grant_type=authorization_code" toData:requestBody];
        
        id code = [self.authProvider.session objectForKey:kCMISSessionParameterOAuthCode];
        if (code) {
            [self appendString:@"&code=" toData:requestBody];
            [self appendString:[CMISURLUtil encodeUrlParameterValue:[code description]] toData:requestBody];
        }
        
        id redirectUri = [self.authProvider.session objectForKey:kCMISSessionParameterOAuthRedirectUri];
        if (redirectUri) {
            [self appendString:@"&redirect_uri=" toData:requestBody];
            [self appendString:[CMISURLUtil encodeUrlParameterValue:[redirectUri description]] toData:requestBody];
        }
    }
    
    id clientId = [self.authProvider.session objectForKey:kCMISSessionParameterOAuthClientId];
    if (clientId) {
        [self appendString:@"&client_id=" toData:requestBody];
        [self appendString:[CMISURLUtil encodeUrlParameterValue:[clientId description]] toData:requestBody];
    }
    
    id clientSecret = [self.authProvider.session objectForKey:kCMISSessionParameterOAuthClientSecret];
    if (clientSecret) {
        [self appendString:@"&client_secret=" toData:requestBody];
        [self appendString:[CMISURLUtil encodeUrlParameterValue:[clientSecret description]] toData:requestBody];
    }
    
    if ([CMISLog sharedInstance].logLevel == CMISLogLevelTrace) {
        CMISLogTrace(@"Request body: %@", [[NSString alloc] initWithData:requestBody encoding:NSUTF8StringEncoding]);
    }
    
    // request token
    __weak typeof(self) weakSelf = self;
    [self invoke:[NSURL URLWithString:(NSString *)tokenEndpoint]
      httpMethod:HTTP_POST
         session:self.authProvider.session
            body:requestBody
         headers:headers
     cmisRequest:nil
 completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
     NSError *cmisError = nil;
     if (error) {
         completionBlock(error);
     } else {
         // parse response
         NSDictionary *jsonDictionary = [CMISOAuthHttpResponse parseResponse:httpResponse error:&cmisError];
         
         if(cmisError) { // there was an error parsing the response
             completionBlock(cmisError);
         } else {
             id tokenType = [jsonDictionary cmis_objectForKeyNotNull:@"token_type"];
             if (![tokenType isKindOfClass:NSString.class] || [@"bearer" caseInsensitiveCompare:(NSString *) tokenType] != NSOrderedSame) {
                 cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection detailedDescription:[NSString stringWithFormat:@"Unsupported OAuth token type: %@", tokenType]];
                 completionBlock(cmisError);
                 return;
             }
             
             id jsonAccessToken = [jsonDictionary cmis_objectForKeyNotNull:@"access_token"];
             if (![jsonAccessToken isKindOfClass:NSString.class]) {
                 cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection detailedDescription:@"Invalid OAuth access_token!"];
                 completionBlock(cmisError);
                 return;
                 
             }
             
             id jsonRefreshToken = [jsonDictionary cmis_objectForKeyNotNull:@"refresh_token"];
             if (jsonRefreshToken && ![jsonRefreshToken isKindOfClass:NSString.class]) {
                 cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection detailedDescription:@"Invalid OAuth refresh_token!"];
                 completionBlock(cmisError);
                 return;
             }
             
             NSNumber *expiresIn = weakSelf.authProvider.defaultTokenLifetime;
             id jsonExpiresIn = [jsonDictionary cmis_objectForKeyNotNull:@"expires_in"];
             if (jsonExpiresIn) {
                 if ([jsonExpiresIn isKindOfClass:NSNumber.class]) {
                     expiresIn = (NSNumber *)jsonExpiresIn;
                 } else if ([jsonExpiresIn isKindOfClass:NSString.class]) {
                     expiresIn = [NSNumber numberWithLongLong:[(NSString *)jsonExpiresIn longLongValue]];
                 } else {
                     cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection detailedDescription:@"Invalid OAuth expires_in value!"];
                     completionBlock(cmisError);
                     return;
                 }
             }
             
             if ([expiresIn longLongValue] <= 0) {
                 expiresIn = self.authProvider.defaultTokenLifetime;
             }
             
             weakSelf.authProvider.token = [[CMISOAuthToken alloc] initWithAccessToken:jsonAccessToken refreshToken:jsonRefreshToken expirationTimestamp:[NSNumber numberWithLongLong:([expiresIn longLongValue] * 1000 + [[NSDate date] timeIntervalSince1970] * 1000)]]; // seconds to milliseconds
             completionBlock(nil); // success
         }
     }
 }];
}

- (void)invoke:(NSURL *)url httpMethod:(CMISHttpRequestMethod)httpRequestMethod session:(CMISBindingSession *)session body:(NSData *)body headers:(NSDictionary *)headers cmisRequest:(CMISRequest *)cmisRequest completionBlock:(void (^)(CMISHttpResponse *, NSError *))completionBlock
{
    NSMutableURLRequest *urlRequest = [CMISDefaultNetworkProvider createRequestForUrl:url
                                                                           httpMethod:httpRequestMethod
                                                                              session:session];
    if (!cmisRequest.isCancelled) {
        CMISHttpRequest* request = [CMISOAuthHttpRequest startRequest:urlRequest
                                                           httpMethod:httpRequestMethod
                                                          requestBody:body
                                                              headers:headers
                                                              session:session
                                                      completionBlock:completionBlock];
        if (request) {
            cmisRequest.httpRequest = request;
        }
    } else {
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeCancelled
                                                 detailedDescription:@"Request was cancelled"]);
        }
    }
}

- (void)appendString:(NSString *)string toData:(NSMutableData *)data
{
    [data appendData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (BOOL)isConcurrent {
    return NO;
}

- (BOOL)isExecuting {
    return executing;
}

- (BOOL)isFinished {
    return finished;
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    executing = NO;
    finished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)executeCompletionBlockAccessToken:(NSString *)accessToken {
    [self executeCompletionBlockAccessToken:accessToken error:nil];
}

- (void)executeCompletionBlockError:(NSError *)error {
    [self executeCompletionBlockAccessToken:nil error:error];
}

- (void)executeCompletionBlockAccessToken:(NSString *)accessToken error:(NSError *)error {
    if (self.operationCompletionBlock) {
        void (^completionBlock)(NSString *accessToken, NSError *error);
        completionBlock = self.operationCompletionBlock;
        self.operationCompletionBlock = nil; // Prevent multiple execution if method on this request gets called inside completion block
        completionBlock(accessToken, error);
    }
    [self completeOperation];
}

@end
