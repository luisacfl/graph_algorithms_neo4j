//----------Centrality Algorithms----------
//Understand roles of the nodes in the graph and their impact
//Centrality is a ranking of the potential impact of nodes, not a measure of actual impact.

//--- Concepts ---
//Degree: Number of connections a node has
//Average Degree: the total number of relationships divided by the total number of nodes
//Degree distribution: the probability that a randomly selected node will have a certain number of relationships
//Betweenness: How much control between nodes and groups (connects two separate big groups)
//Closeness: How close a node is to other nodes (easily reach other nodes)
//PageRank: Importance of node, based on number and weight of links
//pivotal: A  node is considered pivotal for two other nodes if it lies on every shortest path between those nodes.

//Creating Nodes
LOAD CSV WITH HEADERS FROM "file:///social-nodes.csv" as row
MERGE (:User {id: row.id})

//Creating Relationships
LOAD CSV WITH HEADERS FROM "file:///social-relationships.csv" as row
MATCH (source:User {id: row.src})
MATCH (destination:User {id: row.dst}) 
MERGE (source)-[:FOLLOWS]->(destination)

//----------Degree Centrality----------
//Connectedness
//Counts in-going and out-going relationships from each node
//quick measure to help estimate the potential for things to spread or ripple throughout the network
//input: name of nodes
//output: Table with user and its out-going and in-going relationships
//example:  how popular someone is in social media
MATCH (u:User)
RETURN u.id AS name,
size((u)-[:FOLLOWS]->()) AS follows,
size((u)<-[:FOLLOWS]-()) AS followers

//----------Closeness Centrality----------
//Calculates which nodes have the shortest paths to all other nodes.
//A way to detect nodes that are able to spread information efficiently thorough a subgraph

//Algorithm:
//Calculates the sum of its distances to all other nodes, (shortest path algorithm).
//Then, the sum is inverted to determine the closeness centrality score for that node.
//it is common to normalize the score to compare to nodes of other graphs of different sizes.

//input: the column that has the name of the nodes and the name of the relationship
//output: The closeness to others within their subgraph, but not the entire graph
//example:  Which cities are closest to all other cities and thus predict infection spread

//we only get the closeness to others within their subgraph but not the entire graph
//b/c not all nodes are connected
CALL algo.closeness.stream("User", "FOLLOWS") YIELD nodeId, centrality
RETURN algo.getNodeById(nodeId).id, centrality ORDER BY centrality DESC

//-----Variation: Wasserman and Faust-----
//Calculates closeness for graphs with multiple subgraphs without connections between those groups
//A ratio of the fraction of nodes in the group that are reachable to the avg. distance from the reachable nodes

//input: the column that has the name of the nodes and the name of the relationship
//output: The closeness to others in relation with the entire graph

CALL algo.closeness.stream("User", "FOLLOWS", {improved: true}) YIELD nodeId, centrality
RETURN algo.getNodeById(nodeId).id AS user, centrality
ORDER BY centrality DESC

//-----Variation: Harmonic Centrality-----
//Calculates the closeness score for each node
//it sums the inverse of the distances of a node to all other nodes.
//Making infinite values irrelevant.
//input: the column that has the name of the nodes and the name of the relationship
//output: The closeness to others in relation with the entire graph. Similar to the Wasserman and Faust.

CALL algo.closeness.harmonic.stream("User", "FOLLOWS") YIELD nodeId, centrality
RETURN algo.getNodeById(nodeId).id AS user, centrality ORDER BY centrality DESC

//----------Betweenness Centrality----------
//Finding control points, measures the number of shortest paths that pass through a node
//Detecting the amount of influence a node has over the flow of information or resources in a graph
//Used to find nodes that serve as a bridge from one part of a graph to another

//Algorithm:
//Calculates the shortest path between every pair of nodes in a connected graph.
//each node receives a score depending on the number of shortest paths that pass through the node.

//input:the column that has the name of the nodes and the name of the relationship
//output: Betweeness Centrality score for each node
//example: Recognizing vulnerabilities in a network. Finding influencers in an organization/social media.

CALL algo.betweenness.stream("User", "FOLLOWS")
YIELD nodeId, centrality
RETURN algo.getNodeById(nodeId).id AS user, centrality ORDER BY centrality DESC

//-----Variation: Randomized-Approximate Brandes-----
//Calculating betweenness centrality can be very expensive.
//this variation approximates score for betweenness centrality faster than the original algorithm.

//---Strategies---
//****Random: Nodes selected randomly with a defined probability of selection

CALL algo.betweenness.sampled.stream("User", "FOLLOWS", {strategy:"random"}) YIELD nodeId, centrality
RETURN algo.getNodeById(nodeId).id AS user, centrality
ORDER BY centrality DESC

//Degree: Nodes are selected randomly, but those whose degree is lower than the mean are automatically excluded
CALL algo.betweenness.sampled.stream("User", "FOLLOWS", {strategy:"degree"}) YIELD nodeId, centrality
RETURN algo.getNodeById(nodeId).id AS user, centrality
ORDER BY centrality DESC

//----------PageRank----------
//Overall influence of a node. Estimates a node's importance from its linked neighbors and their neighbors
//Measures the transitive (or directional) influence of nodes
//Considers the influence of a node's neighbors and their neighbors
//ex: having a few powerful friends can make you more influential than having a lot of less powerful friends.

//Algorithm:
//Computed either by iteratively distributing one node’s rank over its neighbors
//OR by randomly traversing the graph and counting the frequency with which each node is hit during these walks.
//runs either until scores converge or until a set number of iterations is reached

//input:the column that has the name of the nodes and the name of the relationship, number of iterations and dampingFactor
//output: PageRank score per node
//example: Presenting users with recommendations of other accounts that they may wish to follow

//Fixed number of iterations approach:
CALL algo.pageRank.stream('User', 'FOLLOWS', {iterations:20, dampingFactor:0.85}) YIELD nodeId, score
RETURN algo.getNodeById(nodeId).id AS page, score
ORDER BY score DESC

//-----Variation: Personalized PageRank-----
//Calculates the importance of nodes in a graph from the perspective of a specific node.

MATCH (k:Keyword)-[:DESCRIBES]->()<-[:HAS_ANNOTATED_TEXT]-(a:Article)
WHERE k.value = "social networks"
WITH collect(a) as articles
CALL algo.pageRank.stream('User', 'FOLLOWS', {sourceNodes: articles})
YIELD nodeId, score
WITH nodeId,score order by score desc limit 10
MATCH (n) where id(n) = nodeId
RETURN n.title as article, score

