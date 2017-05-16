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

#import "CMISAtomPubAclService.h"
#import "CMISErrors.h"

@implementation CMISAtomPubAclService

-(CMISRequest *)retrieveAcl:(id)objectId
       onlyBasicPermissions:(BOOL)onlyBasicPermissions
            completionBlock:(void (^)(CMISAcl *, NSError *))completionBlock
{
    // TODO implement
    completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime detailedDescription:@"not implemented!"]);
    return nil;
}

-(CMISRequest *)applyAcl:(id)objectId addAces:(CMISAcl *)addAces
              removeAces:(CMISAcl *)removeAces
          aclPropagation:(CMISAclPropagation)aclPropagation
         completionBlock:(void (^)(CMISAcl *, NSError *))completionBlock
{
    // TODO implement
    completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime detailedDescription:@"not implemented!"]);
    return nil;
}

-(CMISRequest *)setAcl:(id)objectId aces:(CMISAcl *)aces
       completionBlock:(void (^)(CMISAcl *, NSError *))completionBlock
{
    // TODO implement
    completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime detailedDescription:@"not implemented!"]);
    return nil;
}

@end
