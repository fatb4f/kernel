package admission

#Field: {
	name:         string
	type:         "string" | "integer" | "number" | "boolean" | "object" | "array"
	required?:    bool
	items_type?:  "string" | "integer" | "number" | "boolean" | "object"
	description?: string
}

#Structure: {
	name: string
	kind: "object"
	fields: [...#Field] & [#Field, ...#Field]
}

#Constraint: {
	id:               string
	subject:          string
	constraint_class: string
	loss_policy:      "must_not_silently_drop" | "annotation_only" | "best_effort"
	predicate?:       string
	notes?:           string
}

#Normalized: {
	artifact_type:      "kernel.reviewed_structural_draft"
	artifact_version:   string
	draft_id:           string
	title:              string
	contract_format:    "json_structure"
	source_policy_ref?: string
	structures: [...#Structure] & [#Structure, ...#Structure]
	constraints?: [...#Constraint]
	normalization?: {
		normalized_at: string
		source_ref:    string
		policy_ref:    string
		classification: {
			contract_surface: string
			next_surface:     string
		}
	}
}
