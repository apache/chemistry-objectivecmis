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
#import "ObjectiveCMISTests.h"
#import "CMISSession.h"
#import "CMISConstants.h"
#import "CMISFileUtil.h"
#import "CMISAtomLink.h"
#import "CMISAtomPubConstants.h"
#import "CMISObjectList.h"
#import "CMISQueryResult.h"
#import "CMISStringInOutParameter.h"
#import "CMISTypeDefinition.h"
#import "CMISPropertyDefinition.h"
#import "CMISObjectConverter.h"
#import "CMISOperationContext.h"
#import "CMISPagedResult.h"
#import "CMISRenditionData.h"
#import "CMISRendition.h"
#import "CMISAtomFeedParser.h"
#import "CMISAtomPubServiceDocumentParser.h"
#import "CMISAtomWorkspace.h"
#import "CMISRequest.h"
#import "CMISErrors.h"
#import "CMISDateUtil.h"
#import "CMISLog.h"
#import "CMISURLUtil.h"
#import "CMISMimeHelper.h"
#import "CMISQueryStatement.h"

@interface ObjectiveCMISTests ()

@property (nonatomic, strong) CMISRequest *request;

@end


@implementation ObjectiveCMISTests

- (void)testLogging
{
    // grab the singleton instance of the logger
    CMISLog *logger = [CMISLog sharedInstance];
    
    // remember the current log level so we can reset it later
    CMISLogLevel startingLogLevel = logger.logLevel;
    
    // set level to off, message should not appear
    logger.logLevel = CMISLogLevelOff;
    [logger logTrace:@"** FAIL ** This message should not appear **"];
    
    // set level to error, message should not appear
    logger.logLevel = CMISLogLevelError;
    [logger logTrace:@"** FAIL ** This message should not appear **"];
    
    // set level to warning, message should not appear
    logger.logLevel = CMISLogLevelWarning;
    [logger logTrace:@"** FAIL ** This message should not appear **"];
    
    // set level to info, message should not appear
    logger.logLevel = CMISLogLevelInfo;
    [logger logTrace:@"** FAIL ** This message should not appear **"];
    
    // set level to debug, message should not appear
    logger.logLevel = CMISLogLevelDebug;
    [logger logTrace:@"** FAIL ** This message should not appear **"];
    
    // set level to trace, message should appear
    logger.logLevel = CMISLogLevelTrace;
    [logger logTrace:@"This is a TRACE level message so should appear"];

    // set level to Trace so all messages appear
    logger.logLevel = CMISLogLevelTrace;
    
    CMISLogError(@"This is an ERROR message");
    CMISLogWarning(@"This is a WARNING message");
    CMISLogInfo(@"This is an INFO message");
    CMISLogDebug(@"This is a DEBUG message");
    CMISLogTrace(@"This is a TRACE message");
    
    // set level to Trace so all messages appear
    logger.logLevel = CMISLogLevelTrace;
    
    NSString *str = @"A string";
    
    CMISLogError(@"ERROR message with parameter: %@", str);
    CMISLogWarning(@"WARNING message with parameter: %@", str);
    CMISLogInfo(@"INFO message with parameter: %@", str);
    CMISLogDebug(@"DEBUG message with parameter: %@", str);
    CMISLogTrace(@"TRACE message with parameter: %@", str);
    
    [logger logError:@"ERROR message with parameter: %@", str];
    [logger logWarning:@"WARNING message with parameter: %@", str];
    [logger logInfo:@"INFO message with parameter: %@", str];
    [logger logDebug:@"DEBUG message with parameter: %@", str];
    [logger logTrace:@"DEBUG message with parameter: %@", str];
    
    // create an NSError object
    NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
    [errorInfo setValue:@"Error description" forKey:NSLocalizedDescriptionKey];
    NSError *error = [NSError errorWithDomain:kCMISErrorDomainName code:kCMISErrorCodeRuntime userInfo:errorInfo];
    
    [logger logErrorFromError:error];
    
    // reset the log level to what it was at the beginning
    logger.logLevel = startingLogLevel;
}

- (void)testRepositories
{
    [self runTest:^ {
        [CMISSession arrayOfRepositories:self.parameters completionBlock:^(NSArray *repos, NSError *error) {
            XCTAssertNil(error, @"Error when calling arrayOfRepositories : %@", [error description]);
            XCTAssertNotNil(repos, @"repos object should not be nil");
            XCTAssertTrue(repos.count > 0, @"There should be at least one repository");
            
            for (CMISRepositoryInfo *repoInfo in repos) {
                CMISLogDebug(@"Repo id: %@", repoInfo.identifier);
            }
            self.testCompleted = YES;
        }];
    }];
}

- (void)testAuthenticateWithInvalidCredentials
{
    [self runTest:^ {
        CMISSessionParameters *bogusParams = nil;
        if (self.parameters.bindingType == CMISBindingTypeAtomPub) {
            bogusParams = [[CMISSessionParameters alloc] initWithBindingType:CMISBindingTypeAtomPub];
            bogusParams.atomPubUrl = self.parameters.atomPubUrl;
        } else {
            bogusParams = [[CMISSessionParameters alloc] initWithBindingType:CMISBindingTypeBrowser];
            bogusParams.browserUrl = self.parameters.browserUrl;
        }
        bogusParams.repositoryId = self.parameters.repositoryId;
        bogusParams.username = @"bogus";
        bogusParams.password = @"sugob";

        [CMISSession connectWithSessionParameters:bogusParams completionBlock:^(CMISSession *session, NSError *error){
            XCTAssertNil(session, @"we should not get back a valid session");
            if (nil == session) {
                CMISLogDebug(@"*** testAuthenticateWithInvalidCredentials: error domain is %@, error code is %d and error description is %@",[error domain], [error code], [error description]);
                NSError *underlyingError = [[error userInfo] valueForKey:NSUnderlyingErrorKey];
                if (underlyingError) {
                    CMISLogDebug(@"There is an underlying error with reason %@ and error code %d",[underlyingError localizedDescription], [underlyingError code]);
                }
            }
            self.testCompleted = YES;
        }];        
    }];
}

- (void)testGetRootFolder
{
    [self runTest:^ {
        // make sure the repository info is available immediately after authentication
        CMISRepositoryInfo *repoInfo = self.session.repositoryInfo;
        XCTAssertNotNil(repoInfo, @"repoInfo object should not be nil");

        // check the repository info is what we expect
        XCTAssertTrue([repoInfo.productVersion rangeOfString:@"4."].length > 0, @"Product Version should be 4.x.x, but was %@", repoInfo.productVersion);
        XCTAssertTrue([repoInfo.productName hasPrefix:@"Alfresco"], @"Product name should start with Alfresco, but was %@", repoInfo.productName);
        XCTAssertTrue([repoInfo.vendorName isEqualToString:@"Alfresco"], @"Vendor name should be Alfresco, but was %@", repoInfo.vendorName);

        // retrieve the root folder
        [self.session retrieveRootFolderWithCompletionBlock:^(CMISFolder *rootFolder, NSError *error) {
            XCTAssertNotNil(rootFolder, @"rootFolder object should not be nil");
            NSString *rootName = rootFolder.name;
            XCTAssertTrue([rootName isEqualToString:@"Company Home"], @"rootName should be Company Home, but was %@", rootName);

            // check it was modified and created by System and the dates are not nil
            NSString *createdBy = rootFolder.createdBy;
            XCTAssertTrue([createdBy isEqualToString:@"System"], @"root folder should be created by System");
            
            NSString *modifiedBy = rootFolder.lastModifiedBy;
            XCTAssertNotNil(modifiedBy, @"modifiedBy should not be nil");
            
            NSDate *createdDate = rootFolder.creationDate;
            XCTAssertNotNil(createdDate, @"created date should not be nil");
            
            NSDate *modifiedDate = rootFolder.lastModificationDate;
            XCTAssertNotNil(modifiedDate, @"modified date should not be nil");
            
            // test various aspects of type definition
            CMISTypeDefinition *typeDef = rootFolder.typeDefinition;
            XCTAssertNotNil(typeDef, @"Expected the type definition to be present");
            XCTAssertTrue([typeDef.identifier isEqualToString:@"cmis:folder"], @"Expected typeDef.identifier to be cmis:folder but it was %@", typeDef.identifier);
            XCTAssertTrue([typeDef.localName isEqualToString:@"folder"], @"Expected typeDef.localName to be folder but it was %@", typeDef.localName);
            XCTAssertTrue([typeDef.queryName isEqualToString:@"cmis:folder"], @"Expected typeDef.queryName to be cmis:folder but it was %@", typeDef.queryName);
            XCTAssertTrue(typeDef.baseTypeId == CMISBaseTypeFolder, @"Expected baseTypeId to be cmis:folder");
            XCTAssertTrue(typeDef.creatable, @"Expected creatable to be true");
            XCTAssertTrue(typeDef.fileable, @"Expected fileable to be true");
            XCTAssertTrue(typeDef.queryable, @"Expected queryable to be true");
            XCTAssertTrue(typeDef.fullTextIndexed, @"Expected fullTextIndexed to be true");
            XCTAssertTrue(typeDef.includedInSupertypeQuery, @"Expected includedInSupertypeQuery to be true");
            XCTAssertTrue(typeDef.controllableAcl, @"Expected controllableAcl to be true");
            XCTAssertFalse(typeDef.controllablePolicy, @"Expected controllablePolicy to be false");
            
            CMISPropertyDefinition *objectTypeIdDef = typeDef.propertyDefinitions[@"cmis:objectTypeId"];
            XCTAssertNotNil(objectTypeIdDef, @"Expected to find cmis:objectTypeId property definition");
            XCTAssertTrue([objectTypeIdDef.identifier isEqualToString:@"cmis:objectTypeId"],
                          @"Expected objectTypeIdDef.id to be cmis:objectTypeId but it was %@", objectTypeIdDef.identifier);
            XCTAssertTrue([objectTypeIdDef.localName isEqualToString:@"objectTypeId"],
                          @"Expected objectTypeIdDef.localName to be objectTypeId but it was %@", objectTypeIdDef.localName);
            XCTAssertTrue(objectTypeIdDef.propertyType == CMISPropertyTypeId, @"Expected objectTypeId type to be id");
            XCTAssertTrue(objectTypeIdDef.cardinality == CMISCardinalitySingle, @"Expected objectTypeId cardinality to be single");
            XCTAssertTrue(objectTypeIdDef.updatability == CMISUpdatabilityOnCreate, @"Expected objectTypeId updatability to be oncreate");
            XCTAssertTrue(objectTypeIdDef.required, @"Expected objectTypeId to be required");
            
            // test secondary type id when using the 1.1 bindings
            CMISPropertyDefinition *secondaryTypeIdDef = typeDef.propertyDefinitions[@"cmis:secondaryObjectTypeIds"];
            if (secondaryTypeIdDef != nil)
            {
                XCTAssertNotNil(secondaryTypeIdDef, @"Expected to find cmis:secondaryObjectTypeIds property definition");
                XCTAssertTrue([secondaryTypeIdDef.identifier isEqualToString:@"cmis:secondaryObjectTypeIds"],
                              @"Expected secondaryTypeIdDef.id to be cmis:secondaryObjectTypeIds but it was %@", secondaryTypeIdDef.identifier);
                XCTAssertTrue([secondaryTypeIdDef.localName isEqualToString:@"secondaryObjectTypeIds"],
                              @"Expected objectTypeIdDef.localName to be secondaryObjectTypeIds but it was %@", secondaryTypeIdDef.localName);
                XCTAssertTrue(secondaryTypeIdDef.propertyType == CMISPropertyTypeId, @"Expected secondaryTypeIdDef type to be id");
                XCTAssertTrue(secondaryTypeIdDef.cardinality == CMISCardinalityMulti, @"Expected secondaryTypeIdDef cardinality to be multi");
                XCTAssertTrue(secondaryTypeIdDef.updatability == CMISUpdatabilityReadWrite, @"Expected secondaryTypeIdDef updatability to be readwrite");
                XCTAssertFalse(secondaryTypeIdDef.required, @"Expected secondaryTypeIdDef to be optional");
            }
            
            // test some other random properties
            CMISPropertyDefinition *creationDateDef = typeDef.propertyDefinitions[@"cmis:creationDate"];
            XCTAssertTrue(creationDateDef.propertyType == CMISPropertyTypeDateTime, @"Expected creationDateDef type to be datetime");
            XCTAssertTrue(creationDateDef.updatability == CMISUpdatabilityReadOnly, @"Expected creationDateDef updatability to be readonly");
            
            // retrieve the children of the root folder, there should be more than 10!
            [rootFolder retrieveChildrenWithCompletionBlock:^(CMISPagedResult *pagedResult, NSError *error) {
                XCTAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                XCTAssertNotNil(pagedResult, @"Return result should not be nil");
                
                NSArray *children = pagedResult.resultArray;
                XCTAssertNotNil(children, @"children should not be nil");
                CMISLogDebug(@"There are %d children", [children count]);
                XCTAssertTrue([children count] >= 3, @"There should be at least 3 children");
                
                self.testCompleted = YES;
            }];
        }];
    }];
}

- (void)testRetrieveFolderChildrenUsingPaging
{
    [self runTest:^ {
        // Fetch 2 children at a time
        CMISOperationContext *operationContext = [CMISOperationContext defaultOperationContext];
        operationContext.skipCount = 0;
        operationContext.maxItemsPerPage = 2;
        [self.session retrieveObjectByPath:@"/ios-test" completionBlock:^(CMISObject *object, NSError *error) {
            CMISFolder *testFolder = (CMISFolder *)object;
            XCTAssertNil(error, @"Got error while retrieving test folder: %@", [error description]);
            [testFolder retrieveChildrenWithOperationContext:operationContext completionBlock:^(CMISPagedResult *pagedResult, NSError *error) {
                XCTAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                XCTAssertTrue(pagedResult.hasMoreItems, @"There should still be more children");
                XCTAssertTrue(pagedResult.numItems > 6, @"The test repository should have more than 6 objects");
                XCTAssertTrue(pagedResult.resultArray.count == 2, @"Expected 2 children in the page, but got %lu", (unsigned long)pagedResult.resultArray.count);
                
                // Save object ids for checking the next pages
                NSMutableArray *objectIds = [NSMutableArray array];
                for (CMISObject *object in pagedResult.resultArray) {
                    [objectIds addObject:object.identifier];
                }
                
                // Fetch second page
                [pagedResult fetchNextPageWithCompletionBlock:^(CMISPagedResult *secondPageResult, NSError *error) {
                    XCTAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                    XCTAssertTrue(secondPageResult.hasMoreItems, @"There should still be more children");
                    XCTAssertTrue(secondPageResult.numItems > 6, @"The test repository should have more than 6 objects");
                    XCTAssertTrue(secondPageResult.resultArray.count == 2, @"Expected 2 children in the page, but got %lu", (unsigned long)secondPageResult.resultArray.count);
                    
                    // Verify if no double object ids were found
                    for (CMISObject *object in secondPageResult.resultArray) {
                        XCTAssertTrue(![objectIds containsObject:object.identifier], @"Object was already returned in a previous page. This is a serious impl bug!");
                        [objectIds addObject:object.identifier];
                    }
                    
                    
                    // Fetch third page, just to be sure
                    [secondPageResult fetchNextPageWithCompletionBlock:^(CMISPagedResult *thirdPageResult, NSError *error) {
                        XCTAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                        XCTAssertTrue(thirdPageResult.hasMoreItems, @"There should still be more children");
                        XCTAssertTrue(thirdPageResult.numItems > 6, @"The test repository should have more than 6 objects");
                        XCTAssertTrue(thirdPageResult.resultArray.count == 2, @"Expected 2 children in the page, but got %lu", (unsigned long)thirdPageResult.resultArray.count);
                    
                        // Verify if no double object ids were found
                        for (CMISObject *object in thirdPageResult.resultArray)
                        {
                            XCTAssertTrue(![objectIds containsObject:object.identifier], @"Object was already returned in a previous page. This is a serious impl bug!");
                            [objectIds addObject:object.identifier];
                        }
                        
                        self.testCompleted = YES;
                    }];
                }];
            }];
        }];
    }];
}

