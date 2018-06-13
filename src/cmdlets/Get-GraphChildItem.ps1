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

. (import-script ../Invoke-GraphRequest)
. (import-script Get-GraphUri)

function Get-GraphChildItem {
    [cmdletbinding(positionalbinding=$false, supportspaging=$true)]
    param(
        [parameter(position=0)]
        [Uri[]] $ItemRelativeUri = @('.'),

        [parameter(position=1, parametersetname='MSGraphNewConnection')]
        [String[]] $ScopeNames = $null,

        [Object] $ContentColumns = $null,

        [String] $Version = $null,

        [switch] $RawContent,

        [switch] $AbsoluteUri,

        [switch] $IncludeAll,

        [switch] $DetailedChildren,

        [HashTable] $Headers = $null,

        [parameter(parametersetname='MSGraphNewConnection')]
        [GraphCloud] $Cloud = [GraphCloud]::Public,

        [parameter(parametersetname='ExistingConnection', mandatory=$true)]
        [PSCustomObject] $Connection = $null
    )

    if ( $Version -or $Connection -or ($Cloud -ne ([GraphCloud]::Public)) ) {
        throw [NotImplementedException]::new("Non-default context not yet implemented")
    }

    $resolvedUri = if ( $ItemRelativeUri[0] -ne '.' ) {
        Get-GraphUri $ItemRelativeUri[0]
    } else {
        $context = $::.GraphContext |=> GetCurrent
        $parser = new-so SegmentParser $context $null $true
        $::.SegmentHelper |=> ToPublicSegment $parser $context.location
    }

    $results = @()

    $requestArguments = @{
        RelativeUri=$ItemRelativeUri[0]
        Version=$Version
        RawContent=$RawContent
        AbsoluteUri=$AbsoluteUri
        Headers=$Headers
        First=$pscmdlet.pagingparameters.first
        Skip=$pscmdlet.pagingparameters.skip
        IncludeTotalCount=$pscmdlet.pagingparameters.includetotalcount
    }

    if ($ScopeNames -ne $null) {
        $requestArguments['ScopeNames'] = $ScopeNames
    }

    if ( $Connection -ne $null ) {
        $requestArguments['Connection'] = $Connection
    }

    $graphException = $false

    if ( $resolvedUri.Class -ne '__Root' -and $::.SegmentHelper.IsValidLocationClass($resolvedUri.Class) ) {
        try {
            Invoke-GraphRequest @requestArguments | foreach {
                $result = if ( ! $RawContent.ispresent -and (! $resolvedUri.Collection -or $DetailedChildren.IsPresent) ) {
                    $_ | Get-GraphUri
                } else {
                    $::.SegmentHelper.ToPublicSegmentFromGraphItem($resolvedUri, $_)
                }

                $translatedResult = if ( ! $RawContent.IsPresent -and $ContentColumns ) {
                    $ContentColumns | foreach {
                        $specificOutputColumn = $false
                        $outputColumnName = $_
                        $contentColumnName = if ( $_ -is [String] ) {
                            $_
                        } elseif ( $_ -is [HashTable] ) {
                            if ( $_.count -ne 1 ) {
                                throw "Argument '$($_)' must have exactly one key, specify '@{source1=dest1}, @{source2=dest2}' instead"
                            }
                            $specificOutputColumn = $true
                            $outputColumnName = $_.values[0]
                            $_.keys[0]
                        } else {
                            throw "Invalid Content column '$($_.tostring())' of type '$($_.gettype())' specified -- only types [String] and [HashTable] are permitted"
                        }

                        $propertyName = if ( $specificOutputColumn ) {
                            $outputColumnName
                        } else {
                            if ( $result | gm $outputColumnName -erroraction silentlycontinue ) {
                                "__$outputColumnName"
                            } else {
                                $outputColumnName
                            }
                        }

                        $result | add-member -membertype noteproperty -name $propertyName -value ($result.content | select -erroraction silentlycontinue -expandproperty $contentColumnName)
                    }
                }

                $results += $result
            }
        } catch [System.Net.WebException] {
            $graphException = $true
            $statusCode = if ( $_.exception.response | gm statuscode -erroraction silentlycontinue ) {
                $_.exception.response.statuscode
            }
            $_.exception | write-verbose
            if ( $statusCode -eq 'Unauthorized' ) {
                write-warning "Graph endpoint returned 'Unauthorized', retry after re-authenticating via the 'Connect-Graph' cmdlet and requesting appropriate additional application scopes"
                throw
            } elseif ( $statusCode -eq 'Forbidden' ) {
                write-verbose "Graph endpoint returned 'Forbiddden' - ignoring failure"
            } elseif ( $statusCode -eq 'BadRequest' ) {
                write-verbose "Graph endpoint returned 'Bad request' - metadata may be inaccurate, ignoring failure"
            } else {
                throw
            }
        }
    }

    if ( $graphException -or ! $resolvedUri.Collection ) {
        Get-GraphUri $ItemRelativeUri[0] -children -locatablechildren:(!$IncludeAll.IsPresent) | foreach {
            $results += $_
        }
    }

    $results
}