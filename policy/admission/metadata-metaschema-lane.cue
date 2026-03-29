package admission

#EntryClass: "schema_surface" | "workflow_rule" | "dependency_rule"

#Entry: {
	entry_id:    string
	entry_class: #EntryClass
	summary:     string
	source_refs: [...string] & [string, ...string]
	authority_role: "contract_surface" | "derived" | "non_authoritative"
}

#LaneOrder: {
	semantic_authority_lane: "metaschema_model"
	allowed_edges: [...{
		from:     string
		to:       string
		relation: string
	}] & [{
		from:     string
		to:       string
		relation: string
	}, ...]
	forbidden_edges: [...{
		from:     string
		to:       string
		relation: string
	}] & [{
		from:     string
		to:       string
		relation: string
	}, ...]
}

#Normalized: {
	kind:                    "kernel.metadata_metaschema_lane.slice_input"
	control_object_id:       "metadata-metaschema-lane"
	source_module_id:        "metadata-metaschema-lane"
	source_module_ref:       "structures/extensions/metadata-metaschema-lane.module.json"
	kernel_policy_ref:       "policy/kernel/metadata-metaschema-lane.index.json"
	contract_note_ref:       "policy/contracts/metadata-metaschema-lane.md"
	lane_dependency_ref:     "policy/data/metadata-lane-dependency.index.json"
	export_schema_ref:       "schemas/exported/metadata-metaschema-lane-input.schema.json"
	generator_ref:           "manifests/generators/metadata-metaschema-lane.generator.json"
	projection_ref:          "manifests/projections/metadata-metaschema-lane.projection.json"
	output_path:             "generated/registries/metadata-metaschema-lane.index.json"
	authoritative_middle:    "canonical_semantic_model"
	entries:                 [...#Entry] & [#Entry, ...#Entry]
	lane_order:              #LaneOrder
	render_contract: {
		renderer:     "jsonnet"
		input_class:  "admitted_state"
		output_class: "registry"
		runtime:      string
		runtime_path: string
	}
}
