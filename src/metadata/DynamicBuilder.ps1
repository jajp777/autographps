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

. (import-script GraphBuilder)

ScriptClass DynamicBuilder {
    $builder = $null
    $graph = $null

    function __initialize($graph, $graphEndpoint, $version, $metadata) {
        $this.graph = $graph
        $this.builder = new-so GraphBuilder $graphEndpoint $version $metadata
    }

    function GetTypeVertex($qualifiedTypeName, $parent, $includeSinks) {
        $vertex = $this.graph |=> TypeVertexFromTypeName $qualifiedTypeName

        if ( ! $vertex ) {
            __AddTypeVertex $qualifiedTypeName
            $vertex = $this.graph |=> TypeVertexFromTypeName $qualifiedTypeName
        }

        if ( ! $vertex ) {
            throw "Vertex '$qualifiedTypeName' not found"
        }

        UpdateVertex $vertex $parent $includeSinks

        $vertex
    }

    function UpdateVertex($vertex, $parent, $includeSinks) {
        write-host "Called updatevertex for '$($vertex.name)'"

        if ( ! (__IsVertexReady $vertex) ) {
            switch ( $vertex.entity.type ) {
                'Singleton' {
                    write-host "Singleton", $vertex.name, $vertex.entity.typedata.entitytypename
                    $vertex.buildstate.navigationsadded = $true
                    __AddTypeForVertex($vertex)

                    if ( ! $vertex.buildState.SingletonEntityTypeDataAdded ) {
                        __CopyTypeDataToSingleton $vertex
                    }
                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                'EntityType' {
                    $name = $vertex.entity.typedata.entitytypename
                    $unqualifiedName = $name.substring($this.graph.namespace.length + 1, $name.length - $this.graph.namespace.length - 1)
                    if ( ! $vertex.buildstate.navigationsAdded ) {
                        __AddTypeEdges $unqualifiedName
                        $vertex.buildState.NavigationsAdded = $true
                    }

                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                'EntitySet' {
                    write-host "EntitySet", $vertex.name, $vertex.entity.typedata.entitytypename
                    $vertex.buildstate.navigationsadded = $true
                    __AddTypeForVertex($vertex)

                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                'Action' {
                    __AddTypeForVertex($vertex)
                    $vertex.buildState.NavigationsAdded = $true
                    $vertex.buildState.SingletonEntityTypeDataAdded = $true

                }
                '__Scalar' {
                    __AddTypeForVertex($vertex)
                    $vertex.buildState.NavigationsAdded = $true
                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                '__Root' {
                    __AddTypeForVertex($vertex)
                    $vertex.buildState.NavigationsAdded = $true
                    $vertex.buildState.SingletonEntityTypeDataAdded = $true
                }
                default {
                    throw "Unknown entity type $($vertex.entity.type) for entity name $($vertex.entity.name)"
                }
            }
            $vertex.buildState.SingletonEntityTypeDataAdded = $true
 #            $vertex.buildState.MethodEdgesAdded = $true
        }

#        $vertex.buildState.SingletonEntityTypeDataAdded = $true
 #       $vertex.buildState.NavigationsAdded = $true
#        $vertex.buildState.MethodEdgesAdded = $true
    }


    function __AddTypeForVertex($vertex) {
        $name = $vertex.entity.typedata.entitytypename
        $unqualifiedName = $name.substring($this.graph.namespace.length + 1, $name.length - $this.graph.namespace.length - 1)

        $typeVertex = $this.graph |=> TypeVertexFromTypeName $name

        if (! $typeVertex ) {
            __AddTypeVertex $vertex.entity.typedata.entitytypename
            $typeVertex = $this.graph |=> TypeVertexFromTypeName $name
        }

        $typeName = $typeVertex.entity.typedata.entitytypename
        $unqualifiedTypeName = $typeName.substring($this.graph.namespace.length + 1, $typeName.length - $this.graph.namespace.length - 1)
        if ( ! $typeVertex.buildState.NavigationsAdded ) {
            __AddTypeEdges $unqualifiedTypeName
            $typeVertex.buildState.SingletonEntityTypeDataAdded = $true
            $typeVertex.buildState.NavigationsAdded = $true
        }
    }

    function __AddTypeVertex($name) {
        write-host "AddTypeVertex '$name'"
        $unqualifiedName = $name.substring($this.graph.namespace.length + 1, $name.length - $this.graph.namespace.length - 1)
        write-host $unqualifiedName

        $this.builder |=> __AddEntityTypeVertices $this.graph $unqualifiedName

        __AddTypeEdges $unqualifiedName

        $typeVertex = $this.graph |=> TypeVertexFromTypeName $name
        $typeVertex.buildstate.NavigationsAdded = $true
    }

    function __AddTypeEdges($unqualifiedTypeName) {
        write-host "AddEdges '$unqualifiedTypeName'"
        $this.builder |=>  __AddEdgesToEntityTypeVertices $this.graph $unqualifiedTypeName
    }

    function __CopyTypeDataToSingleton($singletonVertex) {
        write-host "CopyTypeToSingleton '$($singletonVertex.name)'"
        $this.builder |=> __CopyEntityTypeEdgesToSingletons $this.graph $singletonVertex.name
    }

    function __IsVertexReady($vertex) {
        $vertex.buildState.SingletonEntityTypeDataAdded -and
        $vertex.buildState.NavigationsAdded
    }
}