- (void)testDocumentProperties
{
    [self runTest:^ {

        // Get some random document
        [self retrieveVersionedTestDocumentWithCompletionBlock:^(CMISDocument *document) {
            // Verify properties
            XCTAssertNotNil(document.name, @"Document name should not be nil");
            XCTAssertNotNil(document.identifier, @"Document identifier should not be nil");
            XCTAssertNotNil(document.objectType, @"Document object type should not be nil");
            
            XCTAssertNotNil(document.createdBy, @"Document created by should not be nil");
            XCTAssertNotNil(document.creationDate, @"Document creation date should not be nil");
            
            XCTAssertNotNil(document.lastModificationDate, @"Document last modification date should not be nil");
            XCTAssertNotNil(document.lastModifiedBy, @"Document last modified by should not be nil");
            
            XCTAssertNotNil(document.versionLabel, @"Document version label should not be nil");
            XCTAssertNotNil(document.versionSeriesId, @"Document version series id should not be nil");
            XCTAssertTrue(document.isLatestVersion, @"Document should be latest version");
            //XCTAssertFalse(document.isLatestMajorVersion, @"Document should be latest major version");
            XCTAssertFalse(document.isMajorVersion, @"Document should not be major version");
            
            XCTAssertNotNil(document.contentStreamId, @"Document content stream id should not be nil");
            XCTAssertNotNil(document.contentStreamFileName, @"Document content stream file name should not be nil");
            XCTAssertNotNil(document.contentStreamMediaType, @"Document content stream media type should not be nil");
            XCTAssertTrue(document.contentStreamLength > 0, @"Document content stream length should be set");
            
            self.testCompleted = YES;
        }];
    }];
}


- (void)testRetrieveAllowableActions
{
    [self runTest:^ {
        [self uploadTestFileWithCompletionBlock:^(CMISDocument *document) {
            XCTAssertNotNil(document.allowableActions, @"Allowable actions should not be nil");
            XCTAssertTrue(document.allowableActions.allowableActionsSet.count > 0, @"Expected at least one allowable action");
            
            // Cleanup
            [self deleteDocumentAndVerify:document completionBlock:^{
                self.testCompleted = YES;
            }];
        }];
    }];
}

- (void)testFileDownload
{
    [self runTest:^ {
        [self.session retrieveObjectByPath:@"/ios-test" completionBlock:^(CMISObject *object, NSError *error) {
            CMISFolder *testFolder = (CMISFolder *)object;
            XCTAssertNil(error, @"Error while retrieving folder: %@", [error description]);
            XCTAssertNotNil(testFolder, @"folder object should not be nil");
            
            CMISOperationContext *operationContext = [CMISOperationContext defaultOperationContext];
            operationContext.maxItemsPerPage = 100;
            [testFolder retrieveChildrenWithOperationContext:operationContext completionBlock:^(CMISPagedResult *childrenResult, NSError *error) {
                XCTAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                XCTAssertNotNil(childrenResult, @"childrenCollection should not be nil");
                
                NSArray *children = childrenResult.resultArray;
                XCTAssertNotNil(children, @"children should not be nil");
                XCTAssertTrue([children count] >= 3, @"There should be at least 3 children");
                
                CMISDocument *randomDoc = nil;
                for (CMISObject *object in children) {
                    if ([object class] == [CMISDocument class]) {
                        randomDoc = (CMISDocument *)object;
                    }
                }
                
                if(!randomDoc) { // stopping test here or else it would run until the test timeout is reached
                    XCTAssertNotNil(randomDoc, @"Can only continue test if test folder contains at least one document");
                    self.testCompleted = YES;
                    return;
                }
                CMISLogDebug(@"Fetching content stream for document %@", randomDoc.name);
                
                // Writing content of CMIS document to local file
                NSString *filePath = [NSString stringWithFormat:@"%@/testfile", NSTemporaryDirectory()];
//                NSString *filePath = @"testfile";
                [randomDoc downloadContentToFile:filePath
                                 completionBlock:^(NSError *error) {
                    if (error == nil) {
                        // Assert File exists and check file length
                        XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath], @"File does not exist");
                        NSError *fileError = nil;
                        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&fileError];
                        XCTAssertNil(fileError, @"Could not verify attributes of file %@: %@", filePath, [fileError description]);
                        XCTAssertTrue([fileAttributes fileSize] >= 10, @"Expected a file of at least 10 bytes, but found one of %llu bytes", [fileAttributes fileSize]);
                        
                        // Nice boys clean up after themselves
                        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
                        XCTAssertNil(fileError, @"Could not remove file %@: %@", filePath, [fileError description]);
                    } else {
                        XCTAssertNil(error, @"Error while writing content: %@", [error description]);
                    }
                    self.testCompleted = YES;
                } progressBlock:nil];
            }];
        }];
    }];
}

- (void)testCancelDownload
{
    [self runTest:^ {
         [self.session retrieveObjectByPath:@"/ios-test/activiti-modeler.png" completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             XCTAssertNil(error, @"Error while retrieving object: %@", [error description]);

             // Writing content of CMIS document to local file
             NSString *filePath = [NSString stringWithFormat:@"%@/testfile", NSTemporaryDirectory()];
             self.request = [document downloadContentToFile:filePath
                                            completionBlock:^(NSError *error) {
                 XCTAssertNotNil(error, @"Could not cancel download");
                 XCTAssertTrue(error.code == kCMISErrorCodeCancelled, @"Unexpected error: %@", [error description]);
                 // Assert File exists and check file length
                 XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath], @"File does not exist");
                 NSError *fileError = nil;
                 NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&fileError];
                 XCTAssertNil(fileError, @"Could not verify attributes of file %@: %@", filePath, [fileError description]);
                 XCTAssertTrue([fileAttributes fileSize] > 0, @"Expected at least some bytes but found an empty file");
                 XCTAssertTrue([fileAttributes fileSize] < document.contentStreamLength, @"Could not cancel download before the complete file was downloaded");
                                          
                 // Nice boys clean up after themselves
                 [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
                 XCTAssertNil(fileError, @"Could not remove file %@: %@", filePath, [fileError description]);

                 self.testCompleted = YES;
             } progressBlock:^(unsigned long long bytesDownloaded, unsigned long long bytesTotal) {
                 CMISLogDebug(@"download progress %llu/%llu", bytesDownloaded, bytesTotal);
                 if (bytesDownloaded > 0) { // as soon as some data was downloaded cancel the request
                     [self.request cancel];
                     CMISLogDebug(@"download cancelled");
                     self.request = nil;
                 }
             }];
         }];
     }];
}

- (void)testCancelCreate
{
    [self runTest:^ {
        // Set properties on test file
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"cmis-spec-v1.0.pdf" ofType:nil];
        NSString *documentName = [NSString stringWithFormat:@"cmis_10_spec_%f.txt", [[NSDate date] timeIntervalSince1970]];
        NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
        [documentProperties setObject:documentName forKey:kCMISPropertyName];
        [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];
        
        // Upload test file
        self.request = [self.session createDocumentFromFilePath:filePath
                                                       mimeType:@"application/pdf"
                                                     properties:documentProperties
                                                       inFolder:self.rootFolder.identifier
                                                completionBlock: ^ (NSString *newObjectId, NSError *error) {
                                                    
                                                    XCTAssertNotNil(error, @"Failed to cancel upload");
                                                    XCTAssertTrue(error.code == kCMISErrorCodeCancelled, @"Expected error code to be 6 (kCMISErrorCodeCancelled) but it was %ld", (long)error.code);
                                                    XCTAssertNil(newObjectId, @"Did not expect to recieve a new object id");
                                                    
                                                    // ensure the object was not created on the server
                                                    NSString *path = [NSString stringWithFormat:@"/%@", documentName];
                                                    [self.session retrieveObjectByPath:path completionBlock:^(CMISObject *object, NSError *error) {
                                                        XCTAssertNotNil(error, @"Expected to get an error when attempting to retrieve cancelled upload");
                                                        XCTAssertTrue(error.code == kCMISErrorCodeObjectNotFound, @"Expected error code to be 257 (kCMISErrorCodeObjectNotFound) but it was %ld", (long)error.code);
                                                        XCTAssertNil(object, @"Did not expect the object to be created on the server");
                                                        
                                                        if (object != nil)
                                                        {
                                                            // if object was created, cleanup
                                                            [self deleteDocumentAndVerify:(CMISDocument *)object completionBlock:^{
                                                                self.testCompleted = YES;
                                                            }];
                                                        }
                                                        else
                                                        {
                                                            self.testCompleted = YES;
                                                        }
                                                    }];
                                                }
                                                  progressBlock: ^ (unsigned long long uploadedBytes, unsigned long long totalBytes) {
                                                      CMISLogDebug(@"upload progress %llu/%llu", uploadedBytes, totalBytes);
                                                      if (uploadedBytes > 0) {
                                                          // as soon as some data was uploaded cancel the request
                                                          [self.request cancel];
                                                          CMISLogDebug(@"create cancelled");
                                                          self.request = nil;
                                                      }
                                                  }];
    }];
}

- (void)testCreateAndDeleteDocument
{
    [self runTest:^ {
        // Check if test file exists
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file.txt" ofType:nil];
        XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath],
            @"Test file 'test_file.txt' cannot be found as resource for the test");

        // Upload test file
        NSString *documentName = [NSString stringWithFormat:@"test_file_%@.txt", [self stringFromCurrentDate]];
        NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
        [documentProperties setObject:documentName forKey:kCMISPropertyName];
        [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];

        __block long long previousBytesUploaded = -1;
        [self.rootFolder createDocumentFromFilePath:filePath
                                           mimeType:@"text/plain"
                                         properties:documentProperties
                                    completionBlock:^ (NSString *objectId, NSError *error) {
                 if (objectId) {
                     XCTAssertNotNil(objectId, @"Object id received should be non-nil");

                     // Verify creation
                     [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                         CMISDocument *document = (CMISDocument *)object;
                         XCTAssertTrue([documentName isEqualToString:document.name],
                                      @"Document name of created document is wrong: should be %@, but was %@", documentName, document.name);
                         
                         // Cleanup after ourselves
                         [document deleteAllVersionsWithCompletionBlock:^(BOOL documentDeleted, NSError *deleteError) {
                             XCTAssertNil(deleteError, @"Error while deleting created document: %@", [error description]);
                             XCTAssertTrue(documentDeleted, @"Document was not deleted");
                             
                             self.testCompleted = YES;
                         }];
                     }];
                 } else {
                     XCTAssertNil(error, @"Got error while creating document: %@", [error description]);
                     
                     self.testCompleted = YES;
                 }
             }
             progressBlock: ^ (unsigned long long bytesUploaded, unsigned long long bytesTotal)
             {
                 XCTAssertTrue((long long)bytesUploaded > previousBytesUploaded, @"No progress was made");
                 previousBytesUploaded = bytesUploaded;
             }];
    }];
}

- (void)testUploadFileThroughSession
{
    [self runTest:^ {

        // Set properties on test file
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file.txt" ofType:nil];
        NSString *documentName = [NSString stringWithFormat:@"test_file_%@.txt", [self stringFromCurrentDate]];
        NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
        [documentProperties setObject:documentName forKey:kCMISPropertyName];
        [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];

        // Upload test file
        __block long long previousUploadedBytes = -1;
        __block NSString *objectId = nil;
        [self.session createDocumentFromFilePath:filePath
                                        mimeType:@"text/plain"
                                      properties:documentProperties
                                        inFolder:self.rootFolder.identifier
                                 completionBlock: ^ (NSString *newObjectId, NSError *error) {
                    if (newObjectId) {
                        objectId = newObjectId;
                   
                        [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                            CMISDocument *document = (CMISDocument *)object;
                            XCTAssertNil(error, @"Got error while creating document: %@", [error description]);
                            XCTAssertNotNil(objectId, @"Object id received should be non-nil");
                            XCTAssertNotNil(document, @"Retrieved document should not be nil");
                            XCTAssertTrue(document.contentStreamLength > 0, @"No content found for document");
                            
                            // Cleanup
                            [self deleteDocumentAndVerify:document completionBlock:^{
                                self.testCompleted = YES;
                            }];
                        }];
                    } else {
                        XCTAssertNotNil(error, @"Object id should not be nil");
                        XCTAssertNil(error, @"Got error while uploading document: %@", [error description]);
                        self.testCompleted = YES;
                    }
                }
                progressBlock: ^ (unsigned long long uploadedBytes, unsigned long long totalBytes)
                {
                    XCTAssertTrue((long long)uploadedBytes > previousUploadedBytes, @"no progress");
                    previousUploadedBytes = uploadedBytes;
                }];
    }];
}

- (void)testVerySmallDocument
{
    [self runTest:^{
        NSString *fileToUploadPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"small_test.txt" ofType:nil];
        NSString *documentName = [NSString stringWithFormat:@"small_test_%@.txt", [self stringFromCurrentDate]];
        
        NSMutableDictionary *properties = [NSMutableDictionary dictionary];
        [properties setObject:documentName forKey:kCMISPropertyName];
        [properties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];
        __block NSString * smallObjectId;
        [self.rootFolder createDocumentFromFilePath:fileToUploadPath mimeType:@"text/plain" properties:properties completionBlock:^(NSString *objectId, NSError *error){
            if (objectId) {
                CMISLogDebug(@"File upload completed");
                XCTAssertNotNil(objectId, @"Object id received should be non-nil");
                smallObjectId = objectId;
                [self.session retrieveObject:smallObjectId completionBlock:^(CMISObject *object, NSError *objError){
                    if (object) {
                        CMISDocument *doc = (CMISDocument *)object;
                        [doc deleteAllVersionsWithCompletionBlock:^(BOOL deleted, NSError *deleteError){
                            XCTAssertTrue(deleted, @"should have successfully deleted file");
                            if (deleteError) {
                                CMISLogDebug(@"we have an error deleting the file %@ with message %@ and code %d", documentName, [deleteError localizedDescription], [deleteError code]);
                            }
                            self.testCompleted = YES;
                        }];
                    }
                    else{
                        XCTAssertNil(error, @"Got error while retrieving document: %@", [objError description]);
                        self.testCompleted = YES;
                        
                    }
                }];
            }
            else{
                XCTAssertNil(error, @"Got error while creating document: %@", [error description]);
                self.testCompleted = YES;
            }
        } progressBlock:^(unsigned long long bytesUploaded, unsigned long long total){}];
        
    }];
}

