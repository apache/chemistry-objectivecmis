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

#import "CMISStandardAuthenticationProvider.h"

@class CMISOAuthAuthenticationProvider, CMISOAuthToken;

@protocol CMISOAuthAuthenticationProviderDelegate <NSObject>

- (void)cmisOAuthAuthenticationProvider:(CMISOAuthAuthenticationProvider *)authenticationProvider didUpdateToken:(CMISOAuthToken *)token withError:(NSError *)error;

@end

/**
 * OAuth 2.0 Authentication Provider.
 * This authentication provider implements OAuth 2.0 (RFC 6749) Bearer Tokens
 * (RFC 6750).
 * The provider can be either configured with an authorization code or with an
 * existing bearer token. Token endpoint and client ID are always required. If a
 * client secret is required depends on the authorization server.
 */
@interface CMISOAuthAuthenticationProvider : CMISStandardAuthenticationProvider

@property (nonatomic, strong, readonly) CMISOAuthToken *token;

@property (nonatomic, weak) id<CMISOAuthAuthenticationProviderDelegate> delegate;

@end
