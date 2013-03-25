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

#import "CMISAtomPubObjectService.h"
#import "CMISAtomPubBaseService+Protected.h"
#import "CMISHttpResponse.h"
#import "CMISAtomEntryWriter.h"
#import "CMISAtomEntryParser.h"
#import "CMISConstants.h"
#import "CMISErrors.h"
#import "CMISStringInOutParameter.h"
#import "CMISURLUtil.h"
#import "CMISFileUtil.h"
#import "CMISRequest.h"
#import "CMISLog.h"

@implementation CMISAtomPubObjectService

- (CMISRequest*)retrieveObject:(NSString *)objectId
                filter:(NSString *)filter
         relationships:(CMISIncludeRelationship)relationships
      includePolicyIds:(BOOL)includePolicyIds
       renditionFilder:(NSString *)renditionFilter
            includeACL:(BOOL)includeACL
    includeAllowableActions:(BOOL)includeAllowableActions
       completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    [self retrieveObjectInternal:objectId
                   returnVersion:NOT_PROVIDED
                          filter:filter
                   relationships:relationships
                includePolicyIds:includePolicyIds
                 renditionFilder:renditionFilter
                      includeACL:includeACL
         includeAllowableActions:includeAllowableActions
                     cmisRequest:cmisRequest
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     if (error) {
                         completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
                     } else {
                         completionBlock(objectData, nil);
                     }
                 }];
    return cmisRequest;
}

- (CMISRequest*)retrieveObjectByPath:(NSString *)path
                      filter:(NSString *)filter
               relationships:(CMISIncludeRelationship)relationships
            includePolicyIds:(BOOL)includePolicyIds
             renditionFilder:(NSString *)renditionFilter
                  includeACL:(BOOL)includeACL
     includeAllowableActions:(BOOL)includeAllowableActions
             completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    [self retrieveObjectByPathInternal:path
                                filter:filter
                         relationships:relationships
                      includePolicyIds:includePolicyIds
                       renditionFilder:renditionFilter
                            includeACL:includeACL
               includeAllowableActions:includeAllowableActions
                           cmisRequest:cmisRequest
                       completionBlock:completionBlock];
    return cmisRequest;
}

- (CMISRequest*)downloadContentOfObject:(NSString *)objectId
                               streamId:(NSString *)streamId
                                 toFile:(NSString *)filePath
                        completionBlock:(void (^)(NSError *error))completionBlock
                          progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock
{
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
    return [self downloadContentOfObject:objectId
                                streamId:streamId
                          toOutputStream:outputStream
                         completionBlock:completionBlock
                           progressBlock:progressBlock];
}

- (CMISRequest*)downloadContentOfObject:(NSString *)objectId
                               streamId:(NSString *)streamId
                         toOutputStream:(NSOutputStream *)outputStream
                        completionBlock:(void (^)(NSError *error))completionBlock
                          progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock
{
    CMISRequest *request = [[CMISRequest alloc] init];
    
    [self retrieveObjectInternal:objectId
                     cmisRequest:request
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
        if (error) {
            CMISLogError(@"Error while retrieving CMIS object for object id '%@' : %@", objectId, error.description);
            if (completionBlock) {
                completionBlock([CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
            }
        } else {
            NSURL *contentUrl = objectData.contentUrl;
            
            if (contentUrl) {
                // This is not spec-compliant!! Took me half a day to find this in opencmis ...
                if (streamId != nil) {
                    contentUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterStreamId value:streamId url:contentUrl];
                }
                
                unsigned long long streamLength = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyContentStreamLength] firstValue] unsignedLongLongValue];
                
                [self.bindingSession.networkProvider invoke:contentUrl
                                                 httpMethod:HTTP_GET
                                                    session:self.bindingSession
                                               outputStream:outputStream
                                              bytesExpected:streamLength
                                                cmisRequest:request
                                            completionBlock:^(CMISHttpResponse *httpResponse, NSError *error)
                 {
                     if (completionBlock) {
                         completionBlock(error);
                     }
                 }progressBlock:progressBlock];
            } else { // it is spec-compliant to have no content stream set and in this case there is nothing to download
                if (completionBlock) {
                    completionBlock(nil);
                }
            }
        }
    }];
    
    return request;
}

