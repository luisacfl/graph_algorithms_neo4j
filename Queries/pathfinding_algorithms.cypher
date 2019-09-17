//Creating Nodes
LOAD CSV WITH HEADERS FROM "file:///transport-nodes.csv" as row
MERGE (place:Place {id:row.id})
SET place.latitude = toFloat(row.latitude), place.longitude = toFloat(row.latitude), place.population = toInteger(row.population)

//Creating Relationships
LOAD CSV WITH HEADERS FROM "file:///transport-relationships.csv" as row
MATCH (origin:Place {id: row.src})
MATCH (destination:Place {id: row.dst})
MERGE (origin)-[:EROAD {distance: toInteger(row.cost)}]->(destination)

//-------------------------Shortest Path-------------------------
//Used to determine the least amount of hops between two nodes.
//No weight, assumes 1.0 as default weight

//input: Source and destination node, name of property that contains distance.
//ouput: Nodes that were visited and their default weight: 1.
//example: Finding the number of social connections between two people.

MATCH (source:Place {id: "Amsterdam"}), (destination:Place {id: "London"})
CALL algo.shortestPath.stream(source, destination, null) YIELD nodeId, cost
RETURN algo.getNodeById(nodeId).id AS place, cost

//-------Actual cost of the shortest unweighted path----------------
//Used as an excersice to understand the least amount of hops is not 
//always the cheapest path in terms of weight.

//input: Source and destination node, name of property that contains distance.
//ouput: Nodes that were visited and their actual weight.
//example: Could be used when looking for the safest path, rather than the
//shortest, still need to know the actual weight between nodes.

MATCH (source:Place {id: "Amsterdam"}), (destination:Place {id: "London"})
    CALL algo.shortestPath.stream(source, destination, null)
    YIELD nodeId, cost
WITH collect(algo.getNodeById(nodeId)) AS path
UNWIND range(0, size(path)-1) AS index
WITH path[index] AS current, path[index+1] AS next
WITH current, next, [(current)-[r:EROAD]-(next) | r.distance][0] AS distance
WITH collect({current: current, next:next, distance: distance}) AS stops UNWIND range(0, size(stops)-1) AS index
WITH stops[index] AS location, stops, index
RETURN location.current.id AS place,
reduce(acc=0.0,
distance in [stop in stops[0..index] | stop.distance] | acc + distance) AS cost

//---------------------Shortest Weighted Path---------------------
//The shortest path considering the relationship weight
//input: Source and destination node, name of property that contains distance.
//output: Nodes that were visited and their weight.
//example: Used when trying to find the shortest path between two places.

MATCH (source:Place {id: "Amsterdam"}), (destination:Place {id: "London"})
CALL algo.shortestPath.stream(source, destination, "distance") YIELD nodeId, cost
RETURN algo.getNodeById(nodeId).id AS place, cost

//---A* Algorithm---
//Variation of Shortest Weighted path. Finds shortest path faster than 
//conventional algorithm by including extra information. 
//Determines which of its partial paths to expand based on an estimate of the cost left.
//input: Source and destination node, name of property that contains distance, latitude, longitude
//output: Nodes that were visited and their weight.
//example: Used when trying to find the shortest path between two places.

MATCH (source:Place {id: "Den Haag"}), (destination:Place {id: "London"})
    CALL algo.shortestPath.astar.stream(source,
              destination, "distance", "latitude", "longitude")
YIELD nodeId, cost
RETURN algo.getNodeById(nodeId).id AS place, cost

//----K-shortests paths----
//The shortests path considering the relationship weight. 
//input: Source and destination node, number of shortest paths to find, name of property that contains distance.
//output: Nodes that were visited on each path and their total cost.
//example: Used when trying to find alternatives when driving from one place to another.
MATCH (start:Place {id:"Gouda"}), (end:Place {id:"Felixstowe"})
CALL algo.kShortestPaths.stream(start, end, 5, "distance") YIELD index, nodeIds, path, costs
RETURN index,
[node in algo.getNodesById(nodeIds[1..-1]) | node.id] AS via, reduce(acc=0.0, cost in costs | acc + cost) AS totalCost

//----------------------All pairs shortest path----------------------
//Calculates the shortest path between all nodes. 
//It is optimized by keeping track of of the distances calculated and running on nodes in parallel
//input: Source and destination node, name of property that contains distance.
//output: List of all nodes with the cost to get to all other nodes.
//example: Making an analysis of network efficency.

CALL algo.allShortestPaths.stream(null)
YIELD sourceNodeId, targetNodeId, distance
WHERE sourceNodeId < targetNodeId
RETURN algo.getNodeById(sourceNodeId).id AS source,
algo.getNodeById(targetNodeId).id AS target,
distance
ORDER BY distance DESC
LIMIT 10

//---------------------single source shortest path--------------------
//Calculates the shortest path from a source node to every other node. 
//input: Source node, name of property that contains distance.
//output: List of all nodes with the cost to get to it from our source node.
//example: Could be used for an ambulance when needing emergency routes. 
MATCH (n:Place {id:"London"})
CALL algo.shortestPath.deltaStepping.stream(n, "distance", 1.0) YIELD nodeId, distance
WHERE algo.isFinite(distance)
RETURN algo.getNodeById(nodeId).id AS destination, distance ORDER BY distance

//---------------------Minimum Spanning Tree---------------------
//Calculates the shortest path from a source node to every other node. 
//input: Source node, name of property that contains distance.
//output: List of all nodes with the cost to get to it from our source node.
//example: Could be used when having to visit all the nodes.
//difference with single source shortest path: this one traverses the next unvisited node
//with the lowest weight avoiding cycles.
MATCH (n:Place {id:"London"})
CALL algo.shortestPath.deltaStepping.stream(n, "distance", 1.0) YIELD nodeId, distance
WHERE algo.isFinite(distance)
RETURN algo.getNodeById(nodeId).id AS destination, distance ORDER BY distance

//---------------------Random walk---------------------
//Observe network behavior that is not controlled
//input: name of property containing sources, number of hops random walk should take, number of random walks to compute
//ouput: list of places it took.
//example: evaluating the average cost of a walk in a touristic place.
MATCH (source:Place {id: "London"})
CALL algo.randomWalk.stream(id(source), 5, 1) YIELD nodeIds
UNWIND algo.getNodesById(nodeIds) AS place RETURN place.id AS place