- (void)testCreateBigDocument
{
    [self runTest:^ {
        // Check if test file exists
        NSString *fileToUploadPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"cmis-spec-v1.0.pdf" ofType:nil];
        XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:fileToUploadPath],
            @"Test file 'cmis-spec-v1.0.pdf' cannot be found as resource for the test");

        // Upload test file
        NSString *documentName = [NSString stringWithFormat:@"cmis-spec-v1.0_%@.pdf", [self stringFromCurrentDate]];
        NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
        [documentProperties setObject:documentName forKey:kCMISPropertyName];
        [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];

        __block long long previousBytesUploaded = -1;
        __block NSString *objectId;
        [self.rootFolder createDocumentFromFilePath:fileToUploadPath
                                           mimeType:@"application/pdf"
                                         properties:documentProperties
                                    completionBlock:^(NSString *newObjectId, NSError *error) {
                   if (newObjectId) {
                       CMISLogDebug(@"File upload completed");
                       
                       objectId = newObjectId;
                       XCTAssertNotNil(objectId, @"Object id received should be non-nil");
                       
                       // Verify created file by downloading it again
                       [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                           CMISDocument *document = (CMISDocument *)object;
                           XCTAssertTrue([documentName isEqualToString:document.name],
                                        @"Document name of created document is wrong: should be %@, but was %@", documentName, document.name);
                           
                           __block long long previousBytesDownloaded = -1;
                           NSString *downloadedFilePath = [NSString stringWithFormat:@"%@/testfile.pdf", NSTemporaryDirectory()];
//                           NSString *downloadedFilePath = @"testfile.pdf";
                           [document downloadContentToFile:downloadedFilePath completionBlock:^(NSError *error) {
                               if (error == nil) {
                                   CMISLogDebug(@"File download completed");
                                   
                                   // Compare file sizes
                                   NSError *fileError;
                                   unsigned long long originalFileSize = [CMISFileUtil fileSizeForFileAtPath:fileToUploadPath error:&fileError];
                                   XCTAssertNil(fileError, @"Got error while getting file size for %@: %@", fileToUploadPath, [fileError description]);
                                   unsigned long long downloadedFileSize = [CMISFileUtil fileSizeForFileAtPath:downloadedFilePath error:&fileError];
                                   XCTAssertNil(fileError, @"Got error while getting file size for %@: %@", downloadedFilePath, [fileError description]);
                                   XCTAssertTrue(originalFileSize == downloadedFileSize, @"Original file size (%llu) is not equal to downloaded file size (%llu)", originalFileSize, downloadedFileSize);
                                   
                                   // Cleanup after ourselves
                                   [document deleteAllVersionsWithCompletionBlock:^(BOOL documentDeleted, NSError *error) {
                                       XCTAssertNil(error, @"Error while deleting created document: %@", [error description]);
                                       XCTAssertTrue(documentDeleted, @"Document was not deleted");
                                       
                                       NSError *internalError;
                                       [[NSFileManager defaultManager] removeItemAtPath:downloadedFilePath error:&internalError];
                                       XCTAssertNil(error, @"Could not remove file %@: %@", downloadedFilePath, [error description]);
                                       
                                       self.testCompleted = YES;
                                   }];
                               } else {
                                   XCTAssertNil(error, @"Error while writing content: %@", [error description]);
                                   
                                   self.testCompleted = YES;
                               }
                           } progressBlock:^(unsigned long long bytesDownloaded, unsigned long long bytesTotal) {
                               XCTAssertTrue((long long)bytesDownloaded > previousBytesDownloaded, @"No progress in downloading file");
                               previousBytesDownloaded = bytesDownloaded;
                           }];
                       }];
                   } else {
                       XCTAssertNil(error, @"Got error while creating document: %@", [error description]);
                       
                       self.testCompleted = YES;
                   }
               }
               progressBlock:^(unsigned long long bytesUploaded, unsigned long long bytesTotal)
               {
                   XCTAssertTrue((long long)bytesUploaded > previousBytesUploaded, @"No progress was made");
                   previousBytesUploaded = bytesUploaded;
               }];
    }];
}

- (void)testCreateAndDeleteFolder
{
    [self runTest:^ {
        // Create a test folder
        NSMutableDictionary *properties = [NSMutableDictionary dictionary];
        NSString *folderName = [NSString stringWithFormat:@"test-folder-%@", [self stringFromCurrentDate]];
        [properties setObject:folderName forKey:kCMISPropertyName];
        [properties setObject:kCMISPropertyObjectTypeIdValueFolder forKey:kCMISPropertyObjectTypeId];

        [self.rootFolder createFolder:properties completionBlock:^(NSString *newFolderObjectId, NSError *error) {
            XCTAssertNil(error, @"Error while creating folder in root folder: %@", [error description]);
            
            // Delete the test folder again
            [self.session retrieveObject:newFolderObjectId completionBlock:^(CMISObject *object, NSError *error) {
                CMISFolder *newFolder = (CMISFolder *)object;
                XCTAssertNil(error, @"Error while retrieving newly created folder: %@", [error description]);
                XCTAssertNotNil(newFolder, @"New folder should not be nil");
                [newFolder deleteTreeWithDeleteAllVersions:YES
                                             unfileObjects:CMISDelete
                                         continueOnFailure:YES
                                           completionBlock:^(NSArray *failedObjects, NSError *error) {
                    XCTAssertNil(error, @"Error while deleting newly created folder: %@", [error description]);

                    self.testCompleted = YES;
                }];
            }];
        }];
    }];
}

- (void)testMoveDocument
{
    [self runTest:^ {
        
        [self setupMoveTestFoldersAndDocumentWithCompletionBlock:^(NSString *containerFolderId, CMISFolder *folder1, CMISFolder *folder2, CMISDocument *document) {
            
            [document moveFromFolderWithId:folder1.identifier toFolderWithId:folder2.identifier completionBlock:^(CMISObject *object, NSError *error) {
                XCTAssertNil(error, @"Error while moving document: %@", [error description]);
                XCTAssertNotNil(object, @"Moved document is nil but should not");
                
                [folder2 retrieveChildrenWithCompletionBlock:^(CMISPagedResult *result, NSError *error) {
                    XCTAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                    XCTAssertNotNil(result, @"Return result should not be nil");
                    
                    NSArray *children = result.resultArray;
                    XCTAssertNotNil(children, @"children should not be nil");
                    CMISLogDebug(@"There are %d children", [children count]);
                    XCTAssertTrue([children count] == 1, @"There should be at least 3 children");
                    
                    CMISObject *child = children[0];
                    XCTAssertTrue([child isKindOfClass:[CMISDocument class]], @"The child of folder2 is not a CMISDocument but should be");
                    CMISDocument *retrievedDocument = (CMISDocument *)child;
                    XCTAssertTrue([retrievedDocument.name isEqualToString:document.name], @"Moved document's name is not equal to original");
                    
                    [self.session.binding.objectService deleteTree:containerFolderId
                                                        allVersion:YES
                                                     unfileObjects:CMISDelete
                                                 continueOnFailure:YES
                                                   completionBlock:^(NSArray *failedObjects, NSError *error) {
                                                       XCTAssertNil(error, @"Error while move test folders and document: %@", [error description]);
                                                       XCTAssertTrue(failedObjects.count == 0, @"some objects could not be deleted");
                                                       
                                                       self.testCompleted = YES;
                                                   }];
                }];
            }];
        }];
    }];
}

- (void)testMoveFolder
{
    [self runTest:^ {
        
        [self setupMoveTestFoldersAndDocumentWithCompletionBlock:^(NSString *containerFolderId, CMISFolder *folder1, CMISFolder *folder2, CMISDocument *document) {
            
            [folder1 moveFromFolderWithId:containerFolderId toFolderWithId:folder2.identifier completionBlock:^(CMISObject *object, NSError *error) {
                XCTAssertNil(error, @"Error while moving document: %@", [error description]);
                XCTAssertNotNil(object, @"Moved document is nil but should not");
                
                [folder2 retrieveChildrenWithCompletionBlock:^(CMISPagedResult *result, NSError *error) {
                    XCTAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                    XCTAssertNotNil(result, @"Return result should not be nil");
                    
                    NSArray *children = result.resultArray;
                    XCTAssertNotNil(children, @"children should not be nil");
                    CMISLogDebug(@"There are %d children", [children count]);
                    XCTAssertTrue([children count] == 1, @"There should be at least 3 children");
                    
                    CMISObject *child = children[0];
                    XCTAssertTrue([child isKindOfClass:[CMISFolder class]], @"The child of folder2 is not a CMISFolder but should be");
                    CMISFolder *retrievedFolder = (CMISFolder *)child;
                    XCTAssertTrue([retrievedFolder.name isEqualToString:folder1.name], @"Moved folder's name is not equal to original");
                    
                    [self.session.binding.objectService deleteTree:containerFolderId
                                                        allVersion:YES
                                                     unfileObjects:CMISDelete
                                                 continueOnFailure:YES
                                                   completionBlock:^(NSArray *failedObjects, NSError *error) {
                                                       XCTAssertNil(error, @"Error while move test folders and document: %@", [error description]);
                                                       
                                                       self.testCompleted = YES;
                                                   }];
                }];
            }];
        }];
    }];
}

- (void)setupMoveTestFoldersAndDocumentWithCompletionBlock:(void (^)(NSString *containerFolderId, CMISFolder *folder1, CMISFolder *folder2, CMISDocument *document))completionBlock
{
    // Setup test folder container
    NSMutableDictionary *containerFolderProperties = [NSMutableDictionary dictionary];
    NSString *containerFolderName = [NSString stringWithFormat:@"test-moveObject-%@", [self stringFromCurrentDate]];
    [containerFolderProperties setObject:containerFolderName forKey:kCMISPropertyName];
    [containerFolderProperties setObject:kCMISPropertyObjectTypeIdValueFolder forKey:kCMISPropertyObjectTypeId];
    
    NSMutableDictionary *propertiesFolder1 = [NSMutableDictionary dictionary];
    NSString *folder1Name = [NSString stringWithFormat:@"folder1"];
    [propertiesFolder1 setObject:folder1Name forKey:kCMISPropertyName];
    [propertiesFolder1 setObject:kCMISPropertyObjectTypeIdValueFolder forKey:kCMISPropertyObjectTypeId];
    
    NSMutableDictionary *propertiesFolder2 = [NSMutableDictionary dictionary];
    NSString *folder2Name = [NSString stringWithFormat:@"folder2"];
    [propertiesFolder2 setObject:folder2Name forKey:kCMISPropertyName];
    [propertiesFolder2 setObject:kCMISPropertyObjectTypeIdValueFolder forKey:kCMISPropertyObjectTypeId];
    
    // Setup test file
    // Check if test file exists
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file.txt" ofType:nil];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath],
                  @"Test file 'test_file.txt' cannot be found as resource for the test");
    
    // Upload test file
    NSString *documentName = [NSString stringWithFormat:@"test_file_%@.txt", [self stringFromCurrentDate]];
    NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
    [documentProperties setObject:documentName forKey:kCMISPropertyName];
    [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];
    
    // Create container folder
    [self.rootFolder createFolder:containerFolderProperties completionBlock:^(NSString *containerFolderId, NSError *error) {
        XCTAssertNil(error, @"Error while creating containerFolder in root folder: %@", [error description]);
        
        // Create folder 1
        [self.session createFolder:propertiesFolder1 inFolder:containerFolderId completionBlock:^(NSString *folder1Id, NSError *error) {
            XCTAssertNil(error, @"Error while creating folder1 in container folder: %@", [error description]);
            
            [self.session retrieveObject:folder1Id completionBlock:^(CMISObject *object, NSError *error) {
                CMISFolder *folder1 = (CMISFolder *)object;
                XCTAssertNil(error, @"Error while retrieving newly created folder: %@", [error description]);
                XCTAssertNotNil(folder1, @"New folder should not be nil");
                
                // Create folder 2
                [self.session createFolder:propertiesFolder2 inFolder:containerFolderId completionBlock:^(NSString *folder2Id, NSError *error) {
                    XCTAssertNil(error, @"Error while creating folder2 in container folder: %@", [error description]);
                    
                    [self.session retrieveObject:folder2Id completionBlock:^(CMISObject *object, NSError *error) {
                        CMISFolder *folder2 = (CMISFolder *)object;
                        XCTAssertNil(error, @"Error while retrieving newly created folder: %@", [error description]);
                        XCTAssertNotNil(folder2, @"New folder should not be nil");
                        
                        
                        [self.session createDocumentFromFilePath:filePath mimeType:@"text/plain"
                                                      properties:documentProperties
                                                        inFolder:folder1Id
                                                 completionBlock:^(NSString *objectId, NSError *error) {
                                                     XCTAssertNil(error, @"Error while creating document in folder1 folder: %@", [error description]);
                                                     
                                                     [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                                                         CMISDocument *document = (CMISDocument *)object;
                                                         XCTAssertNil(error, @"Error while retrieving newly created document: %@", [error description]);
                                                         XCTAssertNotNil(document, @"New document should not be nil");
                                                         
                                                         completionBlock(containerFolderId, folder1, folder2, document);
                                                     }];
                                                 } progressBlock:nil];
                    }];
                }];
                
            }];
        }];
    }];
}

- (void)testRetrieveAllVersionsOfDocument
{
    [self runTest:^ {
        // First find the document which we know that has some versions
        [self retrieveVersionedTestDocumentWithCompletionBlock:^(CMISDocument *document) {
            // Get all the versions of the document
            [document retrieveAllVersionsWithCompletionBlock:^(CMISCollection *allVersionsOfDocument, NSError *error) {
                XCTAssertNil(error, @"Error while retrieving all versions of document : %@", [error description]);
                XCTAssertTrue(allVersionsOfDocument.items.count >= 5, @"Expected at least 5 versions of document, but was %lu", (unsigned long)allVersionsOfDocument.items.count);
                
                // Print out the version labels and verify them, while also verifying that they are ordered by creation date, descending
                NSDate *previousModifiedDate = document.lastModificationDate;
                for (CMISDocument *versionOfDocument in allVersionsOfDocument.items) {
                    CMISLogDebug(@"%@ - version %@", versionOfDocument.name, versionOfDocument.versionLabel);
                    
                    if (!versionOfDocument.isLatestVersion) {// latest version is the one we got originally
                        XCTAssertTrue([document.name isEqualToString:versionOfDocument.name], @"Other version of same document does not have the same name");
                        XCTAssertFalse([document.versionLabel isEqualToString:versionOfDocument.versionLabel], @"Other version of same document should have different version label");
                        XCTAssertTrue([previousModifiedDate compare:versionOfDocument.lastModificationDate] == NSOrderedDescending,
                                     @"Versions of document should be ordered descending by creation date");
                        previousModifiedDate = versionOfDocument.lastModificationDate;
                    }
                }
                
                // Take an older version, and verify its version properties
                CMISDocument *olderVersionOfDocument = [allVersionsOfDocument.items objectAtIndex:3]; // In the test data, this should be version 1.0 of doc.
                XCTAssertFalse(olderVersionOfDocument.isLatestVersion, @"Older version of document should have 'false' for the property 'isLatestVersion");
                XCTAssertFalse(olderVersionOfDocument.isLatestMajorVersion, @"Older version of document should have 'false' for the property 'isLatestMajorVersion");

                self.testCompleted = YES;
            }];
        }];
    }];
}

-(void)testRetrieveLatestVersionOfDocument
{
    [self runTest:^ {
         // First find the document which we know that has some versions
        [self retrieveVersionedTestDocumentWithCompletionBlock:^(CMISDocument *document) {
            // Check if the document retrieved is the latest version
            [document retrieveObjectOfLatestVersionWithMajorVersion:NO completionBlock:^(CMISDocument *latestVersionOfDocument, NSError *error) {
                XCTAssertNil(error, @"Error while retrieving latest version of document");
                XCTAssertTrue([document.versionLabel isEqualToString:latestVersionOfDocument.versionLabel], @"Version label should match");
                XCTAssertTrue([document.creationDate isEqual:latestVersionOfDocument.creationDate], @"Creation dates should be equal");
                
                // Retrieve an older version, and check if we get the right one back if we call the 'retrieveLatest' on it
                [document retrieveAllVersionsWithCompletionBlock:^(CMISCollection *allVersionsOfDocument, NSError *error) {
                    XCTAssertNil(error, @"Error while retrieving all versions: %@", [error description]);
                    
                    CMISDocument *olderVersionOfDocument = [allVersionsOfDocument.items objectAtIndex:1];
                    XCTAssertFalse([document.versionLabel isEqualToString:olderVersionOfDocument.versionLabel], @"Version label should NOT match");
                    
                    // Commented out due to different behaviour when using 'cmisatom' url
                    //    STAssertTrue([document.creationDate isEqualToDate:olderVersionOfDocument.creationDate], @"Creation dates should match: %@ vs %@", document.creationDate, olderVersionOfDocument.creationDate);
                    
                    XCTAssertFalse([document.lastModificationDate isEqual:olderVersionOfDocument.lastModificationDate], @"Creation dates should NOT match");
                    
                    
                    [olderVersionOfDocument retrieveObjectOfLatestVersionWithMajorVersion:NO completionBlock:^(CMISDocument *latestVersionOfDocument, NSError *error) {
                        XCTAssertNil(error, @"Error while retrieving latest version of document");
                        XCTAssertNotNil(latestVersionOfDocument, @"Latest version should not be nil");
                        XCTAssertTrue([document.name isEqualToString:latestVersionOfDocument.name], @"Name should match: expected %@ but was %@", document.name, latestVersionOfDocument.name);
                        XCTAssertTrue([document.versionLabel isEqualToString:latestVersionOfDocument.versionLabel], @"Version label should match");
                        XCTAssertTrue([document.lastModificationDate isEqual:latestVersionOfDocument.lastModificationDate], @"Creation dates should be equal");

                        self.testCompleted = YES;
                    }];
                }];
            }];
        }];
    }];
}

