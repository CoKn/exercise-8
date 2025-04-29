// acting agent

// The agent has a belief about the location of the W3C Web of Thing (WoT) Thing Description (TD)
// that describes a Thing of type https://ci.mines-stetienne.fr/kg/ontology#PhantomX
robot_td("https://raw.githubusercontent.com/Interactions-HSG/example-tds/main/tds/leubot1.ttl").

/* Initial beliefs and rules */
// No initial beliefs about the organization - the agent will discover them

// Define a rule to determine if a role is relevant for the agent
// A role is relevant if it is associated with a mission that contains goals the agent can achieve
relevant_role(Role, Group) :-
    role_mission(Role, Scheme, Mission) &    // Role is associated with a Mission in a Scheme
    mission_goal(Mission, Goal) &            // Mission contains a Goal
    can_achieve(Goal).                       // Agent has a plan for achieving the Goal

// Define a rule to determine if the agent can achieve a goal
can_achieve(manifest_temperature).           // The acting agent can achieve the manifest_temperature goal

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
    .print("Starting acting agent...");
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
 * Plan for reacting to the addition of the goal !manifest_temperature
 * Triggering event: addition of goal !manifest_temperature
 * Context: the agent believes that there is a temperature in Celsius and
 * that a WoT TD of an onto:PhantomX is located at Location
 * Body: converts the temperature from Celsius to binary degrees that are compatible with the 
 * movement of the robotic arm. Then, manifests the temperature with the robotic arm
*/
// Plan to handle the temperature belief received from the sensing agent
+temperature(Celsius) <- 
    .print("Received temperature reading: ", Celsius).

// Plan to handle organizational events
+obligation(Ag, Norm, Goal, Deadline) : .my_name(Ag) <-
	.print("I received an obligation: ", Goal);
	.print("Norm: ", Norm);
	.print("Deadline: ", Deadline).

@manifest_temperature_plan 
+!manifest_temperature : temperature(Celsius) & robot_td(Location) <-
	.print("I will manifest the temperature: ", Celsius);
	makeArtifact("converter", "tools.Converter", [], ConverterId); // creates a converter artifact
	convert(Celsius, -20.00, 20.00, 200.00, 830.00, Degrees)[artifact_id(ConverterId)]; // converts Celsius to binary degress based on the input scale
	.print("Temperature Manifesting (moving robotic arm to): ", Degrees);

	/* 
	 * If you want to test with the real robotic arm, 
	 * follow the instructions here: https://github.com/HSG-WAS-FS25/exercise-8/blob/main/README.md#test-with-the-real-phantomx-reactor-robot-arm
	 */
	// creates a ThingArtifact based on the TD of the robotic arm
	makeArtifact("leubot1", "org.hyperagents.jacamo.artifacts.wot.ThingArtifact", [Location, true], Leubot1Id); 
	
	// sets the API key for controlling the robotic arm as an authenticated user
	//setAPIKey("77d7a2250abbdb59c6f6324bf1dcddb5")[artifact_id(Leubot1Id)];

	// invokes the action onto:SetWristAngle for manifesting the temperature with the wrist of the robotic arm
	invokeAction("https://ci.mines-stetienne.fr/kg/ontology#SetWristAngle", ["https://www.w3.org/2019/wot/json-schema#IntegerSchema"], [Degrees])[artifact_id(Leubot1Id)].

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }

/* Import behavior of agents that work in MOISE organizations */
{ include("$jacamoJar/templates/common-moise.asl") }

/* Import behavior of agents that reason on MOISE organizations */
{ include("$moiseJar/asl/org-rules.asl") }

/* Import behavior of agents that react to organizational events
(if observing, i.e. being focused on the appropriate organization artifacts) */
{ include("inc/skills.asl") }