- (CMISRequest*)deleteContentOfObject:(CMISStringInOutParameter *)objectIdParam
                          changeToken:(CMISStringInOutParameter *)changeTokenParam
                      completionBlock:(void (^)(NSError *error))completionBlock
{
    // Validate object id param
    if (objectIdParam == nil || objectIdParam.inParameter == nil) {
        CMISLogError(@"Object id is nil or inParameter of objectId is nil");
        completionBlock([[NSError alloc] init]); // TODO: properly init error (CmisInvalidArgumentException)
        return nil;
    }
    
    CMISRequest *request = [[CMISRequest alloc] init];
    // Get edit media link
    [self loadLinkForObjectId:objectIdParam.inParameter
                     relation:kCMISLinkEditMedia
                  cmisRequest:request
              completionBlock:^(NSString *editMediaLink, NSError *error) {
        if (editMediaLink == nil){
            CMISLogError(@"Could not retrieve %@ link for object '%@'", kCMISLinkEditMedia, objectIdParam.inParameter);
            completionBlock(error);
            return;
        }
        
        // Append optional change token parameters
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                             value:changeTokenParam.inParameter urlString:editMediaLink];
        }
        
        [self.bindingSession.networkProvider invokeDELETE:[NSURL URLWithString:editMediaLink]
                                                  session:self.bindingSession
                                              cmisRequest:request
                                          completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                   if (httpResponse) {
                       // Atompub DOES NOT SUPPORT returning the new object id and change token
                       // See http://docs.oasis-open.org/cmis/CMIS/v1.0/cs01/cmis-spec-v1.0.html#_Toc243905498
                       objectIdParam.outParameter = nil;
                       changeTokenParam.outParameter = nil;
                       completionBlock(nil);
                   } else {
                       completionBlock(error);
                   }
               }];
    }];
    return request;
}

- (CMISRequest*)changeContentOfObject:(CMISStringInOutParameter *)objectIdParam
                      toContentOfFile:(NSString *)filePath
                             mimeType:(NSString *)mimeType
                    overwriteExisting:(BOOL)overwrite
                          changeToken:(CMISStringInOutParameter *)changeTokenParam
                      completionBlock:(void (^)(NSError *error))completionBlock
                        progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    if (inputStream == nil) {
        CMISLogError(@"Could not find file %@", filePath);
        if (completionBlock) {
            completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        }
        return nil;
    }
    
    NSError *fileError = nil;
    unsigned long long fileSize = [CMISFileUtil fileSizeForFileAtPath:filePath error:&fileError];
    if (fileError) {
        CMISLogError(@"Could not determine size of file %@: %@", filePath, [fileError description]);
    }
    
    return [self changeContentOfObject:objectIdParam
                toContentOfInputStream:inputStream
                         bytesExpected:fileSize
                              filename:[filePath lastPathComponent]
                              mimeType:mimeType
                     overwriteExisting:overwrite
                           changeToken:changeTokenParam
                       completionBlock:completionBlock
                         progressBlock:progressBlock];
}

