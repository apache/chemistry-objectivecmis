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

#import "CMISBrowserBaseService.h"
#import "CMISConstants.h"
#import "CMISBrowserConstants.h"
#import "CMISURLUtil.h"
#import "CMISHttpResponse.h"
#import "CMISBrowserUtil.h"

@interface CMISBrowserBaseService ()
@property (nonatomic, strong, readwrite) CMISBindingSession *bindingSession;
@property (nonatomic, strong, readwrite) NSURL *browserUrl;
@end

@implementation CMISBrowserBaseService

- (id)initWithBindingSession:(CMISBindingSession *)session
{
    self = [super init];
    if (self) {
        self.bindingSession = session;
        self.browserUrl = [session objectForKey:kCMISBindingSessionKeyUrl];
    }
    return self;
}

-(NSString *)getObjectUrlObjectId:(NSString *)objectId selector:(NSString *)selector
{
    NSString *rootUrl = [self.bindingSession objectForKey:kCMISBrowserBindingSessionKeyRootFolderUrl];
    
    NSString *objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterObjectId value:objectId urlString:rootUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISBrowserJSONParameterSelector value:selector urlString:objectUrl];
    return objectUrl;
}

-(NSString *)getObjectUrlByPath:(NSString *)path selector:(NSString *)selector
{
    NSString *rootUrl = [self.bindingSession objectForKey:kCMISBrowserBindingSessionKeyRootFolderUrl];
    
    NSString *objectUrl = [CMISURLUtil urlStringByAppendingPath:path urlString:rootUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISBrowserJSONParameterSelector value:selector urlString:objectUrl];
    return objectUrl;
}

-(NSString *)getRepositoryUrlWithSelector:(NSString *)selector
{
    NSString *repoUrl = [self.bindingSession objectForKey:kCMISBrowserBindingSessionKeyRepositoryUrl];
    repoUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISBrowserJSONParameterSelector value:selector urlString:repoUrl];
    return repoUrl;
}

- (CMISRequest*)retrieveTypeDefinitionInternal:(NSString *)typeId
                                   cmisRequest:(CMISRequest *)cmisRequest
                       completionBlock:(void (^)(CMISTypeDefinition *typeDefinition, NSError *error))completionBlock
{
    NSString *repoUrl = [self getRepositoryUrlWithSelector:kCMISBrowserJSONSelectorTypeDefinition];
    repoUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterTypeId value:typeId urlString:repoUrl];
    
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
