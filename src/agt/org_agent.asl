// organization agent

/* Initial beliefs and rules */
org_name("lab_monitoring_org"). // the agent beliefs that it can manage organizations with the id "lab_monitoting_org"
group_name("monitoring_team"). // the agent beliefs that it can manage groups with the id "monitoring_team"
sch_name("monitoring_scheme"). // the agent beliefs that it can manage schemes with the id "monitoring_scheme"

// Rule to check if a group is responsible for a scheme
responsible(Group, Scheme) :-
    responsible_groups(Scheme, Groups) &
    .member(Group, Groups).

// Rule to check if a scheme is enabled
enabled(Scheme) :-
    state(Scheme, "enabled").

/* Initial goals */
!start. // the agent has the goal to start

/* 
 * Plan for reacting to the addition of the goal !start
 * Triggering event: addition of goal !start
 * Context: the agent believes that it can manage a group and a scheme in an organization
 * Body: initializes the organization and its artifacts
*/
@start_plan
+!start : org_name(OrgName) & group_name(GroupName) & sch_name(SchemeName) <-
  .print("Initializing organization ", OrgName);
  
  // Try to join the workspace first (it might already exist)
  .print("Trying to join workspace ", OrgName);
  !try_join_workspace(OrgName, OrgWsp);
  .print("Successfully joined workspace ", OrgName);
  
  // Try to look up the OrgBoard artifact first, create it if it doesn't exist
  .print("Looking up organization artifact ", OrgName);
  !try_lookup_org_artifact(OrgName, OrgWsp, OrgArtId);
  focus(OrgArtId);
  .print("Successfully focused on organization artifact ", OrgName);
  
  // Try to look up the GroupBoard artifact, create it if it doesn't exist
  .print("Looking up group artifact ", GroupName);
  !try_lookup_group_artifact(GroupName, OrgName, OrgArtId, GroupArtId);
  focus(GroupArtId);
  .print("Successfully focused on group artifact ", GroupName);
  
  // Try to look up the SchemeBoard artifact, create it if it doesn't exist
  .print("Looking up scheme artifact ", SchemeName);
  !try_lookup_scheme_artifact(SchemeName, OrgName, OrgArtId, SchemeArtId);
  focus(SchemeArtId);
  .print("Successfully focused on scheme artifact ", SchemeName);
  
  // Task 4: Broadcast that a new organization workspace is available
  .print("Broadcasting organization workspace availability...");
  .broadcast(tell, org_workspace_available(OrgName, "lab monitoring organization"));
  
  // Launch the inspector GUI for the group board
  !inspect(GroupArtId);
  
  // Task 5: Wait until the group is well-formed
  .print("Waiting for group to become well-formed...");
  ?formationStatus(ok)[artifact_id(GroupArtId)];
  .print("Group is now well-formed!");
  
  // Check if the group is already responsible for the scheme
  .print("Checking if group is responsible for scheme...");
  if (not responsible(GroupName, SchemeName)) {
    // Make the monitoring team responsible for the monitoring scheme
    .print("Making group responsible for scheme...");
    addScheme(SchemeName)[artifact_id(GroupArtId)];
  } else {
    .print("Group is already responsible for scheme");
  }
  
  // Check if the scheme is already enabled
  .print("Checking if scheme is enabled...");
  if (not enabled(SchemeName)) {
    // Start the scheme
    .print("Starting the scheme...");
    // Use the admCommand operation to enable the scheme
    .print("Trying to enable the scheme with admCommand...");
    admCommand(enable)[artifact_id(SchemeArtId)];
  } else {
    .print("Scheme is already enabled");
  }
  
  .print("Organization ", OrgName, " has been successfully initialized!");
  
  // Print detailed information about the organization
  .print("Organization details:");
  .print("- Organization name: ", OrgName);
  .print("- Group name: ", GroupName);
  .print("- Scheme name: ", SchemeName);
  .print("- Organization artifact ID: ", OrgArtId);
  .print("- Group artifact ID: ", GroupArtId);
  .print("- Scheme artifact ID: ", SchemeArtId).

/* 
 * Plan for reacting to the addition of the test-goal ?formationStatus(ok)
 * Triggering event: addition of goal ?formationStatus(ok)
 * Context: the agent beliefs that there exists a group G whose formation status is being tested
 * Body: if the belief formationStatus(ok)[artifact_id(G)] is not already in the agents belief base
 * the agent waits until the belief is added in the belief base
*/
@test_formation_status_is_ok_plan
+?formationStatus(ok)[artifact_id(G)] : group(GroupName,_,G)[artifact_id(OrgName)] <-
  .print("Waiting for group ", GroupName," to become well-formed");
  .wait({+formationStatus(ok)[artifact_id(G)]}, 10000); // waits until the belief is added in the belief base with a timeout
  .print("Group is now well-formed!").

