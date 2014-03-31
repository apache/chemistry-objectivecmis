#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

usage ()
{
   echo 
   echo "usage: run_test [-junit]"
   echo "  -junit : Pipe output through ocunit2junit to allow Bamboo to parse test results"
   echo
   exit 1
}

# check parameters
for param in $*
do
   if [[ "$param" == "-junit" ]] ; then
      JUNIT_FLAG="true"
   else
      # no other parameters supported
      usage
   fi
done

# remove previous test reports
if [[ -d test-reports ]] ; then
  echo "Removing previous test-reports folder..."
  rm -R test-reports
fi

BUILD_OPTS=(test -scheme ObjectiveCMIS -destination OS=latest,name="iPhone Retina (4-inch 64-bit)")

if [[ "$JUNIT_FLAG" == "true" ]] ; then
   echo "Tests are running, output is being piped to ocunit2junit, results will appear soon..."
   xcodebuild "${BUILD_OPTS[@]}" 2>&1 | ocunit2junit
else
   xcodebuild "${BUILD_OPTS[@]}"
fi