- (CMISRequest*)changeContentOfObject:(CMISStringInOutParameter *)objectIdParam
               toContentOfInputStream:(NSInputStream *)inputStream
                        bytesExpected:(unsigned long long)bytesExpected
                             filename:(NSString*)filename
                             mimeType:(NSString *)mimeType
                    overwriteExisting:(BOOL)overwrite
                          changeToken:(CMISStringInOutParameter *)changeTokenParam
                      completionBlock:(void (^)(NSError *error))completionBlock
                        progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    CMISRequest *request = [[CMISRequest alloc] init];
    // Validate object id param
    if (objectIdParam == nil || objectIdParam.inParameter == nil) {
        CMISLogError(@"Object id is nil or inParameter of objectId is nil");
        if (completionBlock) {
            completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:@"Must provide object id"]);
        }
        return nil;
    }
    
    if (inputStream == nil) {
        CMISLogError(@"Invalid input stream");
        if (completionBlock) {
            completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:@"Invalid input stream"]);
        }
        return nil;
    }
    
    if (nil == mimeType)
    {
        mimeType = kCMISMediaTypeOctetStream;
    }
    
    // Atompub DOES NOT SUPPORT returning the new object id and change token
    // See http://docs.oasis-open.org/cmis/CMIS/v1.0/cs01/cmis-spec-v1.0.html#_Toc243905498
    objectIdParam.outParameter = nil;
    changeTokenParam.outParameter = nil;
    
    // Get edit media link
    [self loadLinkForObjectId:objectIdParam.inParameter
                     relation:kCMISLinkEditMedia
                  cmisRequest:request
              completionBlock:^(NSString *editMediaLink, NSError *error) {
        if (editMediaLink == nil){
            CMISLogError(@"Could not retrieve %@ link for object '%@'", kCMISLinkEditMedia, objectIdParam.inParameter);
            if (completionBlock) {
                completionBlock([CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
            }
            return;
        }
        
        // Append optional change token parameters
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                             value:changeTokenParam.inParameter urlString:editMediaLink];
        }
        
        // Append overwrite flag
        editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterOverwriteFlag
                                                         value:(overwrite ? @"true" : @"false") urlString:editMediaLink];
        
        
        // Execute HTTP call on edit media link, passing the a stream to the file
        NSArray *values =  @[[NSString stringWithFormat:kCMISHTTPHeaderContentDispositionAttachment, filename], mimeType];
        NSArray *keys = @[kCMISHTTPHeaderContentDisposition, kCMISHTTPHeaderContentType];
        
        NSDictionary *headers = [NSDictionary dictionaryWithObjects:values forKeys:keys];
                  
        [self.bindingSession.networkProvider invoke:[NSURL URLWithString:editMediaLink]
                                         httpMethod:HTTP_PUT
                                            session:self.bindingSession
                                        inputStream:inputStream
                                            headers:headers
                                      bytesExpected:bytesExpected
                                        cmisRequest:request
                                    completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
             // Check response status
             if (httpResponse) {
                 if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 204) {
                     error = nil;
                 } else {
                     CMISLogError(@"Invalid http response status code when updating content: %d", httpResponse.statusCode);
                     error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                             detailedDescription:[NSString stringWithFormat:@"Could not update content: http status code %d", httpResponse.statusCode]];
                 }
             }
             if (completionBlock) {
                 completionBlock(error);
             }
         }
           progressBlock:progressBlock];
    }];
    
    return request;
}


- (CMISRequest*)createDocumentFromFilePath:(NSString *)filePath
                                  mimeType:(NSString *)mimeType
                                properties:(CMISProperties *)properties
                                  inFolder:(NSString *)folderObjectId
                           completionBlock:(void (^)(NSString *objectId, NSError *Error))completionBlock
                             progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    if (inputStream == nil) {
        CMISLogError(@"Could not find file %@", filePath);
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                                 detailedDescription:@"Invalid file"]);
        }
        return nil;
    }
    
    NSError *fileError = nil;
    unsigned long long bytesExpected = [CMISFileUtil fileSizeForFileAtPath:filePath error:&fileError];
    if (fileError) {
        CMISLogError(@"Could not determine size of file %@: %@", filePath, [fileError description]);
    }
    
    return [self createDocumentFromInputStream:inputStream
                                      mimeType:mimeType
                                    properties:properties
                                      inFolder:folderObjectId
                                 bytesExpected:bytesExpected
                               completionBlock:completionBlock
                                 progressBlock:progressBlock];
}

- (CMISRequest*)createDocumentFromInputStream:(NSInputStream *)inputStream // may be nil if you do not want to set content
                                     mimeType:(NSString *)mimeType
                                   properties:(CMISProperties *)properties
                                     inFolder:(NSString *)folderObjectId
                                bytesExpected:(unsigned long long)bytesExpected // optional
                              completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                                progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    // Validate properties
    if ([properties propertyValueForId:kCMISPropertyName] == nil || [properties propertyValueForId:kCMISPropertyObjectTypeId] == nil) {
        CMISLogError(@"Must provide %@ and %@ as properties", kCMISPropertyName, kCMISPropertyObjectTypeId);
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        }
        return nil;
    }
    
    // Validate mimetype
    if (inputStream && !mimeType) {
        CMISLogError(@"Must provide a mimetype when creating a cmis document");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        }
        return nil;
    }
    
    CMISRequest *request = [[CMISRequest alloc] init];
    // Get Down link
    [self loadLinkForObjectId:folderObjectId
                     relation:kCMISLinkRelationDown
                         type:kCMISMediaTypeChildren
                  cmisRequest:request
              completionBlock:^(NSString *downLink, NSError *error) {
                          if (error) {
                              CMISLogError(@"Could not retrieve down link: %@", error.description);
                              if (completionBlock) {
                                  completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
                              }
                          } else {
                              [self sendAtomEntryXmlToLink:downLink
                                         httpRequestMethod:HTTP_POST
                                                properties:properties
                                        contentInputStream:inputStream
                                           contentMimeType:mimeType
                                             bytesExpected:bytesExpected
                                               cmisRequest:request
                                           completionBlock:completionBlock
                                             progressBlock:progressBlock];
                          }
                      }];
    return request;
}