- (void)testLinkRelations
{
    NSMutableSet *setup = [NSMutableSet set];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"down" type:kCMISMediaTypeChildren href:@"http://down/children"]];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"down" type:kCMISMediaTypeDescendants href:@"http://down/descendants"]];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"up" type:kCMISMediaTypeChildren href:@"http://up/children"]];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"up" type:kCMISMediaTypeEntry href:@"http://up/entry"]];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"service" type:nil href:@"http://service"]];
    CMISLinkRelations *linkRelations = [[CMISLinkRelations alloc] initWithLinkRelationSet:setup];
    
    XCTAssertNil([linkRelations linkHrefForRel:@"down"], @"Expected nil since there are more link relations with the down relations");
    XCTAssertEqual([linkRelations linkHrefForRel:@"service"], @"http://service", @"The Service link should have been returned");
    XCTAssertEqual([linkRelations linkHrefForRel:@"down" type:kCMISMediaTypeChildren], @"http://down/children", @"The down relation for the children media type should have been returned");
    XCTAssertEqual([linkRelations linkHrefForRel:@"down" type:kCMISMediaTypeDescendants], @"http://down/descendants", @"The down relation for the descendants media type should have been returned");
}

- (void)testQueryThroughDiscoveryService
{
    [self runTest:^ {
        id<CMISDiscoveryService> discoveryService = self.session.binding.discoveryService;
        XCTAssertNotNil(discoveryService, @"Discovery service should not be nil");

        // Basic check if the service returns results that are usable
        [discoveryService query:@"SELECT * FROM cmis:document"
              searchAllVersions:NO
                  relationships:CMISIncludeRelationshipNone
                renditionFilter:nil
            includeAllowableActions:YES
                       maxItems:[NSNumber numberWithInt:3]
                      skipCount:[NSNumber numberWithInt:0]
                completionBlock:^(CMISObjectList *objectList, NSError *error) {
             XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
             XCTAssertNotNil(objectList, @"Object list after query should not be nil");
             
             // numitems not supported by cmisatom url
             //    STAssertTrue(objectList.numItems > 100, @"Expecting at least 100 items when querying for all documents, but got %d", objectList.numItems);
             
             XCTAssertTrue(objectList.objects.count == 3, @"Expected 3 items to be returned, but was %lu", (unsigned long)objectList.objects.count);
             
             for (CMISObjectData *objectData in objectList.objects) {
                 XCTAssertTrue(objectData.properties.propertiesDictionary.count > 10, @"Expecting properties to be passed when querying");
             }
             
             // Doing a query without any maxItems or skipCount, and also only requesting one property 'column'
             [discoveryService query:@"SELECT cmis:name FROM cmis:document WHERE cmis:name LIKE '%quote%'"
                   searchAllVersions:NO
                       relationships:CMISIncludeRelationshipNone
                     renditionFilter:nil
             includeAllowableActions:YES
                            maxItems:nil skipCount:nil completionBlock:^(CMISObjectList *objectList, NSError *error) {
                  XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
                  XCTAssertNotNil(objectList, @"Object list after query should not be nil");
                  XCTAssertTrue(objectList.objects.count > 0, @"Returned # objects is repo specific, but should be at least 1");
                  
                  CMISObjectData *firstResult = [objectList.objects objectAtIndex:0];
                  XCTAssertTrue(firstResult.properties.propertiesDictionary.count == 1, @"Only querying for 1 property, but got %lu properties back", (unsigned long)firstResult.properties.propertiesDictionary.count);
                  
                  self.testCompleted = YES;
              }];
         }];
    }];
}

- (void)testQueryThroughSession
{
    [self runTest:^ {
         // Query all properties
         [self.session query:@"SELECT * FROM cmis:document WHERE cmis:name LIKE '%quote%'" searchAllVersions:NO completionBlock:^(CMISPagedResult *result, NSError *error) {
             XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
             XCTAssertTrue(result.resultArray.count > 0, @"Expected at least one result for query");
             
             CMISQueryResult *firstResult = [result.resultArray objectAtIndex:0];
             XCTAssertNotNil([firstResult.properties propertyForId:kCMISPropertyName], @"Name property should not be nil");
             XCTAssertNotNil([firstResult.properties propertyForId:kCMISPropertyVersionLabel], @"Version label property should not be nil");
             XCTAssertNotNil([firstResult.properties propertyForId:kCMISPropertyCreationDate], @"Creation date property should not be nil");
             XCTAssertNotNil([firstResult.properties propertyForId:kCMISPropertyContentStreamLength], @"Content stream length property should not be nil");
             
             XCTAssertNotNil([firstResult.properties propertyForQueryName:kCMISPropertyName], @"Name property should not be nil");
             XCTAssertNotNil([firstResult.properties propertyForQueryName:kCMISPropertyVersionLabel], @"Version label property should not be nil");
             XCTAssertNotNil([firstResult.properties propertyForQueryName:kCMISPropertyCreationDate], @"Creation date property should not be nil");
             XCTAssertNotNil([firstResult.properties propertyForQueryName:kCMISPropertyContentStreamLength], @"Content stream length property should not be nil");
             
             // Query a limited set of properties
             [self.session query:@"SELECT cmis:name, cmis:creationDate FROM cmis:document WHERE cmis:name LIKE '%activiti%'" searchAllVersions:NO completionBlock:^(CMISPagedResult *result, NSError *error) {
                 XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
                 XCTAssertTrue(result.resultArray.count > 0, @"Expected at least one result for query");
                 
                 CMISQueryResult *firstResult = [result.resultArray objectAtIndex:0];
                 XCTAssertNotNil([firstResult.properties propertyForId:kCMISPropertyName], @"Name property should not be nil");
                 XCTAssertNotNil([firstResult.properties propertyForId:kCMISPropertyCreationDate], @"Creation date property should not be nil");
                 XCTAssertNil([firstResult.properties propertyForId:kCMISPropertyVersionLabel], @"Version label property should be nil");
                 XCTAssertNil([firstResult.properties propertyForId:kCMISPropertyContentStreamLength], @"Content stream length property should be nil");
                 XCTAssertNotNil(firstResult.allowableActions, @"By default, allowable actions whould be included");
                 XCTAssertTrue(firstResult.allowableActions.allowableActionsSet.count > 0, @"Expected at least one allowable action");
                 // With operationContext
                 CMISOperationContext *context = [CMISOperationContext defaultOperationContext];
                 context.includeAllowableActions = NO;
                 [self.session query:@"SELECT * FROM cmis:document WHERE cmis:name LIKE '%quote%'"
                   searchAllVersions:NO operationContext:context completionBlock:^(CMISPagedResult *result, NSError *error) {
                       XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
                       XCTAssertTrue(result.resultArray.count > 0, @"Expected at least one result for query");
                       CMISQueryResult *firstResult = [result.resultArray objectAtIndex:0];
                       XCTAssertTrue(firstResult.allowableActions.allowableActionsSet.count == 0,
                                    @"Expected allowable actions, as the operation ctx excluded them, but found %lu allowable actions", (unsigned long)firstResult.allowableActions.allowableActionsSet.count);

                       self.testCompleted = YES;
                   }];
             }];
         }];
     }];
}

- (void)testQueryWithPaging
{
    [self runTest:^ {
         // Fetch first page
         CMISOperationContext *context = [[CMISOperationContext alloc] init];
         context.maxItemsPerPage = 5;
         context.skipCount = 0;
         [self.session query:@"SELECT * FROM cmis:document" searchAllVersions:NO operationContext:context completionBlock:^(CMISPagedResult *firstPageResult, NSError *error) {
             XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
             XCTAssertTrue(firstPageResult.resultArray.count == 5, @"Expected 5 results, but got %lu back", (unsigned long)firstPageResult.resultArray.count);
             
             // Save all the ids to check them later
             NSMutableArray *idsOfFirstPage = [NSMutableArray array];
             for (CMISQueryResult *queryresult in firstPageResult.resultArray) {
                 [idsOfFirstPage addObject:[queryresult propertyForId:kCMISPropertyObjectId]];
             }
             
             // Fetch second page
             [firstPageResult fetchNextPageWithCompletionBlock:^(CMISPagedResult *secondPageResults, NSError *error) {
                 XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
                 XCTAssertTrue(secondPageResults.resultArray.count == 5, @"Expected 5 results, but got %lu back", (unsigned long)secondPageResults.resultArray.count);
                 
                 for (CMISQueryResult *queryResult in secondPageResults.resultArray) {
                     XCTAssertFalse([idsOfFirstPage containsObject:[queryResult propertyForId:kCMISPropertyObjectId]], @"Found same object in first and second page");
                 }
                 
                 // Fetch last element by specifying a page which is just lastelement-1
                 
                 // Commented due to 'cmisatom' not supporting numItems
                 //    context.skipCount = secondPageResults.numItems - 1;
                 //    CMISPagedResult *thirdPageResults = [self.session query:@"SELECT * FROM cmis:document"
                 //                                            searchAllVersions:NO operationContext:context error:&error];
                 //    STAssertNil(error, @"Got an error while executing query: %@", [error description]);
                 //    STAssertTrue(thirdPageResults.resultArray.count == 1, @"Expected 1 result, but got %d back", thirdPageResults.resultArray.count);
                 
                 self.testCompleted = YES;
             }];
         }];
     }];
}

- (void)testQueryObjects
{
    [self runTest:^ {
         // Fetch first page
         CMISOperationContext *context = [[CMISOperationContext alloc] init];
         context.maxItemsPerPage = 2;
         context.skipCount = 0;
         [self.session queryObjectsWithTypeid:@"cmis:document"
                                  whereClause:nil
                            searchAllVersions:NO
                             operationContext:context
                              completionBlock:^(CMISPagedResult *firstPageResult, NSError *error) {
              XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
              XCTAssertTrue(firstPageResult.resultArray.count == 2, @"Expected 2 results, but got %lu back", (unsigned long)firstPageResult.resultArray.count);
              
              // Save all the ids to check them later
              NSMutableArray *idsOfFirstPage = [NSMutableArray array];
              for (CMISDocument *document in firstPageResult.resultArray) {
                  [idsOfFirstPage addObject:document.identifier];
              }
              
              // Fetch second page
              [firstPageResult fetchNextPageWithCompletionBlock:^(CMISPagedResult *secondPageResults, NSError *error) {
                  XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
                  XCTAssertTrue(secondPageResults.resultArray.count == 2, @"Expected 2 results, but got %lu back", (unsigned long)secondPageResults.resultArray.count);
                  
                  for (CMISDocument *document in secondPageResults.resultArray)
                  {
                      XCTAssertFalse([idsOfFirstPage containsObject:document.identifier], @"Found same object in first and second page");
                  }
                  
                  self.testCompleted = YES;
              }];
          }];
     }];
}

- (void)testCancelQuery
{
    [self runTest:^ {
        // Query all properties
        self.request = [self.session query:@"SELECT * FROM cmis:document WHERE cmis:name LIKE '%quote%'" searchAllVersions:NO completionBlock:^(CMISPagedResult *result, NSError *error) {
            XCTAssertNotNil(error, @"Failed to cancel query");
            XCTAssertTrue(error.code == kCMISErrorCodeCancelled, @"Expected error code to be 6 (kCMISErrorCodeCancelled) but it was %ld", (long)error.code);
            XCTAssertNil(result, @"Did not expect to recieve a result object");
            self.testCompleted = YES;
        }];
        
        // immediately cancel the query
        [self.request cancel];
    }];
}

- (void)testRetrieveParents
{
    [self runTest:^ {
         // First, do a query for our test document
         NSString *queryStmt = @"SELECT * FROM cmis:document WHERE cmis:name = 'thumbsup-ios-test-retrieve-parents.gif'";
         [self.session query:queryStmt searchAllVersions:NO completionBlock:^(CMISPagedResult *results, NSError *error) {
             XCTAssertNil(error, @"Got an error while executing query: %@", [error description]);
             XCTAssertTrue(results.resultArray.count == 1, @"Expected one result for query");
             CMISQueryResult *result = [results.resultArray objectAtIndex:0];
             
             // Retrieve the document as CMISDocument
             NSString *objectId = [[result propertyForId:kCMISPropertyObjectId] firstValue];
             [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *)object;
                 XCTAssertNil(error, @"Got an error while retrieving test document: %@", [error description]);
                 XCTAssertNotNil(document, @"Test document should not be nil");
                 
                 // Verify the parents of this document
                 CMISFileableObject *currentObject = document;
                 
                 [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                     XCTAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                     XCTAssertTrue(parentFolders.count == 1, @"Expecting only 1 parent, but found %lu parents", (unsigned long)parentFolders.count);
                     CMISFileableObject *currentObject = [parentFolders objectAtIndex:0];
                     XCTAssertEqualObjects(@"ios-subsubfolder", currentObject.name, @"Wrong parent folder");
                     [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                         XCTAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                         XCTAssertTrue(parentFolders.count == 1, @"Expecting only 1 parent, but found %lu parents", (unsigned long)parentFolders.count);
                         CMISFileableObject *currentObject = [parentFolders objectAtIndex:0];
                         XCTAssertEqualObjects(@"ios-subfolder", currentObject.name, @"Wrong parent folder");
                         [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                             XCTAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                             XCTAssertTrue(parentFolders.count == 1, @"Expecting only 1 parent, but found %lu parents", (unsigned long)parentFolders.count);
                             CMISFileableObject *currentObject = [parentFolders objectAtIndex:0];
                             XCTAssertEqualObjects(@"ios-test", currentObject.name, @"Wrong parent folder");
                             [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                                 XCTAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                                 XCTAssertTrue(parentFolders.count == 1, @"Expecting only 1 parent, but found %lu parents", (unsigned long)parentFolders.count);
                                 CMISFileableObject *currentObject = [parentFolders objectAtIndex:0];
                                 XCTAssertEqualObjects(@"Company Home", currentObject.name, @"Wrong parent folder");
                                 // Check if the root folder parent is empty
                                 [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                                     XCTAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                                     XCTAssertTrue(parentFolders.count == 0, @"Root folder should not have any parents");

                                     self.testCompleted = YES;
                                 }];
                             }];
                         }];
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testRetrieveNonExistingObject
{
    [self runTest:^ {
         // test with non existing object id
         [self.session retrieveObject:@"bogus" completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             XCTAssertNotNil(error, @"Expecting error when retrieving object with wrong id");
             XCTAssertNil(document, @"Document should be nil");
             
             // Test with a non existing path
             NSString *path = @"/bogus/i_do_not_exist.pdf";
             [self.session retrieveObjectByPath:path completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *)object;
                 XCTAssertNotNil(error, @"Expecting error when retrieving object with wrong path");
                 XCTAssertNil(document, @"Document should be nil");

                 self.testCompleted = YES;
             }];
         }];
     }];
}

- (void)testRetrieveObjectByPath
{
    [self runTest:^ {
         // Use a document that has spaces in them (should be correctly encoded)
         NSString *path = [NSString stringWithFormat:@"%@/activiti logo big.png", self.rootFolder.path];
         [self.session retrieveObjectByPath:path completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             XCTAssertNil(error, @"Error while retrieving object with path %@", path);
             XCTAssertNotNil(document, @"Document should not be nil");
             XCTAssertEqualObjects(@"activiti logo big.png", document.name, @"When retrieving document by path, name does not match");
             
             // Test with a few folders
             NSString *path = @"/ios-test/ios-subfolder/ios-subsubfolder/activiti-logo.png";
             [self.session retrieveObjectByPath:path completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *) object;
                 XCTAssertNil(error, @"Error while retrieving object with path %@", path);
                 XCTAssertNotNil(document, @"Document should not be nil");

                 self.testCompleted = YES;
             }];
         }];
     }];
}

