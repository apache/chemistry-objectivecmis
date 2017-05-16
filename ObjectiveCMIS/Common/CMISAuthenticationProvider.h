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

#import <Foundation/Foundation.h>

@class CMISBindingSession;

@protocol CMISAuthenticationProvider <NSObject>

/**
* Returns a set of HTTP headers (key-value pairs) that should be added to a
* HTTP call. This will be called by the AtomPub and the Web Services
* binding. You might want to check the binding in use before you set the
* headers. This property can be overwritten by the asyncHttpHeadersToApply:
* method - if implemented.
*
* @return the HTTP headers or nil if no additional headers should be set
*/
@property(nonatomic, strong, readonly) NSDictionary *httpHeadersToApply;

/**
 * updates the provider with NSHTTPURLResponse
 */
- (void)updateWithHttpURLResponse:(NSHTTPURLResponse*)httpUrlResponse;

/**
 * callback when authentication challenge was received using NSURLSession
 */
- (void)didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
          completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler;

@optional

/**
 * Called when the CMISBindingSession gets initialized. Use a weak reference to avoid 
 * reference cycles when storing the session in a property.
 */
- (void)setSession:(CMISBindingSession *)session;

/**
 * If this method is implemented the property httpHeadersToApply is overwritten
 */
- (void)asyncHttpHeadersToApply:(void(^)(NSDictionary *headers, NSError *cmisError))completionBlock;

@end