- (CMISRequest*)deleteObject:(NSString *)objectId
         allVersions:(BOOL)allVersions
     completionBlock:(void (^)(BOOL objectDeleted, NSError *error))completionBlock
{
    CMISRequest *request = [[CMISRequest alloc] init];
    [self loadLinkForObjectId:objectId
                     relation:kCMISLinkRelationSelf 
                  cmisRequest:request
              completionBlock:^(NSString *selfLink, NSError *error) {
        if (!selfLink) {
            completionBlock(NO, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        } else {
            NSURL *selfUrl = [NSURL URLWithString:selfLink];
            [self.bindingSession.networkProvider invokeDELETE:selfUrl
                                                      session:self.bindingSession
                                                  cmisRequest:request
                                              completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                       if (httpResponse) {
                           completionBlock(YES, nil);
                       } else {
                           completionBlock(NO, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeUpdateConflict]);
                       }
                   } ];
        }
    }];
    return request;
}

- (CMISRequest*)createFolderInParentFolder:(NSString *)folderObjectId
                        properties:(CMISProperties *)properties
                   completionBlock:(void (^)(NSString *, NSError *))completionBlock
{
    if ([properties propertyValueForId:kCMISPropertyName] == nil || [properties propertyValueForId:kCMISPropertyObjectTypeId] == nil) {
        CMISLogError(@"Must provide %@ and %@ as properties", kCMISPropertyName, kCMISPropertyObjectTypeId);
        completionBlock(nil,  [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        return nil;
    }
    
    // Validate parent folder id
    if (!folderObjectId) {
        CMISLogError(@"Must provide a parent folder object id when creating a new folder");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound detailedDescription:nil]);
        return nil;
    }
    CMISRequest *request = [[CMISRequest alloc] init];
    // Get Down link
    [self loadLinkForObjectId:folderObjectId
                     relation:kCMISLinkRelationDown
                         type:kCMISMediaTypeChildren
                  cmisRequest:request
              completionBlock:^(NSString *downLink, NSError *error) {
                          if (error) {
                              CMISLogError(@"Could not retrieve down link: %@", error.description);
                              completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
                          } else {
                              [self sendAtomEntryXmlToLink:downLink
                                         httpRequestMethod:HTTP_POST
                                                properties:properties
                                               cmisRequest:request
                                           completionBlock:^(CMISObjectData *objectData, NSError *error) {
                                               completionBlock(objectData.identifier, error);
                                           }];
                          }
                      }];
    return request;
}

- (CMISRequest*)deleteTree:(NSString *)folderObjectId
                allVersion:(BOOL)allVersions
             unfileObjects:(CMISUnfileObject)unfileObjects
         continueOnFailure:(BOOL)continueOnFailure
           completionBlock:(void (^)(NSArray *failedObjects, NSError *error))completionBlock
{
    // Validate params
    if (!folderObjectId) {
        CMISLogError(@"Must provide a folder object id when deleting a folder tree");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound detailedDescription:nil]);
        return nil;
    }
    CMISRequest *request = [[CMISRequest alloc] init];
    
    [self loadLinkForObjectId:folderObjectId
                     relation:kCMISLinkRelationDown
                         type:kCMISMediaTypeDescendants
                  cmisRequest:request
              completionBlock:^(NSString *link, NSError *error) {
        if (error) {
            CMISLogError(@"Error while fetching %@ link : %@", kCMISLinkRelationDown, error.description);
            completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeRuntime]);
            return;
        }
        
        void (^continueWithLink)(NSString *) = ^(NSString *link) {
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterAllVersions value:(allVersions ? @"true" : @"false") urlString:link];
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterUnfileObjects value:[CMISEnums stringForUnfileObject:unfileObjects] urlString:link];
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterContinueOnFailure value:(continueOnFailure ? @"true" : @"false") urlString:link];
            
            [self.bindingSession.networkProvider invokeDELETE:[NSURL URLWithString:link]
                                                      session:self.bindingSession
                                                  cmisRequest:request
                                              completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                       if (httpResponse) {
                           // TODO: retrieve failed folders and files and return
                           completionBlock([NSArray array], nil);
                       } else {
                           completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
                       }
                   }];
        };
        
        if (link == nil) {
            [self loadLinkForObjectId:folderObjectId
                             relation:kCMISLinkRelationFolderTree
                          cmisRequest:request
                      completionBlock:^(NSString *link, NSError *error) {
                if (error) {
                    CMISLogError(@"Error while fetching %@ link : %@", kCMISLinkRelationFolderTree, error.description);
                    completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeRuntime]);
                } else if (link == nil) {
                    CMISLogError(@"Could not retrieve %@ nor %@ link", kCMISLinkRelationDown, kCMISLinkRelationFolderTree);
                    completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeRuntime]);
                } else {
                    continueWithLink(link);
                }
            }];
        } else {
            continueWithLink(link);
        }
    }];
    return request;
}

