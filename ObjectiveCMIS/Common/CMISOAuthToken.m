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

#import "CMISOAuthToken.h"

@implementation CMISOAuthToken

- (instancetype)initWithAccessToken:(NSString *)accessToken refreshToken:(NSString *)refreshToken expirationTimestamp:(NSNumber *)expirationTimestamp
{
    self = [super init];
    if (self) {
        self.accessToken = accessToken;
        self.refreshToken = refreshToken;
        self.expirationTimestamp = expirationTimestamp;
    }
    return self;
}

- (BOOL)isExpired
{
    return [[NSDate date] timeIntervalSince1970] * 1000.0 >= [self.expirationTimestamp longLongValue]; // seconds to milliseconds
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"CMISOAuthToken - accessToken: %@, refreshToken: %@, expirationTimestamp: %lld",
            self.accessToken, self.refreshToken, [self.expirationTimestamp longLongValue]];
}

@end
