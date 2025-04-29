// sensing agent

/* Initial beliefs and rules */
// No initial beliefs about the organization - the agent will discover them

// Define a rule to determine if a role is relevant for the agent
// A role is relevant if it is associated with a mission that contains goals the agent can achieve
relevant_role(Role, Group) :-
    role_mission(Role, Scheme, Mission) &    // Role is associated with a Mission in a Scheme
    mission_goal(Mission, Goal) &            // Mission contains a Goal
    can_achieve(Goal).                       // Agent has a plan for achieving the Goal

// Define a rule to determine if the agent can achieve a goal
can_achieve(read_temperature).               // The sensing agent can achieve the read_temperature goal

/* Initial goals */
!start. // the agent has the goal to start

/* 
 * Plan for reacting to the addition of the goal !start
 * Triggering event: addition of goal !start
 * Context: true (always applicable)
 * Body: waits for organization workspace notifications
*/
@start_plan
+!start : true <-
    .print("Starting sensing agent...");
    .print("Waiting for organization workspace notifications...").

/* 
 * Plan for reacting to the addition of the belief org_workspace_available
 * Triggering event: addition of belief org_workspace_available(OrgName, Description)
 * Context: true (always applicable)
 * Body: joins the organization workspace and reasons about the organization
*/
@org_workspace_available_plan
+org_workspace_available(OrgName, Description) : true <-
    .print("Received notification about organization workspace: ", OrgName, " (", Description, ")");
    
    // Join the organization workspace
    .print("Joining workspace ", OrgName);
    joinWorkspace(OrgName, OrgWsp);
    
    // Look up and focus on the organization artifact
    lookupArtifact(OrgName, OrgArtId);
    focus(OrgArtId);
    
    // Wait a bit for the agent to perceive the organization specification
    .wait(500);
    
    // Reason about the organization and adopt relevant roles
    !reason_and_adopt_roles(OrgName).

/* 
 * Plan for reasoning about the organization and adopting relevant roles
 * Triggering event: addition of goal !reason_and_adopt_roles(OrgName)
 * Context: true (always applicable)
 * Body: reasons about the organization and adopts relevant roles
*/
@reason_and_adopt_roles_plan
+!reason_and_adopt_roles(OrgName) : true <-
    .print("Reasoning about organization ", OrgName, " to find relevant roles...");
    
    // Find all groups in the organization
    .findall(Group, group(Group, _, _), Groups);
    .print("Available groups: ", Groups);
    
    // For each group, find and adopt relevant roles
    for (.member(Group, Groups)) {
        // Look up and focus on the group artifact
        lookupArtifact(Group, GroupArtId);
        focus(GroupArtId);
        
        // Find all roles in the group
        .findall(Role, role(Role, _), Roles);
        .print("Available roles in group ", Group, ": ", Roles);
        
        // For each role, check if it's relevant for the agent
        for (.member(Role, Roles)) {
            if (relevant_role(Role, Group)) {
                .print("Role ", Role, " is relevant for me because I can achieve its goals");
                adoptRole(Role)[artifact_id(GroupArtId)];
                .print("I have adopted the role of ", Role, " in group ", Group);
            } else {
                .print("Role ", Role, " is not relevant for me");
            }
        }
    }
    
    // Look up and focus on all scheme artifacts
    .findall(Scheme, scheme(Scheme, _, _), Schemes);
    .print("Available schemes: ", Schemes);
    
    for (.member(Scheme, Schemes)) {
        lookupArtifact(Scheme, SchemeArtId);
        focus(SchemeArtId);
    }.

/* 
 * Plan for reacting to the addition of the goal !read_temperature
 * Triggering event: addition of goal !read_temperature
 * Context: true (the plan is always applicable)
 * Body: reads the temperature using a weather station artifact and broadcasts the reading
*/
@read_temperature_plan
+!read_temperature : true <-
	.print("I will read the temperature");
	makeArtifact("weatherStation", "tools.WeatherStation", [], WeatherStationId); // creates a weather station artifact
	focus(WeatherStationId); // focuses on the weather station artifact
	readCurrentTemperature(47.42, 9.37, Celcius); // reads the current temperature using the artifact
	.print("Temperature Reading (Celcius): ", Celcius);
	.broadcast(tell, temperature(Celcius)). // broadcasts the temperature reading

// Plan to handle organizational events
+obligation(Ag, Norm, Goal, Deadline) : .my_name(Ag) <-
	.print("I received an obligation: ", Goal);
	.print("Norm: ", Norm);
	.print("Deadline: ", Deadline).

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }

/* Import behavior of agents that work in MOISE organizations */
{ include("$jacamoJar/templates/common-moise.asl") }

/* Import behavior of agents that reason on MOISE organizations */
{ include("$moiseJar/asl/org-rules.asl") }

/* Import behavior of agents that react to organizational events
(if observing, i.e. being focused on the appropriate organization artifacts) */
{ include("inc/skills.asl") }