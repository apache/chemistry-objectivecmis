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

#import "CMISURLSessionUtil.h"
#import "CMISBindingSession.h"
#import "CMISConstants.h"
#import "CMISLog.h"

@implementation CMISURLSessionUtil

+ (NSURLSession *)internalUrlSessionWithParameters:(CMISBindingSession *)session delegate:(id <NSURLSessionDelegate>)delegate
{
    // determine the type of session configuration to create
    NSURLSessionConfiguration *sessionConfiguration = nil;
    id useBackgroundSession = [session objectForKey:kCMISSessionParameterUseBackgroundNetworkSession];
    if (useBackgroundSession && [useBackgroundSession boolValue]) {
        // get session and container identifiers from session
        NSString *backgroundId = [session objectForKey:kCMISSessionParameterBackgroundNetworkSessionId
                                       defaultValue:kCMISDefaultBackgroundNetworkSessionId];
        NSString *containerId = [session objectForKey:kCMISSessionParameterBackgroundNetworkSessionSharedContainerId
                                      defaultValue:kCMISDefaultBackgroundNetworkSessionSharedContainerId];
        
        // use the background session configuration, cache settings and timeout will be provided by the request object
        sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:backgroundId];
        sessionConfiguration.sharedContainerIdentifier = containerId;
        
        CMISLogDebug(@"Using background network session with identifier '%@' and shared container '%@'",
                     backgroundId, containerId);
    }
    else {
        // use the default session configuration, cache settings and timeout will be provided by the request object
        sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    
    //TODO: do we have a memory leak? need to call invalidateAndCancel or resetWithCompletionHandler when done, see also docu from sessionWithConfiguration:delegate:delegateQueue: method
    // create session
    return [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:delegate delegateQueue:nil];
}

@end
