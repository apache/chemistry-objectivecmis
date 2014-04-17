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

#import "CMISBrowserRepositoryService.h"
#import "CMISConstants.h"
#import "CMISErrors.h"
#import "CMISRequest.h"
#import "CMISLog.h"
#import "CMISHttpResponse.h"
#import "CMISTypeDefinition.h"
#import "CMISPropertyDefinition.h"
#import "CMISBrowserUtil.h"
#import "CMISConstants.h"
#import "CMISBrowserConstants.h"
#import "CMISURLUtil.h"

@interface CMISBrowserRepositoryService ()
@property (nonatomic, strong) NSDictionary *repositories;
@end

@implementation CMISBrowserRepositoryService

- (CMISRequest*)retrieveRepositoriesWithCompletionBlock:(void (^)(NSArray *repositories, NSError *error))completionBlock
{
    return [self internalRetrieveRepositoriesWithCompletionBlock:^(NSError *error) {
        if (error) {
            completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
        } else {
            completionBlock([self.repositories allValues], nil);
        }
    }];
}

- (CMISRequest*)retrieveRepositoryInfoForId:(NSString *)repositoryId
                            completionBlock:(void (^)(CMISRepositoryInfo *repositoryInfo, NSError *error))completionBlock
{
    return [self internalRetrieveRepositoriesWithCompletionBlock:^(NSError *error) {
        if (error) {
            completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeInvalidArgument]);
        } else {
            completionBlock([self.repositories objectForKey:repositoryId], nil);
        }
    }];
}

- (CMISRequest*)internalRetrieveRepositoriesWithCompletionBlock:(void (^)(NSError *error))completionBlock
{
    // TODO: cache the repo info objects

    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    [self.bindingSession.networkProvider invokeGET:self.browserUrl
                                           session:self.bindingSession
                                       cmisRequest:cmisRequest
                                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                       if (httpResponse) {
                                           NSData *data = httpResponse.data;
                                           if (data) {
                                               NSError *parsingError = nil;
                                               self.repositories = [CMISBrowserUtil repositoryInfoDictionaryFromJSONData:data
                                                                                                          bindingSession:self.bindingSession
                                                                                                                   error:&parsingError];
                                               if (parsingError) {
                                                   completionBlock(parsingError);
                                               } else {
                                                   completionBlock(nil);
                                               }
                                           }
                                       } else {
                                           completionBlock(error);
                                       }
                                   }];
    
    return cmisRequest;
}

- (CMISRequest*)retrieveTypeDefinition:(NSString *)typeId
                       completionBlock:(void (^)(CMISTypeDefinition *typeDefinition, NSError *error))completionBlock
{
    NSString *repoUrl = [self getRepositoryUrlWithSelector:kCMISBrowserJSONSelectorTypeDefinition];
    repoUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterTypeId value:typeId urlString:repoUrl];
    
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    
    [self.bindingSession.networkProvider invokeGET:[NSURL URLWithString:repoUrl]
                                           session:self.bindingSession
                                       cmisRequest:cmisRequest
                                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                       if (httpResponse) {
                                           NSData *data = httpResponse.data;
                                           if (data) {
                                               NSError *parsingError = nil;
                                               CMISTypeDefinition *typeDef = [CMISBrowserUtil typeDefinitionFromJSONData:data error:&parsingError];
                                               if (parsingError) {
                                                   completionBlock(nil, parsingError);
                                               }
                                               else {
                                                   completionBlock(typeDef, nil);
                                               }
                                           }
                                       } else {
                                           completionBlock(nil, error);
                                       }
                                   }];
    
    return cmisRequest;
}

@end