- (CMISRequest*)updatePropertiesForObject:(CMISStringInOutParameter *)objectIdParam
                       properties:(CMISProperties *)properties
                      changeToken:(CMISStringInOutParameter *)changeTokenParam
                  completionBlock:(void (^)(NSError *error))completionBlock
{
    // Validate params
    if (objectIdParam == nil || objectIdParam.inParameter == nil) {
        CMISLogError(@"Object id is nil or inParameter of objectId is nil");
        completionBlock([[NSError alloc] init]); // TODO: properly init error (CmisInvalidArgumentException)
        return nil;
    }
    
    CMISRequest *request = [[CMISRequest alloc] init];
    // Get self link
    [self loadLinkForObjectId:objectIdParam.inParameter
                     relation:kCMISLinkRelationSelf
                  cmisRequest:request
              completionBlock:^(NSString *selfLink, NSError *error) {
        if (selfLink == nil) {
            CMISLogError(@"Could not retrieve %@ link", kCMISLinkRelationSelf);
            completionBlock([CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
            return;
        }
        
        // Append optional params
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            selfLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                        value:changeTokenParam.inParameter urlString:selfLink];
        }
        
        // Execute request
        [self sendAtomEntryXmlToLink:selfLink
                   httpRequestMethod:HTTP_PUT
                          properties:properties
                         cmisRequest:request
                     completionBlock:^(CMISObjectData *objectData, NSError *error) {
                         if (objectData == nil) {
                             completionBlock([CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
                         }
                         else {
                             // update the out parameter as the objectId may have changed
                             objectIdParam.outParameter = [[objectData.properties propertyForId:kCMISPropertyObjectId] firstValue];
                             if (changeTokenParam != nil) {
                                 changeTokenParam.outParameter = [[objectData.properties propertyForId:kCMISPropertyChangeToken] firstValue];
                             }
                             completionBlock(nil);
                         }
                     }];
    }];
    return request;
}


- (CMISRequest*)retrieveRenditions:(NSString *)objectId
           renditionFilter:(NSString *)renditionFilter
                  maxItems:(NSNumber *)maxItems
                 skipCount:(NSNumber *)skipCount
           completionBlock:(void (^)(NSArray *renditions, NSError *error))completionBlock
{
    // Only fetching the bare minimum
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    [self retrieveObjectInternal:objectId
                   returnVersion:LATEST
                          filter:kCMISPropertyObjectId
                   relationships:CMISIncludeRelationshipNone
                includePolicyIds:NO
                 renditionFilder:renditionFilter
                      includeACL:NO
         includeAllowableActions:NO
                     cmisRequest:cmisRequest
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     if (error) {
                         completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
                     } else {
                         completionBlock(objectData.renditions, nil);
                     }
                 }];
    return cmisRequest;
}

#pragma mark Helper methods

- (void)sendAtomEntryXmlToLink:(NSString *)link
             httpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
                    properties:(CMISProperties *)properties
                   cmisRequest:(CMISRequest *)request
               completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    // Validate params
    if (link == nil) {
        CMISLogError(@"Could not retrieve link from object to do creation or update");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        }
        return;
    }
    
    // Generate XML
    NSString *writeResult = [self createAtomEntryWriter:properties
                                        contentFilePath:nil
                                        contentMimeType:nil
                                    isXmlStoredInMemory:YES];
    
    // Execute call
    [self.bindingSession.networkProvider invoke:[NSURL URLWithString:link]
                                     httpMethod:httpRequestMethod
                                        session:self.bindingSession
                                           body:[writeResult dataUsingEncoding:NSUTF8StringEncoding]
                                        headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
                                    cmisRequest:request
                                completionBlock:^(CMISHttpResponse *response, NSError *error) {
         if (error) {
             CMISLogError(@"HTTP error when creating/uploading content: %@", error);
             if (completionBlock) {
                 completionBlock(nil, error);
             }
         } else if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
             if (completionBlock) {
                 CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:response.data];
                 NSError *parseError = nil;
                 [atomEntryParser parseAndReturnError:&parseError];
                 if (parseError == nil) {
                     completionBlock(atomEntryParser.objectData, nil);
                 } else {
                     CMISLogError(@"Error while parsing response: %@", [parseError description]);
                     completionBlock(nil, [CMISErrors cmisError:parseError cmisErrorCode:kCMISErrorCodeUpdateConflict]);
                 }
             }
         } else {
             CMISLogError(@"Invalid http response status code when creating/uploading content: %d", response.statusCode);
             CMISLogError(@"Error content: %@", [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
             if (completionBlock) {
                 completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
             }
         }
     }];
}

