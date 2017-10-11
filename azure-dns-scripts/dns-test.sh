#!/bin/sh

#
# Copyright (c) 2017 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# Check that everything is working
#
echo "Running sanity checks:"
echo "1. 'hostname -f'"
echo "2. 'hostname -i'"
echo "3. 'host \$(hostname -f)'"
echo "4. 'host \$(hostname -i)'"

if ! hostname -f
then
    echo "Unable to run the command 'hostname -f' (check 1 of 4)"
    exit 1
fi

if ! hostname -i
then
    echo "Unable to run the command 'hostname -i' (check 2 of 4)"
    exit 1
fi

if ! host "$(hostname -f)"
then
    echo "Unable to run the command 'host \$(hostname -f)' (check 3 of 4)"
    exit 1
fi

if ! host "$(hostname -i)"
then
    echo "Unable to run the command 'host \$(hostname -i)' (check 4 of 4)"
    exit 1
fi

echo ""
echo "Everything is working!"
exit 0
