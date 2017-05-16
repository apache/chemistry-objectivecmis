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

#import "CMISBrowserAclService.h"
#import "CMISConstants.h"
#import "CMISBrowserConstants.h"
#import "CMISURLUtil.h"
#import "CMISRequest.h"
#import "CMISHttpResponse.h"
#import "CMISBrowserUtil.h"
#import "CMISEnums.h"
#import "CMISBroswerFormDataWriter.h"
#import "CMISAce.h"
#import "CMISErrors.h"

@implementation CMISBrowserAclService

-(CMISRequest *)retrieveAcl:(NSString *)objectId
       onlyBasicPermissions:(BOOL)onlyBasicPermissions
            completionBlock:(void (^)(CMISAcl *, NSError *))completionBlock
{
    // build URL
    NSString *objectUrl = [self retrieveObjectUrlForObjectWithId:objectId selector:kCMISBrowserJSONSelectorAcl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterOnlyBasicPermissions boolValue:onlyBasicPermissions urlString:objectUrl];
    
    // read and parse
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    [self.bindingSession.networkProvider invokeGET:[NSURL URLWithString:objectUrl]
                                           session:self.bindingSession
                                       cmisRequest:cmisRequest
                                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                       if (httpResponse.statusCode == 200 && httpResponse.data) {
                                           [CMISBrowserUtil aclFromJSONData:httpResponse.data completionBlock:^(CMISAcl *acl, NSError *error) {
                                               if (error) {
                                                   completionBlock(nil, error);
                                               } else {
                                                   completionBlock(acl, nil);
                                               }
                                           }];
                                       } else {
                                           completionBlock(nil, error);
                                       }
                                   }];
    
    return cmisRequest;
}

- (CMISRequest*)applyAcl:objectId
                 addAces:(CMISAcl *)addAces
              removeAces:(CMISAcl *)removeAces
          aclPropagation:(CMISAclPropagation)aclPropagation
         completionBlock:(void (^)(CMISAcl *acl, NSError *error))completionBlock
{
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    
    [self internalApplyAcl:objectId
                   addAces:addAces
                removeAces:removeAces
            aclPropagation:aclPropagation
               cmisRequest:cmisRequest
           completionBlock:completionBlock];
    
    return cmisRequest;
}

- (CMISRequest*)internalApplyAcl:objectId
                         addAces:(CMISAcl *)addAces
                      removeAces:(CMISAcl *)removeAces
                  aclPropagation:(CMISAclPropagation)aclPropagation
                     cmisRequest:(CMISRequest *)cmisRequest
                 completionBlock:(void (^)(CMISAcl *acl, NSError *error))completionBlock
{
    if (!cmisRequest.isCancelled) {
        // build URL
        NSString *objectUrl = [self retrieveObjectUrlForObjectWithId:objectId selector:kCMISBrowserJSONSelectorAcl];
        
        // prepare form data
        CMISBroswerFormDataWriter *formData = [[CMISBroswerFormDataWriter alloc] initWithAction:kCMISBrowserJSONActionApplyAcl];
        [formData addAcesParameters:addAces];
        [formData addRemoveAcesParameters:removeAces];
        [formData addParameter:kCMISParameterAclPropagation value:[CMISEnums stringForAclPropagation:aclPropagation]];
        
        // send
        [self.bindingSession.networkProvider invokePOST:[NSURL URLWithString:objectUrl]
                                                session:self.bindingSession
                                                   body:formData.body
                                                headers:formData.headers
                                            cmisRequest:cmisRequest
                                        completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                            if ((httpResponse.statusCode == 200 || httpResponse.statusCode == 201) && httpResponse.data) {
                                                [CMISBrowserUtil aclFromJSONData:httpResponse.data completionBlock:^(CMISAcl *acl, NSError *error) {
                                                    if (error) {
                                                        completionBlock(nil, error);
                                                    } else {
                                                        completionBlock(acl, nil);
                                                    }
                                                }];
                                            } else {
                                                completionBlock(nil, error);
                                            }
                                        }];

    } else {
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeCancelled
                                                 detailedDescription:@"Request was cancelled"]);
        }
    }
    return cmisRequest;
}

- (CMISRequest*)setAcl:objectId
                  aces:(CMISAcl *)aces
       completionBlock:(void (^)(CMISAcl *acl, NSError *error))completionBlock
{
    __block CMISRequest *cmisRequest = [self retrieveAcl:objectId onlyBasicPermissions:NO completionBlock:^(CMISAcl *currentAcl, NSError *error) {
        if (error) {
            if (completionBlock) {
                completionBlock(nil, error);
            }
        } else {
            NSMutableSet *removeAcesSet = [NSMutableSet new];
            for (CMISAce *ace in currentAcl.aces) {
                if (ace.isDirect) {
                    [removeAcesSet addObject:ace];
                }
            }
            
            CMISAcl *removeAces = [[CMISAcl alloc] init];
            [removeAces setAces:removeAcesSet];
            [self internalApplyAcl:objectId addAces:aces removeAces:removeAces aclPropagation:CMISAclPropagationObjectOnly cmisRequest:cmisRequest completionBlock:completionBlock];
        }
    }];
    return cmisRequest;
}

@end