// In this test, we'll upload a test file
// Change the content of that test file
// And verify of the content is correct
- (void)testChangeContentOfDocument
{
    [self runTest:^ {
         // Upload test file
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *originalDocument) {
             XCTAssertTrue([originalDocument.contentStreamMediaType isEqualToString:@"text/plain"], @"Mime type for original document should be text/plain but it is: %@", originalDocument.contentStreamMediaType);
             // Change content of test file using overwrite
             __block long long previousUploadedBytes = -1;
             NSString *newContentFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file_2.txt" ofType:nil];
             [self.session.binding.objectService
              changeContentOfObject:[CMISStringInOutParameter inOutParameterUsingInParameter:originalDocument.identifier]
                    toContentOfFile:newContentFilePath
                           mimeType:originalDocument.contentStreamMediaType
                  overwriteExisting:YES
                        changeToken:nil
                    completionBlock: ^(NSError *error) {
                  if (error == nil) {
                      CMISLogDebug(@"Content has been successfully changed");
                      
                      // Verify content of document
                      NSString *tempDownloadFilePath = [NSString stringWithFormat:@"%@/temp_download_file.txt", NSTemporaryDirectory()];
//                      NSString *tempDownloadFilePath = @"temp_download_file.txt";
                      // some repos will up the version when uploading new content
                      [originalDocument retrieveObjectOfLatestVersionWithMajorVersion:NO completionBlock:^(CMISDocument *latestVersionOfDocument , NSError *error) {
                          XCTAssertTrue([latestVersionOfDocument.contentStreamMediaType isEqualToString:@"text/plain"], @"Mime type for updated document should be text/plain but it is: %@", latestVersionOfDocument.contentStreamMediaType);
                          [latestVersionOfDocument downloadContentToFile:tempDownloadFilePath completionBlock:^(NSError *error) {
                              if (error == nil) {
                                  NSString *contentOfDownloadedFile = [NSString stringWithContentsOfFile:tempDownloadFilePath encoding:NSUTF8StringEncoding error:nil];
                                  XCTAssertEqualObjects(@"In theory, there is no difference between theory and practice. But in practice, there is.",
                                                       contentOfDownloadedFile, @"Downloaded file content does not match: '%@'", contentOfDownloadedFile);
                                  
                                  // Delete downloaded file
                                  NSError *fileError;
                                  [[NSFileManager defaultManager] removeItemAtPath:tempDownloadFilePath error:&fileError];
                                  XCTAssertNil(fileError, @"Error when deleting temporary downloaded file: %@", [fileError description]);
                                  
//                                  self.testCompleted = YES;
                                  // Delete test document from server
                                  
                                  [self deleteDocumentAndVerify:originalDocument completionBlock:^{
                                      self.testCompleted = YES;
                                  }];
                                
                              } else {
                                  XCTAssertNil(error, @"Error while writing content: %@", [error description]);
                                  
                                  self.testCompleted = YES;
                              }
                          } progressBlock:nil];
                      }];
                  } else {
                      XCTAssertNil(error, @"Got error while changing content of document: %@", [error description]);
                  
                      self.testCompleted = YES;
                  }
              } progressBlock: ^ (unsigned long long bytesUploaded, unsigned long long bytesTotal) {
                  XCTAssertTrue((long long)bytesUploaded > previousUploadedBytes, @"No progress");
                  previousUploadedBytes = bytesUploaded;
              }];
         }];
     }];
}

