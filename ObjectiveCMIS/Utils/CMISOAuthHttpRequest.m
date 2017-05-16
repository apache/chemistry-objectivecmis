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

#import "CMISOAuthHttpRequest.h"
#import "CMISOAuthHttpResponse.h"
#import "CMISLog.h"
#import "CMISDictionaryUtil.h"
#import "CMISErrors.h"
#import "CMISMimeHelper.h"

@implementation CMISOAuthHttpRequest

-(BOOL)shouldApplyHttpHeaders
{
    return NO; // http headers of the CMISOAuthAuthenticationProvider should not be applied or else we would end up in an endless loop
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (self.completionBlock) {
        if (!error) {
            NSError *cmisError = nil;
            
            // no error returned but we check if an OAuth error message was returned
            CMISHttpResponse *httpResponse = [CMISOAuthHttpResponse responseUsingURLHTTPResponse:self.response data:self.responseBody];
            if (httpResponse.statusCode != 200) {
                if (httpResponse.statusCode == 401) {
                    NSDictionary *challenges = [CMISMimeHelper challengesFromAuthenticateHeader:[[self.response allHeaderFields] objectForKey:@"WWW-Authenticate"]];
                    
                    if ([challenges objectForKey:@"bearer"]) {
                        NSDictionary *params = [challenges objectForKey:@"bearer"];
                        
                        NSString *error = [params objectForKey:@"error"];
                        NSString *description = [params objectForKey:@"error_description"];
                        NSString *uri = [params objectForKey:@"error_uri"];
                        
                        if ([CMISLog sharedInstance].logLevel == CMISLogLevelDebug) {
                            CMISLogDebug(@"Invalid OAuth token: %@", params);
                        }
                        
                        NSMutableDictionary *oAuthErroUserDict = [NSMutableDictionary new];
                        if (error) {
                            oAuthErroUserDict[kCMISErrorOAuthExceptionErrorKey] = error;
                        }
                        if (description) {
                            oAuthErroUserDict[kCMISErrorOAuthExceptionDescriptionKey] = description;
                        }
                        if (uri) {
                            oAuthErroUserDict[kCMISErrorOAuthExceptionUriKey] = uri;
                        }
                        cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection detailedDescription:[NSString stringWithFormat:@"Unauthorized: error: %@ ,errorStr: %@", error, description] additionalUserInfo:oAuthErroUserDict];
                        
                        [self executeCompletionBlockError:cmisError];
                    } // else: superclass will handle authorization error
                } else {
                    NSDictionary *jsonDictionary = [CMISOAuthHttpResponse parseResponse:httpResponse error:&cmisError];
                    if (!cmisError) {
                        if ([CMISLog sharedInstance].logLevel == CMISLogLevelDebug) {
                            CMISLogDebug(@"OAuth token request failed: %@", jsonDictionary);
                        }
                        
                        id error = [jsonDictionary cmis_objectForKeyNotNull:@"error"];
                        id description = [jsonDictionary cmis_objectForKeyNotNull:@"error_description"];
                        id uri = [jsonDictionary cmis_objectForKeyNotNull:@"error_uri"];
                        
                        NSMutableDictionary *oAuthErroUserDict = [NSMutableDictionary new];
                        if ([error description]) {
                            oAuthErroUserDict[kCMISErrorOAuthExceptionErrorKey] = [error description];
                        }
                        if ([description description]) {
                            oAuthErroUserDict[kCMISErrorOAuthExceptionDescriptionKey] = [description description];
                        }
                        if ([uri description]) {
                            oAuthErroUserDict[kCMISErrorOAuthExceptionUriKey] = [uri description];
                        }
                        cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection detailedDescription:[NSString stringWithFormat:@"OAuth token request failed: error=%@, description=%@, errorUri=%@", error, description, uri] additionalUserInfo:oAuthErroUserDict];
                        
                        if(cmisError) {
                            [self executeCompletionBlockError:cmisError];
                        } else {
                            [self executeCompletionBlockResponse:httpResponse];
                        }
                    }
                }
            }
        }
    }
    [super URLSession:session task:task didCompleteWithError:error];
}

-(BOOL)callCompletionBlockOnOriginalThread
{
    /* Note: calling perform selector on the original thread (spawned by the NSOperationQueue) does not work as the runloop is thrown away (after the main method finishes) without ever calling the executeCompletionBlock selector.
     */
    return NO;
}



@end
