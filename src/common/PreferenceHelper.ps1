# Copyright 2018, Adam Edwards
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

$__GraphMetadataPreferenceValues = @(
    'Ignore',
    'Wait',
    'SilentlyWait'
)

$GraphMetadataPreference = 'Ignore'

function __Preference__ShowNotReadyMetadataWarning {
    if ( $GraphMetadataPreference -ne 'SilentlyWait' ) {
        Write-Warning "Waiting for metadata processing, press CTRL-C to abort"
    }
}

function __Preference__MustWaitForMetadata {
    $GraphMetadataPreference -eq 'Wait' -and $GraphMetadataPreference -eq 'SilentlyWait'
}

$__GraphAutoPromptPreferenceValues = @(
    'Manual',
    'Auto'
)

$GraphAutoPromptPreference = 'Auto'

function __AutoConfigurePrompt($context) {
    if ( $GraphAutoPromptPreference -eq 'Auto' ) {
        if ( $context.connection |=> IsConnected ) {
            if ( ! $script:__GraphOriginalPrompt ) {
                Set-GraphPrompt -Enable
            }
        } else {
            if ( $script:__GraphOriginalPrompt ) {
                Set-GraphPrompt -Disable
            }
        }
    }
}

