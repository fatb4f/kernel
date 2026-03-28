package admission

#StringList: [...string] & [string, ...string]

#ScopeControls: {
	target_repos?:            [...string]
	forbidden_repos?:         [...string]
	target_surfaces?:         [...string]
	forbidden_surfaces?:      [...string]
	target_artifact_classes?: [...string]
	forbidden_artifact_classes?: [...string]
}

#Handoff: {
	issue_title_prefix?: string
	labels?:             [...string]
	assignees?:          [...string]
}

#Fingerprint: {
	algorithm: "sha256"
	value:     string & != ""
}

#Normalized: {
	kind:           "kernel.problem_set"
	problem_set_id: string & =~"^ps-"
	version:        string & != ""
	status:         "draft" | "active" | "deprecated" | "archived"
	identity: {
		name:   string & != ""
		title:  string & != ""
		owners?: [...string]
	}
	objective: string & != ""
	scope: {
		in_scope:     #StringList
		out_of_scope: [...string]
	}
	constraints:         [...string]
	assumptions:         [...string]
	requested_outputs:   #StringList
	authority_refs:      #StringList
	acceptance_criteria: #StringList
	review_criteria?:    [...string]
	scope_controls?:     #ScopeControls
	handoff?:            #Handoff
	change_control: {
		normalized_json: true
		stale_when:      [...string]
	}
	fingerprint: #Fingerprint
	normalization?: {
		normalized_at: string & != ""
		source_ref:    string & != ""
		policy:        string & != ""
	}
}
