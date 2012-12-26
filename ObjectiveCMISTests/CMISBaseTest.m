/*
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
 */
#import "CMISBaseTest.h"
#import "CMISFolder.h"
#import "CMISSession.h"
#import "CMISConstants.h"


@implementation CMISBaseTest

@synthesize parameters = _parameters;
@synthesize session = _session;
@synthesize rootFolder = _rootFolder;
@synthesize testCompleted = _testCompleted;


- (void) runTest:(CMISTestBlock)testBlock
{
    [self runTest:testBlock withExtraSessionParameters:nil];
}

- (void) runTest:(CMISTestBlock)testBlock withExtraSessionParameters:(NSDictionary *)extraSessionParameters
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    STAssertNotNil(bundle, @"Bundle is nil!");

    NSString *envsPListPath = [bundle pathForResource:@"env-cfg" ofType:@"plist"];
    STAssertNotNil(envsPListPath, @"envsPListPath is nil!");

    NSDictionary *environmentsDict = [[NSDictionary alloc] initWithContentsOfFile:envsPListPath];
    STAssertNotNil(environmentsDict, @"environmentsDict is nil!");

    NSArray *environmentArray = [environmentsDict objectForKey:@"environments"];
    STAssertNotNil(environmentArray, @"environmentArray is nil!");

    for (NSDictionary *envDict in environmentArray)
    {
        NSString *url = [envDict valueForKey:@"url"];
        NSString *repositoryId = [envDict valueForKey:@"repositoryId"];
        NSString *username = [envDict valueForKey:@"username"];
        NSString *password = [envDict valueForKey:@"password"];

        self.testCompleted = NO;
        [self setupCmisSession:url repositoryId:repositoryId username:username password:password extraSessionParameters:extraSessionParameters completionBlock:^{
            self.testCompleted = NO;
            
            log(@">------------------- Running test against %@ -------------------<", url);
            
            testBlock();
        }];
        [self waitForCompletion:90];
    }
}

- (void)setupCmisSession:(NSString *)url repositoryId:(NSString *)repositoryId username:(NSString *)username
                  password:(NSString *)password extraSessionParameters:(NSDictionary *)extraSessionParameters
         completionBlock:(void (^)(void))completionBlock
{
    self.parameters = [[CMISSessionParameters alloc] initWithBindingType:CMISBindingTypeAtomPub];
    self.parameters.username = username;
    self.parameters.password = password;
    self.parameters.atomPubUrl = [NSURL URLWithString:url];
    self.parameters.repositoryId = repositoryId;

    // Extra cmis params could be provided as method parameter
    if (extraSessionParameters != nil)
    {
        for (id extraSessionParamKey in extraSessionParameters)
        {
            [self.parameters setObject:[extraSessionParameters objectForKey:extraSessionParamKey] forKey:extraSessionParamKey];
        }
    }

    // Or, extra cmis parameters could be provided by overriding a base method
    NSDictionary *customParameters = [self customCmisParameters];
    if (customParameters)
    {
        for (id customParamKey in customParameters)
        {
            [self.parameters setObject:[customParameters objectForKey:customParamKey] forKey:customParamKey];
        }
    }
    [CMISSession connectWithSessionParameters:self.parameters completionBlock:^(CMISSession *session, NSError *error){
        if (nil == session)
        {

        }
        else
        {
            self.session = session;
            STAssertTrue(self.session.isAuthenticated, @"Session should be authenticated");
            [self.session retrieveRootFolderWithCompletionBlock:^(CMISFolder *rootFolder, NSError *error) {
                self.rootFolder = rootFolder;
                STAssertNil(error, @"Error while retrieving root folder: %@", [error description]);
                STAssertNotNil(self.rootFolder, @"rootFolder object should not be nil");
                
                completionBlock();
            }];
        }
    }];

}

- (NSDictionary *)customCmisParameters
{
    // Ment to be overridden.
    return nil;
}

#pragma mark Helper Methods

- (void)retrieveVersionedTestDocumentWithCompletionBlock:(void (^)(CMISDocument *document))completionBlock
{
    [self.session retrieveObjectByPath:@"/ios-test/versioned-quote.txt" completionBlock:^(CMISObject *object, NSError *error) {
        CMISDocument *document = (CMISDocument *)object;
        STAssertNotNil(document, @"Did not find test document for versioning test");
        STAssertTrue(document.isLatestVersion, @"Should have 'true' for the property 'isLatestVersion");
        STAssertFalse(document.isLatestMajorVersion, @"Should have 'false' for the property 'isLatestMajorVersion"); // the latest version is a minor one
        STAssertFalse(document.isMajorVersion, @"Should have 'false' for the property 'isMajorVersion");
        
        completionBlock(document);
    }];
}

- (void)uploadTestFileWithCompletionBlock:(void (^)(CMISDocument *document))completionBlock
{
    // Set properties on test file
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file.txt" ofType:nil];
    NSString *documentName = [NSString stringWithFormat:@"test_file_%@.txt", [self stringFromCurrentDate]];
    NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
    [documentProperties setObject:documentName forKey:kCMISPropertyName];
    [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];

    // Upload test file
    __block long long previousUploadedBytes = -1;
    __block NSString *objectId = nil;
    [self.rootFolder createDocumentFromFilePath:filePath
            withMimeType:@"text/plain"
            withProperties:documentProperties
            completionBlock: ^ (NSString *newObjectId, NSError *error)
            {
                if (newObjectId) {
                    objectId = newObjectId;
                    
                    [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                        CMISDocument *document = (CMISDocument *)object;
                        STAssertNil(error, @"Got error while creating document: %@", [error description]);
                        STAssertNotNil(objectId, @"Object id received should be non-nil");
                        STAssertNotNil(document, @"Retrieved document should not be nil");
                        completionBlock(document);
                    }];
                } else {
                    STAssertNotNil(error, @"Object id should not be nil");
                    STAssertNil(error, @"Got error while uploading document: %@", [error description]);
                }
            }
            progressBlock: ^ (unsigned long long uploadedBytes, unsigned long long totalBytes)
            {
                STAssertTrue((long long)uploadedBytes > previousUploadedBytes, @"no progress");
                previousUploadedBytes = uploadedBytes;
            }];

}

- (void)waitForCompletion:(NSTimeInterval)timeoutSecs
{
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeoutSecs];
    do
    {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
    } while (!self.testCompleted && [timeoutDate timeIntervalSinceNow] > 0);

    STAssertTrue(self.testCompleted, @"Test did not complete within %d seconds", (int)timeoutSecs);

    self.testCompleted = NO;
}

- (void)deleteDocumentAndVerify:(CMISDocument *)document completionBlock:(void (^)(void))completionBlock
{
    [document deleteAllVersionsWithCompletionBlock:^(BOOL documentDeleted, NSError *error) {
        STAssertNil(error, @"Error while deleting created document: %@", [error description]);
        STAssertTrue(documentDeleted, @"Document was not deleted");
        completionBlock();
    }];
}

- (NSDateFormatter *)testDateFormatter
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat: @"yyyy-MM-dd'T'HH-mm-ss-Z'"];
    return formatter;
}

- (NSString *)stringFromCurrentDate
{
    return [[self testDateFormatter] stringFromDate:[NSDate date]];
}


@end