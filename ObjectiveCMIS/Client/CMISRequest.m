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

#import "CMISRequest.h"
#import "CMISHttpRequest.h"

@interface CMISRequest ()

@property (nonatomic, getter = isCancelled) BOOL cancelled;

@end


@implementation CMISRequest

@synthesize httpRequest = _httpRequest;
@synthesize cancelled = _cancelled;

- (void)cancel
{
    self.cancelled = YES;
    
    [self.httpRequest cancel];
}

- (void)setHttpRequest:(CMISHttpRequest *)httpRequest
{
    _httpRequest = httpRequest;
    
    if (self.isCancelled) {
        [httpRequest cancel];
    }
}

@end
