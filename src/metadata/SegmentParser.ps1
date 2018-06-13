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

. (import-script ..\GraphContext)
. (import-script GraphSegment)
. (import-script UriCache)

ScriptClass SegmentParser {
    $graph = $null
    $context = $null
    $uriCache = $null
    $cacheEntities = $false

    function __initialize($graphContext, $existingGraph = $null, $cacheEntities = $false) {
        $this.graph = if ( $existingGraph ) {
            $existingGraph
        } else {
            $this.context = $graphContext
            $this.UriCache = $graphContext.uriCache
            $graph = $graphContext |=> GetGraph
            $graph
        }

        $this.cacheEntities = $cacheEntities
    }

    function GetChildren($segment, $allowedTransitions = $null ) {
        if ( ! $segment ) {
            throw "Segment may not be null"
        }

        $results = if ( $segment.graphElement.PSTypename -eq 'EntityVertex' -and ($segment.graphElement |=> IsRoot) ) {
            $childVertices = $this.graph |=> GetRootVertices
            $childVertices.values | foreach {
                new-so GraphSegment $_
            }
        } else {
            $segment |=> NewNextSegments $this.graph $null $allowedTransitions
        }

        if ( $this.uriCache ) {
            $this.uriCache |=> AddUriForSegments $results $this.cacheEntities
        }

        $results
    }

    function SegmentsFromUri([Uri] $uri) {
        $unescapedPath = [Uri]::UnescapeDataString($uri.tostring()).trim()

        $noRoot = if ( $unescapedPath[0] -eq '/' ) {
            $unescapedPath.trim('/')
        } else {
            if ($unescapedPath.length -gt 0) {
                $unescapedPath.trim('/')
            } else {
                $unescapedPath
            }
        }

        $segmentStrings = $noRoot -split '/'

        if ( $segmentStrings[0] -eq '' ) {
            $segmentStrings = @()
        }

        $segments = @(new-so GraphSegment $::.EntityVertex.RootVertex $null $null)
        $lastSegment = $segments[0]

        $segmentStrings | foreach {
            $targetSegmentName = $_
            $cachedSegment = if ($this.UriCache) {
                $this.uriCache |=> GetSegmentFromParent $lastSegment $targetSegmentName
            }

            $currentSegments = if ( $cachedSegment ) {
                $cachedSegment
            } else {
                GetChildren $lastSegment
            }

            if ( ! $currentSegments -and ($currentSegments -isnot [object[]]) ) {
                throw "No children found for '$($lastSegment.name)'"
            }

            $matchingSegment = $null
            if ( $currentSegments -isnot [object[]] -and ! $cachedSegment ) {
                $matchingSegment = new-so GraphSegment $currentSegments[0].graphElement $lastSegment $targetSegmentName
            } else {
                $matchingSegment = $currentSegments | where {
                    $_.name -eq $targetSegmentName
                }

                if ( ! $matchingSegment ) {
                    $parentName = if ( $lastSegment ) {
                        $lastSegment.name
                    } else {
                        '<root>'
                    }
                    throw "No matching child segment '$targetSegmentName' under segment '$parentName'"
                }
            }
            $lastSegment = $matchingSegment

            $segments += $lastSegment

            if ( $this.uriCache ) {
                $this.uriCache |=> AddUriForSegments $segments $this.cacheentities
            }
        }

        $segments
    }
}