/**
 This method uses a new invoke call on the CMISNetworkProvider. This new method was introduced to allow for base64 encoding while
 streaming. See CMISHttpUploadRequest for more details on how it is done.
 */
- (void)sendAtomEntryXmlToLink:(NSString *)link
             httpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
                    properties:(CMISProperties *)properties
            contentInputStream:(NSInputStream *)contentInputStream
               contentMimeType:(NSString *)contentMimeType
                 bytesExpected:(unsigned long long)bytesExpected
                   cmisRequest:(CMISRequest*)request
               completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                 progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    // Validate param
    if (link == nil) {
        CMISLogError(@"Could not retrieve link from object to do creation or update");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        }
        return;
    }
    
        
    [self.bindingSession.networkProvider invoke:[NSURL URLWithString:link]
                                     httpMethod:HTTP_POST
                                        session:self.bindingSession
                                    inputStream:contentInputStream
                                        headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
                                  bytesExpected:bytesExpected
                                    cmisRequest:request
                                 cmisProperties:properties
                                       mimeType:contentMimeType
                                completionBlock:^(CMISHttpResponse *response, NSError *error) {
         if (error) {
             CMISLogError(@"HTTP error when creating/uploading content: %@", error);
             if (completionBlock) {
                 completionBlock(nil, error);
             }
         } else if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
             if (completionBlock) {
                 NSError *parseError = nil;
                 CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:response.data];
                 [atomEntryParser parseAndReturnError:&parseError];
                 if (parseError == nil) {
                     completionBlock(atomEntryParser.objectData.identifier, nil);
                 } else {
                     CMISLogError(@"Error while parsing response: %@", [parseError description]);
                     completionBlock(nil, [CMISErrors cmisError:parseError cmisErrorCode:kCMISErrorCodeUpdateConflict]);
                 }
             }
         } else {
             CMISLogError(@"Invalid http response status code when creating/uploading content: %d", response.statusCode);
             CMISLogError(@"Error content: %@", [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
             if (completionBlock) {
                 completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                                  detailedDescription:[NSString stringWithFormat:@"Could not create content: http status code %d", response.statusCode]]);
             }
         }
     }
       progressBlock:progressBlock];
}

/**
 This is the original version of the 'sendAtomEntryXmlToLink' method.
 It creates a temporary file to store the base64 encoded data in. It is from this file that the upload starts
 */
