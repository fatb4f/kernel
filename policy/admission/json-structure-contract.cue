package admission

#Field: {
	name:        string
	type:        "string" | "integer" | "number" | "boolean" | "array"
	required:    bool
	items_type?: "string" | "integer" | "number" | "boolean"
	description?: string
	if type == "array" {
		items_type: _
	}
}

#Structure: {
	name:   string
	kind:   "object"
	fields: [...#Field] & [_, ...]
}

#Constraint: {
	id:               string
	subject:          string
	constraint_class: "conditional_presence" | "enum_membership" | "range" | "format"
	predicate?:       string
	loss_policy:      "must_not_silently_drop" | "report_if_externalized"
	notes?:           string
}

#AuthorityBinding: {
	canonical_model_role: "normative_contract"
	serialization_role:   "first_authored_surface"
}

#Normalized: {
	artifact_type:          "kernel.json_structure_contract"
	artifact_version:       string
	contract_id:            string
	title:                  string
	serialization_surface:  "json_structure"
	source_policy_ref:      "policy/kernel/prose-contract-workflow.index.json"
	source_reviewed_draft_ref?: string
	authority_binding:      #AuthorityBinding
	structures:             [...#Structure] & [_, ...]
	constraints:            [...#Constraint]
	normalization?: {
		normalized_at: string
		source_ref:    string
		policy_ref:    "policy/kernel/prose-contract-workflow.index.json"
		classification: {
			contract_surface: "json_structure_contract"
			next_surface:     "normalized_state"
		}
	}
	admission?: {
		decision:         "ALLOW"
		policy_bundle_id: "policy/admission/json-structure-contract.cue"
		admitted_at:      string
	}
}
