//Creating Nodes
LOAD CSV WITH HEADERS FROM "file:///transport-nodes.csv" as row
MERGE (place:Place {id:row.id})
SET place.latitude = toFloat(row.latitude), place.longitude = toFloat(row.latitude), place.population = toInteger(row.population)

//Creating Relationships
LOAD CSV WITH HEADERS FROM "file:///transport-relationships.csv" as row
MATCH (origin:Place {id: row.src})
MATCH (destination:Place {id: row.dst})
MERGE (origin)-[:EROAD {distance: toInteger(row.cost)}]->(destination)

//Shortest Path
//No weight, assumes 1.0 as default weight
MATCH (source:Place {id: "Amsterdam"}), (destination:Place {id: "London"})
CALL algo.shortestPath.stream(source, destination, null) YIELD nodeId, cost
RETURN algo.getNodeById(nodeId).id AS place, cost


MATCH (s:Place{id:'Amsterdam'}), (e:Place{id:'Gouda'})
CALL algo.shortestPath.stream(s, e, 'cost')
YIELD id, cost
RETURN algo.asNode(id) AS name, cost