/* 
 * Plan for reacting to the addition of the goal !inspect(OrganizationalArtifactId)
 * Triggering event: addition of goal !inspect(OrganizationalArtifactId)
 * Context: true (the plan is always applicable)
 * Body: performs an action that launches a console for observing the organizational artifact 
 * identified by OrganizationalArtifactId
*/
@inspect_org_artifacts_plan
+!inspect(OrganizationalArtifactId) : true <-
  // performs an action that launches a console for observing the organizational artifact
  // the action is offered as an operation by the superclass OrgArt (https://moise.sourceforge.net/doc/api/ora4mas/nopl/OrgArt.html)
  debug(inspector_gui(on))[artifact_id(OrganizationalArtifactId)]. 

/* 
 * Plan for reacting to the addition of the belief play(Ag, Role, GroupId)
 * Triggering event: addition of belief play(Ag, Role, GroupId)
 * Context: true (the plan is always applicable)
 * Body: the agent announces that it observed that agent Ag adopted role Role in the group GroupId.
 * The belief is added when a Group Board artifact (https://moise.sourceforge.net/doc/api/ora4mas/nopl/GroupBoard.html)
 * emmits an observable event play(Ag, Role, GroupId)
*/
@play_plan
+play(Ag, Role, GroupId) : true <-
  .print("Agent ", Ag, " adopted the role ", Role, " in group ", GroupId).

/* 
 * Plan for trying to join a workspace
 * Triggering event: addition of goal !try_join_workspace(OrgName, OrgWsp)
 * Context: true (the plan is always applicable)
 * Body: tries to join the workspace, creates it if it doesn't exist
*/
+!try_join_workspace(OrgName, OrgWsp) : true <-
  joinWorkspace(OrgName, OrgWsp).
-!try_join_workspace(OrgName, OrgWsp) : true <-
  .print("Workspace not found, creating it...");
  createWorkspace(OrgName);
  joinWorkspace(OrgName, OrgWsp).

/* 
 * Plan for trying to look up an organization artifact
 * Triggering event: addition of goal !try_lookup_org_artifact(OrgName, OrgWsp, OrgArtId)
 * Context: true (the plan is always applicable)
 * Body: tries to look up the organization artifact, creates it if it doesn't exist
*/
+!try_lookup_org_artifact(OrgName, OrgWsp, OrgArtId) : true <-
  lookupArtifact(OrgName, OrgArtId).
-!try_lookup_org_artifact(OrgName, OrgWsp, OrgArtId) : true <-
  .print("Organization artifact not found, creating it...");
  makeArtifact(OrgName, "ora4mas.nopl.OrgBoard", ["src/org/org-spec.xml"], OrgArtId)[wid(OrgWsp)].

/* 
 * Plan for trying to look up a group artifact
 * Triggering event: addition of goal !try_lookup_group_artifact(GroupName, OrgName, OrgArtId, GroupArtId)
 * Context: true (the plan is always applicable)
 * Body: tries to look up the group artifact, creates it if it doesn't exist
*/
+!try_lookup_group_artifact(GroupName, OrgName, OrgArtId, GroupArtId) : true <-
  lookupArtifact(GroupName, GroupArtId).
-!try_lookup_group_artifact(GroupName, OrgName, OrgArtId, GroupArtId) : true <-
  .print("Group artifact not found, creating it...");
  createGroup(GroupName, GroupName, OrgArtId, GroupArtId).

/* 
 * Plan for trying to look up a scheme artifact
 * Triggering event: addition of goal !try_lookup_scheme_artifact(SchemeName, OrgName, OrgArtId, SchemeArtId)
 * Context: true (the plan is always applicable)
 * Body: tries to look up the scheme artifact, creates it if it doesn't exist
*/
+!try_lookup_scheme_artifact(SchemeName, OrgName, OrgArtId, SchemeArtId) : true <-
  lookupArtifact(SchemeName, SchemeArtId).
-!try_lookup_scheme_artifact(SchemeName, OrgName, OrgArtId, SchemeArtId) : true <-
  .print("Scheme artifact not found, creating it...");
  createScheme(SchemeName, SchemeName, OrgArtId, SchemeArtId).

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }

/* Import behavior of agents that work in MOISE organizations */
{ include("$jacamoJar/templates/common-moise.asl") }

/* Import behavior of agents that reason on MOISE organizations */
{ include("$moiseJar/asl/org-rules.asl") }