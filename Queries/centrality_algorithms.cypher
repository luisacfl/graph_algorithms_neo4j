//----------Centrality Algorithms----------
//Understand roles of the nodes in the graph and their impact

//--- Concepts ---
//Degree: Number of connections a node has
//Betweenness: How much control between nodes and groups (connects two separate big groups)
//Closeness: How close a node is to other nodes (easily reach other nodes)
//PageRank: Importance of node, based on number and weight of links

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
//input: name of nodes
//output: Table with user and its out-going and in-going relationships
//example:  how popular someone is in social media
MATCH (u:User)
RETURN u.id AS name,
size((u)-[:FOLLOWS]->()) AS follows,
size((u)<-[:FOLLOWS]-()) AS followers

//----------Closeness Centrality----------
//How central a node is to a group, variations for disconnected groups
//input:
//output:
//example:  

//----------Betweenness Centrality----------
//Finding control points

//----------PageRank----------
//Overall influence