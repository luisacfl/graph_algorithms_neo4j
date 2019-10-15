//----------Community Detection Algorithms----------
//group behaivor and emergent phenomena
//general principle in finding communities: members will have more relationships withing the group
//than with nodes outside the group

//import data
sw-relationships.csv
sw-nodes.csv

//Creating Nodes
LOAD CSV WITH HEADERS FROM "file:///sw-nodes.csv" as row
MERGE (:library {id: row.id})

//Creating Relationships
LOAD CSV WITH HEADERS FROM "file:///sw-relationships.csv" as row
MATCH (source:Library {id: row.src})
MATCH (destination:Library {id: row.dst}) 
MERGE (source)-[:DEPENDS_ON]->(destination)

//----------Triangle Count and Clustering Coefficient Algorithms----------
//presented together because they are often used together
//---Triangle Count: The number of triangles that pass through a node.
//triangle: set of three nodes where each node has a relationship to all other nodes.
    //a triangle indicates that two of a node's neighbors are also connected
//Networks with a high number of triangles are more likely to exhibit small-world structures and behaviors.
//When you need to determine the stability of a group or as a part of calculating other network measures 
//input: call from the function from the graph
//output: all nodes that have more than 0 triangles
//Example: Calcular la probabilidad de que dos usuarios sean amigos en una red social

result = g.triangleCount()
(result.sort("count", ascending=False).filter('count > 0').show())

//getting a stream of the triangles 
//input: The node label to load from the graph, the relationship type to load from the graph
CALL algo.triangle.stream("Library","DEPENDS_ON") YIELD nodeA, nodeB, nodeC
RETURN algo.getNodeById(nodeA).id AS nodeA,
algo.getNodeById(nodeB).id AS nodeB, algo.getNodeById(nodeC).id AS nodeC

//---Clustering Coefficient: Probability that the neighbors of a node are connected to each other
//Goal: measure how tightly a group is clustered compared to how tightly it could be clustered.
//Gives us an effective means to find obvious groups like cliques.
//Uses triangle count in its calculations, provides ratio of existing triangles to possible relationships.

//-------Local Clustering Coefficient 
//Likelihood that its neighbors are also connected
//Algorithm: multiply the number of triangles passing through the node by two
//          dividing that by the max number of relationships in the group (degree), minus one.
//input: The node label to load from the graph, the relationship type to load from the graph
//output: nodes and their coefficients as long as the coefficient is greater than 0

CALL algo.triangleCount.stream('Library', 'DEPENDS_ON') YIELD nodeId, triangles, coefficient
WHERE coefficient > 0
RETURN algo.getNodeById(nodeId).id AS library, coefficient ORDER BY coefficient DESC

//-------Global Clustering Coefficient 
//Normalized sum of local clustering coefficients.
//Effective menas to find obvious groups like cliques

//-----Strongly Connected Components and Connected Components for finding connected clusters-----

//--Strongly Connected Components: all nodes can reach all other nodes in both relationships
//Finds groups where each node is reachable from every other node in that same group following the direction of relationships

//input: The node label to load from the graph, the relationship type to load from the graph
//output:id of each partition and the libraries that belong to it
//example: to find users with the same interests (twitter)

CALL algo.scc.stream("Library", "DEPENDS_ON")
YIELD nodeId, partition
RETURN partition, collect(algo.getNodeById(nodeId)) AS libraries ORDER BY size(libraries) DESC

//Add circular dependency to illustrate nodes in the same partition
MATCH (py4j:Library {id: "py4j"}) 
MATCH (pyspark:Library {id: "pyspark"}) 
MERGE (extra:Library {id: "extra"}) 
MERGE (py4j)-[:DEPENDS_ON]->(extra) 
MERGE (extra)-[:DEPENDS_ON]->(pyspark)

MATCH (extra:Library {id: "extra"}) 
DETACH DELETE extra

//--Connected Components: all nodes can reach all other nodes, regardless of direction
//Finds groups where each node is reachable from every other node in that same group, regardless of the direction of relationships
//input: The node label to load from the graph and The relationship type to load from the graph
//output: id of each set and the libraries that belong to that set
//example: analyzing citation networks 

CALL algo.unionFind.stream("Library", "DEPENDS_ON")
YIELD nodeId,setId
RETURN setId, collect(algo.getNodeById(nodeId)) AS libraries ORDER BY size(libraries) DESC

//-----Label Propagation for quickly inferring groups based on node labels-----
//Spread labels to or from neighbors to find clusters.
//Run over multiple iterations
//Infers clusters by spreading labels based on neighborhood majorities
//Used for finding communities in a graph

//PUSH method: Nodes are given seed labels. 
             //They look for immediate neighbors as targets to spread
             //If no conflict, the label spreads
             //the places where it spreads become new seeds
//PULL method: Pulls labels from neighbors based on relationship weights to find clusters.
        //each node is initalized witha  unique label
        //labels propagate through the network
        //nodes are shuffled for processing order and each node considers its direct neighbors' labels 
        //Nodes acquire the label matching the total highest relationship weights.
        //this continues until all nodes have updated their labels.

//input: The node label to load from the graph and The relationship type to load from the graph
//output: id of each set and the libraries that belong to that set
//example: finding not so obvious communities.
CALL algo.labelPropagation.stream("Library", "DEPENDS_ON",
      { iterations: 10 })
YIELD nodeId, label RETURN label,
collect(algo.getNodeById(nodeId).id) AS libraries

//for undirected graphs
CALL algo.labelPropagation.stream("Library", "DEPENDS_ON",{ 
    iterations: 10, 
    direction: "BOTH" }).
YIELD nodeId, label RETURN label,
collect(algo.getNodeById(nodeId).id) AS libraries ORDER BY size(libraries) DESC
//example: understanding consensus in social communities

//-----Louvain Modularity for looking at grouping quality and hierarchies
//used to find communities in vast networks. Heurisitic.
//example: uncovering different levels of hierarchy as in a criminal organizaction
    //find subcommunities within subcommunities 
    //extracting topics from online social platforms
    //“Topic Modeling Based on Louvain Method in Online Social Networks”.
    //“Hierarchical Modularity in Human Brain Functional Networks”
//Find clusters by moving nodes into higher relationship density groups and aggregating into supercommunities.
//Maximizes the presumed accuracy of groupings by comparing relationship weights and densities to a de ned estimate or average
//Problems: the algorithms can overlook small communities within large networks.

//input: The node label to load from the graph and The relationship type to load from the graph
//output: the nodes and the communities a node falls into at two levels.
CALL algo.louvain.stream("Library", "DEPENDS_ON")
YIELD nodeId, communities
RETURN algo.getNodeById(nodeId).id AS libraries, communities

//store the resulting communities using the streaming version of the algorithm
CALL algo.louvain.stream("Library", "DEPENDS_ON") YIELD nodeId, communities
WITH algo.getNodeById(nodeId) AS node, communities SET node.communities = communities

//find the final clusters.
MATCH (l:Library)
RETURN l.communities[-1] AS community, collect(l.id) AS libraries 
ORDER BY size(libraries) DESC

//intermediate clustering
MATCH (l:Library)
RETURN l.communities[0] AS community, collect(l.id) AS libraries 
ORDER BY size(libraries) DESC