- (void)testDeleteContentOfDocument
{
    [self runTest:^ {
         // Upload test file
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *originalDocument) {
             // Delete its content
             [originalDocument deleteContentWithCompletionBlock:^(NSError *error) {
                 XCTAssertNil(error, @"Got error while deleting content of document: %@", [error description]);
                 
                 // Get latest version and verify content length
                 [originalDocument retrieveObjectOfLatestVersionWithMajorVersion:NO completionBlock:^(CMISDocument *latestVersion, NSError *error) {
                     XCTAssertNil(error, @"Got error while getting latest version of documet: %@", [error description]);
                     XCTAssertTrue(latestVersion.contentStreamLength == 0, @"Expected zero content length for document with no content, but was %lu", (unsigned long)latestVersion.contentStreamLength);
                     
                     // Delete test document from server
                     [self deleteDocumentAndVerify:originalDocument completionBlock:^{
                         self.testCompleted = YES;
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testRetrieveTypeDefinition
{
    [self runTest:^ {
         [self.session.binding.repositoryService retrieveTypeDefinition:@"cmis:document" completionBlock:^(CMISTypeDefinition *typeDefinition, NSError *error) {
             XCTAssertNil(error, @"Got error while retrieving type definition: %@", [error description]);
             
             // Check type definition properties
             XCTAssertNotNil(typeDefinition, @"Type definition should not be nil");
             XCTAssertTrue(typeDefinition.baseTypeId == CMISBaseTypeDocument, @"Unexpected base type id");
             XCTAssertNotNil(typeDefinition.description, @"Type description should not be nil");
             XCTAssertNotNil(typeDefinition.displayName, @"Type displayName should not be nil");
             XCTAssertNotNil(typeDefinition.identifier, @"Type id should not be nil");
             XCTAssertTrue([typeDefinition.identifier isEqualToString:@"cmis:document"], @"Wrong id for type");
             XCTAssertNotNil(typeDefinition.localName, @"Type local name should not be nil");
             XCTAssertNotNil(typeDefinition.localNameSpace, @"Type local namespace should not be nil");
             XCTAssertNotNil(typeDefinition.queryName, @"Type query name should not be nil");
             
             // Check property definitions
             XCTAssertTrue(typeDefinition.propertyDefinitions.count > 0, @"Expected at least one propery definition, but got %lu", (unsigned long)typeDefinition.propertyDefinitions.count);
             for (id key in typeDefinition.propertyDefinitions)
             {
                 CMISPropertyDefinition *propertyDefinition = [typeDefinition.propertyDefinitions objectForKey:key];
                 XCTAssertNotNil(propertyDefinition.description, @"Property definition description should not be nil");
                 XCTAssertNotNil(propertyDefinition.displayName, @"Property definition display name should not be nil");
                 XCTAssertNotNil(propertyDefinition.identifier, @"Property definition id should not be nil");
                 XCTAssertNotNil(propertyDefinition.localName, @"Property definition local name should not be nil");
                 XCTAssertNotNil(propertyDefinition.localNamespace, @"Property definition local namespace should not be nil");
                 XCTAssertNotNil(propertyDefinition.queryName, @"Property definition query name should not be nil");
             }
             
             self.testCompleted = YES;
         }];
     }];
}

- (void)testUpdateDocumentPropertiesThroughObjectService
{
    [self runTest:^ {
         id<CMISObjectService> objectService = self.session.binding.objectService;
         
         // Create test document
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *document) {
             // Prepare params
             CMISStringInOutParameter *objectIdInOutParam = [CMISStringInOutParameter inOutParameterUsingInParameter:document.identifier];
             CMISProperties *properties = [[CMISProperties alloc] init];
             [properties addProperty:[CMISPropertyData createPropertyForId:kCMISPropertyName stringValue:@"name_has_changed"]];
             
             // Update properties and verify
             [objectService updatePropertiesForObject:objectIdInOutParam properties:properties changeToken:nil completionBlock:^(NSError *error) {
                 XCTAssertNil(error, @"Got error while updating properties: %@", [error description]);
                 XCTAssertNotNil(objectIdInOutParam.outParameter, @"When updating properties, the object id should be returned");
                 
                 NSString *newObjectId = objectIdInOutParam.outParameter;
                 [self.session retrieveObject:newObjectId completionBlock:^(CMISObject *object, NSError *error) {
                     CMISDocument *document = (CMISDocument *)object;
                     XCTAssertNil(error, @"Got error while retrieving test document: %@", [error description]);
                     XCTAssertEqualObjects(document.name, @"name_has_changed", @"Name was not updated");
                     
                     // Cleanup
                     [self deleteDocumentAndVerify:document completionBlock:^{
                         self.testCompleted = YES;
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testUpdateFolderPropertiesThroughObjectService
{
    [self runTest:^ {
         // Create a temporary test folder
         NSMutableDictionary *properties = [NSMutableDictionary dictionary];
         NSString *folderName = [NSString stringWithFormat:@"temp_test_folder_%@", [self stringFromCurrentDate]];
         [properties setObject:folderName forKey:kCMISPropertyName];
         [properties setObject:kCMISPropertyObjectTypeIdValueFolder forKey:kCMISPropertyObjectTypeId];
         
         [self.rootFolder createFolder:properties completionBlock:^(NSString *folderId, NSError *error) {
             XCTAssertNil(error, @"Got error while creating folder: %@", [error description]);
             
             // Update name of test folder through object service
             id<CMISObjectService> objectService = self.session.binding.objectService;
             CMISStringInOutParameter *objectIdParam = [CMISStringInOutParameter inOutParameterUsingInParameter:folderId];
             CMISProperties *updateProperties = [[CMISProperties alloc] init];
             NSString *renamedFolderName = [NSString stringWithFormat:@"temp_test_folder_renamed_%@", [self stringFromCurrentDate]];
             [updateProperties addProperty:[CMISPropertyData createPropertyForId:kCMISPropertyName stringValue:renamedFolderName]];
             [objectService updatePropertiesForObject:objectIdParam properties:updateProperties changeToken:nil completionBlock:^(NSError *error) {
                 XCTAssertNil(error, @"Got error while updating folder properties: %@", [error description]);
                 XCTAssertNotNil(objectIdParam.outParameter, @"Returned object id should not be nil");
                 
                 // Retrieve folder again and check if name has actually changed
                 [self.session retrieveObject:folderId completionBlock:^(CMISObject *object, NSError *error) {
                     CMISFolder *renamedFolder = (CMISFolder *)object;
                     XCTAssertNil(error, @"Got error while retrieving renamed folder: %@", [error description]);
                     XCTAssertEqualObjects(renamedFolder.name, renamedFolderName, @"Folder was not renamed, name is %@", renamedFolder.name);
                     
                     // Delete test folder
                     [renamedFolder deleteTreeWithDeleteAllVersions:YES unfileObjects:CMISDelete continueOnFailure:YES completionBlock:^(NSArray *failedObjects, NSError *error) {
                         XCTAssertNil(error, @"Error while deleting newly created folder: %@", [error description]);

                         self.testCompleted = YES;
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testUpdatePropertiesThroughCmisObject
{
    [self runTest:^ {
         // Create test document
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *document) {
             // Prepare properties
             NSMutableDictionary *properties = [NSMutableDictionary dictionary];
             NSString *newName = @"testUpdatePropertiesThroughCmisObject";
             [properties setObject:newName forKey:kCMISPropertyName];
             [document updateProperties:properties completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *)object;
                 XCTAssertNil(error, @"Got error while retrieving renamed folder: %@", [error description]);
                 XCTAssertEqualObjects(newName, document.name, @"Name was not updated");
                 XCTAssertEqualObjects(newName, [document.properties propertyValueForId:kCMISPropertyName], @"Name property was not updated");
                 
                 // Cleanup
                 [self deleteDocumentAndVerify:document completionBlock:^{
                     self.testCompleted = YES;
                 }];
             }];
         }];
     }];
}


// Helper method used by the extension element parse tests
- (void)checkExtensionElement:(CMISExtensionElement *)extElement withName:(NSString *)expectedName namespaceUri:(NSString *)expectedNamespaceUri
               attributeCount:(NSUInteger)expectedAttrCount childrenCount:(NSUInteger)expectedChildCount hasValue:(BOOL)hasValue
{
    CMISLogDebug(@"Checking Extension Element: %@", extElement);
    XCTAssertTrue([extElement.name isEqualToString:expectedName], @"Expected extension element name '%@', but name is '%@'", expectedName, extElement.name);
    XCTAssertTrue([extElement.namespaceUri isEqualToString:expectedNamespaceUri], @"Expected namespaceUri=%@, but actual namespaceUri=%@", expectedNamespaceUri, extElement.namespaceUri);
    XCTAssertTrue(extElement.attributes.count == expectedAttrCount, @"Expected %lu attributes, but found %lu", (unsigned long)expectedAttrCount, (unsigned long)extElement.attributes.count);
    XCTAssertTrue(extElement.children.count == expectedChildCount, @"Expected %lu children elements but found %lu", (unsigned long)expectedChildCount, (unsigned long)extElement.children.count);
    
    if (extElement.children.count > 0) {
        XCTAssertNil(extElement.value, @"Extension Element value must by nil but value contained '%@'", extElement.value);
    } else if (hasValue) {
        XCTAssertTrue(extElement.value.length > 0, @"Expected extension element value to be non-empty");
    }
}

// Test Extension Elements using generated FolderChildren XML
- (void)testParsedExtensionElementsFromFolderChildrenXml
{
    // Testing FolderChildren, executed at end
    
    void (^testFolderChildrenXml)(NSString *, BOOL) = ^(NSString * filename, BOOL isOpenCmisImpl) {
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:filename ofType:@"xml"];
        NSData *atomData = [[NSData alloc] initWithContentsOfFile:filePath];
        XCTAssertNotNil(atomData, @"FolderChildren.xml is missing from the test target!");
        
        NSError *error = nil;
        CMISAtomFeedParser *feedParser = [[CMISAtomFeedParser alloc] initWithData:atomData];
        XCTAssertTrue([feedParser parseAndReturnError:&error], @"Failed to parse FolderChildren.xml");
        
        NSArray *entries = feedParser.entries;
        XCTAssertTrue(entries.count == 2, @"Expected 2 parsed entry objects, but found %lu", (unsigned long)entries.count);
        
        for (CMISObjectData *objectData  in entries) {
            // Check that there are no extension elements on the Object and allowable actions objects
            XCTAssertTrue(objectData.extensions.count == 0, @"Expected 0 extension elements, but found %lu", (unsigned long)objectData.extensions.count);
            XCTAssertTrue(objectData.allowableActions.extensions.count == 0, @"Expected 0 extension elements, but found %lu", (unsigned long)objectData.allowableActions.extensions.count);
            
            // Check that we have the expected Alfresco Aspect Extension elements on the Properties object
            NSArray *extensions = objectData.properties.extensions;
            XCTAssertTrue(extensions.count == 1, @"Expected only one extension element but encountered %lu", (unsigned long)extensions.count);
            
            // Traverse the extension element tree
            int expectedAspectsExtChildrenCt = (isOpenCmisImpl ? 4 : 5);
            CMISExtensionElement *extElement = [extensions lastObject];
            [self checkExtensionElement:extElement withName:@"aspects" namespaceUri:@"http://www.alfresco.org" attributeCount:0
                          childrenCount:expectedAspectsExtChildrenCt hasValue:NO];
            
            int aspectChildCt = 0;
            for (CMISExtensionElement *aspectChild in extElement.children) {
                switch (aspectChildCt ++) {
                    case 0:
                    case 1:
                    case 2:
                    case 3: {
                        // appliedAspects
                        [self checkExtensionElement:aspectChild withName:@"appliedAspects" namespaceUri:@"http://www.alfresco.org" attributeCount:0 childrenCount:0 hasValue:YES];
                        break;
                    }
                    case 4: {
                        XCTAssertFalse(isOpenCmisImpl, @"Unexpected extension element encountered!");
                        // alf:properties
                        [self checkExtensionElement:aspectChild withName:@"properties" namespaceUri:@"http://www.alfresco.org" attributeCount:0 childrenCount:3 hasValue:NO];
                        
                        for (CMISExtensionElement *aspectPropExt in aspectChild.children) {
                            if (aspectPropExt.children) {
                                [self checkExtensionElement:aspectPropExt withName:@"propertyString" namespaceUri:kCMISNamespaceCmis attributeCount:3 childrenCount:1 hasValue:NO];
                                
                                CMISExtensionElement *valueExt = aspectPropExt.children.lastObject;
                                [self checkExtensionElement:valueExt withName:@"value" namespaceUri:kCMISNamespaceCmis attributeCount:0 childrenCount:0 hasValue:YES];
                            } else {
                                [self checkExtensionElement:aspectPropExt withName:@"propertyString" namespaceUri:kCMISNamespaceCmis attributeCount:3 childrenCount:0 hasValue:NO];
                            }
                            
                            
                            // Test the attributes on each of the cmis property objects
                            NSArray *expectedAttributeNames = [NSArray arrayWithObjects:kCMISCoreQueryName, kCMISCoreDisplayName, kCMISAtomEntryPropertyDefId, nil];
                            NSMutableArray *attrNames = [[aspectPropExt.attributes allKeys] mutableCopy];
                            [attrNames removeObjectsInArray:expectedAttributeNames];
                            XCTAssertTrue(0 == attrNames.count, @"Unexpected Attribute(s) found %@", attrNames);
                            
                            break;
                        }
                    }
                }
            }
        }
    };
    
    // Test the FolderChildren XML generated from Alfresco's Web Script Impl
    testFolderChildrenXml(@"FolderChildren-webscripts", NO);
    
    // Test the FolderChildren XML generated from OpenCmis Impl
    testFolderChildrenXml(@"FolderChildren-opencmis", YES);
}

// This test test the extension levels Allowable Actions, Object, and Properties, with simplicity
// the same extension elements are used at each of the different levels
- (void)testParsedExtensionElementsFromAtomFeedXml
{
    static NSString *exampleUri = @"http://www.example.com";
    
    // Local Blocks
    void (^testSimpleRootExtensionElement)(CMISExtensionElement *) = ^(CMISExtensionElement *rootExtElement) {
        [self checkExtensionElement:rootExtElement withName:@"testExtSimpleRoot" namespaceUri:exampleUri attributeCount:0 childrenCount:1 hasValue:NO];
        
        CMISExtensionElement *simpleChildExtElement = rootExtElement.children.lastObject;
        [self checkExtensionElement:simpleChildExtElement withName:@"simpleChild" namespaceUri:@"http://www.example.com" attributeCount:0 childrenCount:0 hasValue:YES];
        XCTAssertTrue([simpleChildExtElement.value isEqualToString:@"simpleChildValue"], @"Expected value 'simpleChildValue' but was '%@'", simpleChildExtElement.value);
    };
    
    void (^testComplexRootExtensionElement)(CMISExtensionElement *) = ^(CMISExtensionElement *rootExtElement) {
        [self checkExtensionElement:rootExtElement withName:@"testExtRoot" namespaceUri:exampleUri attributeCount:0 childrenCount:5 hasValue:NO];
        // Children Depth=1
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:0] withName:@"testExtChildLevel1A" namespaceUri:exampleUri attributeCount:0 childrenCount:0 hasValue:YES];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:1] withName:@"testExtChildLevel1A" namespaceUri:exampleUri attributeCount:0 childrenCount:0 hasValue:YES];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:2] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:1 hasValue:NO];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:3] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:NO];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:4] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:YES];
        
        CMISExtensionElement *level1ExtElement = [rootExtElement.children objectAtIndex:2];
        
        CMISExtensionElement *level2ExtElement = level1ExtElement.children.lastObject;
        [self checkExtensionElement:level2ExtElement withName:@"testExtChildLevel2" namespaceUri:exampleUri attributeCount:1 childrenCount:1 hasValue:NO];
        
        CMISExtensionElement *level3ExtElement = level2ExtElement.children.lastObject;
        [self checkExtensionElement:level3ExtElement withName:@"testExtChildLevel3" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:YES];
    };
    
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AtomFeedWithExtensions" ofType:@"xml"];
    NSData *atomData = [[NSData alloc] initWithContentsOfFile:filePath];
    XCTAssertNotNil(atomData, @"AtomFeedWithExtensions.xml is missing from the test target!");
    
    NSError *error = nil;
    CMISAtomFeedParser *feedParser = [[CMISAtomFeedParser alloc] initWithData:atomData];
    XCTAssertTrue([feedParser parseAndReturnError:&error], @"Failed to parse AtomFeedWithExtensions.xml");
    
    NSArray *entries = feedParser.entries;
    XCTAssertTrue(entries.count == 2, @"Expected 2 parsed entry objects, but found %lu", (unsigned long)entries.count);
    
    for (CMISObjectData *objectData  in entries) {
        XCTAssertTrue(objectData.extensions.count == 2, @"Expected 2 extension elements, but found %lu", (unsigned long)objectData.extensions.count);
        testSimpleRootExtensionElement([objectData.extensions objectAtIndex:0]);
        testComplexRootExtensionElement([objectData.extensions objectAtIndex:1]);
        
        XCTAssertTrue(objectData.allowableActions.extensions.count == 2, @"Expected 2 extension elements, but found %lu", (unsigned long)objectData.allowableActions.extensions.count);
        testSimpleRootExtensionElement([objectData.allowableActions.extensions objectAtIndex:0]);
        testComplexRootExtensionElement([objectData.allowableActions.extensions objectAtIndex:1]);
        
        NSArray *extensions = objectData.properties.extensions;
        XCTAssertTrue(extensions.count == 2, @"Expected only one extension element but encountered %lu", (unsigned long)extensions.count);
        testSimpleRootExtensionElement([objectData.properties.extensions objectAtIndex:0]);
        testComplexRootExtensionElement([objectData.properties.extensions objectAtIndex:1]);
    }
}


- (void)testParsedExtensionElementsFromAtomPubService
{
    static NSString *exampleUri = @"http://www.example.com";
    
    // Local Blocks
    void (^testSimpleRootExtensionElement)(CMISExtensionElement *) = ^(CMISExtensionElement *rootExtElement) {
        [self checkExtensionElement:rootExtElement withName:@"testExtSimpleRoot" namespaceUri:exampleUri attributeCount:0 childrenCount:1 hasValue:NO];
        
        CMISExtensionElement *simpleChildExtElement = rootExtElement.children.lastObject;
        [self checkExtensionElement:simpleChildExtElement withName:@"simpleChild" namespaceUri:@"http://www.example.com" attributeCount:0 childrenCount:0 hasValue:YES];
        XCTAssertTrue([simpleChildExtElement.value isEqualToString:@"simpleChildValue"], @"Expected value 'simpleChildValue' but was '%@'", simpleChildExtElement.value);
    };
    
    void (^testComplexRootExtensionElement)(CMISExtensionElement *) = ^(CMISExtensionElement *rootExtElement) {
        [self checkExtensionElement:rootExtElement withName:@"testExtRoot" namespaceUri:exampleUri attributeCount:0 childrenCount:5 hasValue:NO];
        // Children Depth=1
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:0] withName:@"testExtChildLevel1A" namespaceUri:exampleUri attributeCount:0 childrenCount:0 hasValue:YES];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:1] withName:@"testExtChildLevel1A" namespaceUri:exampleUri attributeCount:0 childrenCount:0 hasValue:YES];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:2] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:1 hasValue:NO];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:3] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:NO];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:4] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:YES];
        
        CMISExtensionElement *level1ExtElement = [rootExtElement.children objectAtIndex:2];
        
        CMISExtensionElement *level2ExtElement = level1ExtElement.children.lastObject;
        [self checkExtensionElement:level2ExtElement withName:@"testExtChildLevel2" namespaceUri:exampleUri attributeCount:1 childrenCount:1 hasValue:NO];
        
        CMISExtensionElement *level3ExtElement = level2ExtElement.children.lastObject;
        [self checkExtensionElement:level3ExtElement withName:@"testExtChildLevel3" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:YES];
    };
    
    // Testing AllowableActions Extensions using the - initWithData: entry point
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AtomPubServiceDocument" ofType:@"xml"];
    NSData *atomData = [[NSData alloc] initWithContentsOfFile:filePath];
    XCTAssertNotNil(atomData, @"AtomPubServiceDocument.xml is missing from the test target!");
    
    NSError *error = nil;
    CMISAtomPubServiceDocumentParser *serviceDocParser = [[CMISAtomPubServiceDocumentParser alloc] initWithData:atomData];
    XCTAssertTrue([serviceDocParser parseAndReturnError:&error], @"Failed to parse AtomPubServiceDocument.xml");
    
    NSArray *workspaces = [serviceDocParser workspaces];
    CMISAtomWorkspace *workspace = [workspaces objectAtIndex:0];
    CMISRepositoryInfo *repoInfo = workspace.repositoryInfo;
    
    XCTAssertTrue(repoInfo.extensions.count == 2, @"Expected 2 extension elements, but found %lu", (unsigned long)repoInfo.extensions.count);
    testSimpleRootExtensionElement([repoInfo.extensions objectAtIndex:0]);
    testComplexRootExtensionElement([repoInfo.extensions objectAtIndex:1]);
}

// Commented out due to the fact of no extension data returned by the 'cmisatom' url (the old url did)
//
//- (void)testExtensionData
//{
//    [self setupCmisSession];
//    NSError *error = nil;
//
//    // Test RepositoryInfo Extensions
//    CMISRepositoryInfo *repoInfo = self.session.repositoryInfo;
//    NSArray *repoExtensions = repoInfo.extensions;
//    STAssertTrue(1 == repoExtensions.count, @"Expected 1 RepositoryInfo extension, but %d extension(s) returned", repoExtensions.count);
//    CMISExtensionElement *element = [repoExtensions objectAtIndex:0];
//    STAssertTrue([@"Version 1.0 OASIS Standard" isEqualToString:element.value], @"Expected value='Version 1.0 OASIS Standard', actual='%@'", element.value);
//    STAssertTrue([@"http://www.alfresco.org" isEqualToString:element.namespaceUri], @"Expected namespaceUri='http://www.alfresco.org', actual='%@'", element.namespaceUri);
//    STAssertTrue([@"cmisSpecificationTitle" isEqualToString:element.name], @"Expected name='cmisSpecificationTitle', actual='%@'", element.name);
//    STAssertTrue([element.children count] == 0, @"Expected 0 children, but %d were found", [element.children count]);
//    STAssertTrue([element.attributes count] == 0, @"Expected 0 attributes, but %d were found", [element.attributes count]);
//
//
//    // Get an existing Document
//    CMISDocument *testDocument = [self retrieveVersionedTestDocument];
//
//    // Get testDocument but with AllowableActions
//    CMISOperationContext *ctx = [[CMISOperationContext alloc] init];
//    ctx.isIncludeAllowableActions = YES;
//    CMISDocument *document = (CMISDocument *) [self.session retrieveObject:testDocument.identifier withOperationContext:ctx error:&error];
//
//    NSArray *extensions = [document extensionsForExtensionLevel:CMISExtensionLevelObject];
//    STAssertTrue([extensions count] == 0, @"Expected no extensions, but found %d", [extensions count]);
//
//    extensions = [document extensionsForExtensionLevel:CMISExtensionLevelProperties];
//    STAssertTrue([extensions count] > 0, @"Expected extension data for properties, but none were found");
//
//    STAssertTrue([document.allowableActions.allowableActionsSet count] > 0, @"Expected at least one allowable action but found none");
//    extensions = [document extensionsForExtensionLevel:CMISExtensionLevelAllowableActions];
//    STAssertTrue([extensions count] == 0, @"Expected no extension data for allowable actions, but found %d", [extensions count]);
//}


- (void)testPropertiesConversion
{
    [self runTest:^ {
         NSDate *testDate = [NSDate date];
         NSCalendar *calendar = [NSCalendar currentCalendar];
         NSUInteger unitflags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
         NSDateComponents *origComponents = [calendar components:unitflags fromDate:testDate];
         
         // Create converter
         
         // Try to convert with already CMISPropertyData. This should work just fine.
         NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyName stringValue:@"testName"] forKey:kCMISPropertyName];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyObjectTypeId idValue:@"cmis:document"] forKey:kCMISPropertyObjectTypeId];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyCreationDate dateTimeValue:testDate] forKey:kCMISPropertyCreationDate];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyIsLatestVersion boolValue:YES] forKey:kCMISPropertyIsLatestVersion];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyContentStreamLength integerValue:5] forKey:kCMISPropertyContentStreamLength];
         
         [self.session.objectConverter convertProperties:properties forObjectTypeId:@"cmis:document" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
             XCTAssertNil(error, @"Error while converting properties: %@", [error description]);
             XCTAssertNotNil(convertedProperties, @"Conversion failed, nil was returned");
             XCTAssertTrue(convertedProperties.propertyList.count == 5, @"Expected 5 converted properties, but was %lu", (unsigned long)convertedProperties.propertyList.count);
             XCTAssertEqualObjects(@"testName", [[convertedProperties propertyForId:kCMISPropertyName]propertyStringValue], @"Converted property value did not match");
             XCTAssertEqualObjects(@"cmis:document", [[convertedProperties propertyForId:kCMISPropertyObjectTypeId] propertyIdValue], @"Converted property value did not match");
             XCTAssertEqualObjects(testDate, [[convertedProperties propertyForId:kCMISPropertyCreationDate] propertyDateTimeValue], @"Converted property value did not match");
             XCTAssertEqualObjects([NSNumber numberWithBool:YES], [[convertedProperties propertyForId:kCMISPropertyIsLatestVersion] propertyBooleanValue], @"Converted property value did not match");
             XCTAssertEqualObjects([NSNumber numberWithInteger:5], [[convertedProperties propertyForId:kCMISPropertyContentStreamLength] propertyIntegerValue], @"Converted property value did not match");
             
             // Test with non-CMISPropertyData values
             NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
             [properties setObject:@"test" forKey:kCMISPropertyName];
             [properties setObject:@"cmis:document" forKey:kCMISPropertyObjectTypeId];
             [properties setObject:[CMISDateUtil stringFromDate:testDate] forKey:kCMISPropertyCreationDate];
             [properties setObject:[NSNumber numberWithBool:NO] forKey:kCMISPropertyIsLatestVersion];
             [properties setObject:[NSNumber numberWithInt:4] forKey:kCMISPropertyContentStreamLength];
             
             [self.session.objectConverter convertProperties:properties forObjectTypeId:@"cmis:document" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
                 XCTAssertNil(error, @"Error while converting properties: %@", [error description]);
                 XCTAssertNotNil(convertedProperties, @"Conversion failed, nil was returned");
                 XCTAssertTrue(convertedProperties.propertyList.count == 5, @"Expected 5 converted properties, but was %lu", (unsigned long)convertedProperties.propertyList.count);
                 XCTAssertEqualObjects(@"test", [[convertedProperties propertyForId:kCMISPropertyName] propertyStringValue], @"Converted property value did not match");
                 XCTAssertEqualObjects(@"cmis:document", [[convertedProperties propertyForId:kCMISPropertyObjectTypeId] propertyIdValue], @"Converted property value did not match");
                 
                 // NSDate is using sub-second precision ... and the formatter is not.
                 // ... sigh ... hence we test if the dates are 'relatively' (ie 1 second) close
                 NSDate *convertedDate = [[convertedProperties propertyForId:kCMISPropertyCreationDate] propertyDateTimeValue];
                 NSDateComponents *convertedComps = [calendar components:unitflags fromDate:convertedDate];
                 BOOL isOnSameDate = (origComponents.year == convertedComps.year) && (origComponents.month == convertedComps.month) && (origComponents.day == convertedComps.day);
                 XCTAssertTrue(isOnSameDate, @"We expected the reconverted date to be on the same date as the original one");
                 
                 BOOL isOnSameTime = (origComponents.hour == convertedComps.hour) && (origComponents.minute == convertedComps.minute) && (origComponents.second == convertedComps.second);
                 XCTAssertTrue(isOnSameTime, @"We expected the reconverted time to be at the same time as the original one");
                 
//                 NSDate *convertedDate = [[convertedProperties propertyForId:kCMISPropertyCreationDate] propertyDateTimeValue];
//                 STAssertTrue(testDate.timeIntervalSince1970 - 1000 <= convertedDate.timeIntervalSince1970
//                              && convertedDate.timeIntervalSince1970 <= testDate.timeIntervalSince1970 + 1000, @"Converted property value did not match");
                 XCTAssertEqualObjects([NSNumber numberWithBool:NO], [[convertedProperties propertyForId:kCMISPropertyIsLatestVersion] propertyBooleanValue], @"Converted property value did not match");
                 XCTAssertEqualObjects([NSNumber numberWithInteger:4], [[convertedProperties propertyForId:kCMISPropertyContentStreamLength] propertyIntegerValue], @"Converted property value did not match");
                 
                 // Test error return
                 [self.session.objectConverter convertProperties:nil forObjectTypeId:@"doesntmatter" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
                     XCTAssertNil(convertedProperties, @"Should be nil");

                     NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
                     [properties setObject:@"test" forKey:kCMISPropertyContentStreamLength];
                     [self.session.objectConverter convertProperties:properties forObjectTypeId:@"cmis:document" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
                         XCTAssertNotNil(error, @"Expecting an error when converting");
                         XCTAssertNil(convertedProperties, @"When conversion goes wrong, should return nil");
                         
                         NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
                         [properties setObject:[NSNumber numberWithBool:YES] forKey:kCMISPropertyName];
                         [self.session.objectConverter convertProperties:properties forObjectTypeId:@"cmis:document" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
                             XCTAssertNotNil(error, @"Expecting an error when converting");
                             XCTAssertNil(convertedProperties, @"When conversion goes wrong, should return nil");
                             
                             self.testCompleted = YES;
                         }];
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testOperationContextForRetrievingObject
{
    [self runTest:^ {
         // Create some test document
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *testDocument) {
             // Use YES for retrieving the allowable actions
             CMISOperationContext *ctx = [[CMISOperationContext alloc] init];
             ctx.includeAllowableActions = YES;
             [self.session retrieveObject:testDocument.identifier operationContext:ctx completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *)object;
                 XCTAssertNil(error, @"Got error while retrieving object : %@", [error description]);
                 XCTAssertNotNil(document.allowableActions, @"Allowable actions should not be nil");
                 XCTAssertTrue(document.allowableActions.allowableActionsSet.count > 0, @"Expected at least one allowable action");
                 
                 //Use NO for allowable actions
                 CMISOperationContext *ctx = [[CMISOperationContext alloc] init];
                 ctx.includeAllowableActions = NO;
                 [self.session retrieveObject:testDocument.identifier operationContext:ctx completionBlock:^(CMISObject *object, NSError *error) {
                     CMISDocument *document = (CMISDocument *)object;
                     XCTAssertNil(error, @"Got error while retrieving object : %@", [error description]);
                     XCTAssertNil(document.allowableActions, @"Allowable actions should be nil");
                     XCTAssertTrue(document.allowableActions.allowableActionsSet.count == 0, @"Expected zero allowable actions");
                     
                     // Cleanup
                     [self deleteDocumentAndVerify:testDocument completionBlock:^{
                         self.testCompleted = YES;
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testGetRenditionsThroughCmisObject
{
    [self runTest:^ {
         // Fetch test document
         NSString *path = [NSString stringWithFormat:@"%@/millenium-dome-exif.jpg", self.rootFolder.path];
         CMISOperationContext *operationContext = [CMISOperationContext defaultOperationContext];
         operationContext.renditionFilterString = @"*";
         [self.session retrieveObjectByPath:path operationContext:operationContext completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             XCTAssertNil(error, @"Error while retrieving document: %@", [error description]);
             
             // Get and verify Renditions
             NSArray *renditions = document.renditions;
             XCTAssertTrue(renditions.count > 0, @"Expected at least one rendition");
             CMISRendition *thumbnailRendition = nil;
             for (CMISRendition *rendition in renditions) {
                 if ([rendition.kind isEqualToString:@"cmis:thumbnail"]) {
                     thumbnailRendition = rendition;
                 }
             }
             XCTAssertNotNil(thumbnailRendition, @"Thumbnail rendition should be availabile");
             XCTAssertTrue(thumbnailRendition.length > 0, @"Rendition length should be greater than 0");
             
             // Get content
             NSString *filePath = [NSString stringWithFormat:@"%@/testfile.pdf" , NSTemporaryDirectory()];
             [thumbnailRendition downloadRenditionContentToFile:filePath completionBlock:^(NSError *error) {
                 if (error == nil) {
                     // Assert File exists and check file length
                     XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath], @"File does not exist");
                     NSError *fileError;
                     NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&fileError];
                     XCTAssertNil(fileError, @"Could not verify attributes of file %@: %@", filePath, [fileError description]);
                     XCTAssertTrue([fileAttributes fileSize] > 10, @"Expected a file of at least 10 bytes, but found one of %lu bytes", (unsigned long)[fileAttributes fileSize]);
                     
                     // Nice boys clean up after themselves
                     [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
                     XCTAssertNil(fileError, @"Could not remove file %@: %@", filePath, [fileError description]);
                     
                     self.testCompleted = YES;
                 } else {
                     XCTAssertNil(error, @"Error while writing content: %@", [error description]);
                 
                     self.testCompleted = YES;
                 }
             } progressBlock:nil];
         }];
     }];
}

- (void)testGetRenditionsThroughObjectService
{
    [self runTest:^ {
         // Fetch test document
         NSString *path = [NSString stringWithFormat:@"%@/millenium-dome-exif.jpg", self.rootFolder.path];
         CMISOperationContext *operationContext = [CMISOperationContext defaultOperationContext];
         operationContext.renditionFilterString = @"*";
         [self.session retrieveObjectByPath:path operationContext:operationContext completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             XCTAssertNil(error, @"Error while retrieving document: %@", [error description]);
             
             // Get renditions through service
             [self.session.binding.objectService retrieveRenditions:document.identifier
                                                    renditionFilter:@"*"
                                                           maxItems:nil
                                                          skipCount:nil
                                                    completionBlock:^(NSArray *renditions, NSError *error) {
                  XCTAssertNil(error, @"Error while retrieving renditions: %@", [error description]);
                  XCTAssertTrue(renditions.count > 0, @"Expected at least one rendition");
                  CMISRenditionData *thumbnailRendition = nil;
                  for (CMISRenditionData *rendition in renditions) {
                      if ([rendition.kind isEqualToString:@"cmis:thumbnail"]) {
                          thumbnailRendition = rendition;
                      }
                  }
                  XCTAssertNotNil(thumbnailRendition, @"Thumbnail rendition should be availabile");
                  XCTAssertTrue(thumbnailRendition.length > 0, @"Rendition length should be greater than 0");
                  
                  // Download content through objectService
                  NSString *filePath = [NSString stringWithFormat:@"%@/testfile-rendition-through-objectservice.pdf", NSTemporaryDirectory()];
                  [self.session.binding.objectService downloadContentOfObject:document.identifier
                                                                     streamId:thumbnailRendition.streamId
                                                                       toFile:filePath
                                                              completionBlock: ^(NSError *error) {
                       if (error == nil) {
                           // Assert File exists and check file length
                           XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath], @"File does not exist");
                           NSError *fileError;
                           NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&fileError];
                           XCTAssertNil(error, @"Could not verify attributes of file %@: %@", filePath, [error description]);
                           XCTAssertTrue([fileAttributes fileSize] > 10, @"Expected a file of at least 10 bytes, but found one of %lu bytes", (unsigned long)[fileAttributes fileSize]);

                           // Nice boys clean up after themselves
                           [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
                           XCTAssertNil(fileError, @"Could not remove file %@: %@", filePath, [fileError description]);
                       } else {
                           XCTAssertNil(error, @"Error while downloading content: %@", [error description]);
                       }
                       
                       self.testCompleted = YES;
                   } progressBlock:nil];
              }];
         }];
     }];
}

- (void)testCheckoutCheckin
{
    [self runTest:^ {
        // Upload test file
        [self uploadTestFileWithCompletionBlock:^(CMISDocument *testDocument) {
            
            XCTAssertNotNil(testDocument, @"Expected testDocument to be uploaded!");
            
            // checkout the uploaded test document
            [testDocument checkOutWithCompletionBlock:^(CMISDocument *privateWorkingCopy, NSError *error) {
                
                // check we got the working copy
                XCTAssertNotNil(privateWorkingCopy, @"Expected to recieve the private working copy object");
                
                // sleep for a couple of seconds before checking back in
                [NSThread sleepForTimeInterval:2.0];
                
                // checkin the test document
                NSString *updatedFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file_2.txt" ofType:nil];
                [privateWorkingCopy checkInAsMajorVersion:YES filePath:updatedFilePath mimeType:@"text/plain" properties:nil checkinComment:@"Next version" completionBlock:^(CMISDocument *checkedInDocument, NSError *error) {
                    
                    // check we got back the checked in document
                    XCTAssertNotNil(checkedInDocument, @"Expected to receive the checked in document object");

                    // validate the content was updated
                    NSString *tempDownloadFilePath = [NSString stringWithFormat:@"%@/temp_download_file.txt", NSTemporaryDirectory()];
                    [checkedInDocument downloadContentToFile:tempDownloadFilePath completionBlock:^(NSError *error) {
                        
                        // check the content has been updated
                        NSString *contentOfDownloadedFile = [NSString stringWithContentsOfFile:tempDownloadFilePath encoding:NSUTF8StringEncoding error:nil];
                        XCTAssertEqualObjects(@"In theory, there is no difference between theory and practice. But in practice, there is.",
                                              contentOfDownloadedFile, @"Downloaded file content does not match, it was: '%@'", contentOfDownloadedFile);
                        
                        // retrieve all versions of the document and make sure there are 2 and the last one has the correct info
                        [checkedInDocument retrieveAllVersionsWithCompletionBlock:^(CMISCollection *allVersionsOfDocument, NSError *error) {
                            
                            // make sure there are 2 versions
                            XCTAssertTrue(allVersionsOfDocument.items.count == 2,
                                          @"Expected to find 2 versions but there were %lu", (unsigned long)allVersionsOfDocument.items.count);
                            
                            // get the first item (should be the latest one) and check the version label and checkin comment
                            CMISDocument *secondVersion = allVersionsOfDocument.items[0];
                            XCTAssertTrue([secondVersion.versionLabel isEqualToString:@"2.0"],
                                          @"Expected version label to be 2.0 but was %@", secondVersion.versionLabel);
                            XCTAssertTrue(secondVersion.isLatestVersion, @"Expected document to be the latest version");
                            XCTAssertTrue(secondVersion.isLatestMajorVersion, @"Expected document to be the latest major version");
                            XCTAssertTrue(secondVersion.isMajorVersion, @"Expected document to be a major version");
                            NSString *checkinComment = [secondVersion.properties propertyValueForId:kCMISPropertyCheckinComment];
                            XCTAssertTrue([checkinComment isEqualToString:@"Next version"],
                                          @"Expected checkin comment to be 'Next version' but was %@", checkinComment);
                            
                            CMISDocument *firstVersion = allVersionsOfDocument.items[1];
                            XCTAssertTrue([firstVersion.versionLabel isEqualToString:@"1.0"],
                                          @"Expected version label to be 1.0 but was %@", firstVersion.versionLabel);
                            XCTAssertFalse(firstVersion.isLatestVersion, @"Did not expect document to be the latest version");
                            XCTAssertFalse(firstVersion.isLatestMajorVersion, @"Did not expect document to be the latest major version");
                            XCTAssertTrue(firstVersion.isMajorVersion, @"Expected document to be a major version");
                            
                            // delete the document
                            [self deleteDocumentAndVerify:checkedInDocument completionBlock:^{
                                // mark the test as completed
                                self.testCompleted = YES;
                            }];
                        }];
                        
                    } progressBlock:^(unsigned long long bytesDownloaded, unsigned long long bytesTotal) {
                          CMISLogDebug(@"download progress %llu/%llu", bytesDownloaded, bytesTotal);
                    }];
                } progressBlock:^(unsigned long long bytesUploaded, unsigned long long bytesTotal) {
                      CMISLogDebug(@"upload progress %llu/%llu", bytesUploaded, bytesTotal);
                }];
            }];
        }];
    }];
}

- (void)testCancelCheckout
{
    [self runTest:^ {
        // Upload test file
        [self uploadTestFileWithCompletionBlock:^(CMISDocument *testDocument) {
            
            XCTAssertNotNil(testDocument, @"Expected testDocument to be uploaded!");
            
            // checkout the uploaded test document
            [testDocument checkOutWithCompletionBlock:^(CMISDocument *privateWorkingCopy, NSError *checkOutError) {
                XCTAssertNotNil(privateWorkingCopy, @"Expected to recieve the private working copy object");
                
                // cancel checkout of the test document
                [privateWorkingCopy cancelCheckOutWithCompletionBlock:^(BOOL checkoutCancelled, NSError *cancelError) {
                    
                    // make sure the pwc has been deleted
                    [self.session retrieveObject:privateWorkingCopy.identifier completionBlock:^(CMISObject *object, NSError *retrieveError) {
                        
                        // make sure the object is nill and error is not nil
                        XCTAssertNil(object, @"Did not expect to receive a document, the pwc should have been deleted");
                        XCTAssertNotNil(retrieveError, @"Expected there to be an error object");
                        XCTAssertTrue(retrieveError.code == kCMISErrorCodeObjectNotFound,
                                      @"Expected the error code to be 257 (kCMISErrorCodeObjectNotFound) but was %ld", (long)retrieveError.code);
                        
                        // delete the document
                        [self deleteDocumentAndVerify:testDocument completionBlock:^{
                            // mark the test as completed
                            self.testCompleted = YES;
                        }];
                    }];
                }];
            }];
        }];
    }];
}

- (void)testSecondaryTypes
{
    [self runTest:^ {
        
        // only run this test on servers that support the 1.1 CMIS spec.
        if ([self.session.repositoryInfo.cmisVersionSupported isEqualToString:@"1.1"])
        {
            NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file.txt" ofType:nil];
            XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath],
                          @"Test file 'test_file.txt' cannot be found as resource for the test");
            
            // Upload test file
            NSString *documentName = [NSString stringWithFormat:@"test_file_%@.txt", [self stringFromCurrentDate]];
            NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
            [documentProperties setObject:documentName forKey:kCMISPropertyName];
            [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];
            
            // add cm:titled secondary type
            [documentProperties setObject:[NSArray arrayWithObject:@"P:cm:titled"] forKey:kCMISPropertySecondaryObjectTypeIds];
            
            [self.rootFolder createDocumentFromFilePath:filePath mimeType:@"text/plain" properties:documentProperties completionBlock:^ (NSString *objectId, NSError *createError) {
                
                if (objectId) {
                    XCTAssertNotNil(objectId, @"Object id received should be non-nil");
                    
                    // Verify creation
                    [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *retrieveError) {
                        CMISDocument *document = (CMISDocument *)object;
                        XCTAssertTrue([documentName isEqualToString:document.name],
                                      @"Document name of created document is wrong: should be %@, but was %@", documentName, document.name);
                        
                        // ensure the "titled" aspect/secondary type is present
                        CMISProperties *createdProperties = document.properties;
                        CMISPropertyData *secondaryTypesProperty = [createdProperties propertyForId:kCMISPropertySecondaryObjectTypeIds];
                        XCTAssertNotNil(secondaryTypesProperty, @"Expected secondary types property to be present");
                        
                        NSArray *secondaryTypesValues = secondaryTypesProperty.values;
                        XCTAssertNotNil(secondaryTypesValues, @"Expected secondary types property to have a value");
                        
                        // we should have the cm:titled and cm:author secondary types in the array
                        XCTAssertTrue([secondaryTypesValues containsObject:@"P:cm:titled"],
                                      @"Expected secondary types values to contain P:cm:titled but it was %@", secondaryTypesValues);
                        XCTAssertTrue([secondaryTypesValues containsObject:@"P:cm:author"],
                                      @"Expected secondary types values to contain P:cm:author but it was %@", secondaryTypesValues);
                        
                        // add and remove a secondary type value
                        NSMutableArray *updatedValues = [NSMutableArray arrayWithArray:secondaryTypesValues];
                        [updatedValues removeObject:@"P:cm:titled"];
                        [updatedValues addObject:@"P:exif:exif"];
                        
                        NSMutableDictionary *updatedProperties = [NSMutableDictionary dictionary];
                        [updatedProperties setObject:updatedValues forKey:kCMISPropertySecondaryObjectTypeIds];
                        
                        [document updateProperties:updatedProperties completionBlock:^(CMISObject *updatedObject, NSError *updateError) {
                            if (object != nil) {
                                
                                CMISDocument *updatedDocument = (CMISDocument *)updatedObject;
                                CMISPropertyData *updatedSecondaryTypesProperty = [updatedDocument.properties propertyForId:kCMISPropertySecondaryObjectTypeIds];
                                XCTAssertNotNil(updatedSecondaryTypesProperty, @"Expected updated secondary types property to be present");
                                
                                // check it contains the correct entries
                                XCTAssertTrue([updatedSecondaryTypesProperty.values containsObject:@"P:exif:exif"],
                                              @"Expected the updated secondary types property to contain exif:exif but it was %@", updatedSecondaryTypesProperty.values);
                                XCTAssertFalse([updatedSecondaryTypesProperty.values containsObject:@"P:cm:titled"],
                                              @"Expected cm:titled to be missing from the updated secondary types property but it was %@", updatedSecondaryTypesProperty.values);
                                
                                // Cleanup after ourselves
                                [document deleteAllVersionsWithCompletionBlock:^(BOOL documentDeleted, NSError *deleteError) {
                                    XCTAssertNil(deleteError, @"Error while deleting created document: %@", [deleteError description]);
                                    XCTAssertTrue(documentDeleted, @"Document was not deleted");
                                    
                                    self.testCompleted = YES;
                                }];
                            }
                            else
                            {
                                XCTAssertNil(updateError, @"Got error while updating document: %@", [updateError description]);
                                self.testCompleted = YES;
                            }
                        }];
                    }];
                } else {
                    XCTAssertNil(createError, @"Got error while creating document: %@", [createError description]);
                    
                    self.testCompleted = YES;
                }
            }
            progressBlock: nil];
        }
        else
        {
            self.testCompleted = YES;
        }
    }];
}

- (void)testUrlUtilAppendParameter
{
    NSString *path;
    
    path = [CMISURLUtil urlStringByAppendingParameter:@"param1" value:@"value1" urlString:@"scheme://host:12345/path?"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path?param1=value1", @"expected url with with one parameter and it's value");
    
    path = [CMISURLUtil urlStringByAppendingParameter:@"param1" value:@"value1" urlString:@"scheme://host:12345/path"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path?param1=value1", @"expected url with with one parameter and it's value");
    
    path = [CMISURLUtil urlStringByAppendingParameter:@"param2" value:@"value2" urlString:@"scheme://host:12345/path?param1=value1"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path?param1=value1&param2=value2", @"expected url with with two parameters plus value");
    
    path = [CMISURLUtil urlStringByAppendingParameter:@"umlautParam" value:@"välüe1" urlString:@"scheme://host:12345/path"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path?umlautParam=v%C3%A4l%C3%BCe1", @"expected url with with encoded value");
    
    path = [CMISURLUtil urlStringByAppendingParameter:nil value:@"paramIsNil" urlString:@"scheme://host:12345/path"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path", @"expected url not to be modified as parameter is nil");
    
    path = [CMISURLUtil urlStringByAppendingParameter:@"valueIsNil" value:nil urlString:@"scheme://host:12345/path"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path", @"expected url not to be modified as value is nil");
    
    path = [CMISURLUtil urlStringByAppendingParameter:@"param1" value:@"value1" urlString:@"scheme://host/"];
    XCTAssertEqualObjects(path, @"scheme://host/?param1=value1", @"expected url (no port) with with one parameter and it's value");
    
    path = [CMISURLUtil urlStringByAppendingParameter:@"param1" value:@"value1" urlString:@"https://example.com:12345/path1/path2"];
    XCTAssertEqualObjects(path, @"https://example.com:12345/path1/path2?param1=value1", @"expected url with with one parameter and it's value");
}

- (void)testUrlUtilAppendPath
{
    NSString *path;
    
    path = [CMISURLUtil urlStringByAppendingPath:@"aPath" urlString:@"scheme://host:12345?"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/aPath?", @"expected url with path");
    
    path = [CMISURLUtil urlStringByAppendingPath:@"subPath" urlString:@"scheme://host:12345/path?"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path/subPath?", @"expected url with sub path component");
    
    path = [CMISURLUtil urlStringByAppendingPath:@"subPath" urlString:@"scheme://host:12345/path"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path/subPath", @"expected url with sub path component");
    
    path = [CMISURLUtil urlStringByAppendingPath:@"subPath" urlString:@"scheme://host:12345/path/"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path/subPath", @"expected url with sub path component");
    
    path = [CMISURLUtil urlStringByAppendingPath:@"subPath" urlString:@"scheme://host:12345/path?parm1=value1"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path/subPath?parm1=value1", @"expected url with sub path component, parmater and it's value");
    
    path = [CMISURLUtil urlStringByAppendingPath:@"subPath" urlString:@"scheme://host:12345/path?parm1=value1&param2=value2"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/path/subPath?parm1=value1&param2=value2", @"expected url with sub path component, multiple parmaters and their values");
    
    path = [CMISURLUtil urlStringByAppendingPath:@"/aPath" urlString:@"scheme://host:12345/test"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/test/aPath", @"expected url with sub path component");
    
    path = [CMISURLUtil urlStringByAppendingPath:@"/aPath" urlString:@"scheme://host:12345/test/"];
    XCTAssertEqualObjects(path, @"scheme://host:12345/test/aPath", @"expected url with sub path component");
    
    // multi-segment path with special chars, space turns into %20
    path = [CMISURLUtil urlStringByAppendingPath:@"path/caf\u00e9 d@d" urlString:@"http://host/test/"];
    XCTAssertEqualObjects(path, @"http://host/test/path/caf%C3%A9%20d%40d", @"expected url with encoded path component");
    NSLog(@"%@", path);
}

- (void)testEncodeContentDisposition
{
    XCTAssertEqualObjects(@"inline; filename=foo.bar", [CMISMimeHelper encodeContentDisposition:@"inline" fileName:@"foo.bar"], @"wrong encoded content disposition");
    XCTAssertEqualObjects(@"attachment; filename=foo.bar", [CMISMimeHelper encodeContentDisposition:nil fileName:@"foo.bar"], @"wrong encoded content disposition");
    XCTAssertEqualObjects(@"attachment; filename*=UTF-8''caf%C3%A9.pdf", [CMISMimeHelper encodeContentDisposition:nil fileName:@"caf\u00e9.pdf"], @"wrong encoded content disposition");

    // TODO how to add those unicode control characters directly into the string?
    uint codeValue1;
    [[NSScanner scannerWithString:@"0x0081"] scanHexInt:&codeValue1];
    uint codeValue2;
    [[NSScanner scannerWithString:@"0x0082"] scanHexInt:&codeValue2];
    NSString *fileName = [NSString stringWithFormat:@" '*%% abc %C%C\r\n\t", (unichar)codeValue1, (unichar)codeValue2];
    XCTAssertEqualObjects(@"attachment; filename*=UTF-8''%20%27%2A%25%20abc%20%C2%81%C2%82%0D%0A%09", [CMISMimeHelper encodeContentDisposition:nil fileName:fileName], @"wrong encoded content disposition");
}

- (void)testEncodeUrlParameterValue
{
    XCTAssertEqualObjects(@"test%20%2B%20%2Fvalue%20%26%20", [CMISURLUtil encodeUrlParameterValue:@"test + /value & "], @"wrong encoded url parameter value");
    XCTAssertEqualObjects(@"%20%25%20%22%20", [CMISURLUtil encodeUrlParameterValue:@" % \" "], @"wrong encoded url parameter value");
    XCTAssertEqualObjects(@"%20%60~%21%40%23%24%25%5E%26%2A%28%29_%2B-%3D%7B%7D%5B%5D%7C%5C%3A%3B%22%27%3C%2C%3E.%3F%2FAZaz", [CMISURLUtil encodeUrlParameterValue:@" `~!@#$%^&*()_+-={}[]|\\:;\"'<,>.?/AZaz"], @"wrong encoded url parameter value");
    XCTAssertEqualObjects(@"%E5%BD%BC%E5%BE%97", [CMISURLUtil encodeUrlParameterValue:@"彼得"], @"wrong encoded url parameter value");
    
    XCTAssertEqualObjects(@"%C3%BC%C3%A4%C3%B6%C3%9C%C3%84%C3%96%C3%A9%C4%9F", [CMISURLUtil encodeUrlParameterValue:@"üäöÜÄÖéğ"], @"wrong encoded url parameter value");
}

- (void)testQueryStatementStaticQueries {
    NSString *query;
    CMISQueryStatement *st;
    
    query = @"SELECT cmis:name FROM cmis:folder";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    XCTAssertEqualObjects(query, [st queryString], @"wrong encoded query statement");
    
    query = @"SELECT * FROM cmis:document WHERE cmis:createdBy = \'admin\' AND abc:int = 42";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    XCTAssertEqualObjects(query, [st queryString], @"wrong encoded query statement");
    
    query = @"SELECT * FROM cmis:document WHERE abc:test = 'x?z'";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    [st setStringAtIndex:1 string:@"y"];
    XCTAssertEqualObjects(query, [st queryString], @"wrong encoded query statement");
}

- (void)testQueryStatementWherePlacholder {
    NSString *query;
    CMISQueryStatement *st;
    
    // strings
    query = @"SELECT * FROM cmis:document WHERE abc:string = ?";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    [st setStringAtIndex:1 string:@"test"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE abc:string = 'test'", [st queryString], @"wrong encoded query statement");
    
    query = @"SELECT * FROM cmis:document WHERE abc:string = ?";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    [st setStringAtIndex:1 string:@"te'st"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE abc:string = 'te\\'st'", [st queryString], @"wrong encoded query statement");
    
    // likes
    query = @"SELECT * FROM cmis:document WHERE abc:string LIKE ?";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    [st setStringLikeAtIndex:1 string:@"%test%"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE abc:string LIKE '%test%'", [st queryString], @"wrong encoded query statement");
    
    query = @"SELECT * FROM cmis:document WHERE abc:string LIKE ?";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    [st setStringLikeAtIndex:1 string:@"\\_test\\%blah\\\\blah"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE abc:string LIKE '\\_test\\%blah\\\\\\\\blah'", [st queryString], @"wrong encoded query statement");
    
    // contains
    
    // *, ? and - are treated as text search operators: 1st level escaping:
    // none, 2nd level escaping: none
    // \*, \? and \- are used as literals, 1st level escaping: none, 2nd
    // level escaping: \\*, \\?, \\-
    // ' and " are used as literals, 1st level escaping: \', \", 2nd level
    // escaping: \\\', \\\",
    // \ plus any other character, 1st level escaping \\ plus character, 2nd
    // level: \\\\ plus character
    
    query = @"SELECT * FROM cmis:document WHERE CONTAINS(?)";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    [st setStringContainsAtIndex:1 string:@"John's"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE CONTAINS('John\\\\\\'s')", [st queryString], @"wrong encoded query statement");
    [st setStringContainsAtIndex:1 string:@"foo -bar"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE CONTAINS('foo -bar')", [st queryString], @"wrong encoded query statement");
    [st setStringContainsAtIndex:1 string:@"foo*"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE CONTAINS('foo*')", [st queryString], @"wrong encoded query statement");
    [st setStringContainsAtIndex:1 string:@"foo?"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE CONTAINS('foo?')", [st queryString], @"wrong encoded query statement");
    [st setStringContainsAtIndex:1 string:@"foo\\-bar"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE CONTAINS('foo\\\\-bar')", [st queryString], @"wrong encoded query statement");
    [st setStringContainsAtIndex:1 string:@"foo\\*"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE CONTAINS('foo\\\\*')", [st queryString], @"wrong encoded query statement");
    [st setStringContainsAtIndex:1 string:@"foo\\?"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE CONTAINS('foo\\\\?')", [st queryString], @"wrong encoded query statement");
    [st setStringContainsAtIndex:1 string:@"\"Cool\""];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE CONTAINS('\\\\\\\"Cool\\\\\\\"')", [st queryString], @"wrong encoded query statement");
    [st setStringContainsAtIndex:1 string:@"c:\\MyDcuments"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE CONTAINS('c:\\\\MyDcuments')", [st queryString], @"wrong encoded query statement");
    
    // ids
    query = @"SELECT * FROM cmis:document WHERE abc:id = ?";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    [st setStringAtIndex:1 string:@"123"];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE abc:id = '123'", [st queryString], @"wrong encoded query statement");
    
    // booleans
    query = @"SELECT * FROM cmis:document WHERE abc:bool = ?";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    [st setBooleanAtIndex:1 boolean:YES];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE abc:bool = TRUE", [st queryString], @"wrong encoded query statement");
    
    // numbers
    query = @"SELECT * FROM cmis:document WHERE abc:int = ? AND abc:int2 = 123";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    [st setNumberAtIndex:1 number:[NSNumber numberWithInt:42]];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE abc:int = 42 AND abc:int2 = 123", [st queryString], @"wrong encoded query statement");
    
    query = @"SELECT * FROM cmis:document WHERE abc:dateTime = ?";
    st = [[CMISQueryStatement alloc] initWithStatement:query];
    NSDateFormatter *df = [NSDateFormatter new];
    [df setDateFormat:@"dd/MM/yyyy HH:mm:ss"];
    //Create the GMT date
    df.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDate *date = [df dateFromString:@"02/02/2012 03:04:05"];

    [st setDateTimeAtIndex:1 date:date];
    XCTAssertEqualObjects(@"SELECT * FROM cmis:document WHERE abc:dateTime = TIMESTAMP '2012-02-02T03:04:05.000Z'", [st queryString], @"wrong encoded query statement");
}

@end