- (void)sendAtomEntryXmlToLinkUsingTmpFile:(NSString *)link
                         httpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
                                properties:(CMISProperties *)properties
                        contentInputStream:(NSInputStream *)contentInputStream
                           contentMimeType:(NSString *)contentMimeType
                             bytesExpected:(unsigned long long)bytesExpected
                               cmisRequest:(CMISRequest*)request
                           completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                             progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    // Validate param
    if (link == nil) {
        CMISLogError(@"Could not retrieve link from object to do creation or update");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        }
        return;
    }
    
    
    // Generate XML
     NSString *writeResult = [self createAtomEntryWriter:properties
                                      contentInputStream:contentInputStream
                                         contentMimeType:contentMimeType
                                     isXmlStoredInMemory:NO];
     
     
     NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:writeResult];
     NSError *fileSizeError = nil;
     unsigned long long fileSize = [CMISFileUtil fileSizeForFileAtPath:writeResult error:&fileSizeError];
     if (fileSizeError) {
         CMISLogError(@"Could not determine file size of %@ : %@", writeResult, [fileSizeError description]);
     }
    
    [self.bindingSession.networkProvider invoke:[NSURL URLWithString:link]
                                     httpMethod:HTTP_POST
                                        session:self.bindingSession
                                    inputStream:inputStream
                                        headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
                                  bytesExpected:fileSize
                                    cmisRequest:request
                                completionBlock:^(CMISHttpResponse *response, NSError *error) {
                                    // close stream to and delete temporary file
                                    [inputStream close];
                                    
                                     NSError *fileError = nil;
                                     [[NSFileManager defaultManager] removeItemAtPath:writeResult error:&fileError];
                                     if (fileError) {
                                     // the upload itself is not impacted by this error, so do not report it in the completion block
                                     CMISLogError(@"Could not delete temporary file %@: %@", writeResult, [fileError description]);
                                     }
                                    if (error) {
                                        CMISLogError(@"HTTP error when creating/uploading content: %@", error);
                                        if (completionBlock) {
                                            completionBlock(nil, error);
                                        }
                                    } else if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
                                        if (completionBlock) {
                                            NSError *parseError = nil;
                                            CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:response.data];
                                            [atomEntryParser parseAndReturnError:&parseError];
                                            if (parseError == nil) {
                                                completionBlock(atomEntryParser.objectData.identifier, nil);
                                            } else {
                                                CMISLogError(@"Error while parsing response: %@", [parseError description]);
                                                completionBlock(nil, [CMISErrors cmisError:parseError cmisErrorCode:kCMISErrorCodeUpdateConflict]);
                                            }
                                        }
                                    } else {
                                        CMISLogError(@"Invalid http response status code when creating/uploading content: %d", response.statusCode);
                                        CMISLogError(@"Error content: %@", [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
                                        if (completionBlock) {
                                            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                                                                 detailedDescription:[NSString stringWithFormat:@"Could not create content: http status code %d", response.statusCode]]);
                                        }
                                    }
                                }
                                  progressBlock:progressBlock];
}




/**
 * Helper method: creates a writer for the xml needed to upload a file.
 * The atom entry XML can become huge, as the whole file is stored as base64 in the XML itself
 * Hence, we're allowing to store the atom entry xml in a temporary file and stream the body of the http post
 */
- (NSString *)createAtomEntryWriter:(CMISProperties *)properties
                    contentFilePath:(NSString *)contentFilePath
                    contentMimeType:(NSString *)contentMimeType
                isXmlStoredInMemory:(BOOL)isXmlStoredInMemory
{
    
    CMISAtomEntryWriter *atomEntryWriter = [[CMISAtomEntryWriter alloc] init];
    atomEntryWriter.contentFilePath = contentFilePath;
    atomEntryWriter.mimeType = contentMimeType;
    atomEntryWriter.cmisProperties = properties;
    atomEntryWriter.generateXmlInMemory = isXmlStoredInMemory;
    NSString *writeResult = [atomEntryWriter generateAtomEntryXml];
    return writeResult;
}

- (NSString *)createAtomEntryWriter:(CMISProperties *)properties
                 contentInputStream:(NSInputStream *)contentInputStream
                    contentMimeType:(NSString *)contentMimeType
                isXmlStoredInMemory:(BOOL)isXmlStoredInMemory
{
    
    CMISAtomEntryWriter *atomEntryWriter = [[CMISAtomEntryWriter alloc] init];
    atomEntryWriter.inputStream= contentInputStream;
    atomEntryWriter.mimeType = contentMimeType;
    atomEntryWriter.cmisProperties = properties;
    atomEntryWriter.generateXmlInMemory = isXmlStoredInMemory;
    NSString *writeResult = [atomEntryWriter generateAtomEntryXml];
    return writeResult;
}

@end
